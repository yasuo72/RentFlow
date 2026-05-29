import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/room_model.dart';
import '../../data/models/tenant_model.dart';
import '../dashboard/dashboard_provider.dart';
import '../expenses/expenses_provider.dart';
import '../payments/payments_provider.dart';
import '../rooms/rooms_provider.dart';
import '../tenants/tenants_provider.dart';
import 'voice_command_parser.dart';

Future<void> showVoiceCommandSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => VoiceCommandSheet(
      onNavigate: (route) {
        Navigator.of(sheetContext).pop();
        Future.microtask(() {
          if (context.mounted) {
            _navigateAfterVoice(context, route);
          }
        });
      },
    ),
  );
}

void _navigateAfterVoice(BuildContext context, String route) {
  final uri = Uri.tryParse(route);
  final path = uri?.path ?? route;
  const shellTabs = {
    '/dashboard',
    '/rooms',
    '/payments',
    '/expenses',
    '/settings',
  };

  if (shellTabs.contains(path)) {
    context.go(route);
    return;
  }

  context.push(route);
}

int? _pendingMonthFilterThreshold(String filter) {
  final match = RegExp(r'^months_pending_(\d+)$').firstMatch(filter);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!);
}

class VoiceCommandSheet extends ConsumerStatefulWidget {
  const VoiceCommandSheet({required this.onNavigate, super.key});

  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

class _VoiceCommandSheetState extends ConsumerState<VoiceCommandSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  bool _saving = false;
  bool _localeInitialized = false;
  String _localeId = 'hi_IN';
  String _transcript = '';
  String? _error;
  VoiceCommandIntent? _intent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localeInitialized) {
      return;
    }
    _localeInitialized = true;
    _localeId = Localizations.localeOf(context).languageCode == 'hi'
        ? 'hi_IN'
        : 'en_IN';
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider);
    final tenants = ref.watch(tenantsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      child: rooms.when(
        data: (roomList) => tenants.when(
          data: (tenantList) => _content(context, roomList, tenantList),
          loading: () => const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => AppEmptyState(
            title: 'Voice assistant not ready',
            message: 'Tenants could not be loaded: $error',
            icon: Icons.mic_off_rounded,
          ),
        ),
        loading: () => const SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => AppEmptyState(
          title: 'Voice assistant not ready',
          message: 'Rooms could not be loaded: $error',
          icon: Icons.mic_off_rounded,
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<RoomModel> rooms,
    List<TenantModel> tenants,
  ) {
    final intent = _intent;
    final canExecute = intent?.canExecute ?? false;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppSectionTitle(
            eyebrow: 'Hindi + English',
            title: 'Voice assistant',
            subtitle:
                'Say rent updates naturally. We will preview before saving.',
            action: _LanguageToggle(
              localeId: _localeId,
              onChanged: (value) => setState(() => _localeId = value),
            ),
          ),
          const SizedBox(height: 18),
          _MicPanel(
            listening: _listening,
            transcript: _transcript,
            error: _error,
            onTap: _listening
                ? _stopListening
                : () => _startListening(rooms, tenants),
          ),
          const SizedBox(height: 14),
          if (intent != null)
            _IntentPreview(
              intent: intent,
              onChangeRoom: () => _showRoomPicker(rooms),
              matchingRooms: _roomsForFilter(rooms, intent.roomFilter),
            )
          else
            const _VoiceExamples(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _speech.stop();
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: !_saving && canExecute
                      ? () => _executeIntent(intent!)
                      : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_buttonLabel(intent)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startListening(
    List<RoomModel> rooms,
    List<TenantModel> tenants,
  ) async {
    setState(() {
      _error = null;
      _transcript = '';
      _intent = null;
    });

    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) {
            return;
          }
          setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _listening = false;
            _error = error.errorMsg;
          });
        },
      );
    }

    if (!_speechReady) {
      setState(() {
        _error = 'Microphone is not available or permission was denied.';
      });
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }
        final words = result.recognizedWords.trim();
        setState(() {
          _transcript = words;
          _intent = VoiceCommandParser.parse(
            transcript: words,
            rooms: rooms,
            tenants: tenants,
          );
          if (result.finalResult) {
            _listening = false;
          }
        });
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: _localeId,
        listenFor: const Duration(seconds: 18),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _listening = false);
    }
  }

  Future<void> _executeIntent(VoiceCommandIntent intent) async {
    setState(() => _saving = true);

    try {
      switch (intent.type) {
        case VoiceCommandType.recordPayment:
          await _recordPayment(intent);
          break;
        case VoiceCommandType.addDue:
          await _addDue(intent);
          break;
        case VoiceCommandType.addExpense:
          await _addExpense(intent);
          break;
        case VoiceCommandType.navigate:
          widget.onNavigate(intent.route!);
          return;
        case VoiceCommandType.showRooms:
          widget.onNavigate(
            intent.route ?? '/rooms?filter=${intent.roomFilter}',
          );
          return;
        case VoiceCommandType.openDocument:
          widget.onNavigate(_documentRoute(intent.document!, intent.tenant));
          return;
        case VoiceCommandType.uploadDocument:
          widget.onNavigate(intent.route!);
          return;
        case VoiceCommandType.sendWhatsAppReminder:
          await _sendWhatsAppReminder(intent);
          return;
        case VoiceCommandType.callTenant:
          await _callTenant(intent);
          return;
        case VoiceCommandType.unknown:
          throw Exception(intent.message ?? 'Command not understood.');
      }

      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(_successMessage(intent))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _recordPayment(VoiceCommandIntent intent) async {
    final room = intent.room!;
    final tenant = room.currentTenant;
    if (tenant == null) {
      throw Exception('Room ${room.roomNumber} has no tenant.');
    }

    await ref.read(paymentsProvider.notifier).recordPayment({
      'tenant': tenant.id,
      'room': room.id,
      'month': AppDateUtils.currentMonthLabel(),
      'year': DateTime.now().year,
      'amountPaid': intent.amount,
      'manualDueAmount': 0,
      'paymentMethod': intent.paymentMethod,
      'paymentDate': DateTime.now().toIso8601String(),
      'remark': 'Voice command: ${intent.transcript}',
    });
    ref.invalidate(tenantsProvider);
  }

  Future<void> _addDue(VoiceCommandIntent intent) async {
    final room = intent.room!;
    final tenant = room.currentTenant;
    if (tenant == null) {
      throw Exception('Room ${room.roomNumber} has no tenant.');
    }

    await ref.read(paymentsProvider.notifier).recordPayment({
      'tenant': tenant.id,
      'room': room.id,
      'month': AppDateUtils.currentMonthLabel(),
      'year': DateTime.now().year,
      'amountPaid': 0,
      'manualDueAmount': intent.amount,
      'manualDueRemark': 'Voice due: ${intent.transcript}',
      'paymentMethod': 'cash',
      'paymentDate': DateTime.now().toIso8601String(),
      'remark': 'Voice due added',
    });
    ref.invalidate(tenantsProvider);
  }

  Future<void> _addExpense(VoiceCommandIntent intent) async {
    await ref.read(expensesProvider.notifier).addExpense({
      'category': intent.expenseCategory,
      'amount': intent.amount,
      'description': 'Voice command: ${intent.transcript}',
      'date': DateTime.now().toIso8601String(),
    });
    ref.invalidate(dashboardProvider);
  }

  Future<void> _callTenant(VoiceCommandIntent intent) async {
    final phone = intent.tenant!.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final launched = await launchUrlString('tel:$phone');
    if (!launched) {
      throw Exception('Could not open dialer for ${intent.tenant!.fullName}.');
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _sendWhatsAppReminder(VoiceCommandIntent intent) async {
    final tenant = intent.tenant!;
    final phone = _whatsAppPhone(tenant);
    if (phone.isEmpty) {
      throw Exception('WhatsApp number is missing for ${tenant.fullName}.');
    }

    final message = _rentReminderMessage(intent);
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    final launched = await launchUrlString(url);
    if (!launched) {
      throw Exception('Could not open WhatsApp for ${tenant.fullName}.');
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  String _whatsAppPhone(TenantModel tenant) {
    final raw =
        (tenant.whatsappNumber?.trim().isNotEmpty == true
                ? tenant.whatsappNumber!
                : tenant.phone)
            .trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10) {
      return '91$digits';
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return '91${digits.substring(1)}';
    }
    return digits;
  }

  String _rentReminderMessage(VoiceCommandIntent intent) {
    final tenant = intent.tenant!;
    final snapshot = tenant.currentMonthPayment;
    final amount =
        intent.amount ??
        snapshot?.remainingAmount ??
        snapshot?.totalDue ??
        tenant.room?.monthlyRent ??
        0;
    final roomNumber = tenant.room?.roomNumber ?? '-';
    final monthlyRent =
        snapshot?.monthlyRentDue ?? tenant.room?.monthlyRent ?? 0;
    final carriedForward = snapshot?.carriedForwardAmount ?? 0;
    final manualDue = snapshot?.manualDueAmount ?? 0;
    final paidSoFar = snapshot?.amountPaid ?? 0;
    final totalDue = snapshot?.totalDue ?? amount;
    final remaining = amount;
    final status = paidSoFar > 0 && remaining > 0
        ? 'PARTIAL'
        : remaining <= 0
        ? 'PAID'
        : 'PENDING';

    final buffer = StringBuffer()
      ..writeln('*RentFlow Rent Reminder*')
      ..writeln()
      ..writeln('Namaste ${tenant.fullName} ji,')
      ..writeln()
      ..writeln('*Room:* $roomNumber')
      ..writeln('*Month:* ${AppDateUtils.currentMonthLabel()}')
      ..writeln('*Status:* $status')
      ..writeln()
      ..writeln('*Rent Breakdown*')
      ..writeln('Monthly rent: ${CurrencyFormatter.inr(monthlyRent)}');

    if (carriedForward > 0) {
      buffer.writeln(
        'Previous pending: ${CurrencyFormatter.inr(carriedForward)}',
      );
    }

    if (manualDue > 0) {
      buffer.writeln('Extra due: ${CurrencyFormatter.inr(manualDue)}');
    }

    if (paidSoFar > 0) {
      buffer.writeln('Paid so far: ${CurrencyFormatter.inr(paidSoFar)}');
    }

    buffer
      ..writeln('Total payable: ${CurrencyFormatter.inr(totalDue)}')
      ..writeln('Remaining: *${CurrencyFormatter.inr(remaining)}*')
      ..writeln()
      ..writeln('*Payment QR:*')
      ..writeln(AppStrings.paymentQrPublicUrl)
      ..writeln()
      ..writeln('Kripya payment kar dein.')
      ..writeln('Upar diya QR scan karke payment kar sakte hain.')
      ..writeln()
      ..writeln('_RentFlow - Family Rent Manager_');

    return buffer.toString();
  }

  Future<void> _showRoomPicker(List<RoomModel> rooms) async {
    final selected = await showModalBottomSheet<RoomModel>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final room in rooms.where((room) => room.isOccupied))
              ListTile(
                leading: CircleAvatar(child: Text(room.roomNumber)),
                title: Text('Room ${room.roomNumber}'),
                subtitle: Text(room.currentTenant?.fullName ?? 'No tenant'),
                onTap: () => Navigator.of(context).pop(room),
              ),
          ],
        ),
      ),
    );

    if (selected == null || _intent == null) {
      return;
    }

    setState(() {
      _intent = VoiceCommandIntent(
        type: _intent!.type,
        transcript: _intent!.transcript,
        room: selected,
        amount: _intent!.amount,
        paymentMethod: _intent!.paymentMethod,
        expenseCategory: _intent!.expenseCategory,
        roomFilter: _intent!.roomFilter,
        tenant: _intent!.tenant,
        document: _intent!.document,
        documentType: _intent!.documentType,
        route: _intent!.route,
        message: _intent!.amount == null ? _intent!.message : '',
      );
    });
  }

  List<RoomModel> _roomsForFilter(List<RoomModel> rooms, String filter) {
    return rooms
        .where((room) {
          final monthThreshold = _pendingMonthFilterThreshold(filter);
          return monthThreshold != null
              ? _isPendingByMonthThreshold(room, monthThreshold)
              : switch (filter) {
                  'occupied' => room.status == 'occupied',
                  'vacant' => room.status == 'vacant',
                  'pending' =>
                    room.currentMonthStatus == 'pending' ||
                        room.currentMonthStatus == 'partial',
                  'two_month_pending' => _isPendingByMonthThreshold(room, 2),
                  'low_deposit' =>
                    room.isOccupied && room.depositAmount < room.monthlyRent,
                  'oldest_tenant' => room.isOccupied,
                  'missing_documents' =>
                    room.isOccupied &&
                        (room.currentTenant?.documents.isEmpty ?? true),
                  _ => true,
                };
        })
        .toList(growable: false)
      ..sort((a, b) {
        if (filter != 'oldest_tenant') {
          return 0;
        }
        final left = a.currentTenant?.joiningDate;
        final right = b.currentTenant?.joiningDate;
        if (left == null && right == null) {
          return a.roomNumber.compareTo(b.roomNumber);
        }
        if (left == null) {
          return 1;
        }
        if (right == null) {
          return -1;
        }
        return left.compareTo(right);
      });
  }

  bool _isPendingByMonthThreshold(RoomModel room, int monthThreshold) {
    if (!room.isOccupied) {
      return false;
    }
    final threshold = monthThreshold.clamp(1, 12);
    final payment = room.currentMonthPayment;
    final remaining = payment?.remainingAmount ?? 0;
    final carried = payment?.carriedForwardAmount ?? 0;
    final rent = room.monthlyRent <= 0 ? 1 : room.monthlyRent;
    return remaining >= rent * threshold || carried >= rent * threshold;
  }

  String _documentRoute(TenantDocument document, TenantModel? tenant) {
    final title = [
      if ((tenant?.fullName ?? '').isNotEmpty) tenant!.fullName,
      if (document.name.isNotEmpty) document.name else document.type,
    ].join(' - ');

    return Uri(
      path: _isImageDocument(document) ? '/viewer/image' : '/viewer/pdf',
      queryParameters: {'url': document.url, 'title': title},
    ).toString();
  }

  bool _isImageDocument(TenantDocument document) {
    final url = document.url.toLowerCase();
    final type = document.type.toLowerCase();
    return type == 'photo' ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp');
  }

  String _buttonLabel(VoiceCommandIntent? intent) {
    if (_saving) {
      return 'Saving';
    }
    return switch (intent?.type) {
      VoiceCommandType.navigate => 'Open',
      VoiceCommandType.showRooms => 'Show rooms',
      VoiceCommandType.openDocument => 'Open document',
      VoiceCommandType.uploadDocument => 'Upload',
      VoiceCommandType.sendWhatsAppReminder => 'WhatsApp',
      VoiceCommandType.callTenant => 'Call',
      VoiceCommandType.addExpense => 'Save expense',
      VoiceCommandType.addDue => 'Add due',
      VoiceCommandType.recordPayment => 'Save rent',
      _ => 'Confirm',
    };
  }

  String _successMessage(VoiceCommandIntent intent) {
    return switch (intent.type) {
      VoiceCommandType.addExpense =>
        'Expense ${CurrencyFormatter.inr(intent.amount!)} saved.',
      VoiceCommandType.addDue =>
        'Due ${CurrencyFormatter.inr(intent.amount!)} added.',
      VoiceCommandType.recordPayment =>
        'Rent ${CurrencyFormatter.inr(intent.amount!)} recorded.',
      VoiceCommandType.callTenant => 'Opening phone dialer.',
      VoiceCommandType.openDocument => 'Opening document.',
      VoiceCommandType.uploadDocument => 'Opening upload page.',
      VoiceCommandType.sendWhatsAppReminder => 'Opening WhatsApp.',
      VoiceCommandType.showRooms => 'Opening rooms.',
      VoiceCommandType.navigate => 'Opening screen.',
      VoiceCommandType.unknown => 'Done.',
    };
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }

      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return 'Server rejected this command with status $statusCode. Please check room, tenant, and amount.';
      }

      return 'Could not reach the server. Check internet and try again.';
    }

    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.localeId, required this.onChanged});

  final String localeId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'hi_IN', label: Text('HI')),
        ButtonSegment(value: 'en_IN', label: Text('EN')),
      ],
      selected: {localeId},
      showSelectedIcon: false,
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

class _MicPanel extends StatelessWidget {
  const _MicPanel({
    required this.listening,
    required this.transcript,
    required this.error,
    required this.onTap,
  });

  final bool listening;
  final String transcript;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.info.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: listening ? 86 : 76,
              height: listening ? 86 : 76,
              decoration: BoxDecoration(
                color: listening ? AppColors.danger : AppColors.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (listening ? AppColors.danger : AppColors.primary)
                        .withValues(alpha: 0.34),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            listening ? 'Listening...' : 'Tap mic and speak',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            transcript.isEmpty
                ? 'Try: "Room 101 ka 2500 cash rent add karo"'
                : transcript,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntentPreview extends StatelessWidget {
  const _IntentPreview({
    required this.intent,
    required this.onChangeRoom,
    required this.matchingRooms,
  });

  final VoiceCommandIntent intent;
  final VoidCallback onChangeRoom;
  final List<RoomModel> matchingRooms;

  @override
  Widget build(BuildContext context) {
    final color = switch (intent.type) {
      VoiceCommandType.addDue => AppColors.warning,
      VoiceCommandType.addExpense => AppColors.danger,
      VoiceCommandType.navigate ||
      VoiceCommandType.showRooms ||
      VoiceCommandType.openDocument ||
      VoiceCommandType.uploadDocument ||
      VoiceCommandType.sendWhatsAppReminder ||
      VoiceCommandType.callTenant => AppColors.info,
      VoiceCommandType.recordPayment => AppColors.accent,
      VoiceCommandType.unknown => AppColors.danger,
    };

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionTitle(
            title: _titleFor(intent),
            subtitle: intent.message?.isNotEmpty == true
                ? intent.message
                : null,
            action: StatusBadge(label: _typeLabel(intent.type), color: color),
          ),
          const SizedBox(height: 12),
          if (intent.room != null)
            _PreviewRow(
              label: 'Room',
              value:
                  '${intent.room!.roomNumber} | ${intent.room!.currentTenant?.fullName ?? 'No tenant'}',
            ),
          if (intent.room == null &&
              (intent.type == VoiceCommandType.recordPayment ||
                  intent.type == VoiceCommandType.addDue))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onChangeRoom,
                icon: const Icon(Icons.meeting_room_rounded),
                label: const Text('Select room manually'),
              ),
            ),
          if (intent.amount != null)
            _PreviewRow(
              label: 'Amount',
              value: CurrencyFormatter.inr(intent.amount!),
            ),
          if (intent.type == VoiceCommandType.recordPayment)
            _PreviewRow(
              label: 'Method',
              value: intent.paymentMethod.replaceAll('_', ' ').toUpperCase(),
            ),
          if (intent.type == VoiceCommandType.addExpense)
            _PreviewRow(
              label: 'Category',
              value: intent.expenseCategory.toUpperCase(),
            ),
          if (intent.type == VoiceCommandType.navigate ||
              intent.type == VoiceCommandType.showRooms)
            _PreviewRow(label: 'Open', value: intent.route ?? '-'),
          if (intent.type == VoiceCommandType.showRooms) ...[
            _PreviewRow(
              label: 'Matched',
              value: '${matchingRooms.length} rooms',
            ),
            if (matchingRooms.isNotEmpty)
              Text(
                matchingRooms
                    .take(4)
                    .map(
                      (room) =>
                          'Room ${room.roomNumber} - ${room.currentTenant?.fullName ?? room.status}${_roomHint(intent.roomFilter, room)}',
                    )
                    .join('\n'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          if (intent.type == VoiceCommandType.openDocument) ...[
            _PreviewRow(
              label: 'Tenant',
              value: intent.tenant?.fullName ?? 'Not found',
            ),
            _PreviewRow(
              label: 'Document',
              value: intent.document?.name.isNotEmpty == true
                  ? intent.document!.name
                  : intent.documentType ?? 'Document not uploaded',
            ),
          ],
          if (intent.type == VoiceCommandType.uploadDocument) ...[
            _PreviewRow(
              label: 'Tenant',
              value: intent.tenant?.fullName ?? 'Not found',
            ),
            _PreviewRow(
              label: 'Default type',
              value: (intent.documentType ?? 'other').toUpperCase(),
            ),
          ],
          if (intent.type == VoiceCommandType.sendWhatsAppReminder) ...[
            _PreviewRow(
              label: 'Tenant',
              value: intent.tenant?.fullName ?? 'Not found',
            ),
            _PreviewRow(
              label: 'WhatsApp',
              value: intent.tenant?.whatsappNumber?.isNotEmpty == true
                  ? intent.tenant!.whatsappNumber!
                  : intent.tenant?.phone ?? '-',
            ),
            _PreviewRow(
              label: 'Message',
              value: intent.tenant == null ? '-' : _reminderPreviewText(intent),
            ),
          ],
          if (intent.type == VoiceCommandType.callTenant) ...[
            _PreviewRow(
              label: 'Tenant',
              value: intent.tenant?.fullName ?? 'Not found',
            ),
            _PreviewRow(label: 'Phone', value: intent.tenant?.phone ?? '-'),
          ],
        ],
      ),
    );
  }

  String _titleFor(VoiceCommandIntent intent) {
    if (intent.type == VoiceCommandType.showRooms) {
      final monthThreshold = _pendingMonthFilterThreshold(intent.roomFilter);
      if (monthThreshold != null) {
        return 'Show $monthThreshold+ month pending rooms?';
      }

      return switch (intent.roomFilter) {
        'pending' => 'Show pending rent rooms?',
        'two_month_pending' => 'Show 2+ month pending rooms?',
        'low_deposit' => 'Show low deposit tenants?',
        'oldest_tenant' => 'Show oldest tenants?',
        'missing_documents' => 'Show missing tenant documents?',
        'occupied' => 'Show occupied rooms?',
        'vacant' => 'Show vacant rooms?',
        _ => 'Show matching rooms?',
      };
    }

    return switch (intent.type) {
      VoiceCommandType.recordPayment => 'Record rent payment?',
      VoiceCommandType.addDue => 'Add old due?',
      VoiceCommandType.addExpense => 'Save expense?',
      VoiceCommandType.navigate => 'Open screen?',
      VoiceCommandType.showRooms => 'Show matching rooms?',
      VoiceCommandType.openDocument => 'Open tenant document?',
      VoiceCommandType.uploadDocument => 'Open document upload?',
      VoiceCommandType.sendWhatsAppReminder => 'Send WhatsApp reminder?',
      VoiceCommandType.callTenant => 'Call tenant?',
      VoiceCommandType.unknown => 'Command not understood',
    };
  }

  String _typeLabel(VoiceCommandType type) {
    return switch (type) {
      VoiceCommandType.recordPayment => 'RENT',
      VoiceCommandType.addDue => 'DUE',
      VoiceCommandType.addExpense => 'EXPENSE',
      VoiceCommandType.navigate => 'OPEN',
      VoiceCommandType.showRooms => 'ROOMS',
      VoiceCommandType.openDocument => 'DOC',
      VoiceCommandType.uploadDocument => 'UPLOAD',
      VoiceCommandType.sendWhatsAppReminder => 'WA',
      VoiceCommandType.callTenant => 'CALL',
      VoiceCommandType.unknown => 'CHECK',
    };
  }

  String _roomHint(String filter, RoomModel room) {
    if (_pendingMonthFilterThreshold(filter) != null) {
      return ' | Due ${CurrencyFormatter.inr(room.currentMonthPayment?.remainingAmount ?? 0)}';
    }

    return switch (filter) {
      'low_deposit' =>
        ' | Deposit ${CurrencyFormatter.inr(room.depositAmount)}',
      'oldest_tenant' =>
        room.currentTenant?.joiningDate == null
            ? ''
            : ' | Since ${AppDateUtils.formatDate(room.currentTenant!.joiningDate!)}',
      'missing_documents' => ' | No docs',
      'two_month_pending' =>
        ' | Due ${CurrencyFormatter.inr(room.currentMonthPayment?.remainingAmount ?? 0)}',
      'pending' =>
        ' | Due ${CurrencyFormatter.inr(room.currentMonthPayment?.remainingAmount ?? room.monthlyRent)}',
      _ => '',
    };
  }

  String _reminderPreviewText(VoiceCommandIntent intent) {
    final tenant = intent.tenant!;
    final amount =
        intent.amount ??
        tenant.currentMonthPayment?.remainingAmount ??
        tenant.currentMonthPayment?.totalDue ??
        tenant.room?.monthlyRent ??
        0;
    final roomNumber = tenant.room?.roomNumber ?? '-';
    final amountText = amount > 0 ? CurrencyFormatter.inr(amount) : 'rent';
    return 'Room $roomNumber | $amountText due';
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceExamples extends StatelessWidget {
  const _VoiceExamples();

  @override
  Widget build(BuildContext context) {
    const examples = [
      'Rohit ne kiraya de diya',
      'Room 101 ka 2500 cash rent add karo',
      'Aman ka 5000 due add karo',
      'Kaunse room ka rent pending hai?',
      'Kal kisko yaad dilana hai?',
      'Jiska rent 2 mahine se pending hai',
      'Jiska deposit kam hai',
      'Sabse purana tenant',
      'Madan ka document upload karna hai',
      'Rohit ka document dikhao',
      'Room 102 ka aadhaar dikhao',
      'Room 103 ka police verification upload karo',
      'Payment QR dikhao',
      'Rohit ka profile kholo',
      'Kaunse occupied room ke documents uploaded nahi hain?',
      'Ramesh ko reminder bhejo',
      'Prakash ko call lagao',
    ];

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'Example commands',
            subtitle: 'Hindi, Hinglish, and English are supported.',
          ),
          const SizedBox(height: 10),
          for (final example in examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(example)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

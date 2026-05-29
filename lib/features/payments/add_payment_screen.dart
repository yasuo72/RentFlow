import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/room_model.dart';
import '../auth/auth_provider.dart';
import '../rooms/rooms_provider.dart';
import 'payment_share_service.dart';
import 'payments_provider.dart';
import 'widgets/payment_qr_card.dart';

class AddPaymentScreen extends ConsumerStatefulWidget {
  const AddPaymentScreen({this.roomId, this.tenantId, super.key});

  final String? roomId;
  final String? tenantId;

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _manualDueController = TextEditingController();
  final _manualDueRemarkController = TextEditingController();
  final _remarkController = TextEditingController();
  final DateTime _paymentDate = DateTime.now();

  String _paymentMethod = 'cash';
  bool _showManualDue = false;
  RoomModel? _selectedRoom;

  @override
  void dispose() {
    _amountController.dispose();
    _manualDueController.dispose();
    _manualDueRemarkController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rooms = ref.watch(roomsProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tr('payments'))),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: !isOnline
              ? null
              : () => _savePayment(auth.user?.name ?? 'Family'),
          icon: const Icon(Icons.check_rounded),
          label: Text(isOnline ? 'Save payment' : 'No internet connection'),
        ),
      ),
      body: rooms.when(
        data: (roomList) {
          final occupiedRooms = roomList
              .where((room) => room.isOccupied)
              .toList();
          if (occupiedRooms.isEmpty) {
            return const Center(
              child: AppEmptyState(
                title: 'No occupied rooms available',
                message: 'Assign a tenant to a room before recording rent.',
                icon: Icons.meeting_room_outlined,
              ),
            );
          }

          _selectedRoom ??= occupiedRooms.firstWhere(
            (room) => room.id == widget.roomId,
            orElse: () => occupiedRooms.first,
          );

          final room = _selectedRoom!;
          final snapshot = room.currentMonthPayment;
          final monthlyRentDue = snapshot?.monthlyRentDue ?? room.monthlyRent;
          final carriedForward = snapshot?.carriedForwardAmount ?? 0;
          final existingManualDue = snapshot?.manualDueAmount ?? 0;
          final alreadyPaid = snapshot?.amountPaid ?? 0;
          final totalDueEstimate =
              snapshot?.totalDue ?? (monthlyRentDue + carriedForward);
          final outstanding = snapshot?.remainingAmount ?? totalDueEstimate;
          final payingNow = num.tryParse(_amountController.text) ?? 0;
          final manualDueToAdd = _showManualDue
              ? (num.tryParse(_manualDueController.text) ?? 0)
              : 0;
          final payableNow = outstanding + manualDueToAdd;
          final remaining = (payableNow - payingNow).clamp(0, payableNow);
          final advance = (payingNow - payableNow).clamp(0, payingNow);
          final updatedTotalDue = totalDueEstimate + manualDueToAdd;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
              children: [
                AppHeaderPanel(
                  title: 'Room ${room.roomNumber}',
                  subtitle:
                      '${room.currentTenant?.fullName ?? 'No tenant'} | ${room.building ?? 'Main'}${(room.floor ?? '').isNotEmpty ? ' | Floor ${room.floor}' : ''}',
                  trailing: StatusBadge(
                    label: advance > 0
                        ? 'ADVANCE'
                        : remaining == 0
                        ? 'READY TO CLOSE'
                        : 'PARTIAL DUE',
                    color: advance > 0
                        ? AppColors.info
                        : remaining == 0
                        ? AppColors.accent
                        : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        eyebrow: 'Payment context',
                        title: 'Rent details',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey(room.id),
                        initialValue: room.id,
                        decoration: const InputDecoration(
                          labelText: 'Select room',
                        ),
                        items: occupiedRooms
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  'Room ${item.roomNumber} | ${item.currentTenant?.fullName ?? 'Vacant'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _selectedRoom = occupiedRooms.firstWhere(
                              (item) => item.id == value,
                            );
                            _amountController.clear();
                            _manualDueController.clear();
                            _manualDueRemarkController.clear();
                            _showManualDue = false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Month',
                        value: AppDateUtils.currentMonthLabel(),
                      ),
                      _InfoRow(
                        label: 'Monthly rent',
                        value: CurrencyFormatter.inr(monthlyRentDue),
                      ),
                      _InfoRow(
                        label: 'Carried forward',
                        value: CurrencyFormatter.inr(carriedForward),
                      ),
                      _InfoRow(
                        label: 'Manual extra already added',
                        value: CurrencyFormatter.inr(existingManualDue),
                      ),
                      _InfoRow(
                        label: 'Already paid this month',
                        value: CurrencyFormatter.inr(alreadyPaid),
                      ),
                      _InfoRow(
                        label: 'Outstanding before today',
                        value: CurrencyFormatter.inr(outstanding),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionTitle(
                        eyebrow: 'Flexible dues',
                        title: 'Add old balance manually',
                        subtitle:
                            'Use this when old rent is not already carried forward.',
                        action: Switch(
                          value: _showManualDue,
                          onChanged: (value) {
                            setState(() {
                              _showManualDue = value;
                              if (!value) {
                                _manualDueController.clear();
                                _manualDueRemarkController.clear();
                              }
                            });
                          },
                        ),
                      ),
                      if (_showManualDue) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _manualDueController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (!_showManualDue ||
                                (value ?? '').trim().isEmpty) {
                              return null;
                            }
                            final parsed = num.tryParse(value!.trim());
                            if (parsed == null || parsed < 0) {
                              return 'Enter a valid extra due amount';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Manual extra due',
                            prefixText: '₹ ',
                            hintText: '2500',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _manualDueRemarkController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Reason',
                            hintText: 'Old pending rent for April',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickDueChip(
                              label: '1 month',
                              amount: room.monthlyRent,
                              onTap: () => _setManualDue(room.monthlyRent),
                            ),
                            _QuickDueChip(
                              label: '2 months',
                              amount: room.monthlyRent * 2,
                              onTap: () => _setManualDue(room.monthlyRent * 2),
                            ),
                            _QuickDueChip(
                              label: '3 months',
                              amount: room.monthlyRent * 3,
                              onTap: () => _setManualDue(room.monthlyRent * 3),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        eyebrow: 'Amount received',
                        title: 'Enter today\'s payment',
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                '\u20B9',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                validator: Validators.amount,
                                onChanged: (_) => setState(() {}),
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(fontSize: 34),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PreviewBanner(
                        totalDue: updatedTotalDue,
                        payableNow: payableNow,
                        manualDueToAdd: manualDueToAdd,
                        alreadyPaid: alreadyPaid,
                        payingNow: payingNow,
                        remaining: remaining,
                        advance: advance,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        eyebrow: 'Payment method',
                        title: 'How was it paid?',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final method in const [
                            ('cash', 'Cash', Icons.payments_rounded),
                            ('upi', 'UPI', Icons.phone_android_rounded),
                            (
                              'bank_transfer',
                              'Bank',
                              Icons.account_balance_rounded,
                            ),
                            ('card', 'Card', Icons.credit_card_rounded),
                            ('other', 'Other', Icons.more_horiz_rounded),
                          ])
                            _MethodChip(
                              label: method.$2,
                              icon: method.$3,
                              selected: _paymentMethod == method.$1,
                              onTap: () => setState(() {
                                _paymentMethod = method.$1;
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        eyebrow: 'Remark',
                        title: 'Add context for the family',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Partial now, rest by 10th...',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PaymentQrCard(
                  heroTag: 'add-payment-qr-hero',
                  onOpen: () => context.push('/payment-qr'),
                ),
                const SizedBox(height: 12),
                Text(
                  '${l10n.tr('paymentDate')}: ${AppDateUtils.formatDate(_paymentDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: AppEmptyState(
            title: 'Unable to prepare payment form',
            message: '$error',
            icon: Icons.cloud_off_rounded,
          ),
        ),
      ),
    );
  }

  Future<void> _savePayment(String recordedBy) async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate() || _selectedRoom == null) {
      return;
    }

    final room = _selectedRoom!;
    final amountPaid = num.parse(_amountController.text);
    final manualDueAmount = _showManualDue
        ? (num.tryParse(_manualDueController.text.trim()) ?? 0)
        : 0;

    final payment = await ref.read(paymentsProvider.notifier).recordPayment({
      'tenant': room.currentTenant?.id,
      'room': room.id,
      'month': AppDateUtils.currentMonthLabel(),
      'year': DateTime.now().year,
      'amountPaid': amountPaid,
      'manualDueAmount': manualDueAmount,
      'manualDueRemark': _manualDueRemarkController.text.trim(),
      'paymentMethod': _paymentMethod,
      'paymentDate': _paymentDate.toIso8601String(),
      'remark': _remarkController.text.trim(),
    });

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SuccessSheet(
        payment: payment,
        recordedBy: recordedBy,
        onRecordAnother: () {
          Navigator.of(context).pop();
          _amountController.clear();
          _manualDueController.clear();
          _manualDueRemarkController.clear();
          _remarkController.clear();
          _showManualDue = false;
          setState(() {});
        },
      ),
    );
  }

  void _setManualDue(num amount) {
    _manualDueController.text = amount.toInt().toString();
    setState(() {});
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({
    required this.totalDue,
    required this.payableNow,
    required this.manualDueToAdd,
    required this.alreadyPaid,
    required this.payingNow,
    required this.remaining,
    required this.advance,
  });

  final num totalDue;
  final num payableNow;
  final num manualDueToAdd;
  final num alreadyPaid;
  final num payingNow;
  final num remaining;
  final num advance;

  @override
  Widget build(BuildContext context) {
    final clear = remaining == 0;
    final hasAdvance = advance > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasAdvance
            ? AppColors.info.withValues(alpha: 0.14)
            : clear
            ? AppColors.accentDim
            : AppColors.warningDim,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _InfoRow(label: 'Total due', value: CurrencyFormatter.inr(totalDue)),
          _InfoRow(
            label: 'Manual due added',
            value: CurrencyFormatter.inr(manualDueToAdd),
          ),
          _InfoRow(
            label: 'Already paid',
            value: CurrencyFormatter.inr(alreadyPaid),
          ),
          _InfoRow(
            label: 'Payable now',
            value: CurrencyFormatter.inr(payableNow),
          ),
          _InfoRow(
            label: 'Paying now',
            value: CurrencyFormatter.inr(payingNow),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Remaining',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                CurrencyFormatter.inr(remaining),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: clear ? AppColors.accent : AppColors.warning,
                ),
              ),
            ],
          ),
          if (hasAdvance) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Advance / extra paid',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  CurrencyFormatter.inr(advance),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.info),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickDueChip extends StatelessWidget {
  const _QuickDueChip({
    required this.label,
    required this.amount,
    required this.onTap,
  });

  final String label;
  final num amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.add_rounded, size: 16),
      label: Text('$label ${CurrencyFormatter.inr(amount)}'),
      onPressed: onTap,
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryDim
              : Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected
                  ? AppColors.primary
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({
    required this.payment,
    required this.recordedBy,
    required this.onRecordAnother,
  });

  final PaymentModel payment;
  final String recordedBy;
  final VoidCallback onRecordAnother;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: AppColors.accentDim,
              border: Border.all(color: AppColors.accent),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 42,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Payment recorded',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Receipt ${payment.receiptNumber}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          AppSectionCard(
            child: Column(
              children: [
                _InfoRow(label: 'Room', value: payment.room?.roomNumber ?? '-'),
                _InfoRow(
                  label: 'Tenant',
                  value: payment.tenant?.fullName ?? '-',
                ),
                _InfoRow(
                  label: 'Paid now',
                  value: CurrencyFormatter.inr(payment.amountPaid),
                ),
                _InfoRow(
                  label: 'Remaining',
                  value: CurrencyFormatter.inr(payment.remainingAmount),
                ),
                _InfoRow(
                  label: 'Advance',
                  value: CurrencyFormatter.inr(payment.advanceAmount),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRecordAnother,
                  child: const Text('Record another'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/payments/${payment.id}');
                  },
                  child: const Text('View receipt'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _shareSafely(
                context,
                () => PaymentShareService.shareWhatsAppText(
                  payment,
                  recordedBy: recordedBy,
                ),
              ),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('WhatsApp receipt'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _shareSafely(
                context,
                () => PaymentShareService.shareReceiptWithQr(
                  payment,
                  recordedBy: recordedBy,
                ),
              ),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Share receipt + QR'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSafely(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share receipt: $error')),
      );
    }
  }
}

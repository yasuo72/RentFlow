import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
  final _remarkController = TextEditingController();
  final DateTime _paymentDate = DateTime.now();

  String _paymentMethod = 'cash';
  RoomModel? _selectedRoom;

  @override
  void dispose() {
    _amountController.dispose();
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
          final occupiedRooms = roomList.where((room) => room.isOccupied).toList();
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
          final alreadyPaid = snapshot?.amountPaid ?? 0;
          final totalDueEstimate =
              snapshot?.totalDue ?? (monthlyRentDue + carriedForward);
          final outstanding = snapshot?.remainingAmount ?? totalDueEstimate;
          final payingNow = num.tryParse(_amountController.text) ?? 0;
          final remaining = (outstanding - payingNow).clamp(
            0,
            outstanding,
          );

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
                    label: remaining == 0 ? 'READY TO CLOSE' : 'PARTIAL DUE',
                    color: remaining == 0 ? AppColors.accent : AppColors.warning,
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
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Theme.of(context).dividerColor),
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
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
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
                        totalDue: totalDueEstimate,
                        alreadyPaid: alreadyPaid,
                        payingNow: payingNow,
                        remaining: remaining,
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
    final outstanding = room.currentMonthPayment?.remainingAmount ??
        room.currentMonthPayment?.totalDue ??
        room.monthlyRent;
    final amountPaid = num.parse(_amountController.text);

    if (amountPaid > outstanding) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount cannot be more than ${CurrencyFormatter.inr(outstanding)} for this payment.',
            ),
          ),
        );
      }
      return;
    }

    final payment = await ref.read(paymentsProvider.notifier).recordPayment({
      'tenant': room.currentTenant?.id,
      'room': room.id,
      'month': AppDateUtils.currentMonthLabel(),
      'year': DateTime.now().year,
      'amountPaid': amountPaid,
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
          _remarkController.clear();
          setState(() {});
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({
    required this.totalDue,
    required this.alreadyPaid,
    required this.payingNow,
    required this.remaining,
  });

  final num totalDue;
  final num alreadyPaid;
  final num payingNow;
  final num remaining;

  @override
  Widget build(BuildContext context) {
    final clear = remaining == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: clear ? AppColors.accentDim : AppColors.warningDim,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Total due',
            value: CurrencyFormatter.inr(totalDue),
          ),
          _InfoRow(
            label: 'Already paid',
            value: CurrencyFormatter.inr(alreadyPaid),
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
        ],
      ),
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
            color: selected ? AppColors.primary : Theme.of(context).dividerColor,
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

  String get whatsappText => '''
*RentFlow Receipt*
Room: ${payment.room?.roomNumber ?? '-'} | Tenant: ${payment.tenant?.fullName ?? '-'}
Month: ${payment.month}
Rent Due: ${CurrencyFormatter.inr(payment.totalDue)}
Paid: ${CurrencyFormatter.inr(payment.amountPaid)}
Remaining: ${CurrencyFormatter.inr(payment.remainingAmount)}
Method: ${payment.paymentMethod}
Remark: ${payment.remark ?? '-'}
Date: ${AppDateUtils.formatDate(payment.paymentDate)}
Recorded by: $recordedBy
_RentFlow - Family Rent Manager_
''';

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
                _InfoRow(
                  label: 'Room',
                  value: payment.room?.roomNumber ?? '-',
                ),
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
              onPressed: () async {
                final encoded = Uri.encodeComponent(whatsappText);
                await launchUrlString('whatsapp://send?text=$encoded');
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share on WhatsApp'),
            ),
          ),
        ],
      ),
    );
  }
}

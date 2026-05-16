import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';

final paymentsFilterProvider =
    NotifierProvider<PaymentsFilterController, PaymentsFilter>(
      PaymentsFilterController.new,
    );

final paymentsProvider =
    AsyncNotifierProvider<PaymentsController, List<PaymentModel>>(
      PaymentsController.new,
    );

final paymentDetailProvider = FutureProvider.family<PaymentModel, String>((
  ref,
  paymentId,
) async {
  return ref.read(paymentRepositoryProvider).fetchPayment(paymentId);
});

final pendingPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.read(paymentRepositoryProvider).fetchPendingPayments();
});

class PaymentsFilter {
  const PaymentsFilter({this.month, this.status = 'all', this.roomId});

  final String? month;
  final String status;
  final String? roomId;

  PaymentsFilter copyWith({String? month, String? status, String? roomId}) {
    return PaymentsFilter(
      month: month ?? this.month,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
    );
  }
}

class PaymentsFilterController extends Notifier<PaymentsFilter> {
  @override
  PaymentsFilter build() => const PaymentsFilter();

  void update({String? month, String? status, String? roomId}) {
    state = state.copyWith(month: month, status: status, roomId: roomId);
  }
}

class PaymentsController extends AsyncNotifier<List<PaymentModel>> {
  @override
  Future<List<PaymentModel>> build() {
    final filter = ref.watch(paymentsFilterProvider);
    return ref
        .read(paymentRepositoryProvider)
        .fetchPayments(
          month: filter.month,
          status: filter.status,
          roomId: filter.roomId,
        );
  }

  Future<PaymentModel> recordPayment(Map<String, dynamic> payload) async {
    final payment = await ref
        .read(paymentRepositoryProvider)
        .recordPayment(payload);
    ref.invalidateSelf();
    ref.invalidate(pendingPaymentsProvider);
    return payment;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';

final expensesProvider =
    AsyncNotifierProvider<ExpensesController, List<ExpenseModel>>(
      ExpensesController.new,
    );

class ExpensesController extends AsyncNotifier<List<ExpenseModel>> {
  @override
  Future<List<ExpenseModel>> build() {
    return ref.read(expenseRepositoryProvider).fetchExpenses();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).fetchExpenses(),
    );
  }

  Future<void> addExpense(
    Map<String, dynamic> payload, {
    String? billPhotoPath,
  }) async {
    await ref
        .read(expenseRepositoryProvider)
        .addExpense(payload, billPhotoPath: billPhotoPath);
    ref.invalidateSelf();
  }

  Future<void> updateExpense(
    String id,
    Map<String, dynamic> payload, {
    String? billPhotoPath,
  }) async {
    await ref
        .read(expenseRepositoryProvider)
        .updateExpense(id, payload, billPhotoPath: billPhotoPath);
    ref.invalidateSelf();
  }

  Future<void> deleteExpense(String id) async {
    await ref.read(expenseRepositoryProvider).deleteExpense(id);
    ref.invalidateSelf();
  }
}

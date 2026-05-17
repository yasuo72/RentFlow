import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';

final expensesProvider =
    AsyncNotifierProvider<ExpensesController, List<ExpenseModel>>(
      ExpensesController.new,
    );

class ExpensesController extends AsyncNotifier<List<ExpenseModel>> {
  @override
  Future<List<ExpenseModel>> build() async {
    final repository = ref.read(expenseRepositoryProvider);
    final cached = repository.readCachedExpenses();

    if (cached != null) {
      Future.microtask(() => refresh(silent: true));
      return cached;
    }

    return repository.fetchExpenses();
  }

  Future<void> refresh({bool silent = false}) async {
    final previous = state.asData?.value;

    try {
      final fresh = await ref.read(expenseRepositoryProvider).fetchExpenses();
      state = AsyncData(fresh);
    } catch (error, stackTrace) {
      if (!silent || previous == null) {
        state = AsyncError(error, stackTrace);
      }
    }
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

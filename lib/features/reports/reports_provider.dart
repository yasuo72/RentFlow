import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportsProvider = Provider<List<String>>((ref) {
  return const [
    'Monthly Collection Report',
    'Yearly Income Summary',
    'Due Report',
    'Expense Report',
  ];
});

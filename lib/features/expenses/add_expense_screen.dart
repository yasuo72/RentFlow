import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import 'expenses_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'maintenance';

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                          'electricity',
                          'water',
                          'repair',
                          'cleaning',
                          'internet',
                          'maintenance',
                          'other',
                        ]
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item.toUpperCase()),
                            selected: _category == item,
                            onSelected: (_) => setState(() => _category = item),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: Validators.amount,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  await ref.read(expensesProvider.notifier).addExpense({
                    'category': _category,
                    'amount': num.parse(_amountController.text),
                    'description': _descriptionController.text.trim(),
                    'date': DateTime.now().toIso8601String(),
                  });
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Save expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

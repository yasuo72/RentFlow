class Validators {
  const Validators._();

  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (value.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final parsed = num.tryParse(value);
    if (parsed == null || parsed < 0) {
      return 'Enter a valid amount';
    }
    return null;
  }
}

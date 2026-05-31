class Validators {
  Validators._();

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final cleaned = value.replaceAll(',', '').replaceAll('₹', '').trim();
    final num = double.tryParse(cleaned);
    if (num == null) return 'Enter a valid amount';
    if (num <= 0) return 'Amount must be greater than 0';
    if (num > 99999999) return 'Amount is too large';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleaned.length < 10) return 'Enter a valid phone number';
    return null;
  }

  static String? interestRate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Rate is required';
    final num = double.tryParse(value.trim());
    if (num == null) return 'Enter a valid rate';
    if (num < 0 || num > 100) return 'Rate must be between 0–100%';
    return null;
  }

  static String? tenure(String? value) {
    if (value == null || value.trim().isEmpty) return 'Tenure is required';
    final num = int.tryParse(value.trim());
    if (num == null || num <= 0) return 'Enter valid tenure in months';
    return null;
  }

  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.length < min) {
      return '${fieldName ?? 'Field'} must be at least $min characters';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value != null && value.length > max) {
      return '${fieldName ?? 'Field'} must be at most $max characters';
    }
    return null;
  }

  static String? sipAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'SIP amount is required';
    final num = double.tryParse(value.replaceAll(',', ''));
    if (num == null) return 'Enter a valid amount';
    if (num < 100) return 'Minimum SIP is ₹100';
    return null;
  }

  static String? stockQuantity(String? value) {
    if (value == null || value.trim().isEmpty) return 'Quantity is required';
    final num = int.tryParse(value.trim());
    if (num == null || num <= 0) return 'Enter valid quantity';
    return null;
  }
}

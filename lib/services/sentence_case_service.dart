import 'package:flutter/services.dart';

/// Capitalizes only the first letter of the input string or sentence.
String toSentenceCase(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.isEmpty) return text;
  final leadingWhitespace = text.substring(0, text.length - trimmed.length);
  final firstChar = trimmed[0].toUpperCase();
  final rest = trimmed.length > 1 ? trimmed.substring(1) : '';
  return '$leadingWhitespace$firstChar$rest';
}

/// TextInputFormatter enforcing sentence capitalization at typing time.
class SentenceCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final formatted = toSentenceCase(newValue.text);
    return newValue.copyWith(
      text: formatted,
      selection: newValue.selection,
    );
  }
}

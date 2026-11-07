import 'package:flutter/services.dart';

/// Formats text into Title Case where the first letter of each word is capitalized.
String toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.splitMapJoin(
    RegExp(r'\b[a-zA-Z]'),
    onMatch: (m) => m.group(0)!.toUpperCase(),
    onNonMatch: (n) => n,
  );
}

/// A TextInputFormatter that automatically capitalizes the first letter of every word
/// as the user types without changing cursor position.
class TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final converted = toTitleCase(newValue.text);
    return newValue.copyWith(
      text: converted,
      selection: newValue.selection,
    );
  }
}

import 'package:flutter/material.dart';

class RtlDetectionService {
  // Perso-Arabic unicode ranges: Arabic, Persian, Arabic Supplement, Extended-A
  static final RegExp _persianArabicRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  /// Returns true if the first non-whitespace character is Persian/Arabic.
  static bool startsWithRtl(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return false;
    return _persianArabicRegex.hasMatch(trimmed[0]);
  }

  /// Resolves TextDirection based on content leading script.
  static TextDirection resolveDirection(String text) {
    return startsWithRtl(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Resolves TextAlign based on content leading script.
  static TextAlign resolveAlignment(String text) {
    return startsWithRtl(text) ? TextAlign.right : TextAlign.left;
  }
}

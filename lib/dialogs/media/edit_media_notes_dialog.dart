import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rtl_aware_text_field.dart';
import '../../services/sentence_case_service.dart';

class EditMediaNotesDialog {
  static Future<void> show({
    required BuildContext context,
    required VibePalette palette,
    required MediaItem item,
    required ValueChanged<String> onNotesSaved,
  }) async {
    final controller = TextEditingController(text: item.personalNotes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.bgElevated,
        title: Text(
          'Edit Media Notes',
          style: TextStyle(color: palette.textMain, fontWeight: FontWeight.bold),
        ),
        content: RtlAwareTextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: palette.textMain),
          decoration: InputDecoration(
            hintText: 'Enter notes',
            hintStyle: TextStyle(color: palette.textDim.withValues(alpha: 0.45)),
            filled: true,
            fillColor: palette.bgSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accentPrimary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(toSentenceCase(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      onNotesSaved(result);
    }
  }
}

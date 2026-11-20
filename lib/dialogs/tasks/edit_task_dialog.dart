import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rtl_aware_text_field.dart';
import '../../services/sentence_case_service.dart';

class EditTaskDialog {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required Task task,
    required ValueChanged<Task> onTaskUpdated,
  }) {
    final titleController = TextEditingController(text: task.title);
    final notesController = TextEditingController(text: task.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Task',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.textMain,
                ),
              ),
              const SizedBox(height: 14),
              RtlAwareTextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(color: palette.textMain),
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: TextStyle(color: palette.textMuted),
                  hintText: 'What needs to get done?',
                  hintStyle: TextStyle(color: palette.textDim),
                  filled: true,
                  fillColor: palette.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              RtlAwareTextField(
                controller: notesController,
                maxLines: 3,
                style: TextStyle(color: palette.textMain),
                decoration: InputDecoration(
                  labelText: 'Notes / Description',
                  labelStyle: TextStyle(color: palette.textMuted),
                  hintText: 'Add extra details, checklist bullets, or notes (optional)...',
                  hintStyle: TextStyle(color: palette.textDim.withValues(alpha: 0.45)),
                  filled: true,
                  fillColor: palette.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accentPrimary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final title = toSentenceCase(titleController.text.trim());
                      if (title.isNotEmpty) {
                        final notes = toSentenceCase(notesController.text.trim());
                        final updated = task.copyWith(
                          title: title,
                          notes: notes,
                        );
                        onTaskUpdated(updated);
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

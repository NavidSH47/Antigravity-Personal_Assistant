import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rtl_aware_text_field.dart';
import '../../services/sentence_case_service.dart';
import '../../services/date_navigation_service.dart';

class AddTaskModal {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required TaskCategory category,
    required Jalali selectedDate,
    required ValueChanged<Task> onTaskCreated,
  }) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();

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
                category == TaskCategory.daily
                    ? 'Add Task for Today'
                    : 'Add to General Backlog',
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
                  hintText:
                      'Add extra details, checklist bullets, or notes (optional)...',
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
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: palette.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accentPrimary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isNotEmpty) {
                        final newTask = Task(
                          id: 'task_${DateTime.now().millisecondsSinceEpoch}',
                          title: toSentenceCase(title),
                          notes: toSentenceCase(notesController.text.trim()),
                          category: category,
                          targetDateJalali: category == TaskCategory.daily
                              ? DateNavigationService.formatJalaliKey(selectedDate)
                              : null,
                        );
                        onTaskCreated(newTask);
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Save Task',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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

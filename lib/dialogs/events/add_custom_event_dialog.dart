import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../models/shamsi_event.dart';
import '../../theme/app_theme.dart';
import '../../services/dual_calendar_service.dart';
import '../../services/sentence_case_service.dart';
import '../../widgets/rtl_aware_text_field.dart';

class AddCustomEventDialog {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required Jalali selectedDate,
    required ValueChanged<ShamsiEvent> onEventCreated,
  }) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    Jalali targetDate = selectedDate;
    EventCategory selectedCategory = EventCategory.birthday;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: palette.bgElevated,
              title: Row(
                children: [
                  const Text('📅 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'Add Custom Event',
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RtlAwareTextField(
                      controller: titleController,
                      autofocus: true,
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'e.g. Sara\'s Birthday, Exam...',
                        hintStyle: TextStyle(color: palette.textDim),
                        labelStyle: TextStyle(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.bgSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showPersianDatePicker(
                          context: context,
                          initialDate: targetDate,
                          firstDate: Jalali(1380, 1, 1),
                          lastDate: Jalali(1450, 12, 29),
                        );
                        if (picked != null) {
                          setDState(() => targetDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: palette.bgSurface,
                          border: Border.all(color: palette.borderSubtle),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('🗓️ ', style: TextStyle(fontSize: 13)),
                                Text(
                                  'Date: ${DualCalendarService.toShamsiString(targetDate)}',
                                  style: TextStyle(
                                    color: palette.textMain,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.edit, size: 14, color: palette.accentPrimary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Event Type:',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDState(() => selectedCategory = EventCategory.birthday),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedCategory == EventCategory.birthday
                                    ? const Color(0x33EC4899)
                                    : palette.bgSurface,
                                border: Border.all(
                                  color: selectedCategory == EventCategory.birthday
                                      ? const Color(0xFFEC4899)
                                      : palette.borderSubtle,
                                  width: selectedCategory == EventCategory.birthday ? 1.5 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '🎂 Birthday',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedCategory == EventCategory.birthday
                                        ? const Color(0xFFF472B6)
                                        : palette.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDState(() => selectedCategory = EventCategory.customDate),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedCategory == EventCategory.customDate
                                    ? const Color(0x3360A5FA)
                                    : palette.bgSurface,
                                border: Border.all(
                                  color: selectedCategory == EventCategory.customDate
                                      ? const Color(0xFF60A5FA)
                                      : palette.borderSubtle,
                                  width: selectedCategory == EventCategory.customDate ? 1.5 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '🎯 Milestone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedCategory == EventCategory.customDate
                                        ? const Color(0xFF93C5FD)
                                        : palette.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RtlAwareTextField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Optional Notes',
                        hintText: '+ Add reminder notes...',
                        hintStyle: TextStyle(color: palette.textDim.withValues(alpha: 0.45)),
                        labelStyle: TextStyle(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.bgSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accentPrimary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final title = toSentenceCase(titleController.text.trim());
                    if (title.isNotEmpty) {
                      final newEvt = ShamsiEvent(
                        id: 'custom_evt_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        jalaliMonth: targetDate.month,
                        jalaliDay: targetDate.day,
                        isCustom: true,
                        isOfficialHoliday: false,
                        category: selectedCategory,
                        note: notesController.text.trim().isEmpty ? null : toSentenceCase(notesController.text.trim()),
                      );
                      onEventCreated(newEvt);
                      Navigator.pop(dCtx);
                    }
                  },
                  child: const Text('Save Event', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

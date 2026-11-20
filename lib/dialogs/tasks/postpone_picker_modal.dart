import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../services/dual_calendar_service.dart';

class PostponePickerModal {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required Task task,
    required Jalali selectedDate,
    required ValueChanged<Jalali> onDateSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: palette.bgElevated,
          title: Text(
            'Reschedule Task',
            style: TextStyle(
              color: palette.textMain,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select target date for "${task.title}":',
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showPersianDatePicker(
                      context: context,
                      initialDate: selectedDate.addDays(1),
                      firstDate: Jalali(1380, 1, 1),
                      lastDate: Jalali(1450, 12, 29),
                    );
                    if (picked != null) {
                      onDateSelected(picked);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentPrimary.withValues(alpha: 0.15),
                      border: Border.all(color: palette.accentPrimary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📅 ', style: TextStyle(fontSize: 13)),
                        Text(
                          'Pick Custom Shamsi Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: palette.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(7, (i) {
                  final daysToAdd = i == 0
                      ? 1
                      : (i == 1
                          ? 2
                          : (i == 2
                              ? 3
                              : (i == 3
                                  ? 7
                                  : (i == 4
                                      ? 14
                                      : (i == 5 ? 21 : 30)))));
                  final target = selectedDate.addDays(daysToAdd);
                  final label = i == 0
                      ? 'Tomorrow'
                      : (i == 3
                          ? '+1 Week'
                          : (i == 4
                              ? '+2 Weeks'
                              : (i == 6 ? '+1 Month' : '+$daysToAdd Days')));
                  final shamsiStr = DualCalendarService.toShamsiString(target);
                  final gregStr = DualCalendarService.toGregorianString(target);

                  return InkWell(
                    onTap: () {
                      onDateSelected(target);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: palette.accentPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                shamsiStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textMain,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            gregStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: palette.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }
}

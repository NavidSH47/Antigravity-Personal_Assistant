import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../models/media_item.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../services/media_goal_sync_service.dart';
import '../../services/date_navigation_service.dart';
import '../../widgets/rtl_aware_text_field.dart';

class ScheduleMediaModal {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required MediaItem item,
    required int currentTaskCount,
    required Function(Task task, String notificationMessage) onTaskScheduled,
  }) {
    final remaining = MediaGoalSyncService.remainingUnits(item);
    double initialAmount = 1.0;
    if (item.type == MediaType.book) {
      initialAmount = remaining >= 25 ? 25.0 : remaining;
    } else if (item.type == MediaType.movie) {
      initialAmount = remaining >= 30 ? 30.0 : remaining;
    } else {
      initialAmount = remaining >= 3 ? 3.0 : (remaining > 0 ? remaining : 1.0);
    }
    if (initialAmount <= 0 && remaining > 0) initialAmount = 1.0;

    final amountController = TextEditingController(
      text: MediaGoalSyncService.formatUnits(initialAmount),
    );
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final curAmount = double.tryParse(amountController.text);
            final error = MediaGoalSyncService.validateGoalAmount(curAmount, item);

            void selectIncrement(double delta) {
              final currentVal = double.tryParse(amountController.text) ?? 0.0;
              final newVal = (currentVal + delta).clamp(1.0, remaining);
              amountController.text = MediaGoalSyncService.formatUnits(newVal);
              setDState(() {});
            }

            void finishRemaining() {
              amountController.text = MediaGoalSyncService.formatUnits(remaining);
              setDState(() {});
            }

            return AlertDialog(
              backgroundColor: palette.bgElevated,
              title: Text(
                'Schedule Daily Goal',
                style: TextStyle(
                  color: palette.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.bgSurface,
                        border: Border.all(color: palette.borderSubtle),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(item.iconEmoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    color: palette.textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.progressCurrent.toInt()} / ${item.progressTotal.toInt()} ${item.metricUnit} (${item.progressPercent}%)',
                                  style: TextStyle(
                                    color: palette.accentPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'How many ${item.metricUnit} do you want to accomplish today?',
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Target Amount (${item.metricUnit})',
                        labelStyle: TextStyle(color: palette.textMuted),
                        errorText: error,
                        filled: true,
                        fillColor: palette.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setDState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          label: const Text('+5'),
                          labelStyle: TextStyle(fontSize: 11, color: palette.textMain),
                          backgroundColor: palette.bgSurface,
                          onPressed: remaining >= 5 ? () => selectIncrement(5) : null,
                        ),
                        ActionChip(
                          label: const Text('+10'),
                          labelStyle: TextStyle(fontSize: 11, color: palette.textMain),
                          backgroundColor: palette.bgSurface,
                          onPressed: remaining >= 10 ? () => selectIncrement(10) : null,
                        ),
                        ActionChip(
                          label: const Text('+25'),
                          labelStyle: TextStyle(fontSize: 11, color: palette.textMain),
                          backgroundColor: palette.bgSurface,
                          onPressed: remaining >= 25 ? () => selectIncrement(25) : null,
                        ),
                        ActionChip(
                          label: Text('Finish (${MediaGoalSyncService.formatUnits(remaining)})'),
                          labelStyle: TextStyle(fontSize: 11, color: palette.accentPrimary),
                          backgroundColor: palette.bgSurface,
                          onPressed: remaining > 0 ? finishRemaining : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RtlAwareTextField(
                      controller: noteController,
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Optional note (e.g. read chapter 4, watch with friends)',
                        labelStyle: TextStyle(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                  onPressed: error == null && curAmount != null && curAmount > 0
                      ? () {
                          final todayKey = DateNavigationService.formatJalaliKey(Jalali.now());
                          final task = MediaGoalSyncService.createLinkedTask(
                            item: item,
                            amount: curAmount,
                            todayKey: todayKey,
                            orderIndex: currentTaskCount,
                            notes: noteController.text.trim(),
                          );
                          final msg = MediaGoalSyncService.scheduledNotification(item, curAmount);
                          onTaskScheduled(task, msg);
                          Navigator.pop(dCtx);
                        }
                      : null,
                  child: const Text('Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

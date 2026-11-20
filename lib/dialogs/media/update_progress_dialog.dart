import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';
import '../../services/media_ledger_cleanup_service.dart';
import '../../services/media_goal_sync_service.dart';

class UpdateProgressDialog {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required MediaItem item,
    required ValueChanged<MediaItem> onProgressUpdated,
  }) {
    final currentController =
        TextEditingController(text: item.progressCurrent.toInt().toString());
    final totalController =
        TextEditingController(text: item.progressTotal.toInt().toString());
    double selectedScore = item.score ?? 8.0;
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: palette.bgElevated,
              title: Text(
                'Update: ${item.title}',
                style: TextStyle(
                  color: palette.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Metric: ${item.metricUnit}',
                    style: TextStyle(
                      color: palette.accentPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: currentController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: palette.textMain),
                          decoration: InputDecoration(
                            labelText: MediaLedgerCleanupService.currentUnitInputLabelFor(item.type),
                            labelStyle: TextStyle(color: palette.textMuted),
                            filled: true,
                            fillColor: palette.bgSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) {
                            if (validationError != null) {
                              setDState(() => validationError = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: totalController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: palette.textMain),
                          decoration: InputDecoration(
                            labelText: MediaLedgerCleanupService.unitInputLabelFor(item.type),
                            labelStyle: TextStyle(color: palette.textMuted),
                            filled: true,
                            fillColor: palette.bgSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) {
                            if (validationError != null) {
                              setDState(() => validationError = null);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x26EF4444),
                        border: Border.all(color: const Color(0xFFEF4444)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              validationError!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Score (1-10):',
                        style: TextStyle(
                          color: palette.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '⭐ ${selectedScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: palette.accentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedScore,
                    min: 1.0,
                    max: 10.0,
                    divisions: 18,
                    activeColor: palette.accentPrimary,
                    onChanged: (val) {
                      setDState(() => selectedScore = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accentPrimary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final curParsed = double.tryParse(currentController.text.trim());
                    final totParsed = double.tryParse(totalController.text.trim());

                    if (curParsed == null || curParsed < 0) {
                      setDState(() => validationError = 'Current progress must be a non-negative number.');
                      return;
                    }
                    if (totParsed == null || totParsed <= 0) {
                      setDState(() => validationError = 'Total capacity must be greater than 0.');
                      return;
                    }
                    if (curParsed > totParsed) {
                      final cStr = MediaGoalSyncService.formatUnits(curParsed);
                      final tStr = MediaGoalSyncService.formatUnits(totParsed);
                      setDState(() => validationError = 'Progress ($cStr) cannot exceed capacity ($tStr)!');
                      return;
                    }

                    final wasCompleted = item.isCompleted;
                    final updated = item.copyWith(
                      progressCurrent: curParsed,
                      progressTotal: totParsed,
                      score: selectedScore,
                    );
                    final nowCompleted = updated.isCompleted;
                    DateTime newDisplayDate = item.displayDate;
                    if (!wasCompleted && nowCompleted) {
                      newDisplayDate = DateTime.now();
                    } else if (wasCompleted && !nowCompleted) {
                      newDisplayDate = DateTime.now();
                    }
                    final finalItem = updated.copyWith(displayDate: newDisplayDate);

                    onProgressUpdated(finalItem);
                    Navigator.pop(dCtx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

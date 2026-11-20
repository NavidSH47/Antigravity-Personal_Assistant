import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/task.dart';
import '../models/shamsi_event.dart';
import '../theme/app_theme.dart';
import '../services/dual_calendar_service.dart';
import '../services/date_navigation_service.dart';
import '../widgets/shamsi_agenda_banner.dart';
import '../widgets/task_card.dart';
import '../widgets/fast_scroll_rail.dart';

class DailyPulseView extends StatelessWidget {
  final VibePalette palette;
  final Jalali selectedDate;
  final List<Task> allTasks;
  final List<ShamsiEvent> events;
  final List<Task> dailyTasks;
  final List<Task> backlogTasks;
  final bool isDailyFocusCollapsed;
  final bool isBacklogCollapsed;
  final ScrollController scrollController;
  final GlobalKey focusSectionKey;
  final GlobalKey backlogSectionKey;

  final ValueChanged<Jalali> onDateChanged;
  final ValueChanged<ShamsiEvent> onToggleCheckpoint;
  final ValueChanged<ShamsiEvent> onAddEvent;
  final VoidCallback onAddCustomEvent;
  final ValueChanged<ShamsiEvent> onRemoveEvent;
  final VoidCallback onToggleDailyFocusCollapsed;
  final VoidCallback onToggleBacklogCollapsed;
  final ValueChanged<TaskCategory> onAddTask;
  final Function(Task, TaskStatus) onTaskStatusChange;
  final ValueChanged<Task> onPostponeOneDay;
  final ValueChanged<Task> onPostponeToDate;
  final ValueChanged<Task> onDemoteToBacklog;
  final ValueChanged<Task> onAssignToToday;
  final ValueChanged<Task> onEditTask;
  final ValueChanged<Task> onDeleteTask;
  final Function(int oldIndex, int newIndex) onReorderDailyTasks;
  final Function(int oldIndex, int newIndex) onReorderBacklogTasks;
  final VoidCallback onDragAutoScrollStart;
  final VoidCallback onDragAutoScrollStop;
  final ValueChanged<double> onPointerMove;

  const DailyPulseView({
    super.key,
    required this.palette,
    required this.selectedDate,
    required this.allTasks,
    required this.events,
    required this.dailyTasks,
    required this.backlogTasks,
    required this.isDailyFocusCollapsed,
    required this.isBacklogCollapsed,
    required this.scrollController,
    required this.focusSectionKey,
    required this.backlogSectionKey,
    required this.onDateChanged,
    required this.onToggleCheckpoint,
    required this.onAddEvent,
    required this.onAddCustomEvent,
    required this.onRemoveEvent,
    required this.onToggleDailyFocusCollapsed,
    required this.onToggleBacklogCollapsed,
    required this.onAddTask,
    required this.onTaskStatusChange,
    required this.onPostponeOneDay,
    required this.onPostponeToDate,
    required this.onDemoteToBacklog,
    required this.onAssignToToday,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onReorderDailyTasks,
    required this.onReorderBacklogTasks,
    required this.onDragAutoScrollStart,
    required this.onDragAutoScrollStop,
    required this.onPointerMove,
  });

  @override
  Widget build(BuildContext context) {
    final daily = dailyTasks;
    final backlog = backlogTasks;
    final isViewingToday = DateNavigationService.isToday(selectedDate);

    final dailyActiveTasks = daily.where((t) => t.status != TaskStatus.canceled).toList();
    final dailyTotal = dailyActiveTasks.length;
    final dailyDone = daily.where((t) => t.status == TaskStatus.done).length;
    final dailyCanceled = daily.where((t) => t.status == TaskStatus.canceled).length;
    final dailyProgress = dailyTotal == 0 ? 0.0 : (dailyDone / dailyTotal).clamp(0.0, 1.0);

    final backlogActiveTasks = backlog.where((t) => t.status != TaskStatus.canceled).toList();
    final backlogTotal = backlogActiveTasks.length;
    final backlogDone = backlog.where((t) => t.status == TaskStatus.done).length;
    final backlogCanceled = backlog.where((t) => t.status == TaskStatus.canceled).length;
    final backlogProgress = backlogTotal == 0 ? 0.0 : (backlogDone / backlogTotal).clamp(0.0, 1.0);

    final taskCompletionMap = <String, ({int total, int done})>{};
    for (final t in allTasks) {
      if (t.targetDateJalali != null && t.category == TaskCategory.daily) {
        if (t.status == TaskStatus.canceled) continue;
        final key = t.targetDateJalali!;
        final prev = taskCompletionMap[key] ?? (total: 0, done: 0);
        final isDone = t.status == TaskStatus.done;
        final updatedStats = (
          total: prev.total + 1,
          done: prev.done + (isDone ? 1 : 0),
        );
        taskCompletionMap[key] = updatedStats;
        try {
          final parsed = DateNavigationService.parseJalaliKey(key);
          final stdKey = DateNavigationService.formatJalaliKey(parsed);
          final unpaddedKey = '${parsed.year}-${parsed.month}-${parsed.day}';
          taskCompletionMap[stdKey] = updatedStats;
          taskCompletionMap[unpaddedKey] = updatedStats;
        } catch (_) {}
      }
    }

    return Stack(
      children: [
        Listener(
          onPointerMove: (e) => onPointerMove(e.position.dy),
          onPointerUp: (_) => onDragAutoScrollStop(),
          onPointerCancel: (_) => onDragAutoScrollStop(),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
            children: [
              ShamsiAgendaBanner(
                events: events,
                palette: palette,
                selectedDate: selectedDate,
                onDateChanged: onDateChanged,
                onToggleCheckpoint: onToggleCheckpoint,
                onAddEvent: onAddEvent,
                onAddCustomEvent: onAddCustomEvent,
                onRemoveEvent: onRemoveEvent,
                taskCompletionMap: taskCompletionMap,
              ),
              const SizedBox(height: 18),

              // --- TODAY'S FOCUS SECTION ---
              Column(
                key: focusSectionKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: InkWell(
                                onTap: onToggleDailyFocusCollapsed,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(
                                          isDailyFocusCollapsed
                                              ? Icons.keyboard_arrow_down
                                              : Icons.keyboard_arrow_up,
                                          size: 20,
                                          color: palette.accentPrimary,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          isViewingToday
                                              ? '📌 Today\'s Focus'
                                              : '📌 Focus for ${DualCalendarService.toShamsiString(selectedDate)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: palette.textMain,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.bgElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: palette.borderSubtle),
                              ),
                              child: Text(
                                '$dailyDone/$dailyTotal Done',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textMuted,
                                ),
                              ),
                            ),
                            if (dailyCanceled > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '• $dailyCanceled canceled',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: palette.textDim,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => onAddTask(TaskCategory.daily),
                        child: Text(
                          isViewingToday ? '+ Add' : '+ Add to Day',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: palette.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Dynamic Theme-Colored Progress Bar
                  Container(
                    height: 5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: palette.bgElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: constraints.maxWidth * dailyProgress,
                            decoration: BoxDecoration(
                              gradient: palette.accentGradient,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: dailyProgress > 0
                                  ? [
                                      BoxShadow(
                                        color: palette.accentGlow,
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedCrossFade(
                crossFadeState: isDailyFocusCollapsed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                firstChild: daily.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          isViewingToday
                              ? 'No tasks scheduled for today. Add one above!'
                              : 'No tasks scheduled for this day. Add one above!',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textDim,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: daily.length,
                        onReorderStart: (_) => onDragAutoScrollStart(),
                        // ignore: deprecated_member_use
                        onReorder: onReorderDailyTasks,
                        itemBuilder: (context, index) {
                          final task = daily[index];
                          return TaskCard(
                            key: ValueKey(task.id),
                            task: task,
                            palette: palette,
                            dragIndex: index,
                            onStatusChange: (status) => onTaskStatusChange(task, status),
                            onPostponeOneDay: () => onPostponeOneDay(task),
                            onPostponeToDate: () => onPostponeToDate(task),
                            onDemoteToBacklog: () => onDemoteToBacklog(task),
                            onEdit: () => onEditTask(task),
                            onDelete: () => onDeleteTask(task),
                          );
                        },
                      ),
                secondChild: const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
              Divider(color: palette.borderSubtle),
              const SizedBox(height: 10),

              // --- ORBIT & BACKLOG SECTION ---
              Column(
                key: backlogSectionKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            InkWell(
                              onTap: onToggleBacklogCollapsed,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Icon(
                                        isBacklogCollapsed
                                            ? Icons.keyboard_arrow_down
                                            : Icons.keyboard_arrow_up,
                                        size: 20,
                                        color: palette.accentPrimary,
                                      ),
                                    ),
                                    Text(
                                      '🪐 Orbit & Backlog',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: palette.textMain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.bgElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: palette.borderSubtle),
                              ),
                              child: Text(
                                '$backlogDone/$backlogTotal Done',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textMuted,
                                ),
                              ),
                            ),
                            if (backlogCanceled > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '• $backlogCanceled canceled',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: palette.textDim,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => onAddTask(TaskCategory.general),
                        child: Text(
                          '+ Add Backlog',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: palette.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Dynamic Theme-Colored Progress Bar
                  Container(
                    height: 5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: palette.bgElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: constraints.maxWidth * backlogProgress,
                            decoration: BoxDecoration(
                              gradient: palette.accentGradient,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: backlogProgress > 0
                                  ? [
                                      BoxShadow(
                                        color: palette.accentGlow,
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedCrossFade(
                crossFadeState: isBacklogCollapsed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                firstChild: backlog.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Backlog is clear! Relax and enjoy.',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textDim,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: backlog.length,
                        onReorderStart: (_) => onDragAutoScrollStart(),
                        // ignore: deprecated_member_use
                        onReorder: onReorderBacklogTasks,
                        itemBuilder: (context, index) {
                          final task = backlog[index];
                          return TaskCard(
                            key: ValueKey(task.id),
                            task: task,
                            palette: palette,
                            dragIndex: index,
                            onStatusChange: (status) => onTaskStatusChange(task, status),
                            onAssignToToday: () => onAssignToToday(task),
                            onScheduleForDate: () => onAssignToToday(task),
                            scheduleLabel:
                                isViewingToday ? '⚡ Assign Today' : '📅 Assign to Day',
                            onEdit: () => onEditTask(task),
                            onDelete: () => onDeleteTask(task),
                          );
                        },
                      ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: FastScrollRail(
            controller: scrollController,
            palette: palette,
            sections: [
              FastScrollSection(
                id: 'focus',
                label: 'Focus',
                icon: Icons.push_pin_rounded,
                onTap: () {
                  scrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
              FastScrollSection(
                id: 'orbit',
                label: 'Orbit',
                icon: Icons.public_rounded,
                onTap: () {
                  if (isBacklogCollapsed) {
                    onToggleBacklogCollapsed();
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (backlogSectionKey.currentContext != null) {
                      Scrollable.ensureVisible(
                        backlogSectionKey.currentContext!,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: 0.05,
                      );
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

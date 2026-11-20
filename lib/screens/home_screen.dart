import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/task.dart';
import '../models/shamsi_event.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/date_navigation_service.dart';
import '../services/task_reschedule_service.dart';
import '../services/task_stream_flow_service.dart';
import '../services/reorder_service.dart';
import '../services/media_goal_sync_service.dart';
import '../services/media_label_service.dart';
import '../widgets/settings_drawer.dart';
import '../dialogs/dialogs.dart';
import 'daily_pulse_view.dart';
import 'entertainment_view.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final ThemeVibe currentVibe;
  final AppFontStyle currentFont;
  final double fontSizeScale;
  final Function(ThemeVibe) onSelectVibe;
  final Function(AppFontStyle) onSelectFont;
  final Function(double) onSelectFontSizeScale;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.currentVibe,
    required this.currentFont,
    this.fontSizeScale = 1.0,
    required this.onSelectVibe,
    required this.onSelectFont,
    required this.onSelectFontSizeScale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _currentTab = 'notes';
  late PageController _pageController;
  String _mediaFilter = 'all';
  String _mediaSort = 'custom';
  bool _isMediaGrid = false;
  bool _isDailyFocusCollapsed = false;
  bool _isBacklogCollapsed = false;

  late Jalali _selectedDate;
  late List<Task> _tasks;
  late List<ShamsiEvent> _events;
  late List<MediaItem> _mediaItems;
  late List<String> _activeLabels;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _entertainmentScrollController = ScrollController();
  final GlobalKey _focusSectionKey = GlobalKey();
  final GlobalKey _backlogSectionKey = GlobalKey();
  final GlobalKey _activeMediaKey = GlobalKey();
  final GlobalKey _onHoldMediaKey = GlobalKey();
  final GlobalKey _finishedMediaKey = GlobalKey();

  Timer? _dragAutoScrollTimer;
  double _lastPointerY = 0.0;
  bool _isDraggingTask = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = Jalali.now();
    _tasks = widget.storage.loadTasks();
    _events = widget.storage.loadShamsiEvents();
    _mediaItems = widget.storage.loadMediaItems();
    _activeLabels = widget.storage.loadActiveLabels();
    _isMediaGrid = widget.storage.loadMediaViewMode() == 'grid';
    _mediaSort = widget.storage.loadMediaSort();
    _pageController = PageController(initialPage: _currentTab == 'notes' ? 0 : 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dragAutoScrollTimer?.cancel();
    _scrollController.dispose();
    _entertainmentScrollController.dispose();
    super.dispose();
  }

  VibePalette get _palette =>
      AppTheme.vibes[widget.currentVibe] ??
      AppTheme.vibes[ThemeVibe.deepAmethyst]!;

  // --- AUTO SCROLL FOR DRAGGING ---
  void _startAutoScrollTimer() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isDraggingTask || !_scrollController.hasClients) return;
      final screenHeight = MediaQuery.of(context).size.height;
      if (_lastPointerY > 0 && _lastPointerY < 90.0) {
        final delta = (90.0 - _lastPointerY).clamp(0.0, 90.0) / 90.0 * 16.0;
        final newOffset = (_scrollController.offset - delta).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.jumpTo(newOffset);
      } else if (_lastPointerY > (screenHeight - 90.0) && _lastPointerY <= screenHeight) {
        final delta = (_lastPointerY - (screenHeight - 90.0)).clamp(0.0, 90.0) / 90.0 * 16.0;
        final newOffset = (_scrollController.offset + delta).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.jumpTo(newOffset);
      }
    });
  }

  void _stopAutoScrollTimer() {
    _isDraggingTask = false;
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
  }

  // --- TASK STATE & ACTIONS ---
  void _setTaskStatus(Task task, TaskStatus status) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        int newPostponedCount = task.postponedCount;
        if (status == TaskStatus.postponed &&
            task.status != TaskStatus.postponed) {
          newPostponedCount++;
        }
        _tasks[index] = task.copyWith(
          status: status,
          postponedCount: newPostponedCount,
        );

        // Automatic Progress Sync on Task Completion ("Done")
        if (task.linkedMediaId != null) {
          final mIndex =
              _mediaItems.indexWhere((m) => m.id == task.linkedMediaId);
          if (mIndex != -1) {
            final units = task.mediaUnitsToAdvance ?? 1.0;
            if (task.status != TaskStatus.done && status == TaskStatus.done) {
              _mediaItems[mIndex] =
                  MediaGoalSyncService.advanceProgress(_mediaItems[mIndex], units);
              widget.storage.saveMediaItems(_mediaItems);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(MediaGoalSyncService.celebrationMessage(
                      _mediaItems[mIndex])),
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (task.status == TaskStatus.done &&
                status != TaskStatus.done) {
              _mediaItems[mIndex] =
                  MediaGoalSyncService.revertProgress(_mediaItems[mIndex], units);
              widget.storage.saveMediaItems(_mediaItems);
            }
          }
        }
      }
    });
    widget.storage.saveTasks(_tasks);
  }

  void _assignTaskToToday(Task task) {
    final isViewingToday = DateNavigationService.isToday(_selectedDate);
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = TaskStreamFlowService.promoteToDaily(
          task,
          _selectedDate,
        );
      }
    });
    widget.storage.saveTasks(_tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isViewingToday
              ? 'Task moved to Today\'s Focus'
              : 'Task assigned to ${DateNavigationService.formatJalaliKey(_selectedDate)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _demoteTaskToBacklog(Task task) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = TaskStreamFlowService.demoteToBacklog(task);
      }
    });
    widget.storage.saveTasks(_tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task moved to Backlog'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _postponeTaskOneDay(Task task) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = TaskRescheduleService.postponeOneDay(task, _selectedDate);
      }
    });
    widget.storage.saveTasks(_tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task postponed to tomorrow'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _postponeTaskToDate(Task task, Jalali targetDate) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = TaskRescheduleService.postponeToDate(task, targetDate);
      }
    });
    widget.storage.saveTasks(_tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Task postponed to ${DateNavigationService.formatJalaliKey(targetDate)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteTask(Task task) {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    widget.storage.saveTasks(_tasks);
  }

  // --- SHAMSI EVENTS ---
  void _removeShamsiEvent(ShamsiEvent event) {
    setState(() {
      _events.removeWhere((e) => e.id == event.id);
    });
    widget.storage.saveShamsiEvents(_events);
    widget.storage.addDeletedEventId(event.id);
  }

  void _toggleShamsiCheckpoint(ShamsiEvent event) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = event.copyWith(
          actionChecked: !event.actionChecked,
        );
      }
    });
    widget.storage.saveShamsiEvents(_events);
  }

  void _addShamsiEvent(ShamsiEvent newEvent) {
    setState(() {
      _events.add(newEvent);
    });
    widget.storage.saveShamsiEvents(_events);
  }

  // --- MEDIA ACTIONS ---
  void _toggleMediaOnHold(MediaItem item, bool isOnHold) {
    setState(() {
      final index = _mediaItems.indexWhere((m) => m.id == item.id);
      if (index != -1) {
        _mediaItems[index] = item.copyWith(isOnHold: isOnHold);
      }
    });
    widget.storage.saveMediaItems(_mediaItems);
  }

  void _removeMediaItem(String mediaId) {
    setState(() {
      _mediaItems.removeWhere((m) => m.id == mediaId);
      // Decouple linked tasks: retain tasks, remove link
      for (int i = 0; i < _tasks.length; i++) {
        if (_tasks[i].linkedMediaId == mediaId) {
          _tasks[i] = _tasks[i].copyWith(linkedMediaId: null);
        }
      }
    });
    widget.storage.saveMediaItems(_mediaItems);
    widget.storage.saveTasks(_tasks);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Media item removed. Linked daily goals preserved.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // --- DIALOG DISPATCHERS ---
  void _openAddTaskModal(TaskCategory category) {
    AddTaskModal.show(
      context: context,
      palette: _palette,
      category: category,
      selectedDate: _selectedDate,
      onTaskCreated: (newTask) {
        setState(() {
          _tasks.insert(0, newTask);
        });
        widget.storage.saveTasks(_tasks);
      },
    );
  }

  void _showEditTaskDialog(Task task) {
    EditTaskDialog.show(
      context: context,
      palette: _palette,
      task: task,
      onTaskUpdated: (updated) {
        setState(() {
          final idx = _tasks.indexWhere((t) => t.id == task.id);
          if (idx != -1) {
            _tasks[idx] = updated;
          }
        });
        widget.storage.saveTasks(_tasks);
      },
    );
  }

  void _showPostponeDatePickerModal(Task task) {
    PostponePickerModal.show(
      context: context,
      palette: _palette,
      task: task,
      selectedDate: _selectedDate,
      onDateSelected: (target) => _postponeTaskToDate(task, target),
    );
  }

  void _showAddCustomEventDialog() {
    AddCustomEventDialog.show(
      context: context,
      palette: _palette,
      selectedDate: _selectedDate,
      onEventCreated: (newEvt) {
        setState(() {
          _events.add(newEvt);
        });
        widget.storage.saveShamsiEvents(_events);
      },
    );
  }

  void _scheduleMediaToday(MediaItem item) {
    ScheduleMediaModal.show(
      context: context,
      palette: _palette,
      item: item,
      currentTaskCount: _tasks.length,
      onTaskScheduled: (task, message) {
        setState(() {
          _tasks.add(task);
        });
        widget.storage.saveTasks(_tasks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'View in Daily Pulse',
              textColor: _palette.accentPrimary,
              onPressed: () {
                setState(() => _currentTab = 'notes');
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
  }

  void _showEditLabelsDialog(MediaItem item) {
    MediaLabelsModal.showSelection(
      context: context,
      palette: _palette,
      activeLabels: _activeLabels,
      mediaItems: _mediaItems,
      initialSelected: item.labels,
      onDone: (newLabels) {
        setState(() {
          final idx = _mediaItems.indexWhere((m) => m.id == item.id);
          if (idx != -1) {
            _mediaItems[idx] = item.copyWith(labels: newLabels);
          }
        });
        widget.storage.saveMediaItems(_mediaItems);
      },
      onLabelPermanentlyDeleted: (deletedTag) {
        setState(() {
          _activeLabels.removeWhere(
            (l) => l.trim().toLowerCase() == deletedTag.trim().toLowerCase(),
          );
          _mediaItems = MediaLabelService.untagMediaItems(_mediaItems, deletedTag);
        });
        widget.storage.saveActiveLabels(_activeLabels);
        widget.storage.saveMediaItems(_mediaItems);
      },
      onLabelCreated: (newLabel) {
        widget.storage.saveActiveLabels(_activeLabels);
      },
    );
  }

  void _editMediaNotes(MediaItem item) {
    EditMediaNotesDialog.show(
      context: context,
      palette: _palette,
      item: item,
      onNotesSaved: (result) {
        setState(() {
          final idx = _mediaItems.indexWhere((m) => m.id == item.id);
          if (idx != -1) {
            _mediaItems[idx] = item.copyWith(personalNotes: result);
          }
        });
        widget.storage.saveMediaItems(_mediaItems);
      },
    );
  }

  void _showUpdateProgressDialog(MediaItem item) {
    UpdateProgressDialog.show(
      context: context,
      palette: _palette,
      item: item,
      onProgressUpdated: (finalItem) {
        setState(() {
          final index = _mediaItems.indexWhere((m) => m.id == item.id);
          if (index != -1) {
            _mediaItems[index] = finalItem;
          }
        });
        widget.storage.saveMediaItems(_mediaItems);
      },
    );
  }

  void _showEditCoverDialog(MediaItem item) {
    EditCoverDialog.show(
      context: context,
      palette: _palette,
      item: item,
      onCoverUpdated: (url) {
        setState(() {
          final index = _mediaItems.indexWhere((m) => m.id == item.id);
          if (index != -1) {
            _mediaItems[index] = item.copyWith(coverUrl: url);
          }
        });
        widget.storage.saveMediaItems(_mediaItems);
      },
      onRemoveMedia: () => _confirmRemoveMedia(item),
    );
  }

  void _confirmRemoveMedia(MediaItem item) {
    ConfirmRemoveMediaDialog.show(
      context: context,
      palette: _palette,
      item: item,
      onConfirmed: () => _removeMediaItem(item.id),
    );
  }

  void _showAddMediaDialog() {
    AddMediaDialog.show(
      context: context,
      palette: _palette,
      activeLabels: _activeLabels,
      mediaItems: _mediaItems,
      onMediaAdded: (newItem) {
        setState(() {
          _mediaItems.insert(0, newItem);
        });
        widget.storage.saveMediaItems(_mediaItems);
      },
      onLabelPermanentlyDeleted: (deletedTag) {
        setState(() {
          _activeLabels.removeWhere(
            (l) => l.trim().toLowerCase() == deletedTag.trim().toLowerCase(),
          );
          _mediaItems = MediaLabelService.untagMediaItems(_mediaItems, deletedTag);
        });
        widget.storage.saveActiveLabels(_activeLabels);
        widget.storage.saveMediaItems(_mediaItems);
      },
      onLabelCreated: (newLabel) {
        widget.storage.saveActiveLabels(_activeLabels);
      },
    );
  }

  void _showEditMediaDialog(MediaItem item) {
    EditMediaDialog.show(
      context: context,
      palette: _palette,
      item: item,
      activeLabels: _activeLabels,
      mediaItems: _mediaItems,
      onMediaUpdated: (finalUpdated) {
        setState(() {
          final idx = _mediaItems.indexWhere((m) => m.id == item.id);
          if (idx != -1) {
            _mediaItems[idx] = finalUpdated;
          }
          if (finalUpdated.title != item.title) {
            for (int i = 0; i < _tasks.length; i++) {
              if (_tasks[i].linkedMediaId == item.id) {
                _tasks[i] = _tasks[i].copyWith(
                  mediaTitle: finalUpdated.title,
                  title: '🎯 Media Goal: ${finalUpdated.title}',
                );
              }
            }
          }
        });
        widget.storage.saveMediaItems(_mediaItems);
        widget.storage.saveTasks(_tasks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${finalUpdated.title}" successfully'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      onRemoveMedia: () => _confirmRemoveMedia(item),
      onLabelPermanentlyDeleted: (deletedTag) {
        setState(() {
          _activeLabels.removeWhere(
            (l) => l.trim().toLowerCase() == deletedTag.trim().toLowerCase(),
          );
          _mediaItems = MediaLabelService.untagMediaItems(_mediaItems, deletedTag);
        });
        widget.storage.saveActiveLabels(_activeLabels);
        widget.storage.saveMediaItems(_mediaItems);
      },
      onLabelCreated: (newLabel) {
        widget.storage.saveActiveLabels(_activeLabels);
      },
    );
  }

  // --- FILTER & SORT GETTERS ---
  List<Task> get _dailyTasks =>
      DateNavigationService.getTasksForDate(_tasks, _selectedDate)
        ..sort(compareTaskExecutionState);

  List<Task> get _backlogTasks => _tasks
      .where((t) => t.category == TaskCategory.general)
      .toList()
    ..sort(compareTaskExecutionState);

  void _sortMediaBySelectedSorter(List<MediaItem> list) {
    switch (_mediaSort) {
      case 'score':
        list.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
        break;
      case 'progress':
        list.sort((a, b) => b.progressRatio.compareTo(a.progressRatio));
        break;
      case 'year':
        list.sort((a, b) => b.releaseYear.compareTo(a.releaseYear));
        break;
      case 'name':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'custom':
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }

  List<({MediaType type, List<MediaItem> items})> _partitionMediaByType(List<MediaItem> items) {
    if (items.isEmpty) return const [];
    if (_mediaFilter != 'all') {
      final copy = List<MediaItem>.from(items);
      _sortMediaBySelectedSorter(copy);
      return [(type: copy.first.type, items: copy)];
    }

    final result = <({MediaType type, List<MediaItem> items})>[];
    for (final t in MediaType.values) {
      final matching = items.where((m) => m.type == t).toList();
      if (matching.isNotEmpty) {
        _sortMediaBySelectedSorter(matching);
        result.add((type: t, items: matching));
      }
    }
    return result;
  }

  List<MediaItem> get _filteredMediaItems {
    var list = _mediaItems.where((m) {
      if (_mediaFilter == 'all') return true;
      if (_mediaFilter == 'book' && m.type == MediaType.book) return true;
      if (_mediaFilter == 'tvShow' && m.type == MediaType.tvShow) return true;
      if (_mediaFilter == 'movie' && m.type == MediaType.movie) return true;
      if (_mediaFilter == 'videoGame' && m.type == MediaType.videoGame) {
        return true;
      }
      return false;
    }).toList();

    final uncompleted = list.where((m) => !m.isCompleted && !m.isOnHold).toList();
    final onHold = list.where((m) => !m.isCompleted && m.isOnHold).toList();
    final finished = list.where((m) => m.isCompleted).toList();

    List<MediaItem> flattenGroups(List<MediaItem> source) {
      final groups = _partitionMediaByType(source);
      return [for (final g in groups) ...g.items];
    }

    return [
      ...flattenGroups(uncompleted),
      ...flattenGroups(onHold),
      ...flattenGroups(finished),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _palette.bgCanvas,
      endDrawer: SettingsDrawer(
        currentVibe: widget.currentVibe,
        currentFont: widget.currentFont,
        palette: _palette,
        onSelectVibe: widget.onSelectVibe,
        onSelectFont: widget.onSelectFont,
        fontSizeScale: widget.fontSizeScale,
        onFontSizeScaleChanged: widget.onSelectFontSizeScale,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                color: _palette.bgSurface,
                border: Border(bottom: BorderSide(color: _palette.borderSubtle)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _palette.borderFocus.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6.5),
                              child: Image.asset(
                                'assets/images/Logo.jpeg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.bolt,
                                  size: 18,
                                  color: _palette.accentPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                _palette.accentGradient.createShader(bounds),
                            child: const Text(
                              'NSH Pulse',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _palette.bgElevated,
                            border: Border.all(color: _palette.borderSubtle),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.settings,
                                size: 14,
                                color: _palette.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Appearance',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _palette.textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _palette.bgElevated,
                      border: Border.all(color: _palette.borderSubtle),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSegmentButton(
                            label: '📝 Daily Pulse',
                            isActive: _currentTab == 'notes',
                            onTap: () {
                              setState(() => _currentTab = 'notes');
                              if (_pageController.hasClients) {
                                _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            label: '🎬 Entertainment',
                            isActive: _currentTab == 'entertainment',
                            onTap: () {
                              setState(() => _currentTab = 'entertainment');
                              if (_pageController.hasClients) {
                                _pageController.animateToPage(
                                  1,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentTab = index == 0 ? 'notes' : 'entertainment';
                  });
                },
                physics: const ClampingScrollPhysics(),
                children: [
                  DailyPulseView(
                    palette: _palette,
                    selectedDate: _selectedDate,
                    allTasks: _tasks,
                    events: _events,
                    dailyTasks: _dailyTasks,
                    backlogTasks: _backlogTasks,
                    isDailyFocusCollapsed: _isDailyFocusCollapsed,
                    isBacklogCollapsed: _isBacklogCollapsed,
                    scrollController: _scrollController,
                    focusSectionKey: _focusSectionKey,
                    backlogSectionKey: _backlogSectionKey,
                    onDateChanged: (newDate) => setState(() => _selectedDate = newDate),
                    onToggleCheckpoint: _toggleShamsiCheckpoint,
                    onAddEvent: _addShamsiEvent,
                    onAddCustomEvent: _showAddCustomEventDialog,
                    onRemoveEvent: _removeShamsiEvent,
                    onToggleDailyFocusCollapsed: () => setState(() => _isDailyFocusCollapsed = !_isDailyFocusCollapsed),
                    onToggleBacklogCollapsed: () => setState(() => _isBacklogCollapsed = !_isBacklogCollapsed),
                    onAddTask: _openAddTaskModal,
                    onTaskStatusChange: _setTaskStatus,
                    onPostponeOneDay: _postponeTaskOneDay,
                    onPostponeToDate: _showPostponeDatePickerModal,
                    onDemoteToBacklog: _demoteTaskToBacklog,
                    onAssignToToday: _assignTaskToToday,
                    onEditTask: _showEditTaskDialog,
                    onDeleteTask: _deleteTask,
                    onReorderDailyTasks: (oldIndex, newIndex) {
                      _stopAutoScrollTimer();
                      setState(() {
                        final reordered = ReorderService.reorderTasks(_dailyTasks, oldIndex, newIndex);
                        for (final updated in reordered) {
                          final idx = _tasks.indexWhere((t) => t.id == updated.id);
                          if (idx != -1) {
                            _tasks[idx] = updated;
                          }
                        }
                      });
                      widget.storage.saveTasks(_tasks);
                    },
                    onReorderBacklogTasks: (oldIndex, newIndex) {
                      _stopAutoScrollTimer();
                      setState(() {
                        final reordered = ReorderService.reorderTasks(_backlogTasks, oldIndex, newIndex);
                        for (final updated in reordered) {
                          final idx = _tasks.indexWhere((t) => t.id == updated.id);
                          if (idx != -1) {
                            _tasks[idx] = updated;
                          }
                        }
                      });
                      widget.storage.saveTasks(_tasks);
                    },
                    onDragAutoScrollStart: () {
                      _isDraggingTask = true;
                      _startAutoScrollTimer();
                    },
                    onDragAutoScrollStop: _stopAutoScrollTimer,
                    onPointerMove: (dy) => _lastPointerY = dy,
                  ),
                  EntertainmentView(
                    palette: _palette,
                    mediaList: _filteredMediaItems,
                    mediaFilter: _mediaFilter,
                    mediaSort: _mediaSort,
                    isMediaGrid: _isMediaGrid,
                    scrollController: _entertainmentScrollController,
                    activeMediaKey: _activeMediaKey,
                    onHoldMediaKey: _onHoldMediaKey,
                    finishedMediaKey: _finishedMediaKey,
                    onFilterChanged: (filter) => setState(() => _mediaFilter = filter),
                    onSortChanged: (sort) {
                      setState(() => _mediaSort = sort);
                      widget.storage.saveMediaSort(sort);
                    },
                    onToggleViewMode: (isGrid) {
                      setState(() => _isMediaGrid = isGrid);
                      widget.storage.saveMediaViewMode(isGrid ? 'grid' : 'list');
                    },
                    onAddMedia: _showAddMediaDialog,
                    onToggleOnHold: _toggleMediaOnHold,
                    onUpdateProgress: _showUpdateProgressDialog,
                    onEditCover: _showEditCoverDialog,
                    onScheduleToday: _scheduleMediaToday,
                    onEditNotes: _editMediaNotes,
                    onEditLabels: _showEditLabelsDialog,
                    onEditMedia: _showEditMediaDialog,
                    onDeleteMedia: _removeMediaItem,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _palette.bgSurface : Colors.transparent,
          border: isActive
              ? Border.all(color: _palette.borderSubtle)
              : null,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? _palette.textMain : _palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

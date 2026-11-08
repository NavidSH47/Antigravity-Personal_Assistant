import 'dart:async';
import 'package:flutter/material.dart';
import 'models/task.dart';
import 'models/shamsi_event.dart';
import 'models/media_item.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'services/date_navigation_service.dart';
import 'services/task_reschedule_service.dart';
import 'services/task_stream_flow_service.dart';
import 'services/reorder_service.dart';
import 'services/media_ledger_cleanup_service.dart';
import 'services/dual_calendar_service.dart';
import 'services/media_label_service.dart';
import 'services/media_goal_sync_service.dart';
import 'services/cover_fetch_service.dart';
import 'services/sentence_case_service.dart';
import 'widgets/shamsi_agenda_banner.dart';
import 'widgets/task_card.dart';
import 'widgets/media_card.dart';
import 'widgets/settings_drawer.dart';
import 'widgets/rtl_aware_text_field.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'services/title_case_service.dart';
import 'widgets/safe_cover_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  runApp(NSHAssistantApp(storage: storage));
}

class NSHAssistantApp extends StatefulWidget {
  final StorageService storage;

  const NSHAssistantApp({super.key, required this.storage});

  @override
  State<NSHAssistantApp> createState() => _NSHAssistantAppState();
}

class _NSHAssistantAppState extends State<NSHAssistantApp> {
  late ThemeVibe _currentVibe;
  late AppFontStyle _currentFont;

  @override
  void initState() {
    super.initState();
    _currentVibe = widget.storage.loadThemeVibe();
    _currentFont = widget.storage.loadFontStyle();
  }

  void _updateThemeVibe(ThemeVibe vibe) {
    setState(() => _currentVibe = vibe);
    widget.storage.saveThemeVibe(vibe);
  }

  void _updateFontStyle(AppFontStyle font) {
    setState(() => _currentFont = font);
    widget.storage.saveFontStyle(font);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSH Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.createTheme(_currentVibe, _currentFont),
      home: HomeScreen(
        storage: widget.storage,
        currentVibe: _currentVibe,
        currentFont: _currentFont,
        onSelectVibe: _updateThemeVibe,
        onSelectFont: _updateFontStyle,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final ThemeVibe currentVibe;
  final AppFontStyle currentFont;
  final Function(ThemeVibe) onSelectVibe;
  final Function(AppFontStyle) onSelectFont;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.currentVibe,
    required this.currentFont,
    required this.onSelectVibe,
    required this.onSelectFont,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Existing fields...
  // Added placeholder methods for media scheduling and notes editing
  void _scheduleMediaToday(MediaItem item) {
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
              backgroundColor: _palette.bgElevated,
              title: Text(
                'Schedule Daily Goal',
                style: TextStyle(
                  color: _palette.textMain,
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
                        color: _palette.bgSurface,
                        border: Border.all(color: _palette.borderSubtle),
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
                                    color: _palette.textMain,
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
                                    color: _palette.accentPrimary,
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
                        color: _palette.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: _palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Target Amount (${item.metricUnit})',
                        labelStyle: TextStyle(color: _palette.textMuted),
                        errorText: error,
                        filled: true,
                        fillColor: _palette.bgSurface,
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
                          labelStyle: TextStyle(fontSize: 11, color: _palette.textMain),
                          backgroundColor: _palette.bgSurface,
                          onPressed: remaining >= 5 ? () => selectIncrement(5) : null,
                        ),
                        ActionChip(
                          label: const Text('+10'),
                          labelStyle: TextStyle(fontSize: 11, color: _palette.textMain),
                          backgroundColor: _palette.bgSurface,
                          onPressed: remaining >= 10 ? () => selectIncrement(10) : null,
                        ),
                        ActionChip(
                          label: const Text('+25'),
                          labelStyle: TextStyle(fontSize: 11, color: _palette.textMain),
                          backgroundColor: _palette.bgSurface,
                          onPressed: remaining >= 25 ? () => selectIncrement(25) : null,
                        ),
                        ActionChip(
                          label: Text('Finish (${MediaGoalSyncService.formatUnits(remaining)})'),
                          labelStyle: TextStyle(fontSize: 11, color: _palette.accentPrimary),
                          backgroundColor: _palette.bgSurface,
                          onPressed: remaining > 0 ? finishRemaining : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RtlAwareTextField(
                      controller: noteController,
                      style: TextStyle(color: _palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Optional note (e.g. read chapter 4, watch with friends)',
                        labelStyle: TextStyle(color: _palette.textMuted),
                        filled: true,
                        fillColor: _palette.bgSurface,
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
                  child: Text('Cancel', style: TextStyle(color: _palette.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _palette.accentPrimary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: error == null && curAmount != null && curAmount > 0
                      ? () {
                          final todayKey = DateNavigationService.formatJalaliKey(Jalali.now());
                          final task = MediaGoalSyncService.createLinkedTask(
                            item: item,
                            amount: curAmount,
                            todayKey: todayKey,
                            orderIndex: _tasks.length,
                            notes: noteController.text.trim(),
                          );
                          setState(() {
                            _tasks.add(task);
                          });
                          widget.storage.saveTasks(_tasks);
                          Navigator.pop(dCtx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                MediaGoalSyncService.scheduledNotification(item, curAmount),
                              ),
                              action: SnackBarAction(
                                label: 'View in Daily Pulse',
                                textColor: _palette.accentPrimary,
                                onPressed: () {
                                  setState(() {
                                    _currentTab = 'notes';
                                  });
                                },
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
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

  void _showConfirmDeleteLabelDialog({
    required String tag,
    required VoidCallback onConfirmed,
  }) {
    showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          backgroundColor: _palette.bgSurface,
          title: Text(
            'Delete Label?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _palette.textMain,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete "$tag" from the database? This will untag it from all media items.',
            style: TextStyle(fontSize: 13, color: _palette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel', style: TextStyle(color: _palette.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                onConfirmed();
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  void _showLabelSelectionModal({
    required BuildContext context,
    required List<String> initialSelected,
    required ValueChanged<List<String>> onDone,
  }) {
    List<String> selected = List<String>.from(initialSelected);
    final searchController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _palette.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setMState) {
            final poolSet = <String>{..._activeLabels};
            for (final m in _mediaItems) {
              poolSet.addAll(m.labels);
            }
            final pool = poolSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            final filteredPool = pool.where((tag) {
              if (searchQuery.trim().isEmpty) return true;
              return tag.toLowerCase().contains(searchQuery.trim().toLowerCase());
            }).toList();

            final canAddNew = searchQuery.trim().isNotEmpty &&
                !pool.any((t) => t.toLowerCase() == searchQuery.trim().toLowerCase());

            void addTag(String val) {
              final trimmed = toSentenceCase(val.trim());
              if (trimmed.isNotEmpty) {
                setMState(() {
                  if (!_activeLabels.any((l) => l.toLowerCase() == trimmed.toLowerCase())) {
                    _activeLabels.add(trimmed);
                    widget.storage.saveActiveLabels(_activeLabels);
                  }
                  selected = MediaLabelService.addLabel(selected, trimmed);
                  searchController.clear();
                  searchQuery = '';
                });
                setState(() {});
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🏷️ ', style: TextStyle(fontSize: 16)),
                            Text(
                              'Select Labels / Tags',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _palette.textMain,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: _palette.textMuted, size: 20),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search or add new tag
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            textCapitalization: TextCapitalization.sentences,
                            inputFormatters: [SentenceCaseTextInputFormatter()],
                            style: TextStyle(color: _palette.textMain),
                            decoration: InputDecoration(
                              hintText: 'Search or add new tag...',
                              hintStyle: TextStyle(color: _palette.textDim),
                              prefixIcon: Icon(Icons.search, size: 18, color: _palette.textDim),
                              filled: true,
                              fillColor: _palette.bgSurface,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: _palette.borderSubtle),
                              ),
                            ),
                            onChanged: (val) => setMState(() => searchQuery = val),
                            onSubmitted: addTag,
                          ),
                        ),
                        if (canAddNew) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _palette.accentPrimary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add'),
                            onPressed: () => addTag(searchQuery),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (selected.isNotEmpty) ...[
                      Text(
                        'Selected (${selected.length}):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _palette.accentPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selected.map((tag) {
                          return Chip(
                            label: Text(tag),
                            labelStyle: TextStyle(
                              color: _palette.textMain,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: _palette.bgSurface,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: _palette.textMuted,
                            onDeleted: () {
                              setMState(() {
                                selected = MediaLabelService.removeLabel(selected, tag);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Divider(color: _palette.borderSubtle, height: 1),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Available Labels:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: filteredPool.map((tag) {
                            final isSelected = selected.contains(tag);
                            return InkWell(
                              onTap: () {
                                setMState(() {
                                  if (isSelected) {
                                    selected = MediaLabelService.removeLabel(selected, tag);
                                  } else {
                                    selected = MediaLabelService.addLabel(selected, tag);
                                  }
                                });
                              },
                              onLongPress: () {
                                _showConfirmDeleteLabelDialog(
                                  tag: tag,
                                  onConfirmed: () {
                                    setMState(() {
                                      _activeLabels.removeWhere(
                                        (l) => l.trim().toLowerCase() == tag.trim().toLowerCase(),
                                      );
                                      widget.storage.saveActiveLabels(_activeLabels);

                                      selected = MediaLabelService.removeLabel(selected, tag);

                                      _mediaItems = MediaLabelService.untagMediaItems(_mediaItems, tag);
                                      widget.storage.saveMediaItems(_mediaItems);
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? _palette.accentPrimary : _palette.bgSurface,
                                  border: Border.all(
                                    color: isSelected ? _palette.accentPrimary : _palette.borderSubtle,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.black : _palette.textMain,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _palette.accentPrimary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        onDone(selected);
                        Navigator.pop(modalCtx);
                      },
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditLabelsDialog(MediaItem item) {
    _showLabelSelectionModal(
      context: context,
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
    );
  }



  void _editMediaNotes(MediaItem item) async {
    final controller = TextEditingController(text: item.personalNotes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _palette.bgElevated,
        title: Text(
          'Edit Media Notes',
          style: TextStyle(color: _palette.textMain, fontWeight: FontWeight.bold),
        ),
        content: RtlAwareTextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: _palette.textMain),
          decoration: InputDecoration(
            hintText: 'Enter notes',
            hintStyle: TextStyle(color: _palette.textDim.withValues(alpha: 0.45)),
            filled: true,
            fillColor: _palette.bgSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: _palette.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _palette.accentPrimary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(toSentenceCase(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        final idx = _mediaItems.indexWhere((m) => m.id == item.id);
        if (idx != -1) {
          _mediaItems[idx] = item.copyWith(personalNotes: result);
        }
      });
      widget.storage.saveMediaItems(_mediaItems);
    }
  }

  // Existing methods continue...
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
  Timer? _dragAutoScrollTimer;
  double _lastPointerY = 0.0;
  bool _isDraggingTask = false;

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

  @override
  void dispose() {
    _pageController.dispose();
    _dragAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _removeShamsiEvent(ShamsiEvent event) {
    setState(() {
      _events.removeWhere((e) => e.id == event.id);
    });
    widget.storage.saveShamsiEvents(_events);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = Jalali.now();
    _tasks = widget.storage.loadTasks();
    _events = widget.storage.loadShamsiEvents();
    _mediaItems = widget.storage.loadMediaItems();
    _activeLabels = widget.storage.loadActiveLabels();
    _isMediaGrid = widget.storage.loadMediaViewMode() == 'grid';
    _pageController = PageController(initialPage: _currentTab == 'notes' ? 0 : 1);
  }

  VibePalette get _palette =>
      AppTheme.vibes[widget.currentVibe] ??
      AppTheme.vibes[ThemeVibe.deepAmethyst]!;

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
        _tasks[index] =
            TaskStreamFlowService.promoteToDaily(task, _selectedDate);
      }
    });
    widget.storage.saveTasks(_tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isViewingToday
              ? 'Task scheduled for Today\'s Focus!'
              : 'Task scheduled for ${DualCalendarService.toShamsiString(_selectedDate)}!',
        ),
        duration: const Duration(seconds: 1),
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
        content: Text('Task moved to Backlog / Orbit!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _postponeTaskOneDay(Task task) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] =
            TaskRescheduleService.postponeOneDay(task, _selectedDate);
      }
    });
    widget.storage.saveTasks(_tasks);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task postponed to tomorrow!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _postponeTaskToDate(Task task, Jalali targetDate) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] =
            TaskRescheduleService.postponeToDate(task, targetDate);
      }
    });
    widget.storage.saveTasks(_tasks);
    final formatted = DualCalendarService.toShamsiString(targetDate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task rescheduled to $formatted'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showPostponeDatePickerModal(Task task) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _palette.bgElevated,
          title: Text(
            'Reschedule Task',
            style: TextStyle(
              color: _palette.textMain,
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
                  style: TextStyle(color: _palette.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showPersianDatePicker(
                      context: context,
                      initialDate: _selectedDate.addDays(1),
                      firstDate: Jalali(1380, 1, 1),
                      lastDate: Jalali(1450, 12, 29),
                    );
                    if (picked != null) {
                      _postponeTaskToDate(task, picked);
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
                      color: _palette.accentPrimary.withValues(alpha: 0.15),
                      border: Border.all(color: _palette.accentPrimary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('??? ', style: TextStyle(fontSize: 13)),
                        Text(
                          'Pick Custom Shamsi Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _palette.accentPrimary,
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
                  final target = _selectedDate.addDays(daysToAdd);
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
                      _postponeTaskToDate(task, target);
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
                        color: _palette.bgSurface,
                        border: Border.all(color: _palette.borderSubtle),
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
                                  color: _palette.accentPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                shamsiStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _palette.textMain,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            gregStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: _palette.textDim,
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
                style: TextStyle(color: _palette.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteTask(Task task) {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    widget.storage.saveTasks(_tasks);
  }

  void _showAddCustomEventDialog() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    Jalali targetDate = _selectedDate;
    EventCategory selectedCategory = EventCategory.birthday;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: _palette.bgElevated,
              title: Row(
                children: [
                  const Text('📅 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'Add Custom Event',
                    style: TextStyle(
                      color: _palette.textMain,
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
                      style: TextStyle(color: _palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'e.g. Sara\'s Birthday, Exam...',
                        hintStyle: TextStyle(color: _palette.textDim),
                        labelStyle: TextStyle(color: _palette.textMuted),
                        filled: true,
                        fillColor: _palette.bgSurface,
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
                          color: _palette.bgSurface,
                          border: Border.all(color: _palette.borderSubtle),
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
                                    color: _palette.textMain,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.edit, size: 14, color: _palette.accentPrimary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Event Type:',
                      style: TextStyle(
                        color: _palette.textMuted,
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
                                    : _palette.bgSurface,
                                border: Border.all(
                                  color: selectedCategory == EventCategory.birthday
                                      ? const Color(0xFFEC4899)
                                      : _palette.borderSubtle,
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
                                        : _palette.textMuted,
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
                                    : _palette.bgSurface,
                                border: Border.all(
                                  color: selectedCategory == EventCategory.customDate
                                      ? const Color(0xFF60A5FA)
                                      : _palette.borderSubtle,
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
                                        : _palette.textMuted,
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
                      style: TextStyle(color: _palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Optional Notes',
                        hintText: '+ Add reminder notes...',
                        hintStyle: TextStyle(color: _palette.textDim.withValues(alpha: 0.45)),
                        labelStyle: TextStyle(color: _palette.textMuted),
                        filled: true,
                        fillColor: _palette.bgSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text('Cancel', style: TextStyle(color: _palette.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _palette.accentPrimary,
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
                      setState(() {
                        _events.add(newEvt);
                      });
                      widget.storage.saveShamsiEvents(_events);
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

  void _showEditTaskDialog(Task task) {
    final titleController = TextEditingController(text: task.title);
    final notesController = TextEditingController(text: task.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _palette.bgElevated,
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
                  color: _palette.textMain,
                ),
              ),
              const SizedBox(height: 14),
              RtlAwareTextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(color: _palette.textMain),
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: TextStyle(color: _palette.textMuted),
                  hintText: 'What needs to get done?',
                  hintStyle: TextStyle(color: _palette.textDim),
                  filled: true,
                  fillColor: _palette.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _palette.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              RtlAwareTextField(
                controller: notesController,
                maxLines: 3,
                style: TextStyle(color: _palette.textMain),
                decoration: InputDecoration(
                  labelText: 'Notes / Description',
                  labelStyle: TextStyle(color: _palette.textMuted),
                  hintText: 'Add extra details, checklist bullets, or notes (optional)...',
                  hintStyle: TextStyle(color: _palette.textDim.withValues(alpha: 0.45)),
                  filled: true,
                  fillColor: _palette.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _palette.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: _palette.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _palette.accentPrimary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final title = toSentenceCase(titleController.text.trim());
                      if (title.isNotEmpty) {
                        final notes = toSentenceCase(notesController.text.trim());
                        setState(() {
                          final idx = _tasks.indexWhere((t) => t.id == task.id);
                          if (idx != -1) {
                            _tasks[idx] = task.copyWith(
                              title: title,
                              notes: notes,
                            );
                          }
                        });
                        widget.storage.saveTasks(_tasks);
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

  void _openAddTaskModal(TaskCategory category) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _palette.bgElevated,
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
                  color: _palette.textMain,
                ),
              ),
              const SizedBox(height: 14),
              RtlAwareTextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(color: _palette.textMain),
                decoration: InputDecoration(
                  hintText: 'What needs to get done?',
                  hintStyle: TextStyle(color: _palette.textDim),
                  filled: true,
                  fillColor: _palette.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _palette.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              RtlAwareTextField(
                controller: notesController,
                maxLines: 3,
                style: TextStyle(color: _palette.textMain),
                decoration: InputDecoration(
                  hintText:
                      'Add extra details, checklist bullets, or notes (optional)...',
                  hintStyle: TextStyle(color: _palette.textDim.withValues(alpha: 0.45)),
                  filled: true,
                  fillColor: _palette.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _palette.borderSubtle),
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
                      style: TextStyle(color: _palette.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _palette.accentPrimary,
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
                              ? DateNavigationService.formatJalaliKey(_selectedDate)
                              : null,
                        );
                        setState(() {
                          _tasks.insert(0, newTask);
                        });
                        widget.storage.saveTasks(_tasks);
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

  void _toggleShamsiCheckpoint(ShamsiEvent event) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] =
            event.copyWith(actionChecked: !event.actionChecked);
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
    final itemIndex = _mediaItems.indexWhere((m) => m.id == mediaId);
    if (itemIndex == -1) return;

    final removedItem = _mediaItems[itemIndex];
    // Decouple linked tasks without removing task history
    final affectedTaskIndices = <int>[];
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].linkedMediaId == mediaId) {
        affectedTaskIndices.add(i);
      }
    }

    setState(() {
      _mediaItems.removeAt(itemIndex);
      for (final idx in affectedTaskIndices) {
        _tasks[idx] = _tasks[idx].copyWith(clearLinkedMedia: true);
      }
    });

    widget.storage.saveMediaItems(_mediaItems);
    widget.storage.saveTasks(_tasks);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${removedItem.title}" from library.'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: _palette.accentPrimary,
          onPressed: () {
            setState(() {
              _mediaItems.insert(itemIndex, removedItem);
              for (final idx in affectedTaskIndices) {
                if (idx < _tasks.length) {
                  _tasks[idx] = _tasks[idx].copyWith(
                    linkedMediaId: removedItem.id,
                    mediaTitle: removedItem.title,
                  );
                }
              }
            });
            widget.storage.saveMediaItems(_mediaItems);
            widget.storage.saveTasks(_tasks);
          },
        ),
      ),
    );
  }

  void _confirmRemoveMedia(MediaItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _palette.bgElevated,
        title: Text(
          'Remove Media Item',
          style: TextStyle(
            color: _palette.textMain,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${item.title}" from your library? Any ongoing daily goals linked to this item will remain as standalone tasks.',
          style: TextStyle(color: _palette.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _palette.borderSubtle),
              foregroundColor: _palette.textMuted,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _removeMediaItem(item.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showUpdateProgressDialog(MediaItem item) {
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
              backgroundColor: _palette.bgElevated,
              title: Text(
                'Update: ${item.title}',
                style: TextStyle(
                  color: _palette.textMain,
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
                      color: _palette.accentPrimary,
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
                          style: TextStyle(color: _palette.textMain),
                          decoration: InputDecoration(
                            labelText: MediaLedgerCleanupService.currentUnitInputLabelFor(item.type),
                            labelStyle: TextStyle(color: _palette.textMuted),
                            filled: true,
                            fillColor: _palette.bgSurface,
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
                          style: TextStyle(color: _palette.textMain),
                          decoration: InputDecoration(
                            labelText: MediaLedgerCleanupService.unitInputLabelFor(item.type),
                            labelStyle: TextStyle(color: _palette.textMuted),
                            filled: true,
                            fillColor: _palette.bgSurface,
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
                          color: _palette.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '⭐ ${selectedScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: _palette.accentPrimary,
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
                    activeColor: _palette.accentPrimary,
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
                    style: TextStyle(color: _palette.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _palette.accentPrimary,
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

                    setState(() {
                      final index = _mediaItems.indexWhere((m) => m.id == item.id);
                      if (index != -1) {
                        _mediaItems[index] = item.copyWith(
                          progressCurrent: curParsed,
                          progressTotal: totParsed,
                          score: selectedScore,
                        );
                      }
                    });
                    widget.storage.saveMediaItems(_mediaItems);
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

  void _showEditCoverDialog(MediaItem item) {
    final urlController = TextEditingController(text: item.coverUrl ?? '');
    bool isSearchingCovers = false;
    List<CoverSearchResult> candidates = [];
    String? searchMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: _palette.bgElevated,
              title: Text(
                'Cover Art: ${item.title}',
                style: TextStyle(
                  color: _palette.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: urlController,
                      style: TextStyle(color: _palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Image Web URL',
                        hintText: 'https://...',
                        labelStyle: TextStyle(color: _palette.textMuted),
                        filled: true,
                        fillColor: _palette.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setDState(() {}),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: isSearchingCovers
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.search, size: 14),
                      label: const Text('🔍 Auto-Fetch Cover'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _palette.accentPrimary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                      ),
                      onPressed: isSearchingCovers
                          ? null
                          : () async {
                              setDState(() {
                                isSearchingCovers = true;
                                searchMsg = null;
                              });
                              final results =
                                  await CoverFetchService.searchCovers(
                                query: item.title,
                                type: item.type,
                              );
                              setDState(() {
                                isSearchingCovers = false;
                                candidates = results;
                                if (results.isEmpty) {
                                  searchMsg =
                                      'No covers found for "${item.title}".';
                                }
                              });
                            },
                    ),
                    if (searchMsg != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        searchMsg!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _palette.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (candidates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 85,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: candidates.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final c = candidates[idx];
                            final isSelected =
                                urlController.text == c.coverUrl;
                            return InkWell(
                              onTap: () {
                                urlController.text = c.coverUrl;
                                setDState(() {});
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? _palette.accentPrimary
                                        : _palette.borderSubtle,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    SafeCoverImage(
                                      url: c.coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child:
                                            Icon(Icons.broken_image, size: 16),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                        color: Colors.black.withValues(alpha: 0.75),
                                        child: Text(
                                          c.source,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (urlController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 75,
                            height: 100,
                            child: SafeCoverImage(
                              url: urlController.text.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.broken_image, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove Cover (Use Placeholder)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _palette.bgSurface,
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          final index =
                              _mediaItems.indexWhere((m) => m.id == item.id);
                          if (index != -1) {
                            _mediaItems[index] = item.copyWith(coverUrl: '');
                          }
                        });
                        widget.storage.saveMediaItems(_mediaItems);
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text('🗑️ Remove Media'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x66EF4444)),
                        foregroundColor: const Color(0xFFEF4444),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmRemoveMedia(item);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: _palette.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _palette.accentPrimary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final url = SafeCoverImage.sanitizeUrl(urlController.text);
                    setState(() {
                      final index =
                          _mediaItems.indexWhere((m) => m.id == item.id);
                      if (index != -1) {
                        _mediaItems[index] = item.copyWith(coverUrl: url);
                      }
                    });
                    widget.storage.saveMediaItems(_mediaItems);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMediaDialog() {
    final titleController = TextEditingController();
    final yearController =
        TextEditingController(text: DateTime.now().year.toString());
    final totalController = TextEditingController(text: '100');
    final coverUrlController = TextEditingController();
    MediaType selectedType = MediaType.book;
    List<String> selectedLabels = [];
    bool isSearchingCovers = false;
    List<CoverSearchResult> candidates = [];
    String? coverSearchMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: _palette.bgElevated,
              title: Text(
                'Add Media Item',
                style: TextStyle(
                  color: _palette.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<MediaType>(
                      initialValue: selectedType,
                      dropdownColor: _palette.bgElevated,
                      style: TextStyle(color: _palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: _palette.textMuted),
                        filled: true,
                        fillColor: _palette.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: MediaType.book,
                          child: Text('📖 Book'),
                        ),
                        DropdownMenuItem(
                          value: MediaType.tvShow,
                          child: Text('📺 TV Show'),
                        ),
                        DropdownMenuItem(
                          value: MediaType.movie,
                          child: Text('🎬 Movie'),
                        ),
                        DropdownMenuItem(
                          value: MediaType.videoGame,
                          child: Text('🎮 Video Game'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    RtlAwareTextField(
                      controller: titleController,
                      style: TextStyle(color: _palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: _palette.textMuted),
                        filled: true,
                        fillColor: _palette.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: _palette.textMain),
                            decoration: InputDecoration(
                              labelText: 'Release Year',
                              labelStyle: TextStyle(color: _palette.textMuted),
                              filled: true,
                              fillColor: _palette.bgSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: totalController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: _palette.textMain),
                            decoration: InputDecoration(
                              labelText: MediaLedgerCleanupService.unitInputLabelFor(selectedType),
                              labelStyle: TextStyle(color: _palette.textMuted),
                              filled: true,
                              fillColor: _palette.bgSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Labels / Tags:',
                      style: TextStyle(
                        color: _palette.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        _showLabelSelectionModal(
                          context: dCtx,
                          initialSelected: selectedLabels,
                          onDone: (newLabels) {
                            setDState(() => selectedLabels = newLabels);
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _palette.bgSurface,
                          border: Border.all(color: _palette.borderSubtle),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedLabels.isEmpty
                                  ? '🏷️ Select Labels / Tags'
                                  : '🏷️ Labels (${selectedLabels.length}): ${selectedLabels.take(3).join(', ')}${selectedLabels.length > 3 ? '...' : ''}',
                              style: TextStyle(
                                color: selectedLabels.isEmpty ? _palette.textDim : _palette.accentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.edit, size: 14, color: _palette.textDim),
                          ],
                        ),
                      ),
                    ),
                    if (selectedLabels.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: selectedLabels.map((l) {
                          return Chip(
                            label: Text(l),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: _palette.textMain,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: _palette.bgSurface,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: _palette.textMuted,
                            onDeleted: () {
                              setDState(() {
                                selectedLabels = MediaLabelService.removeLabel(selectedLabels, l);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Cover Art:',
                      style: TextStyle(
                        color: _palette.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: coverUrlController,
                            style: TextStyle(color: _palette.textMain),
                            decoration: InputDecoration(
                              hintText: 'Image URL (https://...)',
                              hintStyle: TextStyle(color: _palette.textDim),
                              filled: true,
                              fillColor: _palette.bgSurface,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (_) => setDState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: isSearchingCovers
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.search, size: 14),
                          label: const Text('🔍 Auto-Fetch', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _palette.accentPrimary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            elevation: 0,
                          ),
                          onPressed: isSearchingCovers
                              ? null
                              : () async {
                                  final query = titleController.text.trim();
                                  if (query.isEmpty) {
                                    setDState(() => coverSearchMsg = 'Enter title first!');
                                    return;
                                  }
                                  setDState(() {
                                    isSearchingCovers = true;
                                    coverSearchMsg = null;
                                  });
                                  final results = await CoverFetchService.searchCovers(
                                    query: query,
                                    type: selectedType,
                                  );
                                  setDState(() {
                                    isSearchingCovers = false;
                                    candidates = results;
                                    if (results.isEmpty) {
                                      coverSearchMsg = 'No covers found for "$query".';
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                    if (coverSearchMsg != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        coverSearchMsg!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _palette.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (candidates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 85,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: candidates.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final c = candidates[idx];
                            final isSelected = coverUrlController.text == c.coverUrl;
                            return InkWell(
                              onTap: () {
                                coverUrlController.text = c.coverUrl;
                                setDState(() {});
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? _palette.accentPrimary : _palette.borderSubtle,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    SafeCoverImage(
                                      url: c.coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child: Icon(Icons.broken_image, size: 16),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                        color: Colors.black.withValues(alpha: 0.75),
                                        child: Text(
                                          c.source,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (coverUrlController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 36,
                              height: 48,
                              child: SafeCoverImage(
                                url: coverUrlController.text.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cover selected',
                            style: TextStyle(
                              fontSize: 11,
                              color: _palette.accentPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: _palette.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _palette.accentPrimary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final title = toSentenceCase(titleController.text.trim());
                    if (title.isNotEmpty) {
                      final year = int.tryParse(yearController.text) ?? 2024;
                      final total = double.tryParse(totalController.text) ?? 100;
                      final cover = coverUrlController.text.trim().isEmpty
                          ? null
                          : SafeCoverImage.sanitizeUrl(coverUrlController.text);
                      final newItem = MediaItem(
                        id: 'media_${DateTime.now().millisecondsSinceEpoch}',
                        type: selectedType,
                        title: title,
                        releaseYear: year,
                        labels: selectedLabels,
                        coverUrl: cover,
                        progressCurrent: 0,
                        progressTotal: total,
                      );
                      setState(() {
                        _mediaItems.insert(0, newItem);
                      });
                      widget.storage.saveMediaItems(_mediaItems);
                      Navigator.pop(dCtx);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMediaDialog(MediaItem item) {
    final titleController = TextEditingController(text: item.title);
    final yearController = TextEditingController(text: item.releaseYear.toString());
    final notesController = TextEditingController(text: item.personalNotes ?? '');
    final coverUrlController = TextEditingController(text: item.coverUrl ?? '');
    final currentUnitsController = TextEditingController(
      text: item.progressCurrent % 1 == 0 ? item.progressCurrent.toInt().toString() : item.progressCurrent.toString(),
    );
    final totalCapacityController = TextEditingController(
      text: item.progressTotal % 1 == 0 ? item.progressTotal.toInt().toString() : item.progressTotal.toString(),
    );
    double rating = (item.score ?? 5.0).clamp(1.0, 10.0);
    bool onHold = item.isOnHold;
    List<String> labels = List<String>.from(item.labels);
    String? validationError;
    bool isSearchingCovers = false;
    List<CoverSearchResult> candidates = [];
    String? coverSearchMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: _palette.bgElevated,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('✏️ ', style: TextStyle(fontSize: 16)),
                      Text(
                        'Edit Media Item',
                        style: TextStyle(
                          color: _palette.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: _palette.textMuted, size: 20),
                    onPressed: () => Navigator.pop(dCtx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (validationError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0x20EF4444),
                            border: Border.all(color: const Color(0xFFEF4444)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            validationError!,
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                          ),
                        ),
                      ],
                      // Title
                      RtlAwareTextField(
                        controller: titleController,
                        style: TextStyle(color: _palette.textMain),
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(color: _palette.textMuted),
                          filled: true,
                          fillColor: _palette.bgSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Release Year
                      TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: _palette.textMain),
                        decoration: InputDecoration(
                          labelText: 'Release Year',
                          labelStyle: TextStyle(color: _palette.textMuted),
                          filled: true,
                          fillColor: _palette.bgSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Notes / Description
                      RtlAwareTextField(
                        controller: notesController,
                        maxLines: 3,
                        style: TextStyle(color: _palette.textMain),
                        decoration: InputDecoration(
                          labelText: 'Personal Notes & Description',
                          labelStyle: TextStyle(color: _palette.textMuted),
                          hintText: '+ Add personal description/notes...',
                          hintStyle: TextStyle(color: _palette.textDim.withValues(alpha: 0.45)),
                          filled: true,
                          fillColor: _palette.bgSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cover Preview & URL & Auto-fetch
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _palette.bgSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _palette.borderSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: coverUrlController.text.trim().isNotEmpty
                                ? SafeCoverImage(url: coverUrlController.text.trim())
                                : Center(child: Icon(Icons.image, color: _palette.textDim, size: 24)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: coverUrlController,
                                  style: TextStyle(color: _palette.textMain, fontSize: 12),
                                  decoration: InputDecoration(
                                    labelText: 'Cover Image URL',
                                    labelStyle: TextStyle(color: _palette.textMuted, fontSize: 11),
                                    filled: true,
                                    fillColor: _palette.bgSurface,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => setDState(() {}),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _palette.bgSurface,
                                    foregroundColor: _palette.accentPrimary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  icon: isSearchingCovers
                                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.search, size: 14),
                                  label: Text(
                                    isSearchingCovers ? 'Searching...' : '🔍 Auto-Fetch Cover',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: isSearchingCovers
                                      ? null
                                      : () async {
                                          final query = titleController.text.trim();
                                          if (query.isEmpty) return;
                                          setDState(() {
                                            isSearchingCovers = true;
                                            coverSearchMsg = null;
                                          });
                                          try {
                                            final results = await CoverFetchService.searchCovers(
                                              query: query,
                                              type: item.type,
                                            );
                                            setDState(() {
                                              isSearchingCovers = false;
                                              candidates = results;
                                              if (results.isEmpty) {
                                                coverSearchMsg = 'No covers found for "$query"';
                                              }
                                            });
                                          } catch (_) {
                                            setDState(() {
                                              isSearchingCovers = false;
                                              coverSearchMsg = 'Search failed';
                                            });
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (coverSearchMsg != null) ...[
                        const SizedBox(height: 6),
                        Text(coverSearchMsg!, style: TextStyle(color: _palette.textDim, fontSize: 11)),
                      ],
                      if (candidates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Select Cover:', style: TextStyle(color: _palette.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: candidates.length,
                            separatorBuilder: (c, i) => const SizedBox(width: 8),
                            itemBuilder: (c, idx) {
                              final cand = candidates[idx];
                              final isSelected = coverUrlController.text == cand.coverUrl;
                              return InkWell(
                                onTap: () {
                                  setDState(() {
                                    coverUrlController.text = cand.coverUrl;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 65,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected ? _palette.accentPrimary : _palette.borderSubtle,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      SafeCoverImage(
                                        url: cand.coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Center(
                                          child: Icon(Icons.broken_image, size: 16),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                          color: Colors.black.withValues(alpha: 0.75),
                                          child: Text(
                                            cand.source,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Progress & Capacity
                      Text(
                        'Metric: ${item.metricUnit}',
                        style: TextStyle(
                          color: _palette.accentPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: currentUnitsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: _palette.textMain),
                              decoration: InputDecoration(
                                labelText: MediaLedgerCleanupService.currentUnitInputLabelFor(item.type),
                                labelStyle: TextStyle(color: _palette.textMuted),
                                filled: true,
                                fillColor: _palette.bgSurface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: totalCapacityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: _palette.textMain),
                              decoration: InputDecoration(
                                labelText: MediaLedgerCleanupService.unitInputLabelFor(item.type),
                                labelStyle: TextStyle(color: _palette.textMuted),
                                filled: true,
                                fillColor: _palette.bgSurface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Labels picker button
                      InkWell(
                        onTap: () {
                          _showLabelSelectionModal(
                            context: dCtx,
                            initialSelected: labels,
                            onDone: (newLabels) {
                              setDState(() => labels = newLabels);
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _palette.bgSurface,
                            border: Border.all(color: _palette.borderSubtle),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                labels.isEmpty ? '🏷️ Select Labels / Tags' : '🏷️ Labels (${labels.length}): ${labels.take(3).join(', ')}${labels.length > 3 ? '...' : ''}',
                                style: TextStyle(
                                  color: labels.isEmpty ? _palette.textDim : _palette.accentPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(Icons.edit, size: 14, color: _palette.textDim),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Half-Point Rating Slider (1.0 to 10.0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Rating:', style: TextStyle(color: _palette.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('⭐ ${rating.toStringAsFixed(1)} / 10.0', style: TextStyle(color: _palette.accentPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: rating,
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        activeColor: _palette.accentPrimary,
                        inactiveColor: _palette.bgSurface,
                        label: rating.toStringAsFixed(1),
                        onChanged: (val) => setDState(() => rating = val),
                      ),
                      // On-Hold switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('On Hold', style: TextStyle(color: _palette.textMain, fontSize: 13)),
                        subtitle: Text(
                          onHold ? 'Paused progress' : 'Active tracking',
                          style: TextStyle(color: _palette.textDim, fontSize: 11),
                        ),
                        value: onHold,
                        activeThumbColor: const Color(0xFFF59E0B),
                        onChanged: (val) => setDState(() => onHold = val),
                      ),
                      const SizedBox(height: 8),
                      // Delete Media Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0x66EF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Remove Media Item', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.pop(dCtx);
                          _confirmRemoveMedia(item);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text('Cancel', style: TextStyle(color: _palette.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _palette.accentPrimary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final title = toSentenceCase(titleController.text.trim());
                    if (title.isEmpty) {
                      setDState(() => validationError = 'Title cannot be empty');
                      return;
                    }
                    final cur = double.tryParse(currentUnitsController.text.trim());
                    final tot = double.tryParse(totalCapacityController.text.trim());
                    if (cur == null || tot == null) {
                      setDState(() => validationError = 'Progress and capacity must be valid numbers');
                      return;
                    }
                    if (cur < 0 || tot <= 0) {
                      setDState(() => validationError = 'Values must be positive (capacity > 0)');
                      return;
                    }
                    if (cur > tot) {
                      setDState(() => validationError = 'Current progress ($cur) cannot exceed total capacity ($tot)');
                      return;
                    }
                    final yr = int.tryParse(yearController.text.trim()) ?? item.releaseYear;
                    final notes = notesController.text.trim().isEmpty ? null : toSentenceCase(notesController.text.trim());
                    final cover = coverUrlController.text.trim().isEmpty ? null : coverUrlController.text.trim();

                    final updated = item.copyWith(
                      title: title,
                      releaseYear: yr,
                      personalNotes: notes,
                      coverUrl: cover,
                      progressCurrent: cur,
                      progressTotal: tot,
                      labels: labels,
                      score: rating,
                      isOnHold: onHold,
                    );

                    setState(() {
                      final idx = _mediaItems.indexWhere((m) => m.id == item.id);
                      if (idx != -1) {
                        _mediaItems[idx] = updated;
                      }
                      // Decouple/update linked tasks if title changed
                      if (title != item.title) {
                        for (int i = 0; i < _tasks.length; i++) {
                          if (_tasks[i].linkedMediaId == item.id) {
                            _tasks[i] = _tasks[i].copyWith(
                              mediaTitle: title,
                              title: '🎯 Media Goal: $title',
                            );
                          }
                        }
                      }
                    });
                    widget.storage.saveMediaItems(_mediaItems);
                    widget.storage.saveTasks(_tasks);
                    Navigator.pop(dCtx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated "${updated.title}" successfully'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Task> get _dailyTasks =>
      DateNavigationService.getTasksForDate(_tasks, _selectedDate)
        ..sort(compareTaskExecutionState);

  List<Task> get _backlogTasks => _tasks
      .where((t) => t.category == TaskCategory.general)
      .toList()
    ..sort(compareTaskExecutionState);

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
    return list;
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
                                'Logo.jpeg',
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
                            onTap: () { setState(() => _currentTab = 'notes'); if (_pageController.hasClients) { _pageController.animateToPage(0, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut); } },
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            label: '🎬 Entertainment',
                            isActive: _currentTab == 'entertainment',
                            onTap: () { setState(() => _currentTab = 'entertainment'); if (_pageController.hasClients) { _pageController.animateToPage(1, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut); } },
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
                  _buildDailyPulseView(),
                  _buildEntertainmentView(),
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

  Widget _buildDailyPulseView() {
    final daily = _dailyTasks;
    final backlog = _backlogTasks;
    final isViewingToday = DateNavigationService.isToday(_selectedDate);

    final dailyTotal = daily.length;
    final dailyDone = daily.where((t) => t.status == TaskStatus.done).length;
    final dailyCanceled = daily.where((t) => t.status == TaskStatus.canceled).length;
    final dailyProgress = dailyTotal == 0 ? 0.0 : (dailyDone / dailyTotal).clamp(0.0, 1.0);

    final backlogTotal = backlog.length;
    final backlogDone = backlog.where((t) => t.status == TaskStatus.done).length;
    final backlogCanceled = backlog.where((t) => t.status == TaskStatus.canceled).length;
    final backlogProgress = backlogTotal == 0 ? 0.0 : (backlogDone / backlogTotal).clamp(0.0, 1.0);

    return Listener(
      onPointerMove: (e) => _lastPointerY = e.position.dy,
      onPointerUp: (_) => _stopAutoScrollTimer(),
      onPointerCancel: (_) => _stopAutoScrollTimer(),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          ShamsiAgendaBanner(
            events: _events,
            palette: _palette,
            selectedDate: _selectedDate,
            onDateChanged: (newDate) => setState(() => _selectedDate = newDate),
            onToggleCheckpoint: _toggleShamsiCheckpoint,
            onAddEvent: _addShamsiEvent,
            onAddCustomEvent: _showAddCustomEventDialog,
            onRemoveEvent: _removeShamsiEvent,
          ),
        const SizedBox(height: 18),

        // --- TODAY'S FOCUS SECTION ---
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Arrow-Only Toggle Button (strictly no text label)
                      InkWell(
                        onTap: () => setState(() => _isDailyFocusCollapsed = !_isDailyFocusCollapsed),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            _isDailyFocusCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            size: 20,
                            color: _palette.accentPrimary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          isViewingToday
                              ? '📌 Today\'s Focus'
                              : '📌 Focus for ${DualCalendarService.toShamsiString(_selectedDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _palette.textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Done/Total Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _palette.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _palette.borderSubtle),
                        ),
                        child: Text(
                          '$dailyDone/$dailyTotal Done',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _palette.textMuted,
                          ),
                        ),
                      ),
                      if (dailyCanceled > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• $dailyCanceled canceled',
                          style: TextStyle(
                            fontSize: 10,
                            color: _palette.textDim,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openAddTaskModal(TaskCategory.daily),
                  child: Text(
                    isViewingToday ? '+ Add' : '+ Add to Day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _palette.accentPrimary,
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
                color: _palette.bgElevated,
                borderRadius: BorderRadius.circular(4),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: constraints.maxWidth * dailyProgress,
                      decoration: BoxDecoration(
                        gradient: _palette.accentGradient,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: dailyProgress > 0
                            ? [
                                BoxShadow(
                                  color: _palette.accentGlow,
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
          crossFadeState: _isDailyFocusCollapsed
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
                      color: _palette.textDim,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: daily.length,
                  onReorderStart: (_) {
                    _isDraggingTask = true;
                    _startAutoScrollTimer();
                  },
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    _isDraggingTask = false;
                    _stopAutoScrollTimer();
                    setState(() {
                      final reordered =
                          ReorderService.reorderTasks(daily, oldIndex, newIndex);
                      for (final updated in reordered) {
                        final idx = _tasks.indexWhere((t) => t.id == updated.id);
                        if (idx != -1) {
                          _tasks[idx] = updated;
                        }
                      }
                    });
                    widget.storage.saveTasks(_tasks);
                  },
                  itemBuilder: (context, index) {
                    final task = daily[index];
                    return TaskCard(
                      key: ValueKey(task.id),
                      task: task,
                      palette: _palette,
                      dragIndex: index,
                      onStatusChange: (status) => _setTaskStatus(task, status),
                      onPostponeOneDay: () => _postponeTaskOneDay(task),
                      onPostponeToDate: () => _showPostponeDatePickerModal(task),
                      onDemoteToBacklog: () => _demoteTaskToBacklog(task),
                      onEdit: () => _showEditTaskDialog(task),
                      onDelete: () => _deleteTask(task),
                    );
                  },
                ),
          secondChild: const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        Divider(color: _palette.borderSubtle),
        const SizedBox(height: 10),

        // --- ORBIT & BACKLOG SECTION ---
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Arrow-Only Toggle Button (strictly no text label)
                      InkWell(
                        onTap: () => setState(() => _isBacklogCollapsed = !_isBacklogCollapsed),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            _isBacklogCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            size: 20,
                            color: _palette.accentPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '🪐 Orbit & Backlog',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _palette.textMain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Done/Total Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _palette.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _palette.borderSubtle),
                        ),
                        child: Text(
                          '$backlogDone/$backlogTotal Done',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _palette.textMuted,
                          ),
                        ),
                      ),
                      if (backlogCanceled > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• $backlogCanceled canceled',
                          style: TextStyle(
                            fontSize: 10,
                            color: _palette.textDim,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openAddTaskModal(TaskCategory.general),
                  child: Text(
                    '+ Add Backlog',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _palette.accentPrimary,
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
                color: _palette.bgElevated,
                borderRadius: BorderRadius.circular(4),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: constraints.maxWidth * backlogProgress,
                      decoration: BoxDecoration(
                        gradient: _palette.accentGradient,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: backlogProgress > 0
                            ? [
                                BoxShadow(
                                  color: _palette.accentGlow,
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
          crossFadeState: _isBacklogCollapsed
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
                      color: _palette.textDim,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: backlog.length,
                  onReorderStart: (_) {
                    _isDraggingTask = true;
                    _startAutoScrollTimer();
                  },
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    _isDraggingTask = false;
                    _stopAutoScrollTimer();
                    setState(() {
                      final reordered =
                          ReorderService.reorderTasks(backlog, oldIndex, newIndex);
                      for (final updated in reordered) {
                        final idx = _tasks.indexWhere((t) => t.id == updated.id);
                        if (idx != -1) {
                          _tasks[idx] = updated;
                        }
                      }
                    });
                    widget.storage.saveTasks(_tasks);
                  },
                  itemBuilder: (context, index) {
                    final task = backlog[index];
                    return TaskCard(
                      key: ValueKey(task.id),
                      task: task,
                      palette: _palette,
                      dragIndex: index,
                      onStatusChange: (status) => _setTaskStatus(task, status),
                      onAssignToToday: () => _assignTaskToToday(task),
                      onScheduleForDate: () => _assignTaskToToday(task),
                      scheduleLabel:
                          isViewingToday ? '⚡ Assign Today' : '📅 Assign to Day',
                      onEdit: () => _showEditTaskDialog(task),
                      onDelete: () => _deleteTask(task),
                    );
                  },
                ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

  Widget _buildEntertainmentView() {
    final mediaList = _filteredMediaItems;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryPill('all', '✨ All'),
              const SizedBox(width: 6),
              _buildCategoryPill('book', '📚 Books'),
              const SizedBox(width: 6),
              _buildCategoryPill('tvShow', '📺 TV Shows'),
              const SizedBox(width: 6),
              _buildCategoryPill('movie', '🎬 Movies'),
              const SizedBox(width: 6),
              _buildCategoryPill('videoGame', '🎮 Video Games'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tracking ${mediaList.length} Items',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _palette.textMuted,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _palette.bgElevated,
                    border: Border.all(color: _palette.borderSubtle),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _isMediaGrid = false);
                          widget.storage.saveMediaViewMode('list');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: !_isMediaGrid
                                ? _palette.bgSurface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.view_agenda_outlined,
                            size: 14,
                            color: !_isMediaGrid
                                ? _palette.textMain
                                : _palette.textDim,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _isMediaGrid = true);
                          widget.storage.saveMediaViewMode('grid');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _isMediaGrid
                                ? _palette.bgSurface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.grid_view,
                            size: 14,
                            color: _isMediaGrid
                                ? _palette.textMain
                                : _palette.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _mediaSort,
                    dropdownColor: _palette.bgElevated,
                    style: TextStyle(
                      fontSize: 11,
                      color: _palette.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Recently Added'),
                      ),
                      DropdownMenuItem(
                        value: 'score',
                        child: Text('Highest Score'),
                      ),
                      DropdownMenuItem(
                        value: 'progress',
                        child: Text('Most Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'year',
                        child: Text('Release Year'),
                      ),
                      DropdownMenuItem(
                        value: 'name',
                        child: Text('Name (A-Z)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _mediaSort = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _showAddMediaDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _palette.accentPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '+ Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (mediaList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No media entries found in this category.',
                style: TextStyle(
                  fontSize: 12,
                  color: _palette.textDim,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else if (_isMediaGrid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: mediaList.length,
            itemBuilder: (context, index) {
              final item = mediaList[index];
              return MediaCard(
                key: ValueKey(item.id),
                item: item,
                palette: _palette,
                isGrid: true,
                onToggleOnHold: (val) => _toggleMediaOnHold(item, val),
                onUpdateProgress: () => _showUpdateProgressDialog(item),
                onEditCover: () => _showEditCoverDialog(item),
                onScheduleToday: () => _scheduleMediaToday(item),
                onEditNotes: () => _editMediaNotes(item),
                onEditLabels: () => _showEditLabelsDialog(item),
                onEditMedia: () => _showEditMediaDialog(item),
                onDelete: () => _removeMediaItem(item.id),
              );
            },
          )
        else
          ...mediaList.map((item) {
            return MediaCard(
              key: ValueKey(item.id),
              item: item,
              palette: _palette,
              isGrid: false,
              onToggleOnHold: (val) => _toggleMediaOnHold(item, val),
              onUpdateProgress: () => _showUpdateProgressDialog(item),
              onEditCover: () => _showEditCoverDialog(item),
              onScheduleToday: () => _scheduleMediaToday(item),
              onEditNotes: () => _editMediaNotes(item),
              onEditLabels: () => _showEditLabelsDialog(item),
              onEditMedia: () => _showEditMediaDialog(item),
              onDelete: () => _removeMediaItem(item.id),
            );
          }),
      ],
    );
  }

  Widget _buildCategoryPill(String filterKey, String label) {
    final isActive = _mediaFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _mediaFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _palette.textMain : _palette.bgElevated,
          border: Border.all(
            color: isActive ? _palette.textMain : _palette.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? _palette.bgCanvas : _palette.textMuted,
          ),
        ),
      ),
    );
  }
}


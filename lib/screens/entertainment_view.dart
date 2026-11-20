import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../widgets/media_card.dart';
import '../widgets/fast_scroll_rail.dart';

class EntertainmentView extends StatelessWidget {
  final VibePalette palette;
  final List<MediaItem> mediaList;
  final String mediaFilter;
  final String mediaSort;
  final bool isMediaGrid;
  final ScrollController scrollController;
  final GlobalKey activeMediaKey;
  final GlobalKey onHoldMediaKey;
  final GlobalKey finishedMediaKey;

  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onToggleViewMode;
  final VoidCallback onAddMedia;
  final Function(MediaItem, bool) onToggleOnHold;
  final ValueChanged<MediaItem> onUpdateProgress;
  final ValueChanged<MediaItem> onEditCover;
  final ValueChanged<MediaItem> onScheduleToday;
  final ValueChanged<MediaItem> onEditNotes;
  final ValueChanged<MediaItem> onEditLabels;
  final ValueChanged<MediaItem> onEditMedia;
  final ValueChanged<String> onDeleteMedia;

  const EntertainmentView({
    super.key,
    required this.palette,
    required this.mediaList,
    required this.mediaFilter,
    required this.mediaSort,
    required this.isMediaGrid,
    required this.scrollController,
    required this.activeMediaKey,
    required this.onHoldMediaKey,
    required this.finishedMediaKey,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onToggleViewMode,
    required this.onAddMedia,
    required this.onToggleOnHold,
    required this.onUpdateProgress,
    required this.onEditCover,
    required this.onScheduleToday,
    required this.onEditNotes,
    required this.onEditLabels,
    required this.onEditMedia,
    required this.onDeleteMedia,
  });

  void _sortMediaBySelectedSorter(List<MediaItem> list) {
    switch (mediaSort) {
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
    if (mediaFilter != 'all') {
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

  Widget _buildMediaCard(MediaItem item, {required bool isGrid}) {
    return MediaCard(
      key: ValueKey(item.id),
      item: item,
      palette: palette,
      isGrid: isGrid,
      onToggleOnHold: (val) => onToggleOnHold(item, val),
      onUpdateProgress: () => onUpdateProgress(item),
      onEditCover: () => onEditCover(item),
      onScheduleToday: () => onScheduleToday(item),
      onEditNotes: () => onEditNotes(item),
      onEditLabels: () => onEditLabels(item),
      onEditMedia: () => onEditMedia(item),
      onDelete: () => onDeleteMedia(item.id),
    );
  }

  Widget _buildMediaChunk(List<MediaItem> items) {
    if (isMediaGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _buildMediaCard(items[index], isGrid: true),
      );
    } else {
      return Column(
        children: items
            .map((item) => _buildMediaCard(item, isGrid: false))
            .toList(),
      );
    }
  }

  Widget _buildSectionDivider({
    Key? key,
    required String title,
    required IconData icon,
    required int count,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 14, color: palette.accentPrimary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: palette.accentPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: palette.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.borderSubtle),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: palette.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: palette.borderSubtle,
              thickness: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMediaGroupWidgets(
    List<({MediaType type, List<MediaItem> items})> groups,
  ) {
    final widgets = <Widget>[];
    for (final g in groups) {
      widgets.add(_buildMediaChunk(g.items));
    }
    return widgets;
  }

  Widget _buildCategoryPill(String filterKey, String label) {
    final isActive = mediaFilter == filterKey;
    return InkWell(
      onTap: () => onFilterChanged(filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? palette.textMain : palette.bgElevated,
          border: Border.all(
            color: isActive ? palette.textMain : palette.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? palette.bgCanvas : palette.textMuted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uncompletedItems =
        mediaList.where((m) => !m.isCompleted && !m.isOnHold).toList();
    final onHoldItems =
        mediaList.where((m) => !m.isCompleted && m.isOnHold).toList();
    final finishedItems = mediaList.where((m) => m.isCompleted).toList();

    final uncompletedGroups = _partitionMediaByType(uncompletedItems);
    final onHoldGroups = _partitionMediaByType(onHoldItems);
    final finishedGroups = _partitionMediaByType(finishedItems);

    return Stack(
      children: [
        ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
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
                    color: palette.textMuted,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: palette.bgElevated,
                        border: Border.all(color: palette.borderSubtle),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => onToggleViewMode(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: !isMediaGrid
                                    ? palette.bgSurface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.view_agenda_outlined,
                                size: 14,
                                color: !isMediaGrid
                                    ? palette.textMain
                                    : palette.textDim,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => onToggleViewMode(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isMediaGrid
                                    ? palette.bgSurface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.grid_view,
                                size: 14,
                                color: isMediaGrid
                                    ? palette.textMain
                                    : palette.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: mediaSort,
                        dropdownColor: palette.bgElevated,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textMain,
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
                            onSortChanged(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onAddMedia,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.accentPrimary,
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
                      color: palette.textDim,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else ...[
              // Uncompleted Section
              if (uncompletedGroups.isNotEmpty) ...[
                KeyedSubtree(
                  key: activeMediaKey,
                  child: const SizedBox.shrink(),
                ),
                ..._buildMediaGroupWidgets(uncompletedGroups),
              ],

              // On-Hold Section
              if (onHoldGroups.isNotEmpty) ...[
                _buildSectionDivider(
                  key: onHoldMediaKey,
                  title: 'On-Hold',
                  icon: Icons.pause_circle_outline,
                  count: onHoldItems.length,
                ),
                ..._buildMediaGroupWidgets(onHoldGroups),
              ],

              // Finished Section
              if (finishedGroups.isNotEmpty) ...[
                _buildSectionDivider(
                  key: finishedMediaKey,
                  title: 'Finished',
                  icon: Icons.check_circle_outline,
                  count: finishedItems.length,
                ),
                ..._buildMediaGroupWidgets(finishedGroups),
              ],
            ],
          ],
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
                id: 'active',
                label: 'Active',
                icon: Icons.play_arrow_rounded,
                isEnabled: uncompletedItems.isNotEmpty,
                weight: uncompletedItems.isNotEmpty
                    ? uncompletedItems.length.toDouble()
                    : 0.0,
                onTap: () {
                  scrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
              FastScrollSection(
                id: 'onHold',
                label: 'Hold',
                icon: Icons.pause_rounded,
                isEnabled: onHoldItems.isNotEmpty,
                weight: onHoldItems.isNotEmpty
                    ? onHoldItems.length.toDouble()
                    : 0.0,
                onTap: () {
                  if (onHoldMediaKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      onHoldMediaKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: 0.05,
                    );
                  }
                },
              ),
              FastScrollSection(
                id: 'finished',
                label: 'Done',
                icon: Icons.check_circle_outline_rounded,
                isEnabled: finishedItems.isNotEmpty,
                weight: finishedItems.isNotEmpty
                    ? finishedItems.length.toDouble()
                    : 0.0,
                onTap: () {
                  if (finishedMediaKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      finishedMediaKey.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: 0.05,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

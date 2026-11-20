import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';
import '../../services/media_label_service.dart';
import '../../services/sentence_case_service.dart';

class MediaLabelsModal {
  static void showConfirmDelete({
    required BuildContext context,
    required VibePalette palette,
    required String tag,
    required VoidCallback onConfirmed,
  }) {
    showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          backgroundColor: palette.bgSurface,
          title: Text(
            'Delete Label?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: palette.textMain,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete "$tag" from the database? This will untag it from all media items.',
            style: TextStyle(fontSize: 13, color: palette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
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

  static void showSelection({
    required BuildContext context,
    required VibePalette palette,
    required List<String> activeLabels,
    required List<MediaItem> mediaItems,
    required List<String> initialSelected,
    required ValueChanged<List<String>> onDone,
    required Function(String deletedTag) onLabelPermanentlyDeleted,
    required Function(String newLabel) onLabelCreated,
  }) {
    List<String> selected = List<String>.from(initialSelected);
    final searchController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setMState) {
            final poolSet = <String>{...activeLabels};
            for (final m in mediaItems) {
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
                  if (!activeLabels.any((l) => l.toLowerCase() == trimmed.toLowerCase())) {
                    activeLabels.add(trimmed);
                    onLabelCreated(trimmed);
                  }
                  selected = MediaLabelService.addLabel(selected, trimmed);
                  searchController.clear();
                  searchQuery = '';
                });
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
                                color: palette.textMain,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: palette.textMuted, size: 20),
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
                            style: TextStyle(color: palette.textMain),
                            decoration: InputDecoration(
                              hintText: 'Search or add new tag...',
                              hintStyle: TextStyle(color: palette.textDim),
                              prefixIcon: Icon(Icons.search, size: 18, color: palette.textDim),
                              filled: true,
                              fillColor: palette.bgSurface,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: palette.borderSubtle),
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
                              backgroundColor: palette.accentPrimary,
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
                          color: palette.accentPrimary,
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
                              color: palette.textMain,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: palette.bgSurface,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: palette.textMuted,
                            onDeleted: () {
                              setMState(() {
                                selected = MediaLabelService.removeLabel(selected, tag);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Divider(color: palette.borderSubtle, height: 1),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Available Labels:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: palette.textMuted,
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
                                showConfirmDelete(
                                  context: context,
                                  palette: palette,
                                  tag: tag,
                                  onConfirmed: () {
                                    setMState(() {
                                      activeLabels.removeWhere(
                                        (l) => l.trim().toLowerCase() == tag.trim().toLowerCase(),
                                      );
                                      selected = MediaLabelService.removeLabel(selected, tag);
                                    });
                                    onLabelPermanentlyDeleted(tag);
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? palette.accentPrimary : palette.bgSurface,
                                  border: Border.all(
                                    color: isSelected ? palette.accentPrimary : palette.borderSubtle,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.black : palette.textMain,
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
                        backgroundColor: palette.accentPrimary,
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
}

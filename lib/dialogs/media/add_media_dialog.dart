import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';
import '../../services/media_ledger_cleanup_service.dart';
import '../../services/media_info_fetch_service.dart';
import '../../services/cover_fetch_service.dart';
import '../../services/media_label_service.dart';
import '../../services/sentence_case_service.dart';
import '../../widgets/safe_cover_image.dart';
import '../../widgets/rtl_aware_text_field.dart';
import 'media_labels_modal.dart';

class AddMediaDialog {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required List<String> activeLabels,
    required List<MediaItem> mediaItems,
    required ValueChanged<MediaItem> onMediaAdded,
    required Function(String deletedTag) onLabelPermanentlyDeleted,
    required Function(String newLabel) onLabelCreated,
  }) {
    final titleController = TextEditingController();
    final yearController =
        TextEditingController(text: DateTime.now().year.toString());
    final totalController = TextEditingController(text: '100');
    final notesController = TextEditingController();
    final coverUrlController = TextEditingController();
    MediaType selectedType = MediaType.book;
    List<String> selectedLabels = [];
    bool isSearchingCovers = false;
    List<CoverSearchResult> candidates = [];
    String? coverSearchMsg;
    bool isFetchingInfo = false;
    String? fetchInfoMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: palette.bgElevated,
              title: Text(
                'Add Media Item',
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
                    DropdownButtonFormField<MediaType>(
                      initialValue: selectedType,
                      dropdownColor: palette.bgElevated,
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.bgSurface,
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
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.bgSurface,
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
                            style: TextStyle(color: palette.textMain),
                            decoration: InputDecoration(
                              labelText: 'Release Year',
                              labelStyle: TextStyle(color: palette.textMuted),
                              filled: true,
                              fillColor: palette.bgSurface,
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
                            style: TextStyle(color: palette.textMain),
                            decoration: InputDecoration(
                              labelText: MediaLedgerCleanupService.unitInputLabelFor(selectedType),
                              labelStyle: TextStyle(color: palette.textMuted),
                              filled: true,
                              fillColor: palette.bgSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: isFetchingInfo
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search, size: 14),
                          label: const Text('🔎 Fetch Info', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.accentPrimary,
                            side: BorderSide(color: palette.accentPrimary.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: isFetchingInfo
                              ? null
                              : () async {
                                  final title = titleController.text.trim();
                                  if (title.isEmpty) {
                                    setDState(() => fetchInfoMsg = 'Enter title first!');
                                    return;
                                  }
                                  setDState(() {
                                    isFetchingInfo = true;
                                    fetchInfoMsg = null;
                                  });
                                  final info = await MediaInfoFetchService.fetchInfo(
                                    title: title,
                                    type: selectedType,
                                  );
                                  setDState(() {
                                    isFetchingInfo = false;
                                    if (info != null) {
                                      final parts = <String>[];
                                      if (info.releaseYear != null) {
                                        yearController.text = info.releaseYear.toString();
                                        parts.add('${info.releaseYear}');
                                      }
                                      if (selectedType == MediaType.tvShow && info.episodeCount != null) {
                                        totalController.text = info.episodeCount.toString();
                                        parts.add('${info.episodeCount} episodes');
                                      } else if (selectedType == MediaType.movie && info.runtimeMinutes != null) {
                                        totalController.text = info.runtimeMinutes.toString();
                                        parts.add('${info.runtimeMinutes} min');
                                      }
                                      if (parts.isNotEmpty) {
                                        fetchInfoMsg = 'Fetched: ${parts.join(', ')}';
                                      } else {
                                        fetchInfoMsg = 'No extra info found for "$title".';
                                      }
                                    } else {
                                      fetchInfoMsg = 'No info found for "$title".';
                                    }
                                  });
                                },
                        ),
                        if (fetchInfoMsg != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fetchInfoMsg!,
                              style: TextStyle(
                                fontSize: 11,
                                color: fetchInfoMsg!.startsWith('Fetched:')
                                    ? const Color(0xFF10B981)
                                    : (fetchInfoMsg == 'Enter title first!' ? const Color(0xFFEF4444) : palette.textMuted),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Labels / Tags:',
                      style: TextStyle(
                        color: palette.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        MediaLabelsModal.showSelection(
                          context: dCtx,
                          palette: palette,
                          activeLabels: activeLabels,
                          mediaItems: mediaItems,
                          initialSelected: selectedLabels,
                          onDone: (newLabels) {
                            setDState(() => selectedLabels = newLabels);
                          },
                          onLabelPermanentlyDeleted: onLabelPermanentlyDeleted,
                          onLabelCreated: onLabelCreated,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: palette.bgSurface,
                          border: Border.all(color: palette.borderSubtle),
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
                                color: selectedLabels.isEmpty ? palette.textDim : palette.accentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.edit, size: 14, color: palette.textDim),
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
                              color: palette.textMain,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: palette.bgSurface,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: palette.textMuted,
                            onDeleted: () {
                              setDState(() {
                                selectedLabels = MediaLabelService.removeLabel(selectedLabels, l);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 10),
                    RtlAwareTextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Personal Description / Notes',
                        hintText: '+ Add personal description/notes (optional)...',
                        hintStyle: TextStyle(color: palette.textDim.withValues(alpha: 0.45)),
                        labelStyle: TextStyle(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.bgSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cover Art:',
                      style: TextStyle(
                        color: palette.textMain,
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
                            style: TextStyle(color: palette.textMain),
                            decoration: InputDecoration(
                              hintText: 'Image URL (https://...)',
                              hintStyle: TextStyle(color: palette.textDim),
                              filled: true,
                              fillColor: palette.bgSurface,
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
                            backgroundColor: palette.accentPrimary,
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
                          color: palette.textMuted,
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
                                    color: isSelected ? palette.accentPrimary : palette.borderSubtle,
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
                              color: palette.accentPrimary,
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
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accentPrimary,
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
                      final notes = notesController.text.trim().isEmpty
                          ? null
                          : toSentenceCase(notesController.text.trim());
                      final newItem = MediaItem(
                        id: 'media_${DateTime.now().millisecondsSinceEpoch}',
                        type: selectedType,
                        title: title,
                        releaseYear: year,
                        labels: selectedLabels,
                        coverUrl: cover,
                        progressCurrent: 0,
                        progressTotal: total,
                        personalNotes: notes,
                        displayDate: DateTime.now(),
                      );
                      onMediaAdded(newItem);
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
}

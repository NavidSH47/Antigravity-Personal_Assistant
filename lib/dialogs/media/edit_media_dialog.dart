import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';
import '../../services/media_ledger_cleanup_service.dart';
import '../../services/media_info_fetch_service.dart';
import '../../services/cover_fetch_service.dart';
import '../../services/sentence_case_service.dart';
import '../../widgets/safe_cover_image.dart';
import '../../widgets/rtl_aware_text_field.dart';
import 'media_labels_modal.dart';

class EditMediaDialog {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required MediaItem item,
    required List<String> activeLabels,
    required List<MediaItem> mediaItems,
    required ValueChanged<MediaItem> onMediaUpdated,
    required VoidCallback onRemoveMedia,
    required Function(String deletedTag) onLabelPermanentlyDeleted,
    required Function(String newLabel) onLabelCreated,
  }) {
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
    bool isFetchingInfo = false;
    String? fetchInfoMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: palette.bgElevated,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('✏️ ', style: TextStyle(fontSize: 16)),
                      Text(
                        'Edit Media Item',
                        style: TextStyle(
                          color: palette.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textMuted, size: 20),
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
                        style: TextStyle(color: palette.textMain),
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(color: palette.textMuted),
                          filled: true,
                          fillColor: palette.bgSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Release Year
                      TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: palette.textMain),
                        decoration: InputDecoration(
                          labelText: 'Release Year',
                          labelStyle: TextStyle(color: palette.textMuted),
                          filled: true,
                          fillColor: palette.bgSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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
                                      type: item.type,
                                    );
                                    setDState(() {
                                      isFetchingInfo = false;
                                      if (info != null) {
                                        final parts = <String>[];
                                        if (info.releaseYear != null) {
                                          yearController.text = info.releaseYear.toString();
                                          parts.add('${info.releaseYear}');
                                        }
                                        if (item.type == MediaType.tvShow && info.episodeCount != null) {
                                          totalCapacityController.text = info.episodeCount.toString();
                                          parts.add('${info.episodeCount} episodes');
                                        } else if (item.type == MediaType.movie && info.runtimeMinutes != null) {
                                          totalCapacityController.text = info.runtimeMinutes.toString();
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
                      const SizedBox(height: 10),
                      // Notes / Description
                      RtlAwareTextField(
                        controller: notesController,
                        maxLines: 3,
                        style: TextStyle(color: palette.textMain),
                        decoration: InputDecoration(
                          labelText: 'Personal Notes & Description',
                          labelStyle: TextStyle(color: palette.textMuted),
                          hintText: '+ Add personal description/notes...',
                          hintStyle: TextStyle(color: palette.textDim.withValues(alpha: 0.45)),
                          filled: true,
                          fillColor: palette.bgSurface,
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
                              color: palette.bgSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: palette.borderSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: coverUrlController.text.trim().isNotEmpty
                                ? SafeCoverImage(url: coverUrlController.text.trim())
                                : Center(child: Icon(Icons.image, color: palette.textDim, size: 24)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: coverUrlController,
                                  style: TextStyle(color: palette.textMain, fontSize: 12),
                                  decoration: InputDecoration(
                                    labelText: 'Cover Image URL',
                                    labelStyle: TextStyle(color: palette.textMuted, fontSize: 11),
                                    filled: true,
                                    fillColor: palette.bgSurface,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => setDState(() {}),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.bgSurface,
                                    foregroundColor: palette.accentPrimary,
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
                        Text(coverSearchMsg!, style: TextStyle(color: palette.textDim, fontSize: 11)),
                      ],
                      if (candidates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Select Cover:', style: TextStyle(color: palette.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                      color: isSelected ? palette.accentPrimary : palette.borderSubtle,
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
                          color: palette.accentPrimary,
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
                              style: TextStyle(color: palette.textMain),
                              decoration: InputDecoration(
                                labelText: MediaLedgerCleanupService.currentUnitInputLabelFor(item.type),
                                labelStyle: TextStyle(color: palette.textMuted),
                                filled: true,
                                fillColor: palette.bgSurface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: totalCapacityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: palette.textMain),
                              decoration: InputDecoration(
                                labelText: MediaLedgerCleanupService.unitInputLabelFor(item.type),
                                labelStyle: TextStyle(color: palette.textMuted),
                                filled: true,
                                fillColor: palette.bgSurface,
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
                          MediaLabelsModal.showSelection(
                            context: dCtx,
                            palette: palette,
                            activeLabels: activeLabels,
                            mediaItems: mediaItems,
                            initialSelected: labels,
                            onDone: (newLabels) {
                              setDState(() => labels = newLabels);
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
                                labels.isEmpty ? '🏷️ Select Labels / Tags' : '🏷️ Labels (${labels.length}): ${labels.take(3).join(', ')}${labels.length > 3 ? '...' : ''}',
                                style: TextStyle(
                                  color: labels.isEmpty ? palette.textDim : palette.accentPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(Icons.edit, size: 14, color: palette.textDim),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Half-Point Rating Slider (1.0 to 10.0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Rating:', style: TextStyle(color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('⭐ ${rating.toStringAsFixed(1)} / 10.0', style: TextStyle(color: palette.accentPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: rating,
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        activeColor: palette.accentPrimary,
                        inactiveColor: palette.bgSurface,
                        label: rating.toStringAsFixed(1),
                        onChanged: (val) => setDState(() => rating = val),
                      ),
                      // On-Hold switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('On Hold', style: TextStyle(color: palette.textMain, fontSize: 13)),
                        subtitle: Text(
                          onHold ? 'Paused progress' : 'Active tracking',
                          style: TextStyle(color: palette.textDim, fontSize: 11),
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
                          onRemoveMedia();
                        },
                      ),
                    ],
                  ),
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

                    final wasCompleted = item.isCompleted;
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
                    final nowCompleted = updated.isCompleted;
                    DateTime newDisplayDate = item.displayDate;
                    if (!wasCompleted && nowCompleted) {
                      newDisplayDate = DateTime.now(); // Just finished
                    } else if (wasCompleted && !nowCompleted) {
                      newDisplayDate = DateTime.now(); // Re-opened
                    }
                    final finalUpdated = updated.copyWith(displayDate: newDisplayDate);

                    onMediaUpdated(finalUpdated);
                    Navigator.pop(dCtx);
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
}

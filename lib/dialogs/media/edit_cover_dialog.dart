import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';
import '../../services/cover_fetch_service.dart';
import '../../widgets/safe_cover_image.dart';

class EditCoverDialog {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required MediaItem item,
    required ValueChanged<String?> onCoverUpdated,
    required VoidCallback onRemoveMedia,
  }) {
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
              backgroundColor: palette.bgElevated,
              title: Text(
                'Cover Art: ${item.title}',
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
                    TextField(
                      controller: urlController,
                      style: TextStyle(color: palette.textMain),
                      decoration: InputDecoration(
                        labelText: 'Image Web URL',
                        hintText: 'https://...',
                        labelStyle: TextStyle(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.bgSurface,
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
                        backgroundColor: palette.accentPrimary,
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
                                        ? palette.accentPrimary
                                        : palette.borderSubtle,
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
                        backgroundColor: palette.bgSurface,
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                      ),
                      onPressed: () {
                        onCoverUpdated('');
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
                        onRemoveMedia();
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
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accentPrimary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final url = SafeCoverImage.sanitizeUrl(urlController.text);
                    onCoverUpdated(url);
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
}

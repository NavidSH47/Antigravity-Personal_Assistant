import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Service responsible for managing local persistent disk caching for media cover art.
class CoverCacheService {
  static final BaseCacheManager _cacheManager = DefaultCacheManager();

  /// Gets the underlying cache manager instance.
  static BaseCacheManager get cacheManager => _cacheManager;

  /// Pre-fetches and downloads a cover image to local disk cache.
  static Future<void> preloadCover(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    try {
      await _cacheManager.downloadFile(cleanUrl);
    } catch (_) {
      // Best-effort pre-caching; ignore network or SSL errors
    }
  }

  /// Checks if a cover image is already cached on disk.
  static Future<bool> isCoverCached(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return false;
    final fileInfo = await _cacheManager.getFileFromCache(cleanUrl);
    return fileInfo != null;
  }

  /// Clears the cached cover images from device disk storage.
  static Future<void> clearCoverCache() async {
    await _cacheManager.emptyCache();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeCoverImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SafeCoverImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.errorBuilder,
  });

  /// Sanitizes URL by trimming whitespace and normalizing double slashes in paths.
  /// Example: https://images.launchbox-app.com//e9438ab4.jpg -> https://images.launchbox-app.com/e9438ab4.jpg
  static String sanitizeUrl(String rawUrl) {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceFirstMapped(
      RegExp(r'^(https?:\/\/)(.*)$'),
      (m) => '${m[1]}${m[2]!.replaceAll(RegExp(r'/+'), '/')}',
    );
  }

  /// Free, high-speed CORS image proxy URL for Web or blocked CDNs.
  static String toCorsProxyUrl(String originalUrl) {
    final clean = sanitizeUrl(originalUrl);
    final withoutProto = clean.replaceFirst(RegExp(r'^https?:\/\/'), '');
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(withoutProto)}';
  }

  /// Returns the fallback Steam header.jpg URL if the given [url] is a Steam library poster,
  /// or null if not applicable. Guaranteed to resolve on Steam CDN when library_600x900 404s.
  static String? getSteamHeaderFallbackUrl(String url) {
    final cleanUrl = sanitizeUrl(url);
    final isSteamLibrary =
        cleanUrl.contains('steamstatic.com') && cleanUrl.contains('library_600x900');
    if (isSteamLibrary) {
      return cleanUrl.replaceAll(RegExp(r'library_600x900(_2x)?\.jpg'), 'header.jpg');
    }
    return null;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildDefaultError(BuildContext context, Object error, StackTrace? stackTrace) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error, stackTrace);
    }
    return const Center(
      child: Icon(Icons.broken_image, size: 20, color: Colors.white38),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = sanitizeUrl(url);
    if (cleanUrl.isEmpty) {
      return _buildDefaultError(context, 'Empty URL', null);
    }

    // On Flutter Web, LaunchBox, Steam, and some CDNs do not emit Access-Control-Allow-Origin: *
    // When direct loading fails or on Web, we route or fallback via images.weserv.nl
    final effectiveUrl = kIsWeb &&
            !cleanUrl.contains('weserv.nl') &&
            !cleanUrl.contains('openlibrary.org') &&
            !cleanUrl.contains('tvmaze.com')
        ? toCorsProxyUrl(cleanUrl)
        : cleanUrl;

    const headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    // For Steam games/soundtracks where library_600x900_2x.jpg may return 404,
    // header.jpg is universally guaranteed to exist for all App IDs on Steam CDN.
    final steamHeaderUrl = getSteamHeaderFallbackUrl(cleanUrl);

    return CachedNetworkImage(
      imageUrl: effectiveUrl,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      httpHeaders: headers,
      placeholder: (context, url) => _buildPlaceholder(context),
      errorWidget: (context, url, error) {
        final fallbackUrl = toCorsProxyUrl(cleanUrl);
        if (effectiveUrl != fallbackUrl) {
          return CachedNetworkImage(
            imageUrl: fallbackUrl,
            fit: fit,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            httpHeaders: headers,
            placeholder: (ctx, u) => _buildPlaceholder(ctx),
            errorWidget: (ctx, u, err) {
              if (steamHeaderUrl != null) {
                return CachedNetworkImage(
                  imageUrl: steamHeaderUrl,
                  fit: fit,
                  memCacheWidth: cacheWidth,
                  memCacheHeight: cacheHeight,
                  httpHeaders: headers,
                  placeholder: (c, u2) => _buildPlaceholder(c),
                  errorWidget: (c, u2, e2) => _buildDefaultError(c, e2, null),
                );
              }
              return _buildDefaultError(ctx, err, null);
            },
          );
        } else if (steamHeaderUrl != null) {
          return CachedNetworkImage(
            imageUrl: steamHeaderUrl,
            fit: fit,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            httpHeaders: headers,
            placeholder: (ctx, u) => _buildPlaceholder(ctx),
            errorWidget: (ctx, u, err) => _buildDefaultError(ctx, err, null),
          );
        }
        return _buildDefaultError(context, error, null);
      },
    );
  }
}

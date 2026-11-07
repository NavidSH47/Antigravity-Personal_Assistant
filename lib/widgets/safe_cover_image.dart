import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final cleanUrl = sanitizeUrl(url);
    if (cleanUrl.isEmpty) {
      return errorBuilder != null
          ? errorBuilder!(context, 'Empty URL', null)
          : const Icon(Icons.broken_image, size: 20);
    }

    // On Flutter Web, LaunchBox, Steam, and some CDNs do not emit Access-Control-Allow-Origin: *
    // When direct loading fails or on Web, we route or fallback via images.weserv.nl
    final effectiveUrl = kIsWeb &&
            !cleanUrl.contains('weserv.nl') &&
            !cleanUrl.contains('openlibrary.org') &&
            !cleanUrl.contains('tvmaze.com')
        ? toCorsProxyUrl(cleanUrl)
        : cleanUrl;

    return Image.network(
      effectiveUrl,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      errorBuilder: (context, error, stackTrace) {
        // If the primary attempt failed and we haven't tried the CORS proxy yet, try it!
        final fallbackUrl = toCorsProxyUrl(cleanUrl);
        if (effectiveUrl != fallbackUrl) {
          return Image.network(
            fallbackUrl,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            errorBuilder: (ctx, err, st) {
              if (errorBuilder != null) {
                return errorBuilder!(ctx, err, st);
              }
              return const Icon(Icons.broken_image, size: 20);
            },
          );
        }
        if (errorBuilder != null) {
          return errorBuilder!(context, error, stackTrace);
        }
        return const Icon(Icons.broken_image, size: 20);
      },
    );
  }
}

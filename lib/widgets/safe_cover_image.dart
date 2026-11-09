import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeCoverImage extends StatefulWidget {
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

  @override
  State<SafeCoverImage> createState() => _SafeCoverImageState();
}

class _SafeCoverImageState extends State<SafeCoverImage> {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  late List<String> _candidates;
  int _currentIndex = 0;
  bool _isAllFailed = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initCandidates();
  }

  @override
  void didUpdateWidget(covariant SafeCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _timeoutTimer?.cancel();
      _initCandidates();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _initCandidates() {
    final clean = SafeCoverImage.sanitizeUrl(widget.url);
    if (clean.isEmpty) {
      _candidates = [];
      _isAllFailed = true;
      _currentIndex = 0;
      return;
    }

    final list = <String>[];
    final steamHeader = SafeCoverImage.getSteamHeaderFallbackUrl(clean);

    if (kIsWeb) {
      // On Web, direct connections to Steam / LaunchBox lack CORS headers.
      // Proxied URLs ensure images load properly without silent browser drops.
      list.add(SafeCoverImage.toCorsProxyUrl(clean));
      if (steamHeader != null) {
        list.add(SafeCoverImage.toCorsProxyUrl(steamHeader));
      }
    } else {
      // Native platforms (Android, Windows, iOS, macOS, Linux)
      list.add(clean);
      if (steamHeader != null) {
        list.add(steamHeader);
        list.add(SafeCoverImage.toCorsProxyUrl(steamHeader));
      }
      list.add(SafeCoverImage.toCorsProxyUrl(clean));
    }

    // Deduplicate preserving priority order
    _candidates = list.toSet().toList();
    _currentIndex = 0;
    _isAllFailed = _candidates.isEmpty;
    _scheduleTimeout();
  }

  void _scheduleTimeout() {
    _timeoutTimer?.cancel();
    if (_isAllFailed || _candidates.isEmpty) return;

    // Safety timeout: If any candidate image hangs in loading for > 8 seconds,
    // automatically advance to the next candidate to prevent indefinite spinning.
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_isAllFailed) {
        _advanceCandidate();
      }
    });
  }

  void _advanceCandidate() {
    _timeoutTimer?.cancel();
    if (_currentIndex + 1 < _candidates.length) {
      setState(() {
        _currentIndex++;
      });
      _scheduleTimeout();
    } else {
      setState(() {
        _isAllFailed = true;
      });
    }
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
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error, stackTrace);
    }
    return const Center(
      child: Icon(Icons.broken_image, size: 20, color: Colors.white38),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAllFailed || _candidates.isEmpty) {
      return _buildDefaultError(context, 'Failed to load cover', null);
    }

    final activeUrl = _candidates[_currentIndex];

    return CachedNetworkImage(
      key: ValueKey(activeUrl),
      imageUrl: activeUrl,
      fit: widget.fit,
      memCacheWidth: widget.cacheWidth,
      memCacheHeight: widget.cacheHeight,
      httpHeaders: _headers,
      imageBuilder: (ctx, imageProvider) {
        _timeoutTimer?.cancel();
        return Image(
          image: imageProvider,
          fit: widget.fit,
        );
      },
      placeholder: (ctx, u) => _buildPlaceholder(ctx),
      errorWidget: (ctx, u, err) {
        // Cleanly advance candidate on next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _advanceCandidate();
          }
        });
        return _buildPlaceholder(ctx);
      },
    );
  }
}

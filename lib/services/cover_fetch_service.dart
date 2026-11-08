import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class CoverSearchResult {
  final String title;
  final String coverUrl;
  final String? year;
  final String source;

  const CoverSearchResult({
    required this.title,
    required this.coverUrl,
    this.year,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'coverUrl': coverUrl,
    'year': year,
    'source': source,
  };
}

class CoverFetchService {
  static const Duration _timeout = Duration(seconds: 8);

  static const Map<String, String> _requestHeaders = {
    'User-Agent':
        'NSHPulse/1.0 (Android; Mobile; +https://github.com/NavidSH47/pulse-assistant)',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Sanitizes image URLs by trimming whitespace and normalizing double slashes in paths.
  static String sanitizeImageUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceFirstMapped(
      RegExp(r'^(https?:\/\/)(.*)$'),
      (match) => '${match[1]}${match[2]!.replaceAll(RegExp(r'/+'), '/')}',
    );
  }

  /// Searches for cover art candidates across free zero-auth public APIs
  /// based on media [type] and [query].
  static Future<List<CoverSearchResult>> searchCovers({
    required String query,
    required MediaType type,
    http.Client? client,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final httpClient = client ?? http.Client();
    try {
      switch (type) {
        case MediaType.book:
          return await _searchBooks(trimmed, httpClient);
        case MediaType.tvShow:
          return await _searchTvShows(trimmed, httpClient);
        case MediaType.movie:
          return await _searchMovies(trimmed, httpClient);
        case MediaType.videoGame:
          return await _searchGames(trimmed, httpClient);
      }
    } catch (_) {
      return [];
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  // --- Books: Open Library with Google Books fallback ---
  static Future<List<CoverSearchResult>> _searchBooks(
    String query,
    http.Client client,
  ) async {
    final results = <CoverSearchResult>[];
    try {
      final uri = Uri.parse(
        'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=5',
      );
      final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final docs = (data['docs'] as List<dynamic>?) ?? [];
        for (final doc in docs) {
          final coverId = doc['cover_i'];
          final title = doc['title']?.toString() ?? query;
          final year = doc['first_publish_year']?.toString();
          if (coverId != null) {
            results.add(
              CoverSearchResult(
                title: title,
                coverUrl: sanitizeImageUrl('https://covers.openlibrary.org/b/id/$coverId-L.jpg'),
                year: year,
                source: 'Open Library',
              ),
            );
          }
        }
      }
    } catch (_) {
      // Fall through to Google Books
    }

    if (results.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://www.googleapis.com/books/v1/volumes?q=intitle:${Uri.encodeComponent(query)}&maxResults=5',
        );
        final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final items = (data['items'] as List<dynamic>?) ?? [];
          for (final item in items) {
            final info = item['volumeInfo'] as Map<String, dynamic>?;
            if (info == null) continue;
            final imageLinks = info['imageLinks'] as Map<String, dynamic>?;
            String? thumb = imageLinks?['thumbnail']?.toString() ??
                imageLinks?['smallThumbnail']?.toString();
            if (thumb != null) {
              if (thumb.startsWith('http://')) {
                thumb = thumb.replaceFirst('http://', 'https://');
              }
              final title = info['title']?.toString() ?? query;
              final pubDate = info['publishedDate']?.toString();
              final year = pubDate != null && pubDate.length >= 4
                  ? pubDate.substring(0, 4)
                  : null;
              results.add(
                CoverSearchResult(
                  title: title,
                  coverUrl: sanitizeImageUrl(thumb),
                  year: year,
                  source: 'Google Books',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    return results;
  }

  // --- TV Shows: TVMaze with iTunes Search fallback ---
  static Future<List<CoverSearchResult>> _searchTvShows(
    String query,
    http.Client client,
  ) async {
    final results = <CoverSearchResult>[];
    try {
      final uri = Uri.parse(
        'https://api.tvmaze.com/search/shows?q=${Uri.encodeComponent(query)}',
      );
      final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List<dynamic>;
        for (final item in list) {
          final show = item['show'] as Map<String, dynamic>?;
          if (show == null) continue;
          final image = show['image'] as Map<String, dynamic>?;
          String? cover = image?['original']?.toString() ??
              image?['medium']?.toString();
          if (cover != null) {
            if (cover.startsWith('http://')) {
              cover = cover.replaceFirst('http://', 'https://');
            }
            final title = show['name']?.toString() ?? query;
            final premiered = show['premiered']?.toString();
            final year = premiered != null && premiered.length >= 4
                ? premiered.substring(0, 4)
                : null;
            results.add(
              CoverSearchResult(
                title: title,
                coverUrl: sanitizeImageUrl(cover),
                year: year,
                source: 'TVMaze',
              ),
            );
          }
        }
      }
    } catch (_) {}

    if (results.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=tvShow&limit=5',
        );
        final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final list = (data['results'] as List<dynamic>?) ?? [];
          for (final item in list) {
            String? thumb = item['artworkUrl100']?.toString();
            if (thumb != null) {
              thumb = thumb.replaceAll('100x100bb.jpg', '600x600bb.jpg');
              final title = item['collectionName']?.toString() ??
                  item['trackName']?.toString() ??
                  query;
              final release = item['releaseDate']?.toString();
              final year = release != null && release.length >= 4
                  ? release.substring(0, 4)
                  : null;
              results.add(
                CoverSearchResult(
                  title: title,
                  coverUrl: sanitizeImageUrl(thumb),
                  year: year,
                  source: 'iTunes',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    return results;
  }

  // --- Movies: iTunes Search with Cinemeta fallback ---
  static Future<List<CoverSearchResult>> _searchMovies(
    String query,
    http.Client client,
  ) async {
    final results = <CoverSearchResult>[];
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=movie&limit=5',
      );
      final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final list = (data['results'] as List<dynamic>?) ?? [];
        for (final item in list) {
          String? thumb = item['artworkUrl100']?.toString();
          if (thumb != null) {
            thumb = thumb.replaceAll('100x100bb.jpg', '600x600bb.jpg');
            final title = item['trackName']?.toString() ?? query;
            final release = item['releaseDate']?.toString();
            final year = release != null && release.length >= 4
                ? release.substring(0, 4)
                : null;
            results.add(
              CoverSearchResult(
                title: title,
                coverUrl: sanitizeImageUrl(thumb),
                year: year,
                source: 'iTunes',
              ),
            );
          }
        }
      }
    } catch (_) {}

    if (results.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://v3-cinemeta.strem.io/catalog/movie/top/search=${Uri.encodeComponent(query)}.json',
        );
        final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final metas = (data['metas'] as List<dynamic>?) ?? [];
          for (final meta in metas) {
            final poster = meta['poster']?.toString();
            if (poster != null && poster.isNotEmpty) {
              results.add(
                CoverSearchResult(
                  title: meta['name']?.toString() ?? query,
                  coverUrl: sanitizeImageUrl(poster),
                  year: meta['year']?.toString(),
                  source: 'Cinemeta',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    return results;
  }

  // --- Games: Steam Store Search with CheapShark, RAWG, LaunchBox & Libretro fallback ---
  static Future<List<CoverSearchResult>> _searchGames(
    String query,
    http.Client client,
  ) async {
    final results = <CoverSearchResult>[];

    // 1. Steam Store Search (Primary for PC titles)
    try {
      final uri = Uri.parse(
        'https://store.steampowered.com/api/storesearch/?term=${Uri.encodeComponent(query)}&l=english&cc=US',
      );
      final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        for (final item in items) {
          final id = item['id'];
          final name = item['name']?.toString() ?? query;
          String? coverUrl;
          if (id != null) {
            // Steam vertical library poster (4:3 / portrait)
            coverUrl =
                'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$id/library_600x900_2x.jpg';
          } else if (item['tiny_image'] != null) {
            coverUrl = item['tiny_image'].toString();
          }

          if (coverUrl != null) {
            results.add(
              CoverSearchResult(
                title: name,
                coverUrl: sanitizeImageUrl(coverUrl),
                source: 'Steam',
              ),
            );
          }
        }
      }
    } catch (_) {}

    // 2. CheapShark Search (PC fallback)
    if (results.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://www.cheapshark.com/api/1.0/games?title=${Uri.encodeComponent(query)}&limit=6',
        );
        final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
        if (resp.statusCode == 200) {
          final list = json.decode(resp.body) as List<dynamic>;
          for (final item in list) {
            final name = item['external']?.toString() ?? query;
            final steamAppID = item['steamAppID']?.toString();
            String? coverUrl;
            if (steamAppID != null && steamAppID != '0' && steamAppID.isNotEmpty) {
              coverUrl =
                  'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$steamAppID/library_600x900_2x.jpg';
            } else if (item['thumb'] != null && item['thumb'].toString().isNotEmpty) {
              coverUrl = item['thumb'].toString();
            }

            if (coverUrl != null) {
              results.add(
                CoverSearchResult(
                  title: name,
                  coverUrl: sanitizeImageUrl(coverUrl),
                  source: 'CheapShark',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // 3. RAWG Video Games Database API (Multi-Platform / Nintendo Switch / PlayStation / Xbox)
    if (results.isEmpty) {
      try {
        // RAWG public free tier endpoint
        final uri = Uri.parse(
          'https://api.rawg.io/api/games?search=${Uri.encodeComponent(query)}&page_size=5&key=c542e67aec3a4340908f9de9e86038af',
        );
        final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final items = (data['results'] as List<dynamic>?) ?? [];
          for (final item in items) {
            final name = item['name']?.toString() ?? query;
            final bg = item['background_image']?.toString();
            final released = item['released']?.toString();
            final year = released != null && released.length >= 4 ? released.substring(0, 4) : null;
            if (bg != null && bg.isNotEmpty) {
              results.add(
                CoverSearchResult(
                  title: name,
                  coverUrl: sanitizeImageUrl(bg),
                  year: year,
                  source: 'RAWG',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // 4. Libretro Boxart CDN (Direct zero-auth box art for Nintendo & retro console titles)
    if (results.isEmpty) {
      try {
        // Formatted title for Libretro thumbnails repo
        final formatted = query.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
        final switchUrl =
            'https://raw.githubusercontent.com/libretro-thumbnails/Nintendo_-_Nintendo_Switch/master/Named_Boxarts/$formatted.png';
        final headResp = await client.head(Uri.parse(switchUrl)).timeout(const Duration(seconds: 4));
        if (headResp.statusCode == 200) {
          results.add(
            CoverSearchResult(
              title: query,
              coverUrl: sanitizeImageUrl(switchUrl),
              source: 'Libretro',
            ),
          );
        }
      } catch (_) {}
    }

    // 5. iTunes / LaunchBox Web Search Fallback for Console/Mobile titles
    if (results.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=software&limit=5',
        );
        final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final list = (data['results'] as List<dynamic>?) ?? [];
          for (final item in list) {
            String? thumb = item['artworkUrl512']?.toString() ??
                item['artworkUrl100']?.toString();
            if (thumb != null) {
              final title = item['trackName']?.toString() ?? query;
              final release = item['releaseDate']?.toString();
              final year = release != null && release.length >= 4 ? release.substring(0, 4) : null;
              results.add(
                CoverSearchResult(
                  title: title,
                  coverUrl: sanitizeImageUrl(thumb),
                  year: year,
                  source: 'LaunchBox/Store',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    return results;
  }
}

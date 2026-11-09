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
  static const Duration _timeout = Duration(seconds: 12);

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

  // --- Games: Multi-Platform Cover Aggregation (Steam, LaunchBox, Wikipedia, RAWG, Libretro, CheapShark) ---
  static const List<String> _libretroPlatforms = [
    'Nintendo_-_Game_Boy_Advance',
    'Sony_-_PlayStation_2',
    'Sony_-_PlayStation_3',
    'Sony_-_PlayStation_4',
    'Nintendo_-_Nintendo_Switch',
    'Nintendo_-_GameCube',
    'Nintendo_-_Nintendo_DS',
    'Nintendo_-_Nintendo_3DS',
    'Nintendo_-_Nintendo_64',
    'Nintendo_-_Super_Nintendo_Entertainment_System',
    'Nintendo_-_Nintendo_Entertainment_System',
    'Sony_-_PlayStation',
    'Microsoft_-_Xbox_360',
    'Microsoft_-_Xbox',
    'Sega_-_Mega_Drive_-_Genesis',
  ];

  /// Generates regional and punctuation variations for game titles to match retro database naming conventions.
  static List<String> generateGameTitleVariants(String rawQuery) {
    final variants = <String>{};
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return [];

    variants.add(trimmed);

    // Replace ':' with ' - ' (No-Intro standard format)
    if (trimmed.contains(':')) {
      variants.add(trimmed.replaceAll(RegExp(r'\s*:\s*'), ' - '));
      variants.add(trimmed.replaceAll(':', ''));
    }

    // Handle missing 'the' (e.g. "Shadow of Colossus" -> "Shadow of the Colossus")
    if (RegExp(r'\bof\s+colossus\b', caseSensitive: false).hasMatch(trimmed)) {
      variants.add(trimmed.replaceAll(RegExp(r'\bof\s+colossus\b', caseSensitive: false), 'of the Colossus'));
    }

    // Roman numeral conversions (e.g. " 3" -> " III", " 2" -> " II")
    final romanMap = {
      ' 1': ' I',
      ' 2': ' II',
      ' 3': ' III',
      ' 4': ' IV',
      ' 5': ' V',
    };
    for (final entry in romanMap.entries) {
      if (trimmed.endsWith(entry.key)) {
        variants.add(trimmed.substring(0, trimmed.length - entry.key.length) + entry.value);
      }
    }

    final withRegions = <String>[];
    for (final v in variants) {
      final sanitized = v.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
      withRegions.add(sanitized);
      withRegions.add('$sanitized (USA)');
      withRegions.add('$sanitized (Europe)');
      withRegions.add('$sanitized (World)');
    }

    return withRegions.toSet().toList();
  }

  static Future<List<CoverSearchResult>> _searchGames(
    String query,
    http.Client client,
  ) async {
    final results = <CoverSearchResult>[];
    final seenUrls = <String>{};

    void addResult(CoverSearchResult result) {
      final sanitized = sanitizeImageUrl(result.coverUrl);
      if (sanitized.isNotEmpty && !seenUrls.contains(sanitized)) {
        seenUrls.add(sanitized);
        results.add(
          CoverSearchResult(
            title: result.title,
            coverUrl: sanitized,
            year: result.year,
            source: result.source,
          ),
        );
      }
    }

    // 1. Steam Store Search (Top PC candidates)
    try {
      final uri = Uri.parse(
        'https://store.steampowered.com/api/storesearch/?term=${Uri.encodeComponent(query)}&l=english&cc=US',
      );
      final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        for (final item in items.take(3)) {
          final id = item['id'];
          final name = item['name']?.toString() ?? query;
          if (id != null) {
            // Steam vertical library poster (SafeCoverImage automatically handles fallback to header.jpg)
            addResult(
              CoverSearchResult(
                title: name,
                coverUrl:
                    'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$id/library_600x900_2x.jpg',
                source: 'Steam',
              ),
            );
          } else if (item['tiny_image'] != null) {
            addResult(
              CoverSearchResult(
                title: name,
                coverUrl: item['tiny_image'].toString(),
                source: 'Steam',
              ),
            );
          }
        }
      }
    } catch (_) {}

    // 2. LaunchBox Games Database Search (Querying LaunchBox Games Database web frontend)
    try {
      final uri = Uri.parse(
        'https://gamesdb.launchbox-app.com/games/results?search=${Uri.encodeComponent(query)}',
      );
      final resp = await client.get(uri, headers: _requestHeaders).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final imgRegex = RegExp(
          r'https?:\/\/images\.launchbox-app\.com\/([a-zA-Z0-9\-_]+\.(?:jpg|png|jpeg))',
          caseSensitive: false,
        );
        final matches = imgRegex.allMatches(resp.body);
        for (final m in matches.take(3)) {
          final rawUrl = m.group(0);
          if (rawUrl != null) {
            addResult(
              CoverSearchResult(
                title: query,
                coverUrl: rawUrl,
                source: 'LaunchBox',
              ),
            );
          }
        }
      }
    } catch (_) {}

    // 3. Wikipedia / MediaWiki Video Games Box Art (Zero-auth open archive for console exclusives)
    try {
      final wikiUri = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&prop=pageimages&piprop=thumbnail&pithumbsize=600&generator=search&gsrsearch=${Uri.encodeComponent('$query video game')}&gsrlimit=3&origin=*',
      );
      final resp = await client.get(wikiUri, headers: _requestHeaders).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final pages = (data['query']?['pages'] as List<dynamic>?) ?? [];
        for (final p in pages) {
          final thumb = p['thumbnail']?['source']?.toString();
          final pageTitle = p['title']?.toString() ?? query;
          if (thumb != null && thumb.isNotEmpty) {
            addResult(
              CoverSearchResult(
                title: pageTitle.replaceAll(RegExp(r'\s*\([^)]*\)$'), ''),
                coverUrl: thumb,
                source: 'Wikipedia',
              ),
            );
          }
        }
      }
    } catch (_) {}

    // 4. RAWG Video Games Database API (Multi-Platform / Nintendo / PlayStation / Xbox / PC)
    try {
      final uri = Uri.parse(
        'https://api.rawg.io/api/games?search=${Uri.encodeComponent(query)}&page_size=4&key=c542e67aec3a4340908f9de9e86038af',
      );
      final resp = await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final items = (data['results'] as List<dynamic>?) ?? [];
        for (final item in items.take(4)) {
          final name = item['name']?.toString() ?? query;
          final bg = item['background_image']?.toString();
          final released = item['released']?.toString();
          final year = released != null && released.length >= 4 ? released.substring(0, 4) : null;
          if (bg != null && bg.isNotEmpty) {
            addResult(
              CoverSearchResult(
                title: name,
                coverUrl: bg,
                year: year,
                source: 'RAWG',
              ),
            );
          }
        }
      }
    } catch (_) {}

    // 5. Libretro Boxart Multi-Platform CDN (Direct zero-auth box art for Nintendo & PlayStation & Retro Consoles)
    try {
      final variants = generateGameTitleVariants(query);
      for (final platform in _libretroPlatforms.take(6)) {
        for (final variant in variants.take(4)) {
          if (results.length >= 8) break;
          final url =
              'https://raw.githubusercontent.com/libretro-thumbnails/$platform/master/Named_Boxarts/$variant.png';
          try {
            final headResp = await client.head(Uri.parse(url)).timeout(const Duration(seconds: 3));
            if (headResp.statusCode == 200) {
              addResult(
                CoverSearchResult(
                  title: query,
                  coverUrl: url,
                  source: 'Libretro',
                ),
              );
              break; // Found boxart for this platform
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 6. CheapShark Search (Fallback if candidate pool is still small)
    if (results.length < 3) {
      try {
        final uri = Uri.parse(
          'https://www.cheapshark.com/api/1.0/games?title=${Uri.encodeComponent(query)}&limit=4',
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
              addResult(
                CoverSearchResult(
                  title: name,
                  coverUrl: coverUrl,
                  source: 'CheapShark',
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

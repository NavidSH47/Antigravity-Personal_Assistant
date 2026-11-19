import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class MediaInfoResult {
  final int? releaseYear;
  final int? episodeCount; // TV Shows only
  final int? runtimeMinutes; // Movies only

  const MediaInfoResult({
    this.releaseYear,
    this.episodeCount,
    this.runtimeMinutes,
  });

  @override
  String toString() =>
      'MediaInfoResult(releaseYear: $releaseYear, episodeCount: $episodeCount, runtimeMinutes: $runtimeMinutes)';
}

class MediaInfoFetchService {
  static const Duration _timeout = Duration(seconds: 12);

  static const Map<String, String> _requestHeaders = {
    'User-Agent':
        'NSHPulse/1.0 (Android; Mobile; +https://github.com/NavidSH47/pulse-assistant)',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Returns a [MediaInfoResult] containing releaseYear, episodeCount (TV),
  /// runtimeMinutes (Movie), or null if not found.
  static Future<MediaInfoResult?> fetchInfo({
    required String title,
    required MediaType type,
    http.Client? client,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    final httpClient = client ?? http.Client();
    try {
      switch (type) {
        case MediaType.tvShow:
          return await _fetchTvInfo(trimmed, httpClient);
        case MediaType.movie:
          return await _fetchMovieInfo(trimmed, httpClient);
        case MediaType.book:
          return await _fetchBookInfo(trimmed, httpClient);
        case MediaType.videoGame:
          return await _fetchGameInfo(trimmed, httpClient);
      }
    } catch (_) {
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  // --- TV SHOWS ---
  static Future<MediaInfoResult?> _fetchTvInfo(
    String query,
    http.Client client,
  ) async {
    // 1. Try TVMaze single search with embedded episodes
    try {
      final uri = Uri.parse(
        'https://api.tvmaze.com/singlesearch/shows?q=${Uri.encodeComponent(query)}&embed=episodes',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final premiered = data['premiered']?.toString();
        final year = (premiered != null && premiered.length >= 4)
            ? int.tryParse(premiered.substring(0, 4))
            : null;

        final embedded = data['_embedded'] as Map<String, dynamic>?;
        final episodes = embedded?['episodes'] as List<dynamic>?;
        final count = episodes?.length;

        if (year != null || count != null) {
          return MediaInfoResult(releaseYear: year, episodeCount: count);
        }
      }
    } catch (_) {}

    // 2. Fallback: TVMaze general search
    try {
      final uri = Uri.parse(
        'https://api.tvmaze.com/search/shows?q=${Uri.encodeComponent(query)}',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final show = list.first['show'] as Map<String, dynamic>?;
          if (show != null) {
            final premiered = show['premiered']?.toString();
            final year = (premiered != null && premiered.length >= 4)
                ? int.tryParse(premiered.substring(0, 4))
                : null;
            final showId = show['id'];
            int? count;
            if (showId != null) {
              try {
                final epUri = Uri.parse('https://api.tvmaze.com/shows/$showId/episodes');
                final epResp = await client
                    .get(epUri, headers: _requestHeaders)
                    .timeout(_timeout);
                if (epResp.statusCode == 200) {
                  final epList = json.decode(epResp.body) as List<dynamic>;
                  count = epList.length;
                }
              } catch (_) {}
            }
            if (year != null || count != null) {
              return MediaInfoResult(releaseYear: year, episodeCount: count);
            }
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: iTunes TV Show search
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=tvShow&limit=1',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final results = (data['results'] as List<dynamic>?) ?? [];
        if (results.isNotEmpty) {
          final item = results.first as Map<String, dynamic>;
          final release = item['releaseDate']?.toString();
          final year = (release != null && release.length >= 4)
              ? int.tryParse(release.substring(0, 4))
              : null;
          final trackCount = item['trackCount'] as int?;
          if (year != null || trackCount != null) {
            return MediaInfoResult(releaseYear: year, episodeCount: trackCount);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // --- MOVIES ---
  static Future<MediaInfoResult?> _fetchMovieInfo(
    String query,
    http.Client client,
  ) async {
    // 1. Try iTunes Movie search (returns releaseDate and trackTimeMillis)
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=movie&country=US&limit=1',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final results = (data['results'] as List<dynamic>?) ?? [];
        if (results.isNotEmpty) {
          final item = results.first as Map<String, dynamic>;
          final release = item['releaseDate']?.toString();
          final year = (release != null && release.length >= 4)
              ? int.tryParse(release.substring(0, 4))
              : null;
          final millis = item['trackTimeMillis'] as num?;
          final runtime = millis != null ? (millis / 60000).round() : null;
          if (year != null || runtime != null) {
            return MediaInfoResult(releaseYear: year, runtimeMinutes: runtime);
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: Cinemeta
    try {
      final uri = Uri.parse(
        'https://v3-cinemeta.strem.io/catalog/movie/top/search=${Uri.encodeComponent(query)}.json',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final metas = (data['metas'] as List<dynamic>?) ?? [];
        if (metas.isNotEmpty) {
          final meta = metas.first as Map<String, dynamic>;
          int? yr = int.tryParse(meta['year']?.toString() ?? '') ??
              int.tryParse(meta['releaseInfo']?.toString() ?? '');
          final runtimeStr = meta['runtime']?.toString();
          int? runtime;
          if (runtimeStr != null) {
            final match = RegExp(r'\d+').firstMatch(runtimeStr);
            if (match != null) {
              runtime = int.tryParse(match.group(0)!);
            }
          }

          final imdbId = meta['id']?.toString();
          if (imdbId != null && (runtime == null || yr == null)) {
            try {
              final detailUri = Uri.parse(
                'https://v3-cinemeta.strem.io/meta/movie/$imdbId.json',
              );
              final detailResp = await client
                  .get(detailUri, headers: _requestHeaders)
                  .timeout(_timeout);
              if (detailResp.statusCode == 200) {
                final detailData =
                    json.decode(detailResp.body) as Map<String, dynamic>;
                final detailMeta =
                    detailData['meta'] as Map<String, dynamic>?;
                if (detailMeta != null) {
                  yr ??= int.tryParse(detailMeta['year']?.toString() ?? '') ??
                      int.tryParse(
                        detailMeta['releaseInfo']?.toString() ?? '',
                      );
                  final dRuntime = detailMeta['runtime']?.toString();
                  if (dRuntime != null) {
                    final match = RegExp(r'\d+').firstMatch(dRuntime);
                    if (match != null) {
                      runtime ??= int.tryParse(match.group(0)!);
                    }
                  }
                }
              }
            } catch (_) {}
          }

          if (yr != null || runtime != null) {
            return MediaInfoResult(releaseYear: yr, runtimeMinutes: runtime);
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: Wikipedia Summary API
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(query)}',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final desc = data['description']?.toString() ?? '';
        final extract = data['extract']?.toString() ?? '';
        final text = '$desc $extract';
        final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(text);
        final yr = yearMatch != null ? int.tryParse(yearMatch.group(0)!) : null;
        if (yr != null) {
          return MediaInfoResult(releaseYear: yr);
        }
      }
    } catch (_) {}

    return null;
  }

  // --- BOOKS ---
  static Future<MediaInfoResult?> _fetchBookInfo(
    String query,
    http.Client client,
  ) async {
    // 1. Try Open Library
    try {
      final uri = Uri.parse(
        'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=1',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final docs = (data['docs'] as List<dynamic>?) ?? [];
        if (docs.isNotEmpty) {
          final doc = docs.first as Map<String, dynamic>;
          final firstPublish = doc['first_publish_year'];
          final year = firstPublish != null
              ? int.tryParse(firstPublish.toString())
              : null;
          if (year != null) {
            return MediaInfoResult(releaseYear: year);
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: Google Books
    try {
      final uri = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes?q=intitle:${Uri.encodeComponent(query)}&maxResults=1',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        if (items.isNotEmpty) {
          final info = items.first['volumeInfo'] as Map<String, dynamic>?;
          final pubDate = info?['publishedDate']?.toString();
          final year = (pubDate != null && pubDate.length >= 4)
              ? int.tryParse(pubDate.substring(0, 4))
              : null;
          if (year != null) {
            return MediaInfoResult(releaseYear: year);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // --- VIDEO GAMES ---
  static Future<MediaInfoResult?> _fetchGameInfo(
    String query,
    http.Client client,
  ) async {
    // 1. Try Wikipedia summary for release year
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(query)}',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final extract = data['extract']?.toString() ?? '';
        final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(extract);
        if (match != null) {
          final year = int.tryParse(match.group(0)!);
          if (year != null && year >= 1970 && year <= DateTime.now().year + 2) {
            return MediaInfoResult(releaseYear: year);
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: Steam Store API search
    try {
      final uri = Uri.parse(
        'https://store.steampowered.com/api/storesearch/?term=${Uri.encodeComponent(query)}&l=english&cc=US',
      );
      final resp =
          await client.get(uri, headers: _requestHeaders).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        if (items.isNotEmpty) {
          // Check if title or price has year or query app details
          final first = items.first as Map<String, dynamic>;
          final appId = first['id'];
          if (appId != null) {
            final detailUri = Uri.parse(
              'https://store.steampowered.com/api/appdetails?appids=$appId',
            );
            final dResp = await client
                .get(detailUri, headers: _requestHeaders)
                .timeout(_timeout);
            if (dResp.statusCode == 200) {
              final dData = json.decode(dResp.body) as Map<String, dynamic>;
              final appData = dData['$appId']?['data'] as Map<String, dynamic>?;
              final rDate = appData?['release_date']?['date']?.toString();
              if (rDate != null) {
                final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rDate);
                if (match != null) {
                  return MediaInfoResult(releaseYear: int.tryParse(match.group(0)!));
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }
}

import 'package:flutter/material.dart';

enum MediaType { book, tvShow, movie, videoGame }

class MediaItem {
  final String id;
  final MediaType type;
  final String title;
  final int releaseYear;
  final String? coverUrl;
  final String? localCoverPath;
  final String? personalNotes;
  final List<String> labels;
  final double progressCurrent;
  final double progressTotal;
  final double? score; // 1.0 - 10.0 in 0.5 steps
  final bool isOnHold;
  final int customOrder;
  final DateTime createdAt;
  final DateTime displayDate;

  MediaItem({
    required this.id,
    required this.type,
    required this.title,
    required this.releaseYear,
    this.coverUrl,
    this.localCoverPath,
    this.personalNotes,
    this.labels = const [],
    required this.progressCurrent,
    required this.progressTotal,
    this.score,
    this.isOnHold = false,
    this.customOrder = 0,
    DateTime? createdAt,
    DateTime? displayDate,
  })  : createdAt = createdAt ?? DateTime.now(),
        displayDate = displayDate ?? (createdAt ?? DateTime.now());

  double get progressRatio {
    if (progressTotal <= 0) return 0.0;
    final r = progressCurrent / progressTotal;
    return r.clamp(0.0, 1.0);
  }

  int get progressPercent => (progressRatio * 100).round();

  /// Returns true when media progress has reached 100% (done).
  bool get isCompleted => progressTotal > 0 && (progressCurrent >= progressTotal || progressPercent >= 100);
  bool get isDone => isCompleted;

  /// Down-listing comparator: completed (100% / Done) media items sink to the bottom.
  static int compareExecutionState(MediaItem a, MediaItem b) {
    final aDone = a.isCompleted;
    final bDone = b.isCompleted;
    if (aDone != bDone) return aDone ? 1 : -1;
    return 0;
  }

  String get metricUnit {
    switch (type) {
      case MediaType.book:
        return 'Pages';
      case MediaType.tvShow:
        return 'Episodes';
      case MediaType.movie:
        return 'Minutes';
      case MediaType.videoGame:
        return 'Chapters/Missions';
    }
  }

  String get metricDisplay {
    final cur = progressCurrent.toInt();
    final tot = progressTotal.toInt();
    switch (type) {
      case MediaType.book:
        return 'Pages: $cur / $tot';
      case MediaType.tvShow:
        return 'Episodes: $cur / $tot';
      case MediaType.movie:
        return 'Minutes: $cur / $tot min';
      case MediaType.videoGame:
        return 'Missions: $cur / $tot';
    }
  }

  String get iconEmoji {
    switch (type) {
      case MediaType.book:
        return '📖';
      case MediaType.tvShow:
        return '📺';
      case MediaType.movie:
        return '🎬';
      case MediaType.videoGame:
        return '🎮';
    }
  }

  List<Color> get scoreGradient {
    if (score == null) {
      return [const Color(0xFF64748B), const Color(0xFF475569)];
    }
    final s = score!;
    if (s <= 3.5) {
      return [const Color(0xFFE53935), const Color(0xFFFF7043)];
    } else if (s <= 6.5) {
      return [const Color(0xFFFFA000), const Color(0xFFC0CA33)];
    } else if (s <= 8.5) {
      return [const Color(0xFF26A69A), const Color(0xFF43A047)];
    } else {
      return [const Color(0xFF2E7D32), const Color(0xFF7E57C2)];
    }
  }

  MediaItem copyWith({
    String? id,
    MediaType? type,
    String? title,
    int? releaseYear,
    String? coverUrl,
    String? localCoverPath,
    String? personalNotes,
    List<String>? labels,
    double? progressCurrent,
    double? progressTotal,
    double? score,
    bool? isOnHold,
    int? customOrder,
    DateTime? createdAt,
    DateTime? displayDate,
  }) {
    return MediaItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      releaseYear: releaseYear ?? this.releaseYear,
      coverUrl: coverUrl ?? this.coverUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      personalNotes: personalNotes ?? this.personalNotes,
      labels: labels ?? this.labels,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTotal: progressTotal ?? this.progressTotal,
      score: score ?? this.score,
      isOnHold: isOnHold ?? this.isOnHold,
      customOrder: customOrder ?? this.customOrder,
      createdAt: createdAt ?? this.createdAt,
      displayDate: displayDate ?? this.displayDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'releaseYear': releaseYear,
      'coverUrl': coverUrl,
      'localCoverPath': localCoverPath,
      'personalNotes': personalNotes,
      'labels': labels,
      'progressCurrent': progressCurrent,
      'progressTotal': progressTotal,
      'score': score,
      'isOnHold': isOnHold,
      'customOrder': customOrder,
      'createdAt': createdAt.toIso8601String(),
      'displayDate': displayDate.toIso8601String(),
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now();
    final display = json['displayDate'] != null
        ? DateTime.tryParse(json['displayDate'] as String) ?? created
        : created;

    return MediaItem(
      id: json['id'] as String,
      type: MediaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MediaType.book,
      ),
      title: json['title'] as String,
      releaseYear: (json['releaseYear'] as int?) ?? 2024,
      coverUrl: json['coverUrl'] as String?,
      localCoverPath: json['localCoverPath'] as String?,
      personalNotes: json['personalNotes'] as String?,
      labels: (json['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      progressCurrent: (json['progressCurrent'] as num?)?.toDouble() ?? 0.0,
      progressTotal: (json['progressTotal'] as num?)?.toDouble() ?? 100.0,
      score: (json['score'] as num?)?.toDouble(),
      isOnHold: (json['isOnHold'] as bool?) ?? false,
      customOrder: (json['customOrder'] as int?) ?? 0,
      createdAt: created,
      displayDate: display,
    );
  }
}

/// Down-listing comparator function partitioning active media before completed ones.
int compareMediaExecutionState(MediaItem a, MediaItem b) =>
    MediaItem.compareExecutionState(a, b);

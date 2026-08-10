import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/talk.dart';

class WatchedTalkEntry {
  const WatchedTalkEntry({
    required this.id,
    required this.title,
    required this.presenterDisplayName,
    required this.imageUrl,
    required this.watchedAt,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
  });

  final String id;
  final String title;
  final String presenterDisplayName;
  final String imageUrl;
  final DateTime watchedAt;
  final double positionSeconds;
  final double durationSeconds;

  double get progressFraction {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  factory WatchedTalkEntry.fromJson(Map<String, dynamic> json) {
    return WatchedTalkEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Talk',
      presenterDisplayName:
          json['presenterDisplayName']?.toString() ?? 'Unknown',
      imageUrl: json['imageUrl']?.toString() ?? '',
      watchedAt: DateTime.tryParse(json['watchedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      positionSeconds:
          (json['positionSeconds'] as num?)?.toDouble() ?? 0,
      durationSeconds:
          (json['durationSeconds'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'presenterDisplayName': presenterDisplayName,
      'imageUrl': imageUrl,
      'watchedAt': watchedAt.toIso8601String(),
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
    };
  }

  WatchedTalkEntry copyWith({
    String? id,
    String? title,
    String? presenterDisplayName,
    String? imageUrl,
    DateTime? watchedAt,
    double? positionSeconds,
    double? durationSeconds,
  }) {
    return WatchedTalkEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      presenterDisplayName:
          presenterDisplayName ?? this.presenterDisplayName,
      imageUrl: imageUrl ?? this.imageUrl,
      watchedAt: watchedAt ?? this.watchedAt,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

/// Persists watch history, watch later, interests, and discovery state.
class LocalHistoryService {
  LocalHistoryService();

  static const _watchHistoryKey = 'watch_history_v2';
  static const _watchHistoryLegacyKey = 'watch_history_v1';
  static const _watchLaterKey = 'watch_later_v1';
  static const _suggestionsKey = 'suggested_talks_v1';
  static const _shownIdsKey = 'shown_talk_ids_v1';
  static const _interestsKey = 'user_interests_v1';
  static const _interestsPromptKey = 'interests_prompt_done_v1';

  static const int maxWatchHistory = 40;
  static const int maxWatchLater = 60;
  static const int maxCachedSuggestions = 40;
  static const int maxShownIds = 300;

  static const List<String> interestOptions = [
    'Technology',
    'Science',
    'Culture',
    'Design',
    'Business',
    'Education',
    'Health',
    'Art',
    'Psychology',
    'Innovation',
    'Climate change',
    'Personal growth',
    'Society',
    'Film',
    'Storytelling',
  ];

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> hasCompletedInterestsPrompt() async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_interestsPromptKey) ?? false;
  }

  Future<void> markInterestsPromptDone() async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_interestsPromptKey, true);
  }

  Future<List<String>> getInterests() async {
    final prefs = await _ensurePrefs();
    return prefs.getStringList(_interestsKey) ?? const [];
  }

  Future<void> saveInterests(List<String> interests) async {
    final prefs = await _ensurePrefs();
    final cleaned = interests
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    await prefs.setStringList(_interestsKey, cleaned);
    await markInterestsPromptDone();
  }

  Future<List<WatchedTalkEntry>> getWatchHistory() async {
    final prefs = await _ensurePrefs();
    var raw = prefs.getString(_watchHistoryKey);
    raw ??= prefs.getString(_watchHistoryLegacyKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final entries = decoded
          .whereType<Map>()
          .map(
            (item) =>
                WatchedTalkEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
      entries.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistHistory(List<WatchedTalkEntry> history) async {
    final prefs = await _ensurePrefs();
    final trimmed = history.take(maxWatchHistory).toList();
    await prefs.setString(
      _watchHistoryKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  /// Saves / bumps a watch event. Newest first; duplicates move to the top.
  Future<void> recordWatch({
    required String id,
    required String title,
    required String presenterDisplayName,
    required String imageUrl,
    double? positionSeconds,
    double? durationSeconds,
  }) async {
    if (id.trim().isEmpty) return;

    final history = await getWatchHistory();
    WatchedTalkEntry? existing;
    for (final item in history) {
      if (item.id == id) {
        existing = item;
        break;
      }
    }
    history.removeWhere((item) => item.id == id);
    history.insert(
      0,
      WatchedTalkEntry(
        id: id,
        title: title,
        presenterDisplayName: presenterDisplayName,
        imageUrl: imageUrl,
        watchedAt: DateTime.now().toUtc(),
        positionSeconds:
            positionSeconds ?? existing?.positionSeconds ?? 0,
        durationSeconds:
            durationSeconds ?? existing?.durationSeconds ?? 0,
      ),
    );
    await _persistHistory(history);
  }

  Future<void> updateWatchProgress({
    required String id,
    required double positionSeconds,
    required double durationSeconds,
  }) async {
    if (id.trim().isEmpty) return;
    final history = await getWatchHistory();
    final index = history.indexWhere((e) => e.id == id);
    if (index < 0) return;

    final current = history[index];
    history[index] = current.copyWith(
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds > 0
          ? durationSeconds
          : current.durationSeconds,
      watchedAt: DateTime.now().toUtc(),
    );
    // Keep most recently updated near the top.
    final updated = history.removeAt(index);
    history.insert(0, updated);
    await _persistHistory(history);
  }

  Future<WatchedTalkEntry?> getWatchEntry(String id) async {
    final history = await getWatchHistory();
    for (final entry in history) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<List<Talk>> getWatchLater() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_watchLaterKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Talk.fromJson(Map<String, dynamic>.from(item)))
          .where((talk) => talk.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isInWatchLater(String id) async {
    final list = await getWatchLater();
    return list.any((t) => t.id == id);
  }

  Future<void> _persistWatchLater(List<Talk> talks) async {
    final prefs = await _ensurePrefs();
    final limited = talks.take(maxWatchLater).toList();
    await prefs.setString(
      _watchLaterKey,
      jsonEncode(limited.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> addToWatchLater(Talk talk) async {
    if (talk.id.isEmpty) return;
    final list = await getWatchLater();
    list.removeWhere((t) => t.id == talk.id);
    list.insert(0, talk);
    await _persistWatchLater(list);
  }

  Future<void> removeFromWatchLater(String id) async {
    final list = await getWatchLater();
    list.removeWhere((t) => t.id == id);
    await _persistWatchLater(list);
  }

  Future<List<Talk>> getCachedSuggestions() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_suggestionsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Talk.fromJson(Map<String, dynamic>.from(item)))
          .where((talk) => talk.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCachedSuggestions(List<Talk> talks) async {
    final prefs = await _ensurePrefs();
    final unique = <String, Talk>{};
    for (final talk in talks) {
      if (talk.id.isEmpty) continue;
      unique.putIfAbsent(talk.id, () => talk);
    }
    final limited = unique.values.take(maxCachedSuggestions).toList();
    await prefs.setString(
      _suggestionsKey,
      jsonEncode(limited.map((talk) => talk.toJson()).toList()),
    );
  }

  Future<Set<String>> getShownTalkIds() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getStringList(_shownIdsKey) ?? const [];
    return raw.where((id) => id.trim().isNotEmpty).toSet();
  }

  Future<void> markTalksShown(Iterable<String> ids) async {
    final prefs = await _ensurePrefs();
    final current = await getShownTalkIds();
    current.addAll(ids.where((id) => id.trim().isNotEmpty));

    final list = current.toList();
    final trimmed = list.length <= maxShownIds
        ? list
        : list.sublist(list.length - maxShownIds);
    await prefs.setStringList(_shownIdsKey, trimmed);
  }

  Future<Set<String>> pruneShownTalkIds({int keepLatest = 80}) async {
    final prefs = await _ensurePrefs();
    final current = (await getShownTalkIds()).toList();
    if (current.length <= keepLatest) {
      return current.toSet();
    }
    final trimmed = current.sublist(current.length - keepLatest);
    await prefs.setStringList(_shownIdsKey, trimmed);
    return trimmed.toSet();
  }
}

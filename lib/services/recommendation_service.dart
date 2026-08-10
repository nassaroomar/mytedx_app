import 'dart:math';

import '../models/related_talk.dart';
import '../models/similar_talk.dart';
import '../models/talk.dart';
import 'api_service.dart';
import 'local_history_service.dart';

/// Builds personalized home suggestions and unique random page batches.
class RecommendationService {
  RecommendationService({
    ApiService? apiService,
    LocalHistoryService? localHistory,
  })  : _api = apiService ?? ApiService(),
        _local = localHistory ?? LocalHistoryService();

  final ApiService _api;
  final LocalHistoryService _local;
  final Random _random = Random();

  static const List<String> discoveryTags = [
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
    'Media',
    'Social change',
    'Communication',
    'Film',
    'Women',
    'Feminism',
    'Biology',
    'Climate change',
    'Sustainability',
    'Personal growth',
    'Storytelling',
    'Work',
    'Emotions',
    'Ocean',
    'Food',
    'Society',
    'Travel',
    'Animation',
    'TED-Ed',
    'TEDx',
  ];

  LocalHistoryService get localHistory => _local;

  Talk relatedToTalk(RelatedTalk related) {
    return Talk(
      id: related.relatedId,
      title: related.title,
      duration: related.duration,
      presenterDisplayName: related.presenterDisplayName,
      imageUrl: related.imageUrl ?? '',
    );
  }

  List<Talk> dedupeTalks(
    Iterable<Talk> talks, {
    Set<String>? excludeIds,
  }) {
    final seen = <String>{...(excludeIds ?? const <String>{})};
    final result = <Talk>[];
    for (final talk in talks) {
      if (talk.id.isEmpty || seen.contains(talk.id)) continue;
      seen.add(talk.id);
      result.add(talk);
    }
    return result;
  }

  /// Finds talks with overlapping tags.
  /// Higher shared-tag count => higher rank (shown first in Up Next).
  Future<List<SimilarTalk>> findSimilarByTags({
    required String currentTalkId,
    required List<String> tags,
    int limit = 8,
    int maxTagsToQuery = 3,
  }) async {
    final sourceTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (sourceTags.isEmpty) return [];

    // Stage 1 only: score by tag-search hits (fast, no per-talk details storm).
    final appearanceScore = <String, int>{};
    final talksById = <String, Talk>{};
    final tagsToQuery = sourceTags.take(maxTagsToQuery);

    await Future.wait(
      tagsToQuery.map((tag) async {
        try {
          final results = await _api.searchTalks(null, tag);
          for (final talk in results) {
            if (talk.id.isEmpty || talk.id == currentTalkId) continue;
            appearanceScore[talk.id] = (appearanceScore[talk.id] ?? 0) + 1;
            talksById.putIfAbsent(talk.id, () => talk);
          }
        } catch (_) {}
      }),
    );

    if (talksById.isEmpty) return [];

    final ranked = talksById.values.toList()
      ..sort((a, b) {
        final byScore =
            (appearanceScore[b.id] ?? 0).compareTo(appearanceScore[a.id] ?? 0);
        if (byScore != 0) return byScore;
        return a.title.compareTo(b.title);
      });

    return ranked.take(limit).map((talk) {
      return SimilarTalk(
        talk: talk,
        sharedTagCount: appearanceScore[talk.id] ?? 1,
        sharedTags: const [],
      );
    }).toList();
  }

  /// Personalized related talks: interests first, then watch history.
  Future<List<Talk>> buildPersonalizedSuggestions({
    int maxWatchSources = 5,
    int maxSuggestions = 12,
  }) async {
    final suggestions = <Talk>[];
    final history = await _local.getWatchHistory();
    final usedIds = history.map((e) => e.id).toSet();

    final interests = await _local.getInterests();
    if (interests.isNotEmpty) {
      final fromInterests = await findSimilarByTags(
        currentTalkId: '',
        tags: interests,
        limit: maxSuggestions,
        maxTagsToQuery: 4,
      );
      for (final item in fromInterests) {
        if (usedIds.contains(item.talk.id)) continue;
        usedIds.add(item.talk.id);
        suggestions.add(item.talk);
        if (suggestions.length >= maxSuggestions) {
          await _local.saveCachedSuggestions(suggestions);
          return suggestions;
        }
      }
    }

    if (history.isEmpty) {
      await _local.saveCachedSuggestions(suggestions);
      return suggestions;
    }

    for (final entry in history.take(maxWatchSources)) {
      try {
        final details = await _api.getTalkDetails(entry.id);
        if (details.tagsList.isNotEmpty) {
          final similar = await findSimilarByTags(
            currentTalkId: entry.id,
            tags: details.tagsList,
            limit: 6,
          );
          for (final item in similar) {
            if (usedIds.contains(item.talk.id)) continue;
            usedIds.add(item.talk.id);
            suggestions.add(item.talk);
            if (suggestions.length >= maxSuggestions) {
              await _local.saveCachedSuggestions(suggestions);
              return suggestions;
            }
          }
        } else {
          for (final related in details.relatedVideos) {
            final talk = relatedToTalk(related);
            if (talk.id.isEmpty || usedIds.contains(talk.id)) continue;
            usedIds.add(talk.id);
            suggestions.add(talk);
            if (suggestions.length >= maxSuggestions) {
              await _local.saveCachedSuggestions(suggestions);
              return suggestions;
            }
          }
        }
      } catch (_) {
        // Skip failed sources and continue with older history.
      }
    }

    await _local.saveCachedSuggestions(suggestions);
    return suggestions;
  }

  Future<List<Talk>> fetchUniqueDiscoveryBatch({
    required Set<String> excludeIds,
    int targetCount = 10,
    int maxAttempts = 14,
    List<String>? seedTags,
  }) async {
    final collected = <Talk>[];
    final blocked = {...excludeIds};
    final tags = <String>[
      ...?seedTags?.where((t) => t.trim().isNotEmpty),
      ...discoveryTags,
    ]..shuffle(_random);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        List<Talk> batch;
        if (attempt == 0 && (seedTags == null || seedTags.isEmpty)) {
          batch = await _api.getFeed();
          batch = [...batch]..shuffle(_random);
        } else {
          final tag = tags[attempt % tags.length];
          batch = await _api.searchTalks(null, tag);
          batch = [...batch]..shuffle(_random);
        }

        for (final talk in batch) {
          if (talk.id.isEmpty || blocked.contains(talk.id)) continue;
          blocked.add(talk.id);
          collected.add(talk);
          if (collected.length >= targetCount) {
            return collected;
          }
        }
      } catch (_) {
        // Try next discovery source.
      }
    }

    return collected;
  }
}

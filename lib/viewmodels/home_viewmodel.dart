import 'package:flutter/foundation.dart';

import '../models/talk.dart';
import '../services/api_service.dart';
import '../services/local_history_service.dart';
import '../services/recommendation_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    ApiService? apiService,
    LocalHistoryService? localHistory,
    RecommendationService? recommendations,
  })  : _apiService = apiService ?? ApiService(),
        _localHistory = localHistory ?? LocalHistoryService(),
        _recommendations = recommendations ??
            RecommendationService(
              apiService: apiService ?? ApiService(),
              localHistory: localHistory ?? LocalHistoryService(),
            );

  final ApiService _apiService;
  final LocalHistoryService _localHistory;
  final RecommendationService _recommendations;

  List<Talk> _talks = [];
  final Set<String> _shownIds = {};
  int _personalizedCount = 0;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = true;
  String _errorMessage = '';
  int _scrollToTopTick = 0;

  List<Talk> get talks => List.unmodifiable(_talks);
  Set<String> get shownIds => Set.unmodifiable(_shownIds);
  int get personalizedCount => _personalizedCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasError => _hasError;
  bool get hasMore => _hasMore;
  String get errorMessage => _errorMessage;
  bool get hasData => _talks.isNotEmpty;
  int get scrollToTopTick => _scrollToTopTick;

  /// Scroll home to top and reload with a fresh batch.
  Future<void> scrollToTopAndRefresh() async {
    _scrollToTopTick++;
    notifyListeners();
    await refresh();
  }

  Future<void> fetchFeed({bool showLoader = true}) async {
    if (showLoader) {
      _isLoading = true;
    }
    _hasError = false;
    _errorMessage = '';
    _hasMore = true;
    notifyListeners();

    try {
      final cached = await _localHistory.getCachedSuggestions();
      final persistedShown = await _localHistory.getShownTalkIds();
      _shownIds
        ..clear()
        ..addAll(persistedShown);

      if (cached.isNotEmpty && _talks.isEmpty) {
        _talks = _recommendations.dedupeTalks(cached);
        _personalizedCount = _talks.length;
        _registerShown(_talks);
        notifyListeners();
      }

      final personalized =
          await _recommendations.buildPersonalizedSuggestions();

      final history = await _localHistory.getWatchHistory();
      final interests = await _localHistory.getInterests();
      final exclude = <String>{
        ...persistedShown,
        ...history.map((e) => e.id),
        ...personalized.map((t) => t.id),
      };

      final discovery = await _recommendations.fetchUniqueDiscoveryBatch(
        excludeIds: exclude,
        targetCount: 12,
        seedTags: interests,
      );

      final merged = _recommendations.dedupeTalks([
        ...personalized,
        ...discovery,
      ]);

      _talks = merged;
      _personalizedCount = personalized.length;
      _shownIds
        ..clear()
        ..addAll(persistedShown);
      _registerShown(_talks);
      await _localHistory.saveCachedSuggestions(
        personalized.isNotEmpty ? personalized : merged.take(12).toList(),
      );
      await _localHistory.markTalksShown(_talks.map((t) => t.id));

      _hasError = false;
      _errorMessage = '';
      _hasMore = true;
    } catch (error) {
      _hasError = true;
      _errorMessage = _readableError(error);
      if (_talks.isEmpty) {
        try {
          final fallback = await _apiService.getFeed();
          _talks = _recommendations.dedupeTalks(fallback);
          _personalizedCount = 0;
          _registerShown(_talks);
        } catch (_) {
          _talks = [];
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh / Home tap: replace the page with talks not currently shown.
  Future<void> refresh() async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    _hasMore = true;
    notifyListeners();

    try {
      final history = await _localHistory.getWatchHistory();
      final currentlyVisible = _talks.map((t) => t.id).toSet();

      // Prefer brand-new cards vs what is on screen right now.
      final exclude = <String>{
        ...currentlyVisible,
        ...history.map((e) => e.id),
      };

      final personalized =
          await _recommendations.buildPersonalizedSuggestions();

      final interests = await _localHistory.getInterests();
      final discovery = await _recommendations.fetchUniqueDiscoveryBatch(
        excludeIds: {
          ...exclude,
          ...personalized.map((t) => t.id),
        },
        targetCount: 14,
        maxAttempts: 16,
        seedTags: interests,
      );

      var merged = _recommendations.dedupeTalks([
        ...personalized.where((t) => !currentlyVisible.contains(t.id)),
        ...discovery,
      ]);

      // If exclusion was too aggressive, prune history of shown IDs and retry.
      if (merged.length < 6) {
        final pruned = await _localHistory.pruneShownTalkIds(keepLatest: 60);
        _shownIds
          ..clear()
          ..addAll(pruned)
          ..addAll(currentlyVisible);
        final retry = await _recommendations.fetchUniqueDiscoveryBatch(
          excludeIds: {
            ...currentlyVisible,
            ...history.map((e) => e.id),
          },
          targetCount: 14,
          maxAttempts: 16,
        );
        merged = _recommendations.dedupeTalks([...merged, ...retry]);
      }

      if (merged.isEmpty) {
        // Last resort: reshuffle feed but still try to avoid identical order.
        final feed = await _apiService.getFeed();
        merged = _recommendations.dedupeTalks(
          [...feed]..shuffle(),
          excludeIds: currentlyVisible,
        );
        if (merged.isEmpty) {
          merged = _recommendations.dedupeTalks(feed);
        }
      }

      _talks = merged;
      _personalizedCount =
          merged.where((t) => personalized.any((p) => p.id == t.id)).length;
      _registerShown(_talks);
      await _localHistory.markTalksShown(_talks.map((t) => t.id));
      await _localHistory.saveCachedSuggestions(_talks.take(12).toList());
      _hasError = false;
      _errorMessage = '';
      _hasMore = true;
    } catch (error) {
      _hasError = true;
      _errorMessage = _readableError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      var batch = await _recommendations.fetchUniqueDiscoveryBatch(
        excludeIds: _shownIds,
        targetCount: 10,
        maxAttempts: 16,
      );

      if (batch.isEmpty) {
        final pruned = await _localHistory.pruneShownTalkIds(keepLatest: 80);
        _shownIds
          ..clear()
          ..addAll(pruned)
          ..addAll(_talks.map((t) => t.id));
        batch = await _recommendations.fetchUniqueDiscoveryBatch(
          excludeIds: _shownIds,
          targetCount: 10,
          maxAttempts: 16,
        );
      }

      if (batch.isEmpty) {
        _hasMore = false;
      } else {
        _talks = [..._talks, ...batch];
        _registerShown(batch);
        await _localHistory.markTalksShown(batch.map((t) => t.id));
        _hasMore = true;
      }
    } catch (error) {
      if (_talks.isEmpty) {
        _hasError = true;
        _errorMessage = _readableError(error);
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _registerShown(Iterable<Talk> talks) {
    for (final talk in talks) {
      if (talk.id.isNotEmpty) {
        _shownIds.add(talk.id);
      }
    }
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Failed to load the home feed.' : message;
  }
}

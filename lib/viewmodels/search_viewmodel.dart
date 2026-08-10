import 'package:flutter/foundation.dart';

import '../models/talk.dart';
import '../services/api_service.dart';
import '../services/local_history_service.dart';
import '../services/recommendation_service.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    ApiService? apiService,
    LocalHistoryService? localHistory,
    RecommendationService? recommendations,
    Set<String> Function()? homeShownIdsProvider,
  })  : _apiService = apiService ?? ApiService(),
        _recommendations = recommendations ??
            RecommendationService(
              apiService: apiService ?? ApiService(),
              localHistory: localHistory ?? LocalHistoryService(),
            ),
        _homeShownIdsProvider = homeShownIdsProvider;

  final ApiService _apiService;
  final RecommendationService _recommendations;
  final Set<String> Function()? _homeShownIdsProvider;

  List<Talk> _results = [];
  final Set<String> _resultIds = {};
  String _query = '';
  String? _selectedTag;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = true;
  String _errorMessage = '';

  List<Talk> get results => List.unmodifiable(_results);
  String get query => _query;
  String? get selectedTag => _selectedTag;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasError => _hasError;
  bool get hasMore => _hasMore;
  String get errorMessage => _errorMessage;
  bool get hasResults => _results.isNotEmpty;
  bool get hasActiveFilters =>
      _query.trim().isNotEmpty ||
      (_selectedTag != null && _selectedTag!.trim().isNotEmpty);

  void updateQuery(String value) {
    _query = value;
    notifyListeners();
  }

  Future<void> selectTag(String? tag, {bool allowToggleOff = true}) async {
    final normalized = tag?.trim();
    if (normalized == null || normalized.isEmpty) {
      _selectedTag = null;
    } else if (allowToggleOff &&
        _selectedTag?.toLowerCase() == normalized.toLowerCase()) {
      _selectedTag = null;
    } else {
      _selectedTag = normalized;
    }
    notifyListeners();
    await search();
  }

  Future<void> search() async {
    final trimmedQuery = _query.trim();
    final tag = _selectedTag?.trim();

    if (trimmedQuery.isEmpty && (tag == null || tag.isEmpty)) {
      _results = [];
      _resultIds.clear();
      _hasError = false;
      _errorMessage = '';
      _isLoading = false;
      _isLoadingMore = false;
      _hasMore = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    _hasMore = true;
    notifyListeners();

    try {
      final raw = await _apiService.searchTalks(
        trimmedQuery.isEmpty ? null : trimmedQuery,
        tag == null || tag.isEmpty ? null : tag,
      );

      // Only avoid IDs already on this search page / home right now.
      final exclude = <String>{
        ...?_homeShownIdsProvider?.call(),
      };

      var unique = _recommendations.dedupeTalks(raw, excludeIds: exclude);
      if (unique.isEmpty) {
        unique = _recommendations.dedupeTalks(raw);
      }

      _results = unique;
      _resultIds
        ..clear()
        ..addAll(unique.map((t) => t.id));

      _hasError = false;
      _errorMessage = '';
      _hasMore = unique.isNotEmpty;
    } catch (error) {
      _hasError = true;
      _errorMessage = _readableError(error);
      _results = [];
      _resultIds.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore || !hasActiveFilters) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final trimmedQuery = _query.trim();
      final tag = _selectedTag?.trim();
      final exclude = <String>{
        ..._resultIds,
        ...?_homeShownIdsProvider?.call(),
      };

      final seedTags = <String>[
        if (tag != null && tag.isNotEmpty) tag,
        ...trimmedQuery
            .split(RegExp(r'\s+'))
            .where((w) => w.length > 2)
            .take(3),
      ];

      // Related discovery around the same topic, skipping already-listed IDs.
      var batch = await _recommendations.fetchUniqueDiscoveryBatch(
        excludeIds: exclude,
        targetCount: 10,
        maxAttempts: 16,
        seedTags: seedTags,
      );

      // Re-query current filters and keep only unseen items.
      final fresh = await _apiService.searchTalks(
        trimmedQuery.isEmpty ? null : trimmedQuery,
        tag == null || tag.isEmpty ? null : tag,
      );
      final freshUnique =
          _recommendations.dedupeTalks(fresh, excludeIds: exclude);

      var merged = _recommendations.dedupeTalks(
        [...freshUnique, ...batch],
        excludeIds: exclude,
      );

      if (merged.isEmpty) {
        // Soften exclusions and try again so scrolling never dead-ends early.
        batch = await _recommendations.fetchUniqueDiscoveryBatch(
          excludeIds: _resultIds,
          targetCount: 10,
          maxAttempts: 16,
          seedTags: seedTags.isNotEmpty
              ? seedTags
              : RecommendationService.discoveryTags,
        );
        merged = _recommendations.dedupeTalks(batch, excludeIds: _resultIds);
      }

      if (merged.isEmpty) {
        _hasMore = false;
      } else {
        _results = [..._results, ...merged];
        _resultIds.addAll(merged.map((t) => t.id));
        _hasMore = true;
      }
    } catch (_) {
      // Soft-fail: keep current results.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _query = '';
    _selectedTag = null;
    _results = [];
    _resultIds.clear();
    _hasError = false;
    _errorMessage = '';
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = true;
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Failed to search talks.' : message;
  }
}

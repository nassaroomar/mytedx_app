import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/similar_talk.dart';
import '../models/talk_details.dart';
import '../services/api_service.dart';
import '../services/recommendation_service.dart';

class DetailsViewModel extends ChangeNotifier {
  DetailsViewModel({
    ApiService? apiService,
    RecommendationService? recommendations,
  })  : _apiService = apiService ?? ApiService(),
        _recommendations = recommendations ??
            RecommendationService(apiService: apiService ?? ApiService());

  final ApiService _apiService;
  final RecommendationService _recommendations;

  TalkDetails? _talkDetails;
  List<SimilarTalk> _upNext = [];
  bool _isLoading = false;
  bool _isLoadingUpNext = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _upNextRequestId = 0;

  TalkDetails? get talkDetails => _talkDetails;
  List<SimilarTalk> get upNext => List.unmodifiable(_upNext);
  bool get isLoading => _isLoading;
  bool get isLoadingUpNext => _isLoadingUpNext;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasData => _talkDetails != null;

  Future<void> fetchDetails(String id, {bool clearExisting = true}) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    if (clearExisting) {
      _talkDetails = null;
      _upNext = [];
    }
    notifyListeners();

    try {
      _talkDetails = await _apiService.getTalkDetails(id);
      _hasError = false;
      _errorMessage = '';
      _isLoading = false;
      notifyListeners();

      // Load Up Next in the background so video playback is not blocked.
      unawaited(_loadUpNextForCurrentTalk());
    } catch (error) {
      _hasError = true;
      _errorMessage = _readableError(error);
      if (clearExisting) {
        _talkDetails = null;
        _upNext = [];
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUpNextForCurrentTalk() async {
    final details = _talkDetails;
    if (details == null) {
      _upNext = [];
      _isLoadingUpNext = false;
      notifyListeners();
      return;
    }

    final requestId = ++_upNextRequestId;
    _isLoadingUpNext = true;
    notifyListeners();

    try {
      final similar = await _recommendations.findSimilarByTags(
        currentTalkId: details.id,
        tags: details.tagsList,
        limit: 8,
      );

      // Ignore stale responses if the user switched videos quickly.
      if (requestId != _upNextRequestId) return;

      _upNext = similar;
    } catch (_) {
      if (requestId != _upNextRequestId) return;
      _upNext = [];
    } finally {
      if (requestId == _upNextRequestId) {
        _isLoadingUpNext = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh(String id) => fetchDetails(id);

  void clear() {
    _talkDetails = null;
    _upNext = [];
    _isLoading = false;
    _isLoadingUpNext = false;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Failed to load talk details.' : message;
  }
}

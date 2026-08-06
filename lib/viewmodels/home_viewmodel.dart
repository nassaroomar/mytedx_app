import 'package:flutter/foundation.dart';

import '../models/talk.dart';
import '../services/api_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  List<Talk> _talks = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  List<Talk> get talks => List.unmodifiable(_talks);
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasData => _talks.isNotEmpty;

  Future<void> fetchFeed({bool showLoader = true}) async {
    if (showLoader) {
      _isLoading = true;
    }
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      _talks = await _apiService.getFeed();
      _hasError = false;
      _errorMessage = '';
    } catch (error) {
      _hasError = true;
      _errorMessage = _readableError(error);
      if (_talks.isEmpty) {
        _talks = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh keeps existing cards visible while reloading.
  Future<void> refresh() => fetchFeed(showLoader: false);

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Failed to load the home feed.' : message;
  }
}

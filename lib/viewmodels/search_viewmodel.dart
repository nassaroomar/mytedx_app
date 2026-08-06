import 'package:flutter/foundation.dart';

import '../models/talk.dart';
import '../services/api_service.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  List<Talk> _results = [];
  String _query = '';
  String? _selectedTag;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  List<Talk> get results => List.unmodifiable(_results);
  String get query => _query;
  String? get selectedTag => _selectedTag;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasResults => _results.isNotEmpty;
  bool get hasActiveFilters =>
      _query.trim().isNotEmpty ||
      (_selectedTag != null && _selectedTag!.trim().isNotEmpty);

  void updateQuery(String value) {
    _query = value;
    notifyListeners();
  }

  Future<void> selectTag(String? tag) async {
    final normalized = tag?.trim();
    if (normalized == null || normalized.isEmpty) {
      _selectedTag = null;
    } else if (_selectedTag?.toLowerCase() == normalized.toLowerCase()) {
      // Tap again to clear the selected tag.
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
      _hasError = false;
      _errorMessage = '';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      _results = await _apiService.searchTalks(
        trimmedQuery.isEmpty ? null : trimmedQuery,
        tag == null || tag.isEmpty ? null : tag,
      );
      _hasError = false;
      _errorMessage = '';
    } catch (error) {
      _hasError = true;
      _errorMessage = _readableError(error);
      _results = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _query = '';
    _selectedTag = null;
    _results = [];
    _hasError = false;
    _errorMessage = '';
    _isLoading = false;
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Failed to search talks.' : message;
  }
}

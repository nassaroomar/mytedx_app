import 'package:flutter/foundation.dart';

import '../models/talk_details.dart';
import '../services/api_service.dart';

class DetailsViewModel extends ChangeNotifier {
  DetailsViewModel({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  TalkDetails? _talkDetails;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  TalkDetails? get talkDetails => _talkDetails;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasData => _talkDetails != null;

  Future<void> fetchDetails(String id) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    _talkDetails = null;
    notifyListeners();

    try {
      _talkDetails = await _apiService.getTalkDetails(id);
      _hasError = false;
      _errorMessage = '';
    } catch (error) {
      _hasError = true;
      _errorMessage = _readableError(error);
      _talkDetails = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String id) => fetchDetails(id);

  void clear() {
    _talkDetails = null;
    _isLoading = false;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Failed to load talk details.' : message;
  }
}

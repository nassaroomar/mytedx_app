import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/talk.dart';
import '../models/talk_details.dart';

typedef AuthorizationTokenProvider = Future<String?> Function({
  bool useAccessToken,
});

class ApiService {
  ApiService({
    http.Client? client,
    AuthorizationTokenProvider? authorizationTokenProvider,
  })  : _client = client ?? http.Client(),
        _authorizationTokenProvider = authorizationTokenProvider;

  static const String baseUrl =
      'https://bhux9o0old.execute-api.eu-north-1.amazonaws.com';

  final http.Client _client;
  final AuthorizationTokenProvider? _authorizationTokenProvider;

  Future<List<Talk>> getFeed() async {
    // Live API exposes the feed at /feed (GET / returns 404).
    final uri = Uri.parse('$baseUrl/feed');
    final response = await _get(uri);
    return _parseTalkList(response.body, context: 'home feed');
  }

  Future<TalkDetails> getTalkDetails(String id) async {
    if (id.trim().isEmpty) {
      throw Exception('Talk id is required.');
    }

    final uri = Uri.parse('$baseUrl/details').replace(
      queryParameters: {'id': id},
    );
    final response = await _get(uri);

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected details response format.');
      }
      return TalkDetails.fromJson(decoded);
    } on FormatException {
      throw Exception('Failed to parse talk details.');
    }
  }

  Future<List<Talk>> searchTalks(String? query, String? tag) async {
    final params = <String, String>{};
    final trimmedQuery = query?.trim();
    final trimmedTag = tag?.trim();

    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      params['q'] = trimmedQuery;
    }
    if (trimmedTag != null && trimmedTag.isNotEmpty) {
      params['tag'] = trimmedTag;
    }

    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await _get(uri);
    return _parseTalkList(response.body, context: 'search results');
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      var response = await _sendGet(uri, useAccessToken: false);

      // Some gateways expect the access token instead of the ID token.
      if (response.statusCode == 401 && _authorizationTokenProvider != null) {
        response = await _sendGet(uri, useAccessToken: true);
      }

      if (response.statusCode == 200) {
        return response;
      }

      throw Exception(
        'Request failed (${response.statusCode}): ${_statusMessage(response.statusCode)}',
      );
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on http.ClientException catch (error) {
      throw Exception('Network error: ${error.message}');
    } on FormatException {
      throw Exception('Invalid response from server.');
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('Unexpected error: $error');
    }
  }

  Future<http.Response> _sendGet(
    Uri uri, {
    required bool useAccessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    final token = await _authorizationTokenProvider?.call(
      useAccessToken: useAccessToken,
    );
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return _client.get(uri, headers: headers).timeout(
          const Duration(seconds: 20),
        );
  }

  List<Talk> _parseTalkList(String body, {required String context}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw Exception('Unexpected $context format.');
      }

      return decoded
          .whereType<Map>()
          .map((item) => Talk.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on FormatException {
      throw Exception('Failed to parse $context.');
    }
  }

  String _statusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request.';
      case 401:
        return 'Unauthorized. Please sign in again.';
      case 403:
        return 'Access denied.';
      case 404:
        return 'Resource not found.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'Unable to complete the request.';
    }
  }

  void dispose() {
    _client.close();
  }
}

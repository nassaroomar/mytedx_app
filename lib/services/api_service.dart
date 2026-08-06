import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/talk.dart';
import '../models/talk_details.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl =
      'https://bhux9o0old.execute-api.eu-north-1.amazonaws.com';

  final http.Client _client;

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
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 20),
          );

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

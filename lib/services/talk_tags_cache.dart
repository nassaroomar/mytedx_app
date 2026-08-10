import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Caches per-talk tags from `/details` so list cards can show them
/// without refetching on every rebuild.
class TalkTagsCache extends ChangeNotifier {
  TalkTagsCache({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;
  final Map<String, List<String>> _tagsById = {};
  final Set<String> _inFlight = {};

  List<String>? tagsFor(String talkId) {
    final id = talkId.trim();
    if (id.isEmpty) return null;
    return _tagsById[id];
  }

  bool isLoading(String talkId) => _inFlight.contains(talkId.trim());

  void seed(String talkId, List<String> tags) {
    final id = talkId.trim();
    if (id.isEmpty) return;
    _tagsById[id] = _normalize(tags);
    notifyListeners();
  }

  Future<void> ensureLoaded(String talkId) async {
    final id = talkId.trim();
    if (id.isEmpty) return;
    if (_tagsById.containsKey(id) || _inFlight.contains(id)) return;

    _inFlight.add(id);
    notifyListeners();

    try {
      final details = await _api.getTalkDetails(id);
      _tagsById[id] = _normalize(details.tagsList);
    } catch (_) {
      _tagsById[id] = const [];
    } finally {
      _inFlight.remove(id);
      notifyListeners();
    }
  }

  List<String> _normalize(List<String> tags) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in tags) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      final key = tag.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(tag);
    }
    return out;
  }
}

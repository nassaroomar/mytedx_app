import 'package:flutter/foundation.dart';

import '../models/talk.dart';
import '../services/local_history_service.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({LocalHistoryService? localHistory})
      : _local = localHistory ?? LocalHistoryService();

  final LocalHistoryService _local;

  List<WatchedTalkEntry> _history = [];
  List<Talk> _watchLater = [];
  bool _loading = false;
  final Set<String> _watchLaterIds = {};

  List<WatchedTalkEntry> get history => List.unmodifiable(_history);
  List<Talk> get watchLater => List.unmodifiable(_watchLater);
  bool get isLoading => _loading;

  bool isSaved(String talkId) => _watchLaterIds.contains(talkId);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _history = await _local.getWatchHistory();
      _watchLater = await _local.getWatchLater();
      _watchLaterIds
        ..clear()
        ..addAll(_watchLater.map((t) => t.id));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> addToWatchLater(Talk talk) async {
    await _local.addToWatchLater(talk);
    await load();
  }

  Future<void> removeFromWatchLater(String id) async {
    await _local.removeFromWatchLater(id);
    await load();
  }

  Future<void> toggleWatchLater(Talk talk) async {
    if (isSaved(talk.id)) {
      await removeFromWatchLater(talk.id);
    } else {
      await addToWatchLater(talk);
    }
  }
}

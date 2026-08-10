import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:miniplayer/miniplayer.dart';

import '../models/talk_details.dart';
import '../services/local_history_service.dart';

/// Global video + mini-player state shared across Home, Search, and Details.
/// Playback is handled by an embedded TED WebView (not video_player).
class VideoPlayerProvider extends ChangeNotifier {
  VideoPlayerProvider({LocalHistoryService? localHistory})
      : _localHistory = localHistory ?? LocalHistoryService();

  final LocalHistoryService _localHistory;

  static const double miniPlayerMinHeight = 64;

  final MiniplayerController miniplayerController = MiniplayerController();
  final ValueNotifier<double> playerExpandProgress =
      ValueNotifier<double>(miniPlayerMinHeight);

  String? _talkId;
  String? _videoUrl;
  String? _embedUrl;
  String? _slug;
  String _title = '';
  String _presenter = '';
  String _imageUrl = '';

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFullscreen = false;
  bool _isVisible = false;

  int _selectedTabIndex = 0;
  String? _pendingSearchTag;
  double? _resumePositionSeconds;

  /// Bumps whenever the embed URL changes so the WebView reloads.
  int _embedGeneration = 0;

  String? get talkId => _talkId;
  String? get videoUrl => _videoUrl;
  String? get embedUrl => _embedUrl;
  String? get slug => _slug;
  String get title => _title;
  String get presenter => _presenter;
  String get imageUrl => _imageUrl;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get isFullscreen => _isFullscreen;
  bool get isVisible => _isVisible;
  bool get hasActiveVideo => _isVisible;
  bool get isPlaying => false;
  int get selectedTabIndex => _selectedTabIndex;
  String? get pendingSearchTag => _pendingSearchTag;
  int get embedGeneration => _embedGeneration;
  double? get resumePositionSeconds => _resumePositionSeconds;

  /// Converts a TED talk page URL into an embeddable player URL.
  /// Example: www.ted.com/talks/x → embed.ted.com/talks/x?autoplay=true
  static String? toEmbedUrl(String? rawUrl, {String? slug}) {
    String? base;

    final cleanSlug = slug?.trim() ?? '';
    if (cleanSlug.isNotEmpty) {
      base = 'https://embed.ted.com/talks/$cleanSlug';
    } else {
      final url = rawUrl?.trim() ?? '';
      if (url.isEmpty) return null;

      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        return null;
      }

      if (!uri.host.toLowerCase().contains('ted.com')) {
        return null;
      }

      final talksIndex = uri.pathSegments.indexOf('talks');
      if (talksIndex >= 0 && talksIndex + 1 < uri.pathSegments.length) {
        final pathSlug = uri.pathSegments[talksIndex + 1];
        if (pathSlug.isNotEmpty) {
          base = 'https://embed.ted.com/talks/$pathSlug';
        }
      }

      base ??= url
          .replaceFirst('www.ted.com', 'embed.ted.com')
          .replaceFirst('://ted.com', '://embed.ted.com')
          .split('?')
          .first;
    }

    final embedUri = Uri.parse(base);
    return embedUri.replace(queryParameters: {
      ...embedUri.queryParameters,
      'autoplay': 'true',
      // Prefer audible playback when the WebView allows it.
      'muted': 'false',
      'controls': '1',
    }).toString();
  }

  Future<void> playTalk(
    TalkDetails details, {
    bool expand = true,
    double? resumePositionSeconds,
  }) async {
    await play(
      talkId: details.id,
      videoUrl: details.videoUrl,
      slug: details.slug,
      title: details.title,
      presenter: details.presenterDisplayName,
      imageUrl: details.imageUrl,
      expand: expand,
      resumePositionSeconds: resumePositionSeconds,
    );
  }

  /// Opens the mini-player UI while details are still loading.
  Future<void> prepareTalkShell({
    required String talkId,
    required String title,
    required String presenter,
    String imageUrl = '',
    bool expand = true,
    double? resumePositionSeconds,
  }) async {
    _talkId = talkId;
    _videoUrl = null;
    _embedUrl = null;
    _slug = null;
    _title = title;
    _presenter = presenter;
    _imageUrl = imageUrl;
    _resumePositionSeconds = resumePositionSeconds;
    _isVisible = true;
    _isInitialized = false;
    _isInitializing = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    if (expand) {
      expandPlayer();
    } else {
      minimizePlayer();
    }
  }

  Future<void> play({
    required String talkId,
    String? videoUrl,
    String? slug,
    required String title,
    required String presenter,
    String imageUrl = '',
    bool expand = true,
    double? resumePositionSeconds,
  }) async {
    final embed = toEmbedUrl(videoUrl, slug: slug);

    if (embed == null || embed.isEmpty) {
      _talkId = talkId;
      _title = title;
      _presenter = presenter;
      _imageUrl = imageUrl;
      _videoUrl = videoUrl;
      _slug = slug;
      _embedUrl = null;
      _resumePositionSeconds = null;
      _isVisible = true;
      _isInitializing = false;
      _isInitialized = false;
      _hasError = true;
      _errorMessage = 'No TED embed URL was found for this talk.';
      notifyListeners();
      if (expand) expandPlayer();
      return;
    }

    final sameEmbed = _talkId == talkId && _embedUrl == embed && _isInitialized;
    if (sameEmbed) {
      _isVisible = true;
      _title = title;
      _presenter = presenter;
      _imageUrl = imageUrl;
      if (resumePositionSeconds != null && resumePositionSeconds >= 2) {
        _resumePositionSeconds = resumePositionSeconds;
        // Force listeners (WebView) to re-apply seek on the existing player.
        _embedGeneration++;
      }
      notifyListeners();
      if (expand) expandPlayer();
      return;
    }

    _talkId = talkId;
    _videoUrl = videoUrl;
    _slug = slug;
    _embedUrl = embed;
    _title = title;
    _presenter = presenter;
    _imageUrl = imageUrl;
    _resumePositionSeconds = resumePositionSeconds;
    _isVisible = true;
    _isInitialized = true;
    _isInitializing = false;
    _hasError = false;
    _errorMessage = '';
    _embedGeneration++;
    notifyListeners();

    if (expand) {
      expandPlayer();
    } else {
      minimizePlayer();
    }

    await _localHistory.recordWatch(
      id: talkId,
      title: title,
      presenterDisplayName: presenter,
      imageUrl: imageUrl,
      positionSeconds: resumePositionSeconds,
    );
  }

  void clearResumePosition() {
    if (_resumePositionSeconds == null) return;
    _resumePositionSeconds = null;
    notifyListeners();
  }

  Future<void> savePlaybackProgress({
    required double positionSeconds,
    required double durationSeconds,
  }) async {
    final id = _talkId;
    if (id == null || id.isEmpty) return;
    if (positionSeconds < 3) return;
    await _localHistory.updateWatchProgress(
      id: id,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
    );
  }

  void markEmbedLoaded() {
    _isInitializing = false;
    _isInitialized = true;
    _hasError = false;
    notifyListeners();
  }

  void markEmbedError(String message) {
    _isInitializing = false;
    _isInitialized = false;
    _hasError = true;
    _errorMessage = message;
    notifyListeners();
  }

  void expandPlayer() {
    miniplayerController.animateToHeight(state: PanelState.MAX);
  }

  void minimizePlayer() {
    if (_isFullscreen) {
      exitFullscreen();
    }
    // Progress is flushed by the WebView progress bridge; still bump history.
    miniplayerController.animateToHeight(state: PanelState.MIN);
  }

  Future<void> dismissPlayer() async {
    _talkId = null;
    _videoUrl = null;
    _embedUrl = null;
    _slug = null;
    _title = '';
    _presenter = '';
    _imageUrl = '';
    _resumePositionSeconds = null;
    _isVisible = false;
    _isInitialized = false;
    _isInitializing = false;
    _hasError = false;
    _errorMessage = '';
    if (_isFullscreen) {
      await exitFullscreen();
    }
    playerExpandProgress.value = miniPlayerMinHeight;
    notifyListeners();
  }

  Future<void> enterFullscreen() async {
    expandPlayer();
    _isFullscreen = true;
    notifyListeners();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> exitFullscreen() async {
    _isFullscreen = false;
    notifyListeners();
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Re-allow all orientations after settling in portrait.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> toggleFullscreen() async {
    if (_isFullscreen) {
      await exitFullscreen();
    } else {
      await enterFullscreen();
    }
  }

  void setSelectedTabIndex(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    notifyListeners();
  }

  /// True when the expanded player is mostly open (not mini-bar).
  bool get isExpanded {
    if (!_isVisible) return false;
    if (_isFullscreen) return true;
    // Approximate: treat anything above ~15% expand as expanded.
    // Exact screen height is known only in the UI layer.
    return playerExpandProgress.value > miniPlayerMinHeight + 80;
  }

  void openSearchWithTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) return;

    _pendingSearchTag = normalized;
    _selectedTabIndex = 1;
    minimizePlayer();
    notifyListeners();
  }

  void clearPendingSearchTag() {
    if (_pendingSearchTag == null) return;
    _pendingSearchTag = null;
    notifyListeners();
  }

  @override
  void dispose() {
    playerExpandProgress.dispose();
    miniplayerController.dispose();
    super.dispose();
  }
}

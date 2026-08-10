import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../theme/app_theme.dart';
import '../viewmodels/video_player_provider.dart';
import 'talk_cover_image.dart';

/// Persistent TED embed WebView.
///
/// Center stays clear so TED's own play button works. Only edge strips handle
/// drag / ±10s seek. Bottom chrome is open for CC / settings / scrubber.
class CustomVideoPlayer extends StatefulWidget {
  const CustomVideoPlayer({
    super.key,
    this.compact = false,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
  });

  final bool compact;
  final ValueChanged<double>? onVerticalDragUpdate;
  final ValueChanged<double>? onVerticalDragEnd;

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  static const double _tedChromeHeight = 72;
  static const double _topDragHeight = 44;
  static const double _sideSeekWidth = 72;

  WebViewController? _controller;
  String? _loadedEmbedUrl;
  bool _pageLoading = false;
  bool _webViewFailed = false;
  String? _statusMessage;
  Timer? _loadingTimeout;
  Timer? _pollTimer;
  Timer? _seekHintTimer;
  Timer? _progressSaveTimer;

  double _position = 0;
  double _duration = 0;
  String? _seekHint;
  bool _didSeekResume = false;
  double? _pendingResumeSeconds;
  int _lastHandledEmbedGeneration = -1;
  int _progressTick = 0;

  bool get _supportsWebView {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _pollTimer?.cancel();
    _seekHintTimer?.cancel();
    _progressSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureLoaded(String embedUrl) async {
    if (_loadedEmbedUrl == embedUrl && (_controller != null || _webViewFailed)) {
      return;
    }
    await _loadEmbed(embedUrl);
  }

  Future<void> _loadEmbed(String embedUrl) async {
    if (!_supportsWebView) {
      setState(() {
        _loadedEmbedUrl = embedUrl;
        _pageLoading = false;
        _webViewFailed = true;
        _statusMessage =
            'In-app player needs an Android/iOS device. Use Watch on TED.';
      });
      return;
    }

    _loadingTimeout?.cancel();
    _pollTimer?.cancel();
    final resumeNow =
        context.read<VideoPlayerProvider>().resumePositionSeconds;
    setState(() {
      _pageLoading = true;
      _webViewFailed = false;
      _statusMessage = 'Loading TED player…';
      _loadedEmbedUrl = embedUrl;
      _position = 0;
      _duration = 0;
      _seekHint = null;
      _didSeekResume = false;
      _pendingResumeSeconds =
          (resumeNow != null && resumeNow >= 2) ? resumeNow : null;
    });

    try {
      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      final controller = WebViewController.fromPlatformCreationParams(params);
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      await controller.addJavaScriptChannel(
        'TedProgress',
        onMessageReceived: (message) {
          _onProgressMessage(message.message);
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.navigate,
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _pageLoading = true);
          },
          onPageFinished: (_) async {
            _loadingTimeout?.cancel();
            await _injectProgressBridge(controller);
            final shouldResume = _pendingResumeTarget() != null;
            await _tryAutoplayUnmute(controller, keepAliveForResume: shouldResume);
            await _applyResumeIfNeeded(controller);
            if (!mounted) return;
            setState(() {
              _pageLoading = false;
              _statusMessage = null;
            });
            context.read<VideoPlayerProvider>().markEmbedLoaded();
            _startPolling();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) return;
            _loadingTimeout?.cancel();
            if (!mounted) return;
            setState(() {
              _pageLoading = false;
              _webViewFailed = true;
              _statusMessage = error.description;
            });
          },
        ),
      );

      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        platform.setMediaPlaybackRequiresUserGesture(false);
      }

      await controller.loadRequest(Uri.parse(embedUrl));

      if (!mounted) return;
      setState(() => _controller = controller);

      _loadingTimeout = Timer(const Duration(seconds: 5), () {
        if (!mounted || !_pageLoading) return;
        setState(() {
          _pageLoading = false;
          _statusMessage = null;
        });
        context.read<VideoPlayerProvider>().markEmbedLoaded();
        _startPolling();
        unawaited(_applyResumeIfNeeded(controller));
      });
    } catch (error, stack) {
      debugPrint('Failed to create WebView: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _pageLoading = false;
        _webViewFailed = true;
        _statusMessage = 'Could not start the in-app player.';
      });
    }
  }

  Future<void> _tryAutoplayUnmute(
    WebViewController controller, {
    bool keepAliveForResume = false,
  }) async {
    try {
      // When resuming, avoid late play-clicks that reset currentTime to 0.
      final lateClicks = keepAliveForResume
          ? ''
          : '''
          setTimeout(function(){ clickPlay(); unmuteAll(); }, 600);
          setTimeout(function(){ clickPlay(); unmuteAll(); }, 1600);
        ''';
      await controller.runJavaScript('''
        (function() {
          function unmuteAll() {
            var videos = document.querySelectorAll('video');
            for (var i = 0; i < videos.length; i++) {
              try {
                videos[i].muted = false;
                videos[i].defaultMuted = false;
                videos[i].volume = 1;
                videos[i].removeAttribute('muted');
              } catch (e) {}
            }
          }
          function clickPlay() {
            unmuteAll();
            var selectors = [
              'button[aria-label*="Play"]',
              'button[aria-label*="play"]',
              'button[title*="Play"]',
              '.play-button',
              'button.player__play-button',
              '[data-testid="play-button"]'
            ];
            for (var i = 0; i < selectors.length; i++) {
              var btn = document.querySelector(selectors[i]);
              if (btn) { btn.click(); unmuteAll(); return true; }
            }
            var video = document.querySelector('video');
            if (video) {
              video.muted = false;
              video.volume = 1;
              video.play().catch(function(){});
              return true;
            }
            return false;
          }
          clickPlay();
          $lateClicks
        })();
      ''');
    } catch (_) {}
  }

  double? _pendingResumeTarget() {
    if (!mounted) return _pendingResumeSeconds;
    final fromProvider =
        context.read<VideoPlayerProvider>().resumePositionSeconds;
    final target = fromProvider ?? _pendingResumeSeconds;
    if (target == null || target < 2) return null;
    return target;
  }

  Future<void> _injectProgressBridge(WebViewController controller) async {
    try {
      await controller.runJavaScript('''
        (function() {
          if (window.__tedProgressBridge) return;
          window.__tedProgressBridge = true;
          function findVideo() {
            var list = document.querySelectorAll('video');
            if (list && list.length) return list[list.length - 1];
            return null;
          }
          setInterval(function() {
            try {
              var v = findVideo();
              if (!v || typeof TedProgress === 'undefined') return;
              TedProgress.postMessage(JSON.stringify({
                ok: true,
                t: v.currentTime || 0,
                d: v.duration || 0,
                muted: !!v.muted,
                paused: !!v.paused
              }));
            } catch (e) {}
          }, 1000);
        })();
      ''');
    } catch (_) {}
  }

  void _onProgressMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      if (map['ok'] != true) return;
      final t = (map['t'] as num?)?.toDouble() ?? 0;
      final d = (map['d'] as num?)?.toDouble() ?? 0;
      if (!mounted) return;
      _position = t;
      if (d.isFinite && d > 0) _duration = d;
      if (map['muted'] == true) {
        unawaited(_unmute());
      }
      _progressTick++;
      if (_progressTick % 5 == 0 && _position > 3 && _duration > 0) {
        unawaited(
          context.read<VideoPlayerProvider>().savePlaybackProgress(
                positionSeconds: _position,
                durationSeconds: _duration,
              ),
        );
      }
    } catch (_) {}
  }

  Future<void> _applyResumeIfNeeded(WebViewController controller) async {
    if (!mounted) return;
    final target = _pendingResumeTarget();
    if (target == null) return;
    if (_didSeekResume) return;
    _didSeekResume = true;
    _pendingResumeSeconds = target;

    try {
      await controller.runJavaScript('''
        (function() {
          var target = $target;
          function findVideo() {
            var list = document.querySelectorAll('video');
            if (list && list.length) return list[list.length - 1];
            return null;
          }
          function seekOnce() {
            var v = findVideo();
            if (!v) return false;
            if (!v.duration || !isFinite(v.duration) || v.duration < 1) return false;
            try {
              v.currentTime = Math.min(target, Math.max(0, v.duration - 1));
              v.muted = false;
              v.volume = 1;
              v.play().catch(function(){});
              return Math.abs((v.currentTime || 0) - target) < 15 || v.currentTime > target * 0.5;
            } catch (e) { return false; }
          }
          function attempt(remaining) {
            if (seekOnce()) return;
            if (remaining <= 0) return;
            setTimeout(function(){ attempt(remaining - 1); }, 700);
          }
          attempt(8);
        })();
      ''');

      // Keep resume until playback has actually advanced near the target.
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (!mounted) return;
        final video = context.read<VideoPlayerProvider>();
        if ((_position - target).abs() < 20 || _position >= target - 5) {
          video.clearResumePosition();
          _pendingResumeSeconds = null;
        } else {
          // Allow another seek pass if the first one missed.
          _didSeekResume = false;
          unawaited(_applyResumeIfNeeded(controller));
        }
      });
    } catch (_) {
      _didSeekResume = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollPlaybackState();
    });
  }

  Future<void> _pollPlaybackState() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      final raw = await controller.runJavaScriptReturningResult('''
        (function() {
          var v = document.querySelector('video');
          if (!v) return '{"ok":false}';
          return JSON.stringify({
            ok: true,
            muted: !!v.muted,
            t: v.currentTime || 0,
            d: v.duration || 0
          });
        })();
      ''');
      final text = raw is String ? raw : '$raw';
      var cleaned = text.trim();
      if (cleaned.length >= 2 &&
          cleaned.startsWith('"') &&
          cleaned.endsWith('"')) {
        cleaned = cleaned
            .substring(1, cleaned.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      }
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      if (map['ok'] != true) return;
      if (!mounted) return;

      _position = (map['t'] as num?)?.toDouble() ?? _position;
      final d = (map['d'] as num?)?.toDouble() ?? 0;
      if (d.isFinite && d > 0) _duration = d;

      if (map['muted'] == true) {
        unawaited(_unmute());
      }

      // Persist progress about every 5 seconds of polling.
      _progressTick++;
      if (_progressTick % 10 == 0 && _position > 3) {
        unawaited(
          context.read<VideoPlayerProvider>().savePlaybackProgress(
                positionSeconds: _position,
                durationSeconds: _duration,
              ),
        );
      }
    } catch (_) {}
  }

  Future<void> _unmute() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript('''
        (function() {
          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            videos[i].muted = false;
            videos[i].defaultMuted = false;
            videos[i].volume = 1;
            videos[i].removeAttribute('muted');
          }
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _seekBy(double deltaSeconds) async {
    final controller = _controller;
    if (controller == null) return;
    final next = (_position + deltaSeconds).clamp(
      0.0,
      _duration > 0 ? _duration : double.infinity,
    );
    try {
      await controller.runJavaScript(
        "var v=document.querySelector('video'); if(v) v.currentTime=$next;",
      );
      setState(() {
        _position = next.toDouble();
        _seekHint = deltaSeconds < 0 ? '-10s' : '+10s';
      });
      _seekHintTimer?.cancel();
      _seekHintTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() => _seekHint = null);
      });
    } catch (_) {}
  }

  Future<void> _openExternally(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = context.select((VideoPlayerProvider v) => v.embedUrl);
    final imageUrl = context.select((VideoPlayerProvider v) => v.imageUrl);
    final title = context.select((VideoPlayerProvider v) => v.title);
    final isInitializing =
        context.select((VideoPlayerProvider v) => v.isInitializing);
    final hasError = context.select((VideoPlayerProvider v) => v.hasError);
    final errorMessage =
        context.select((VideoPlayerProvider v) => v.errorMessage);
    final pageUrl = context.select((VideoPlayerProvider v) => v.videoUrl);
    final resumeAt =
        context.select((VideoPlayerProvider v) => v.resumePositionSeconds);
    final embedGeneration =
        context.select((VideoPlayerProvider v) => v.embedGeneration);

    if (resumeAt != null && resumeAt >= 2) {
      _pendingResumeSeconds = resumeAt;
    }

    if (embedUrl != null &&
        embedUrl.isNotEmpty &&
        embedUrl != _loadedEmbedUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureLoaded(embedUrl);
      });
    } else if (_controller != null &&
        resumeAt != null &&
        resumeAt >= 2 &&
        (!_didSeekResume || embedGeneration != _lastHandledEmbedGeneration)) {
      // Same talk reopened from History — seek without full reload.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null) return;
        if (embedGeneration != _lastHandledEmbedGeneration) {
          _lastHandledEmbedGeneration = embedGeneration;
          _didSeekResume = false;
        }
        unawaited(_applyResumeIfNeeded(_controller!));
      });
    }

    final showFallback = _webViewFailed ||
        (!_supportsWebView && embedUrl != null) ||
        (embedUrl == null && hasError);

    return RepaintBoundary(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              TalkCoverImage(
                imageUrl: imageUrl,
                borderRadius: BorderRadius.zero,
              ),
            if (_controller != null && !_webViewFailed)
              WebViewWidget(controller: _controller!),
            if ((isInitializing && embedUrl == null) || _pageLoading)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.tedRed),
                ),
              ),
            if (showFallback)
              _FallbackPanel(
                title: title,
                message: (_statusMessage != null && _statusMessage!.isNotEmpty)
                    ? _statusMessage!
                    : (errorMessage.isNotEmpty
                        ? errorMessage
                        : 'Open the talk in your browser to watch it.'),
                onOpen: () => _openExternally(embedUrl ?? pageUrl),
              )
            else if (_controller != null) ...[
              // Top strip: swipe to minimize / expand (TED play stays free).
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _topDragHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: widget.onVerticalDragUpdate == null
                      ? null
                      : (d) => widget.onVerticalDragUpdate!(d.delta.dy),
                  onVerticalDragEnd: widget.onVerticalDragEnd == null
                      ? null
                      : (d) =>
                          widget.onVerticalDragEnd!(d.primaryVelocity ?? 0),
                ),
              ),
              // Side seek zones — center open for TED play button.
              Positioned(
                top: _topDragHeight,
                left: 0,
                bottom: _tedChromeHeight,
                width: _sideSeekWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => unawaited(_seekBy(-10)),
                  onVerticalDragUpdate: widget.onVerticalDragUpdate == null
                      ? null
                      : (d) => widget.onVerticalDragUpdate!(d.delta.dy),
                  onVerticalDragEnd: widget.onVerticalDragEnd == null
                      ? null
                      : (d) =>
                          widget.onVerticalDragEnd!(d.primaryVelocity ?? 0),
                ),
              ),
              Positioned(
                top: _topDragHeight,
                right: 0,
                bottom: _tedChromeHeight,
                width: _sideSeekWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => unawaited(_seekBy(10)),
                  onVerticalDragUpdate: widget.onVerticalDragUpdate == null
                      ? null
                      : (d) => widget.onVerticalDragUpdate!(d.delta.dy),
                  onVerticalDragEnd: widget.onVerticalDragEnd == null
                      ? null
                      : (d) =>
                          widget.onVerticalDragEnd!(d.primaryVelocity ?? 0),
                ),
              ),
              if (_seekHint != null)
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        _seekHint!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackPanel extends StatelessWidget {
  const _FallbackPanel({
    required this.title,
    required this.message,
    required this.onOpen,
  });

  final String title;
  final String message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: AppTheme.tedRed,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                title.isEmpty ? 'TED Talk' : title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.tedRed,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Watch on TED'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

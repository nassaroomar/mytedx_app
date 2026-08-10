import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/library_viewmodel.dart';
import '../viewmodels/video_player_provider.dart';
import '../widgets/custom_video_player.dart';
import '../widgets/expanded_player_view.dart';
import '../widgets/interests_dialog.dart';
import '../widgets/mini_player_bar.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey _playerKey = GlobalKey(debugLabel: 'ted-webview-player');

  final List<Widget> _pages = const [
    HomeScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  bool _didRefreshHomeOnBack = false;
  bool _draggingPlayer = false;
  Timer? _snapTimer;

  static const double _handleBodyHeight = 36;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(InterestsDialog.showIfNeeded(context));
      context.read<LibraryViewModel>().load();
      context
          .read<VideoPlayerProvider>()
          .playerExpandProgress
          .addListener(_onExpandProgressChanged);
    });
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    try {
      context
          .read<VideoPlayerProvider>()
          .playerExpandProgress
          .removeListener(_onExpandProgressChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onExpandProgressChanged() {
    if (!mounted || _draggingPlayer) return;
    final video = context.read<VideoPlayerProvider>();
    if (!video.hasActiveVideo || video.isFullscreen) return;
    _scheduleSnap(video);
  }

  double _videoSlotHeight(BuildContext context, bool fullscreen) {
    final size = MediaQuery.sizeOf(context);
    if (fullscreen) return size.height;
    return (size.height * 0.28).clamp(180.0, 280.0);
  }

  double _handleHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + _handleBodyHeight;
  }

  void _snapPlayer(VideoPlayerProvider video) {
    final maxH = MediaQuery.sizeOf(context).height;
    final minH = VideoPlayerProvider.miniPlayerMinHeight;
    final current = video.playerExpandProgress.value;
    final pct = ((current - minH) / (maxH - minH)).clamp(0.0, 1.0);

    // Only two resting states: fully expanded or mini.
    if (pct >= 0.55) {
      video.expandPlayer();
      _didRefreshHomeOnBack = false;
    } else {
      video.minimizePlayer();
    }
  }

  void _scheduleSnap(VideoPlayerProvider video) {
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || _draggingPlayer) return;
      final maxH = MediaQuery.sizeOf(context).height;
      final minH = VideoPlayerProvider.miniPlayerMinHeight;
      final pct = ((video.playerExpandProgress.value - minH) / (maxH - minH))
          .clamp(0.0, 1.0);
      // Ignore near min/max (and mid-animation endpoints).
      if (pct <= 0.12 || pct >= 0.88) return;
      _snapPlayer(video);
    });
  }

  void _onPlayerDragUpdate(VideoPlayerProvider video, double deltaDy) {
    _draggingPlayer = true;
    _snapTimer?.cancel();
    final maxH = MediaQuery.sizeOf(context).height;
    final minH = VideoPlayerProvider.miniPlayerMinHeight;
    final next = (video.playerExpandProgress.value - deltaDy).clamp(minH, maxH);
    video.playerExpandProgress.value = next;
  }

  void _onPlayerDragEnd(VideoPlayerProvider video, double velocityDy) {
    _draggingPlayer = false;
    if (velocityDy > 500) {
      video.minimizePlayer();
      return;
    }
    if (velocityDy < -500) {
      video.expandPlayer();
      _didRefreshHomeOnBack = false;
      return;
    }
    _snapPlayer(video);
  }

  Future<void> _refreshHome() async {
    final video = context.read<VideoPlayerProvider>();
    video.setSelectedTabIndex(0);
    await context.read<HomeViewModel>().scrollToTopAndRefresh();
  }

  void _onBottomNavTap(int index) {
    final video = context.read<VideoPlayerProvider>();
    if (index == 0 && video.selectedTabIndex == 0) {
      unawaited(_refreshHome());
      return;
    }
    if (index == 2) {
      unawaited(context.read<LibraryViewModel>().load());
    }
    video.setSelectedTabIndex(index);
  }

  Future<void> _handleSystemBack() async {
    final video = context.read<VideoPlayerProvider>();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final minH = VideoPlayerProvider.miniPlayerMinHeight;
    final percentage = video.hasActiveVideo
        ? ((video.playerExpandProgress.value - minH) / (screenHeight - minH))
            .clamp(0.0, 1.0)
        : 0.0;

    if (video.isFullscreen) {
      await video.exitFullscreen();
      return;
    }

    if (video.hasActiveVideo && percentage > 0.12) {
      video.minimizePlayer();
      return;
    }

    if (!_didRefreshHomeOnBack) {
      _didRefreshHomeOnBack = true;
      await _refreshHome();
      return;
    }

    SystemNavigator.pop();
  }

  Widget _buildPersistentPlayer(
    VideoPlayerProvider video, {
    required double screenHeight,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: video.playerExpandProgress,
      builder: (context, playerHeight, _) {
        final minH = VideoPlayerProvider.miniPlayerMinHeight;
        final percentage =
            ((playerHeight - minH) / (screenHeight - minH)).clamp(0.0, 1.0);

        final player = CustomVideoPlayer(
          key: _playerKey,
          onVerticalDragUpdate: (dy) => _onPlayerDragUpdate(video, dy),
          onVerticalDragEnd: (v) => _onPlayerDragEnd(video, v),
        );

        if (video.isFullscreen) {
          return Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(child: player),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _CircleIconButton(
                        icon: Icons.fullscreen_exit_rounded,
                        onTap: video.exitFullscreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (percentage < 0.08) {
          return Positioned(
            left: 0,
            right: 0,
            top: -2,
            height: 1,
            child: IgnorePointer(
              child: Opacity(opacity: 0, child: player),
            ),
          );
        }

        final playerTop = screenHeight - playerHeight;
        final handleH = _handleHeight(context);
        final videoH = _videoSlotHeight(context, false);

        return Positioned(
          top: playerTop + handleH,
          left: 0,
          right: 0,
          height: videoH,
          child: player,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Consumer<VideoPlayerProvider>(
      builder: (context, video, _) {
        if (video.hasActiveVideo && video.isExpanded) {
          _didRefreshHomeOnBack = false;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            unawaited(_handleSystemBack());
          },
          child: Scaffold(
            body: Stack(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: video.playerExpandProgress,
                  builder: (context, playerHeight, _) {
                    final minH = VideoPlayerProvider.miniPlayerMinHeight;
                    final percentage = video.hasActiveVideo
                        ? ((playerHeight - minH) / (screenHeight - minH))
                            .clamp(0.0, 1.0)
                        : 0.0;
                    final bottomInset = video.hasActiveVideo &&
                            percentage < 0.9 &&
                            !video.isFullscreen
                        ? minH
                        : 0.0;

                    return Padding(
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: IndexedStack(
                        index: video.selectedTabIndex.clamp(0, _pages.length - 1),
                        children: _pages,
                      ),
                    );
                  },
                ),

                if (video.hasActiveVideo)
                  Miniplayer(
                    key: ValueKey('miniplayer-${video.talkId}'),
                    minHeight: VideoPlayerProvider.miniPlayerMinHeight,
                    maxHeight: screenHeight,
                    controller: video.miniplayerController,
                    valueNotifier: video.playerExpandProgress,
                    backgroundColor: AppTheme.background,
                    elevation: 8,
                    onDismissed: video.dismissPlayer,
                    builder: (height, percentage) {
                      if (percentage < 0.08 && !video.isFullscreen) {
                        return MiniPlayerBar(
                          onVerticalDragUpdate: (dy) =>
                              _onPlayerDragUpdate(video, dy),
                          onVerticalDragEnd: (v) => _onPlayerDragEnd(video, v),
                        );
                      }

                      return ExpandedPlayerView(
                        height: height,
                        percentage: percentage,
                        videoSlotHeight: _videoSlotHeight(
                          context,
                          video.isFullscreen,
                        ),
                        videoSlot: const SizedBox.expand(),
                        onPlayerDragUpdate: (dy) =>
                            _onPlayerDragUpdate(video, dy),
                        onPlayerDragEnd: (v) => _onPlayerDragEnd(video, v),
                      );
                    },
                  ),

                if (video.hasActiveVideo && video.embedUrl != null)
                  _buildPersistentPlayer(video, screenHeight: screenHeight),
              ],
            ),
            bottomNavigationBar: ValueListenableBuilder<double>(
              valueListenable: video.playerExpandProgress,
              builder: (context, playerHeight, _) {
                final minH = VideoPlayerProvider.miniPlayerMinHeight;
                final percentage = video.hasActiveVideo
                    ? ((playerHeight - minH) / (screenHeight - minH))
                        .clamp(0.0, 1.0)
                    : 0.0;

                if (percentage > 0.85 || video.isFullscreen) {
                  return const SizedBox.shrink();
                }

                return Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF222222)),
                    ),
                  ),
                  child: BottomNavigationBar(
                    currentIndex:
                        video.selectedTabIndex.clamp(0, _pages.length - 1),
                    onTap: _onBottomNavTap,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.search_rounded),
                        activeIcon: Icon(Icons.manage_search_rounded),
                        label: 'Search',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline_rounded),
                        activeIcon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

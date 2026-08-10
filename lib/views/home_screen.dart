import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/tag_chip.dart';
import '../widgets/talk_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _handledScrollTick = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<HomeViewModel>();
      if (!viewModel.hasData && !viewModel.isLoading) {
        viewModel.fetchFeed();
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 480) {
      context.read<HomeViewModel>().loadMore();
    }
  }

  void _scrollToTopIfNeeded(HomeViewModel viewModel) {
    final tick = viewModel.scrollToTopTick;
    if (tick == _handledScrollTick) return;
    _handledScrollTick = tick;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<HomeViewModel>(
          builder: (context, viewModel, _) {
            _scrollToTopIfNeeded(viewModel);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: _HomeHeader(
                    onTitleTap: viewModel.scrollToTopAndRefresh,
                  ),
                ),
                if (viewModel.personalizedCount > 0)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      'Picked for you · based on your watch history',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(child: _buildBody(viewModel)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(HomeViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasData) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.tedRed),
      );
    }

    if (viewModel.hasError && !viewModel.hasData) {
      return StateMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Couldn’t load talks',
        message: viewModel.errorMessage,
        actionLabel: 'Try again',
        onAction: viewModel.fetchFeed,
      );
    }

    if (!viewModel.hasData) {
      return StateMessage(
        icon: Icons.movie_filter_outlined,
        title: 'No talks yet',
        message: 'Pull down to refresh and discover the latest TEDx talks.',
        actionLabel: 'Refresh',
        onAction: viewModel.fetchFeed,
      );
    }

    final itemCount =
        viewModel.talks.length + (viewModel.isLoadingMore || viewModel.hasMore ? 1 : 0);

    return RefreshIndicator(
      color: AppTheme.tedRed,
      backgroundColor: AppTheme.surfaceElevated,
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index >= viewModel.talks.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.tedRed,
                  ),
                ),
              ),
            );
          }

          final talk = viewModel.talks[index];
          final isSuggested =
              index < viewModel.personalizedCount && viewModel.personalizedCount > 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSuggested && index == 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 2),
                  child: Text(
                    'Suggested for you',
                    style: TextStyle(
                      color: AppTheme.tedRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (!isSuggested &&
                  viewModel.personalizedCount > 0 &&
                  index == viewModel.personalizedCount)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 2, top: 4),
                  child: Text(
                    'Discover more',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TalkCard(talk: talk),
            ],
          );
        },
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onTitleTap});

  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTitleTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
              children: [
                TextSpan(
                  text: 'TED',
                  style: TextStyle(color: AppTheme.tedRed),
                ),
                TextSpan(
                  text: 'x',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: ' Talks',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ideas worth spreading',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

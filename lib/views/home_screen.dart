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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<HomeViewModel>();
      if (!viewModel.hasData && !viewModel.isLoading) {
        viewModel.fetchFeed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<HomeViewModel>(
          builder: (context, viewModel, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: _HomeHeader(),
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

    return RefreshIndicator(
      color: AppTheme.tedRed,
      backgroundColor: AppTheme.surfaceElevated,
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: viewModel.talks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return TalkCard(talk: viewModel.talks[index]);
        },
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

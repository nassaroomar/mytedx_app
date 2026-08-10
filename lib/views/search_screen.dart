import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/search_viewmodel.dart';
import '../viewmodels/video_player_provider.dart';
import '../widgets/tag_chip.dart';
import '../widgets/talk_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const List<String> _popularTags = [
    'Technology',
    'Science',
    'Culture',
    'Design',
    'Business',
    'Education',
    'Health',
    'Media',
    'Social change',
    'Marketing',
    'Communication',
    'Film',
    'Women',
    'Feminism',
    'Sex',
    'Women Health',
    'Menopause',
    'Ageing',
    'Evolution',
    'Biology',
    'Microbiology',
    'TED-Ed',
    'Animation',
    'Human body',
    'Science communication',
    'Personal growth',
    'TEDx',
    'Exploration',
    'Travel',
    'TED Fellows',
    'Ocean',
    'Climate change',
    'Sustainability',
    'Food',
    'Society',
    'Money',
    'Farming',
    'Countdown',
    'Storytelling',
    'Psychology',
    'Work',
    'Decision-making',
    'Work-life balance',
    'Emotions',
    'Art',
    'Innovation',
  ];

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();
  String? _handledPendingTag;

  @override
  void initState() {
    super.initState();
    final initialQuery = context.read<SearchViewModel>().query;
    _controller = TextEditingController(text: initialQuery);
    _focusNode = FocusNode();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 480) {
      context.read<SearchViewModel>().loadMore();
    }
  }

  Future<void> _submitSearch() async {
    final viewModel = context.read<SearchViewModel>();
    viewModel.updateQuery(_controller.text);
    FocusScope.of(context).unfocus();
    await viewModel.search();
  }

  Future<void> _consumePendingTagIfNeeded(VideoPlayerProvider video) async {
    final tag = video.pendingSearchTag;
    if (tag == null || tag == _handledPendingTag) return;

    _handledPendingTag = tag;
    video.clearPendingSearchTag();

    _controller.clear();
    context.read<SearchViewModel>().updateQuery('');

    final searchVm = context.read<SearchViewModel>();
    await searchVm.selectTag(tag, allowToggleOff: false);

    _handledPendingTag = null;
  }

  @override
  Widget build(BuildContext context) {
    final video = context.watch<VideoPlayerProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingTagIfNeeded(video);
    });

    return Scaffold(
      body: SafeArea(
        child: Consumer<SearchViewModel>(
          builder: (context, viewModel, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: Colors.white),
                    onChanged: viewModel.updateQuery,
                    onSubmitted: (_) => _submitSearch(),
                    decoration: InputDecoration(
                      hintText: 'Search talks, speakers, ideas…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: viewModel.query.isNotEmpty ||
                              viewModel.selectedTag != null
                          ? IconButton(
                              tooltip: 'Clear',
                              onPressed: () async {
                                _controller.clear();
                                await viewModel.clear();
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : IconButton(
                              tooltip: 'Search',
                              onPressed: _submitSearch,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 88,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TwoRowTags(
                      tags: _popularTags,
                      selectedTag: viewModel.selectedTag,
                      onTagTap: viewModel.selectTag,
                    ),
                  ),
                ),
                if (viewModel.selectedTag != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Showing results for “${viewModel.selectedTag}”',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(child: _buildResults(viewModel)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResults(SearchViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.tedRed),
      );
    }

    if (viewModel.hasError) {
      return StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'Search failed',
        message: viewModel.errorMessage,
        actionLabel: 'Retry',
        onAction: viewModel.search,
      );
    }

    if (!viewModel.hasActiveFilters) {
      return const StateMessage(
        icon: Icons.travel_explore_rounded,
        title: 'Find your next idea',
        message:
            'Type a keyword or tap a tag above to explore TEDx talks.',
      );
    }

    if (!viewModel.hasResults) {
      return const StateMessage(
        icon: Icons.search_off_rounded,
        title: 'No talks found',
        message:
            'Try another keyword or pick a different tag to keep exploring.',
      );
    }

    final itemCount = viewModel.results.length +
        (viewModel.isLoadingMore || viewModel.hasMore ? 1 : 0);

    return ListView.separated(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index >= viewModel.results.length) {
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
        return TalkCard(talk: viewModel.results[index]);
      },
    );
  }
}

class _TwoRowTags extends StatelessWidget {
  const _TwoRowTags({
    required this.tags,
    required this.selectedTag,
    required this.onTagTap,
  });

  final List<String> tags;
  final String? selectedTag;
  final Future<void> Function(String tag) onTagTap;

  @override
  Widget build(BuildContext context) {
    final mid = (tags.length / 2).ceil();
    final row1 = tags.sublist(0, mid);
    final row2 = tags.sublist(mid);

    Widget row(List<String> items) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            TagChip(
              label: items[i],
              selected: selectedTag?.toLowerCase() == items[i].toLowerCase(),
              onTap: () => onTagTap(items[i]),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(row1),
        const SizedBox(height: 8),
        row(row2),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/search_viewmodel.dart';
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
  ];

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final initialQuery = context.read<SearchViewModel>().query;
    _controller = TextEditingController(text: initialQuery);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSearch() async {
    final viewModel = context.read<SearchViewModel>();
    viewModel.updateQuery(_controller.text);
    FocusScope.of(context).unfocus();
    await viewModel.search();
  }

  @override
  Widget build(BuildContext context) {
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
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _popularTags.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tag = _popularTags[index];
                      final selected = viewModel.selectedTag?.toLowerCase() ==
                          tag.toLowerCase();
                      return TagChip(
                        label: tag,
                        selected: selected,
                        onTap: () => viewModel.selectTag(tag),
                      );
                    },
                  ),
                ),
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

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: viewModel.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return TalkCard(talk: viewModel.results[index]);
      },
    );
  }
}

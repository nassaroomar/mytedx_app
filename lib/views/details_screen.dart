import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/details_viewmodel.dart';
import '../widgets/tag_chip.dart';
import '../widgets/talk_card.dart';
import '../widgets/talk_cover_image.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({
    super.key,
    required this.talkId,
    this.previewTitle,
    this.previewImageUrl,
  });

  final String talkId;
  final String? previewTitle;
  final String? previewImageUrl;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DetailsViewModel>().fetchDetails(widget.talkId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<DetailsViewModel>(
        builder: (context, viewModel, _) {
          final details = viewModel.talkDetails;
          final title = details?.title ??
              (widget.previewTitle?.isNotEmpty == true
                  ? widget.previewTitle!
                  : 'Talk details');
          final imageUrl = details?.imageUrl.isNotEmpty == true
              ? details!.imageUrl
              : (widget.previewImageUrl ?? '');

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.sizeOf(context).height * 0.42,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.background,
                foregroundColor: Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'talk-image-${widget.talkId}',
                        child: TalkCoverImage(
                          imageUrl: imageUrl,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66000000),
                              Colors.transparent,
                              Color(0xEE000000),
                            ],
                            stops: [0, 0.35, 1],
                          ),
                        ),
                      ),
                      if (details != null)
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: DurationBadge(
                            duration: details.formattedDuration,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  child: _buildContent(
                    viewModel: viewModel,
                    title: title,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required DetailsViewModel viewModel,
    required String title,
  }) {
    if (viewModel.isLoading && !viewModel.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.tedRed),
        ),
      );
    }

    if (viewModel.hasError && !viewModel.hasData) {
      return StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'Couldn’t load details',
        message: viewModel.errorMessage,
        actionLabel: 'Retry',
        onAction: () => viewModel.fetchDetails(widget.talkId),
      );
    }

    final details = viewModel.talkDetails;
    if (details == null) {
      return const SizedBox.shrink();
    }

    final published = details.publishedAt == null
        ? null
        : DateFormat.yMMMMd().format(details.publishedAt!.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title == 'Untitled Talk' && details.slug.isNotEmpty
              ? _titleFromSlug(details.slug)
              : title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: AppTheme.tedRed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                details.presenterDisplayName,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (published != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                published,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
        if (details.tagsList.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: details.tagsList
                .map(
                  (tag) => TagChip(
                    label: tag,
                    outlined: true,
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'About this talk',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          details.description.isEmpty
              ? 'No description available for this talk.'
              : details.description,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  String _titleFromSlug(String slug) {
    return slug
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }
}

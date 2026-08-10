import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/similar_talk.dart';
import '../models/talk.dart';
import '../services/local_history_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/details_viewmodel.dart';
import '../viewmodels/library_viewmodel.dart';
import '../viewmodels/video_player_provider.dart';
import 'tag_chip.dart';
import 'talk_card.dart';
import 'talk_cover_image.dart';

/// Expanded mini-player chrome: drag handle + spacer for overlay WebView + details.
class ExpandedPlayerView extends StatelessWidget {
  const ExpandedPlayerView({
    super.key,
    required this.height,
    required this.percentage,
    required this.videoSlotHeight,
    required this.videoSlot,
    required this.onPlayerDragUpdate,
    required this.onPlayerDragEnd,
  });

  final double height;
  final double percentage;
  final double videoSlotHeight;
  final Widget videoSlot;
  final ValueChanged<double> onPlayerDragUpdate;
  final ValueChanged<double> onPlayerDragEnd;

  @override
  Widget build(BuildContext context) {
    final video = context.watch<VideoPlayerProvider>();
    final fullscreen = video.isFullscreen;

    return Material(
      color: AppTheme.background,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            if (!fullscreen) ...[
              _PlayerDragHandle(
                onDragUpdate: onPlayerDragUpdate,
                onDragEnd: onPlayerDragEnd,
                onTapMinimize: video.minimizePlayer,
              ),
              SizedBox(
                height: videoSlotHeight,
                width: double.infinity,
                child: videoSlot,
              ),
              _PlayerActionsBar(
                onDragUpdate: onPlayerDragUpdate,
                onDragEnd: onPlayerDragEnd,
                onFullscreen: video.enterFullscreen,
                onOpenExternal: () async {
                  final url = video.videoUrl ?? video.embedUrl;
                  if (url == null) return;
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
            Expanded(
              child: percentage < 0.45 && !fullscreen
                  ? const SizedBox.shrink()
                  : const _ExpandedDetailsBody(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDragHandle extends StatelessWidget {
  const _PlayerDragHandle({
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTapMinimize,
  });

  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onTapMinimize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => onDragUpdate(details.delta.dy),
      onVerticalDragEnd: (details) =>
          onDragEnd(details.primaryVelocity ?? 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 36,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Minimize',
                onPressed: onTapMinimize,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                ),
              ),
              const Expanded(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF555555),
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                    ),
                    child: SizedBox(width: 42, height: 4),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerActionsBar extends StatelessWidget {
  const _PlayerActionsBar({
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onFullscreen,
    required this.onOpenExternal,
  });

  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onFullscreen;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
      onVerticalDragEnd: (d) => onDragEnd(d.primaryVelocity ?? 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onFullscreen,
              icon: const Icon(Icons.screen_rotation_rounded, size: 18),
              label: const Text('Landscape'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: const Text('Open in browser'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedDetailsBody extends StatelessWidget {
  const _ExpandedDetailsBody();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(child: _TalkMetaSection()),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 32),
          sliver: SliverToBoxAdapter(child: _UpNextSection()),
        ),
      ],
    );
  }
}

/// Talk title / description — rebuilds only when details change.
class _TalkMetaSection extends StatelessWidget {
  const _TalkMetaSection();

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((DetailsViewModel v) => v.isLoading);
    final hasError = context.select((DetailsViewModel v) => v.hasError);
    final hasData = context.select((DetailsViewModel v) => v.hasData);
    final details = context.select((DetailsViewModel v) => v.talkDetails);
    final errorMessage =
        context.select((DetailsViewModel v) => v.errorMessage);
    final video = context.read<VideoPlayerProvider>();

    if (isLoading && !hasData) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.tedRed),
        ),
      );
    }

    if (hasError && !hasData) {
      return StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'Couldn’t load details',
        message: errorMessage,
        actionLabel: 'Retry',
        onAction: () {
          final id = video.talkId;
          if (id != null) {
            context.read<DetailsViewModel>().fetchDetails(id);
          }
        },
      );
    }

    final title = details?.title ?? video.title;
    final presenter = details?.presenterDisplayName ?? video.presenter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title.isEmpty ? 'Talk details' : title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            _TalkOverflowMenu(
              talkId: details?.id ?? video.talkId ?? '',
              title: title,
              presenter: presenter,
              imageUrl: details?.imageUrl ?? video.imageUrl,
              duration: details?.duration ?? '',
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                presenter,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (details != null)
              DurationBadge(duration: details.formattedDuration),
          ],
        ),
        if (details?.publishedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            DateFormat.yMMMMd().format(details!.publishedAt!.toLocal()),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
        ],
        if (details != null && details.tagsList.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: details.tagsList
                .map(
                  (tag) => TagChip(
                    label: tag,
                    outlined: true,
                    onTap: () => video.openSearchWithTag(tag),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'About this talk',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (details?.description.isNotEmpty == true)
              ? details!.description
              : 'No description available for this talk.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _TalkOverflowMenu extends StatelessWidget {
  const _TalkOverflowMenu({
    required this.talkId,
    required this.title,
    required this.presenter,
    required this.imageUrl,
    required this.duration,
  });

  final String talkId;
  final String title;
  final String presenter;
  final String imageUrl;
  final String duration;

  @override
  Widget build(BuildContext context) {
    if (talkId.isEmpty) return const SizedBox.shrink();

    final library = context.watch<LibraryViewModel>();
    final saved = library.isSaved(talkId);

    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
      color: AppTheme.surfaceElevated,
      onSelected: (value) async {
        final talk = Talk(
          id: talkId,
          title: title,
          duration: duration.isEmpty ? '0' : duration,
          presenterDisplayName: presenter,
          imageUrl: imageUrl,
        );
        if (value == 'save') {
          await library.addToWatchLater(talk);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved to Watch later')),
            );
          }
        } else if (value == 'remove') {
          await library.removeFromWatchLater(talkId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Removed from Watch later')),
            );
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: saved ? 'remove' : 'save',
          child: Text(
            saved ? 'Remove from Watch later' : 'Save to Watch later',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _UpNextSection extends StatelessWidget {
  const _UpNextSection();

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.select((DetailsViewModel v) => v.isLoadingUpNext);
    final upNext = context.select((DetailsViewModel v) => v.upNext);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Up Next',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
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
          )
        else if (upNext.isEmpty)
          const Text(
            'No similar talks found for these tags yet.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          )
        else
          ...upNext.map(
            (similar) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SimilarTalkTile(
                similar: similar,
                onTap: () => _openSimilar(context, similar),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openSimilar(BuildContext context, SimilarTalk similar) async {
    final detailsVm = context.read<DetailsViewModel>();
    final video = context.read<VideoPlayerProvider>();

    await detailsVm.fetchDetails(similar.talk.id, clearExisting: true);
    final details = detailsVm.talkDetails;
    if (details == null || !context.mounted) return;

    await video.playTalk(details, expand: true);
  }
}

class SimilarTalkTile extends StatelessWidget {
  const SimilarTalkTile({
    super.key,
    required this.similar,
    required this.onTap,
  });

  final SimilarTalk similar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final talk = similar.talk;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (talk.imageUrl.isNotEmpty)
                        TalkCoverImage(
                          imageUrl: talk.imageUrl,
                          borderRadius: BorderRadius.zero,
                        )
                      else
                        const ColoredBox(
                          color: AppTheme.surfaceElevated,
                          child: Icon(
                            Icons.movie_outlined,
                            color: AppTheme.tedRed,
                          ),
                        ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: DurationBadge(duration: talk.formattedDuration),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      talk.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      talk.presenterDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      similar.sharedTagCount == 1
                          ? '1 shared tag'
                          : '${similar.sharedTagCount} shared tags',
                      style: const TextStyle(
                        color: AppTheme.tedRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openTalkInPlayer(
  BuildContext context, {
  required String talkId,
  String? previewTitle,
  String? previewImageUrl,
  String? previewPresenter,
  double? resumePositionSeconds,
}) async {
  final detailsVm = context.read<DetailsViewModel>();
  final video = context.read<VideoPlayerProvider>();
  final localHistory = context.read<LocalHistoryService>();

  // Always prefer the freshest saved progress when resuming.
  var resume = resumePositionSeconds;
  if (resume == null || resume < 2) {
    final entry = await localHistory.getWatchEntry(talkId);
    if (entry != null && entry.positionSeconds >= 2) {
      resume = entry.positionSeconds;
    }
  }

  if (!context.mounted) return;

  await video.prepareTalkShell(
    talkId: talkId,
    title: previewTitle ?? 'Loading…',
    presenter: previewPresenter ?? '',
    imageUrl: previewImageUrl ?? '',
    expand: true,
    resumePositionSeconds: resume,
  );

  await detailsVm.fetchDetails(talkId, clearExisting: true);
  if (!context.mounted) return;

  final details = detailsVm.talkDetails;
  if (details != null && details.id == talkId) {
    await video.playTalk(
      details,
      expand: true,
      resumePositionSeconds: resume,
    );
    return;
  }

  await video.play(
    talkId: talkId,
    title: previewTitle ?? 'Talk',
    presenter: previewPresenter ?? '',
    imageUrl: previewImageUrl ?? '',
    expand: true,
    resumePositionSeconds: resume,
  );
}

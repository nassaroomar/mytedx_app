import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/talk.dart';
import '../services/talk_tags_cache.dart';
import '../theme/app_theme.dart';
import '../viewmodels/library_viewmodel.dart';
import '../viewmodels/video_player_provider.dart';
import 'expanded_player_view.dart';
import 'tag_chip.dart';
import 'talk_cover_image.dart';

class TalkCard extends StatelessWidget {
  const TalkCard({
    super.key,
    required this.talk,
    this.heroEnabled = true,
    this.maxTags = 6,
  });

  final Talk talk;
  final bool heroEnabled;
  final int maxTags;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openTalkInPlayer(
          context,
          talkId: talk.id,
          previewTitle: talk.title,
          previewImageUrl: talk.imageUrl,
          previewPresenter: talk.presenterDisplayName,
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      heroEnabled
                          ? Hero(
                              tag: 'talk-image-${talk.id}',
                              child: TalkCoverImage(
                                imageUrl: talk.imageUrl,
                                borderRadius: BorderRadius.zero,
                              ),
                            )
                          : TalkCoverImage(
                              imageUrl: talk.imageUrl,
                              borderRadius: BorderRadius.zero,
                            ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x66000000),
                              Color(0xCC000000),
                            ],
                            stops: [0.45, 0.75, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: DurationBadge(
                          duration: talk.formattedDuration,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TalkCardTags(talk: talk, maxTags: maxTags),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            talk.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        _TalkCardSaveMenu(talk: talk),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        talk.presenterDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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

class _TalkCardSaveMenu extends StatelessWidget {
  const _TalkCardSaveMenu({required this.talk});

  final Talk talk;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryViewModel>();
    final saved = library.isSaved(talk.id);

    return PopupMenuButton<String>(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
      color: AppTheme.surfaceElevated,
      onSelected: (value) async {
        if (value == 'save') {
          await library.addToWatchLater(talk);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved to Watch later')),
            );
          }
        } else if (value == 'remove') {
          await library.removeFromWatchLater(talk.id);
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

class _TalkCardTags extends StatefulWidget {
  const _TalkCardTags({required this.talk, required this.maxTags});

  final Talk talk;
  final int maxTags;

  @override
  State<_TalkCardTags> createState() => _TalkCardTagsState();
}

class _TalkCardTagsState extends State<_TalkCardTags> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestTags());
  }

  @override
  void didUpdateWidget(covariant _TalkCardTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.talk.id != widget.talk.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestTags());
    }
  }

  void _requestTags() {
    if (!mounted) return;
    final talk = widget.talk;
    if (talk.tagsList.isNotEmpty) {
      context.read<TalkTagsCache>().seed(talk.id, talk.tagsList);
      return;
    }
    context.read<TalkTagsCache>().ensureLoaded(talk.id);
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.watch<TalkTagsCache>();
    final cached = cache.tagsFor(widget.talk.id);
    final tags = (cached ?? widget.talk.tagsList).take(widget.maxTags).toList();
    final loading = cached == null &&
        widget.talk.tagsList.isEmpty &&
        cache.isLoading(widget.talk.id);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 22,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.tedRed,
              ),
            ),
          ),
        ),
      );
    }

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final video = context.read<VideoPlayerProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags
            .map(
              (tag) => TagChip(
                label: tag,
                outlined: true,
                compact: true,
                onTap: () => video.openSearchWithTag(tag),
              ),
            )
            .toList(),
      ),
    );
  }
}

class DurationBadge extends StatelessWidget {
  const DurationBadge({super.key, required this.duration});

  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        duration,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

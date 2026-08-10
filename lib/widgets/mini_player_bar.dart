import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/video_player_provider.dart';
import 'talk_cover_image.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
  });

  final ValueChanged<double>? onVerticalDragUpdate;
  final ValueChanged<double>? onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoPlayerProvider>(
      builder: (context, video, _) {
        return Material(
          color: const Color(0xFF151515),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onVerticalDragUpdate == null
                ? null
                : (d) => onVerticalDragUpdate!(d.delta.dy),
            onVerticalDragEnd: onVerticalDragEnd == null
                ? null
                : (d) => onVerticalDragEnd!(d.primaryVelocity ?? 0),
            onTap: video.expandPlayer,
            child: SizedBox(
              height: VideoPlayerProvider.miniPlayerMinHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    height: VideoPlayerProvider.miniPlayerMinHeight,
                    child: video.imageUrl.isNotEmpty
                        ? TalkCoverImage(
                            imageUrl: video.imageUrl,
                            borderRadius: BorderRadius.zero,
                          )
                        : const ColoredBox(
                            color: Colors.black,
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: AppTheme.tedRed,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          video.presenter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Expand',
                    onPressed: video.expandPlayer,
                    icon: const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: video.dismissPlayer,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

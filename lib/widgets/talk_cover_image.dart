import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

class TalkCoverImage extends StatelessWidget {
  const TalkCoverImage({
    super.key,
    required this.imageUrl,
    this.borderRadius,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final BorderRadius? borderRadius;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(14);

    Widget image;
    if (imageUrl.isEmpty) {
      image = _errorPlaceholder();
    } else {
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width ?? double.infinity,
        height: height,
        placeholder: (_, _) => const RedShimmerPlaceholder(),
        errorWidget: (_, _, _) => _errorPlaceholder(),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: image,
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_outline_rounded,
        color: AppTheme.tedRed,
        size: 42,
      ),
    );
  }
}

class RedShimmerPlaceholder extends StatelessWidget {
  const RedShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF3A1210),
      highlightColor: AppTheme.tedRed.withValues(alpha: 0.55),
      child: Container(color: AppTheme.surfaceElevated),
    );
  }
}

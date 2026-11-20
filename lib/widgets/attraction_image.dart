import 'package:flutter/material.dart';

import '../models/attraction.dart';
import 'category_chip.dart';

/// Shared, high-performance image component for TourMate tourist attractions.
///
/// Features:
/// - Real photograph rendering with [BoxFit.cover]
/// - Smooth 300ms fade-in transition via [Image.network] frameBuilder
/// - Zero Cumulative Layout Shift (CLS) via explicit dimension constraints
/// - Graceful category-themed placeholder during network loading
/// - Safe fallback for empty, broken, or blocked network image requests
/// - Optimized memory footprint via cacheWidth/cacheHeight decoding hints
class AttractionImage extends StatelessWidget {
  const AttractionImage({
    super.key,
    required this.imageUrl,
    required this.category,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.heroTag,
  });

  /// Factory constructor to build directly from an [Attraction].
  factory AttractionImage.fromAttraction({
    Key? key,
    required Attraction attraction,
    double? width,
    double? height,
    BorderRadius borderRadius = BorderRadius.zero,
    BoxFit fit = BoxFit.cover,
    String? heroTag,
  }) {
    return AttractionImage(
      key: key,
      imageUrl: attraction.imageUrl,
      category: attraction.category,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: fit,
      heroTag: heroTag,
    );
  }

  final String imageUrl;
  final String category;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    Widget content;
    if (cleanUrl.isEmpty) {
      content = AttractionImageFallback(category: category);
    } else {
      final int cacheWidth = (width != null && width! > 0)
          ? (width! * 2).round().clamp(100, 1600)
          : (height != null && height! > 0
                ? (height! * 2).round().clamp(100, 1600)
                : 800);
      final int? cacheHeight = (height != null && height! > 0)
          ? (height! * 2).round().clamp(100, 1600)
          : null;

      content = Image.network(
        cleanUrl,
        fit: fit,
        width: width ?? double.infinity,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _LoadingPlaceholder(
            category: category,
            loadingProgress: loadingProgress,
          );
        },
        errorBuilder: (_, _, _) => AttractionImageFallback(category: category),
      );
    }

    Widget decorated = ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: content,
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      decorated = Hero(tag: heroTag!, child: decorated);
    }

    return decorated;
  }
}

/// Category-themed fallback illustration displayed when no photograph is available
/// or when an image request fails.
class AttractionImageFallback extends StatelessWidget {
  const AttractionImageFallback({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxHeight < 72 || constraints.maxWidth < 72;
        return Container(
          color: const Color(0xFFD7EBEA),
          alignment: Alignment.center,
          child: isCompact
              ? Icon(
                  CategoryChip.iconFor(category),
                  size: (constraints.maxHeight * 0.45).clamp(18.0, 28.0),
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                )
              : Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CategoryChip.iconFor(category),
                        size: 30,
                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Subtle tinted loading container that prevents layout shift while image bytes download.
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({
    required this.category,
    required this.loadingProgress,
  });

  final String category;
  final ImageChunkEvent loadingProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = (constraints.maxHeight * 0.4).clamp(16.0, 28.0);
        return Container(
          color: const Color(0xFFE8F1F4),
          alignment: Alignment.center,
          child: Icon(
            CategoryChip.iconFor(category),
            size: iconSize,
            color: const Color(0xFF176B87).withValues(alpha: 0.25),
          ),
        );
      },
    );
  }
}

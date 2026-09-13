import 'package:flutter/material.dart';

import '../data/dummy_data.dart';
import '../models/attraction.dart';
import 'category_chip.dart';

enum AttractionCardLayout { horizontal, vertical }

class AttractionCard extends StatelessWidget {
  const AttractionCard({
    super.key,
    required this.attraction,
    this.layout = AttractionCardLayout.vertical,
    this.onTap,
  });

  final Attraction attraction;
  final AttractionCardLayout layout;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return layout == AttractionCardLayout.horizontal
        ? _HorizontalCard(attraction: attraction, onTap: onTap)
        : _VerticalCard(attraction: attraction, onTap: onTap);
  }
}

class _HorizontalCard extends StatelessWidget {
  const _HorizontalCard({required this.attraction, this.onTap});

  final Attraction attraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap ?? () => showAttractionDetails(context, attraction),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardImage(
                attraction: attraction,
                height: 132,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attraction.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attraction.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RatingDistanceRow(attraction: attraction),
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

class _VerticalCard extends StatelessWidget {
  const _VerticalCard({required this.attraction, this.onTap});

  final Attraction attraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap ?? () => showAttractionDetails(context, attraction),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _CardImage(
                attraction: attraction,
                width: 104,
                height: 104,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attraction.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attraction.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      attraction.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _RatingDistanceRow(attraction: attraction),
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

class _CardImage extends StatelessWidget {
  const _CardImage({
    required this.attraction,
    required this.height,
    this.width,
    required this.borderRadius,
  });

  final Attraction attraction;
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            width: width ?? double.infinity,
            height: height,
            child: Image.network(
              attraction.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _ImageFallback(
                category: attraction.category,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(color: Color(0xFFE8F1F4));
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _FavoriteButton(attractionId: attraction.id),
        ),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.attractionId});

  final String attractionId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SavedPlacesStore.instance,
      builder: (context, _) {
        final saved = SavedPlacesStore.instance.isSaved(attractionId);
        return Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => SavedPlacesStore.instance.toggle(attractionId),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: saved ? Colors.redAccent : Colors.black54,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RatingDistanceRow extends StatelessWidget {
  const _RatingDistanceRow({required this.attraction});

  final Attraction attraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A524)),
        const SizedBox(width: 4),
        Text(
          attraction.rating.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          Icons.near_me_rounded,
          size: 15,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            attraction.distance,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFD7EBEA),
      child: Center(
        child: Icon(
          CategoryChip.iconFor(category),
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

Future<void> showAttractionDetails(
  BuildContext context,
  Attraction attraction,
) {
  final theme = Theme.of(context);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attraction.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${attraction.category} · ${attraction.location}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(attraction.description),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Opening hours',
                value: attraction.openingHours,
              ),
              _DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Entry fee',
                value: attraction.entryFee,
              ),
              _DetailRow(
                icon: Icons.star_rounded,
                label: 'Rating',
                value: attraction.rating.toStringAsFixed(1),
              ),
              _DetailRow(
                icon: Icons.near_me_rounded,
                label: 'Distance',
                value: attraction.distance,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

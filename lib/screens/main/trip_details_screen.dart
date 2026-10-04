import 'package:flutter/material.dart';

import '../../models/attraction.dart';
import '../../models/trip.dart';
import '../../services/attraction_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/attraction_card.dart';
import '../../widgets/trip_form_sheet.dart';

/// Screen displaying the trip's itinerary and allowing reordering and attraction management.
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  final String tripId;
  final Trip? initialTrip;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final Map<String, Attraction?> _attractionsCache = {};
  bool _loadingAttractions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrip != null) {
      _loadAttractions(widget.initialTrip!.attractionIds);
    }
  }

  Future<void> _loadAttractions(List<String> attractionIds) async {
    final missingIds =
        attractionIds.where((id) => !_attractionsCache.containsKey(id)).toList();
    if (missingIds.isEmpty) return;

    setState(() => _loadingAttractions = true);

    for (final id in missingIds) {
      try {
        final attraction = await AttractionService.instance.getAttraction(id);
        _attractionsCache[id] = attraction;
      } catch (_) {
        _attractionsCache[id] = null;
      }
    }

    if (mounted) {
      setState(() => _loadingAttractions = false);
    }
  }

  Future<void> _confirmDeleteTrip(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text(
          'Are you sure you want to delete "${trip.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await TripService.instance.deleteTrip(trip.id);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip "${trip.name}" deleted.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is TripServiceException
                    ? e.message
                    : 'Failed to delete trip: $e',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeAttraction(Trip trip, String attractionId, String attractionName) async {
    try {
      await TripService.instance.removeAttractionFromTrip(
        tripId: trip.id,
        attractionId: attractionId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$attractionName" from trip.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is TripServiceException
                  ? e.message
                  : 'Failed to remove attraction: $e',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Trip>>(
      stream: TripService.instance.streamTrips(),
      builder: (context, snapshot) {
        final trips = snapshot.data ?? (widget.initialTrip != null ? [widget.initialTrip!] : const <Trip>[]);
        Trip? trip;
        for (final t in trips) {
          if (t.id == widget.tripId) {
            trip = t;
            break;
          }
        }
        trip ??= widget.initialTrip;

        if (trip == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Trip Details')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Trip not found or has been deleted.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Trips'),
                  ),
                ],
              ),
            ),
          );
        }

        // Trigger loading of any new attraction IDs
        _loadAttractions(trip.attractionIds);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              trip.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Trip',
                onPressed: () => TripFormSheet.show(context, initialTrip: trip),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                tooltip: 'Delete Trip',
                onPressed: () => _confirmDeleteTrip(context, trip!),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Trip Overview Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                trip.destination,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              trip.formattedDateRange,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${trip.durationInDays} ${trip.durationInDays == 1 ? 'day' : 'days'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // "Your Attractions" Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Your Attractions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${trip.attractionCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (trip.attractionCount > 1)
                        Text(
                          'Drag to reorder',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Empty or Reorderable Attractions List
              if (trip.attractionIds.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_location_alt_outlined,
                              size: 40,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No attractions added yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Browse attractions in Explore or Home and tap "Add to Trip" to build your itinerary.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverReorderableList(
                    itemCount: trip.attractionIds.length,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final updatedList = List<String>.from(trip!.attractionIds);
                      final movedId = updatedList.removeAt(oldIndex);
                      updatedList.insert(newIndex, movedId);

                      TripService.instance.reorderAttractions(
                        tripId: trip.id,
                        newOrder: updatedList,
                      );
                    },
                    itemBuilder: (context, index) {
                      final attractionId = trip!.attractionIds[index];
                      final attraction = _attractionsCache[attractionId];

                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(attractionId),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ItineraryAttractionCard(
                            index: index + 1,
                            attractionId: attractionId,
                            attraction: attraction,
                            isLoading: _loadingAttractions && attraction == null,
                            onRemove: () => _removeAttraction(
                              trip!,
                              attractionId,
                              attraction?.name ?? attractionId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ItineraryAttractionCard extends StatelessWidget {
  const _ItineraryAttractionCard({
    required this.index,
    required this.attractionId,
    required this.attraction,
    required this.isLoading,
    required this.onRemove,
  });

  final int index;
  final String attractionId;
  final Attraction? attraction;
  final bool isLoading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1.5,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: attraction != null
            ? () => showAttractionDetails(context, attraction!)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Sequence number badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: attraction != null
                      ? Image.network(
                          attraction!.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.location_city_rounded,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.place_outlined, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Category/Location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attraction?.name ?? (isLoading ? 'Loading...' : attractionId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      attraction != null
                          ? '${attraction!.category} · ${attraction!.displayLocation}'
                          : attractionId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (attraction != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFF5A524),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            attraction!.rating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions: Remove Button & Drag Handle
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Colors.red.shade400,
                  size: 22,
                ),
                tooltip: 'Remove from trip',
                onPressed: onRemove,
              ),
              const Icon(
                Icons.drag_indicator_rounded,
                color: Colors.grey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

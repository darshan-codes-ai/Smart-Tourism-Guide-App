import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/dummy_data.dart';
import '../../models/attraction.dart';
import '../../models/travel_preference.dart';
import '../../models/trip.dart';
import '../../services/attraction_service.dart';
import '../../services/itinerary_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/attraction_card.dart';
import '../../widgets/trip_form_sheet.dart';
import '../../widgets/trip_weather_card.dart';

/// Screen displaying the trip's itinerary and allowing day-by-day management,
/// AI itinerary generation, reordering, and attraction management.
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.tripId, this.initialTrip});

  final String tripId;
  final Trip? initialTrip;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final Map<String, Attraction?> _attractionsCache = {};
  final Set<String> _loadingAttractionIds = <String>{};
  bool _loadingAttractions = false;
  int? _selectedDay; // null = all days

  @override
  void initState() {
    super.initState();
    if (widget.initialTrip != null) {
      _loadAttractions(widget.initialTrip!.attractionIds);
    }
  }

  Future<void> _loadAttractions(List<String> attractionIds) async {
    final missingIds = attractionIds
        .where(
          (id) =>
              !_attractionsCache.containsKey(id) &&
              !_loadingAttractionIds.contains(id),
        )
        .toList();
    if (missingIds.isEmpty) return;

    _loadingAttractionIds.addAll(missingIds);
    if (mounted) {
      setState(() => _loadingAttractions = true);
    }

    for (final id in missingIds) {
      try {
        final attraction = await AttractionService.instance.getAttraction(id);
        _attractionsCache[id] = attraction;
      } catch (_) {
        _attractionsCache[id] = null;
      } finally {
        _loadingAttractionIds.remove(id);
      }
    }

    if (mounted) {
      setState(() => _loadingAttractions = _loadingAttractionIds.isNotEmpty);
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
              minimumSize: const Size(0, 40),
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
            SnackBar(content: Text('Trip "${trip.name}" deleted.')),
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

  Future<void> _removeAttraction(
    Trip trip,
    String attractionId,
    String attractionName,
  ) async {
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

  Future<void> _moveAttractionToDay(
    Trip trip,
    String attractionId,
    int targetDay,
  ) async {
    try {
      await TripService.instance.moveAttractionToDay(
        tripId: trip.id,
        attractionId: attractionId,
        targetDay: targetDay,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to Day $targetDay.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is TripServiceException ? e.message : 'Failed to move: $e',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _showGenerateItineraryModal(
    BuildContext context,
    Trip trip,
  ) async {
    final interests = Set<TravelInterest>.from(
      RecommendationService.instance.currentPreference.selectedInterests,
    );
    int attractionsPerDay = 3;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Smart Itinerary Generator',
                    style: Theme.of(ctx).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Auto-schedule recommended attractions in ${trip.destination} for all ${trip.durationInDays} days.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Pacing Selection
              Text(
                'Pacing (attractions / day):',
                style: Theme.of(ctx).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('Relaxed (2)')),
                  ButtonSegment(value: 3, label: Text('Standard (3)')),
                  ButtonSegment(value: 4, label: Text('Active (4)')),
                ],
                selected: {attractionsPerDay},
                onSelectionChanged: (val) =>
                    setSheetState(() => attractionsPerDay = val.first),
              ),
              const SizedBox(height: 16),

              // Interests Selection
              Text(
                'Prioritize interests:',
                style: Theme.of(ctx).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: TravelInterest.values.map((interest) {
                  final isSelected = interests.contains(interest);
                  return FilterChip(
                    label: Text(
                      interest.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setSheetState(() {
                        if (selected) {
                          interests.add(interest);
                        } else {
                          interests.remove(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                key: const Key('confirm_generate_itinerary_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(sheetContext).pop();

                  // Fetch pool
                  List<Attraction> pool = [];
                  try {
                    pool = await AttractionService.instance
                        .watchAttractions()
                        .first
                        .timeout(const Duration(seconds: 2));
                  } catch (_) {}
                  if (pool.isEmpty) pool = DummyData.attractions;

                  final generated = ItineraryService.instance.generateItinerary(
                    destination: trip.destination,
                    startDate: trip.startDate,
                    endDate: trip.endDate,
                    availableAttractions: pool,
                    interests: interests.isNotEmpty ? interests : null,
                    budget: trip.budget,
                    travelerCount: trip.travelerCount,
                    attractionsPerDay: attractionsPerDay,
                  );

                  if (generated.allAttractionIds.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No attractions found matching destination.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  await TripService.instance.updateDayItinerary(
                    tripId: trip.id,
                    dayItinerary: generated.dayItineraryIds,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Scheduled ${generated.allAttractions.length} attractions across ${trip.durationInDays} days!',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate & Apply Itinerary'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _findDayForAttraction(
    Map<int, List<String>> dayItinerary,
    String attractionId,
  ) {
    for (final entry in dayItinerary.entries) {
      if (entry.value.contains(attractionId)) {
        return entry.key;
      }
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Trip>>(
      stream: TripService.instance.streamTrips(),
      builder: (context, snapshot) {
        final trips =
            snapshot.data ??
            (widget.initialTrip != null
                ? [widget.initialTrip!]
                : const <Trip>[]);
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
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('Trip not found or has been deleted.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Trips'),
                  ),
                ],
              ),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadAttractions(trip!.attractionIds);
        });

        final resolvedDays = trip.resolvedDayItinerary;

        // Filter attractions list based on selected day (or all)
        final displayedAttractionIds = _selectedDay == null
            ? trip.attractionIds
            : (resolvedDays[_selectedDay] ?? const <String>[]);

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
                key: const Key('trip_details_generate_itinerary_appbar_button'),
                icon: const Icon(Icons.auto_awesome_rounded),
                tooltip: 'Smart Itinerary',
                onPressed: () => _showGenerateItineraryModal(context, trip!),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Trip',
                onPressed: () => TripFormSheet.show(context, initialTrip: trip),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade700,
                ),
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
                          theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  trip.formattedDateRange,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people_alt_outlined,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    trip.formattedTravelers,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (trip.formattedBudget.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '💰 ${trip.formattedBudget}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade800,
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

              // Weather Forecast Sliver
              SliverToBoxAdapter(
                child: TripWeatherCard(
                  key: const Key('trip_details_weather_card'),
                  trip: trip,
                ),
              ),

              // Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                      if (trip.attractionCount > 1 && _selectedDay == null)
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

              // Day Selector Filter Bar
              if (trip.durationInDays > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: trip.durationInDays + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedDay == null;
                          return ChoiceChip(
                            label: const Text(
                              'All Days',
                              style: TextStyle(fontSize: 12),
                            ),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedDay = null),
                          );
                        }
                        final dayNum = index;
                        final count = resolvedDays[dayNum]?.length ?? 0;
                        final isSelected = _selectedDay == dayNum;
                        return ChoiceChip(
                          label: Text(
                            'Day $dayNum ($count)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedDay = dayNum),
                        );
                      },
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Empty or Reorderable Attractions List
              if (displayedAttractionIds.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_location_alt_outlined,
                              size: 36,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedDay == null
                                ? 'No attractions added yet'
                                : 'No attractions scheduled for Day $_selectedDay',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Browse attractions or let AI generate a day-by-day plan automatically.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            onPressed: () =>
                                _showGenerateItineraryModal(context, trip!),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                            ),
                            label: const Text('Generate Smart Itinerary'),
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
                    itemCount: displayedAttractionIds.length,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final updatedList = List<String>.from(
                        trip!.attractionIds,
                      );
                      final movedId = updatedList.removeAt(oldIndex);
                      updatedList.insert(newIndex, movedId);

                      TripService.instance.reorderAttractions(
                        tripId: trip.id,
                        newOrder: updatedList,
                      );
                    },
                    itemBuilder: (context, index) {
                      final attractionId = displayedAttractionIds[index];
                      final attraction = _attractionsCache[attractionId];
                      final dayNumber = _findDayForAttraction(
                        resolvedDays,
                        attractionId,
                      );

                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(attractionId),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ItineraryAttractionCard(
                            index: index + 1,
                            attractionId: attractionId,
                            attraction: attraction,
                            dayNumber: dayNumber,
                            totalDays: trip!.durationInDays,
                            isLoading:
                                _loadingAttractions && attraction == null,
                            onMoveToDay: (newDay) => _moveAttractionToDay(
                              trip!,
                              attractionId,
                              newDay,
                            ),
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
    required this.dayNumber,
    required this.totalDays,
    required this.isLoading,
    required this.onMoveToDay,
    required this.onRemove,
  });

  final int index;
  final String attractionId;
  final Attraction? attraction;
  final int dayNumber;
  final int totalDays;
  final bool isLoading;
  final ValueChanged<int> onMoveToDay;
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
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.location_city_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.place_outlined,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Category, Rating & Day Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attraction?.name ??
                          (isLoading ? 'Loading...' : attractionId),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (attraction != null) ...[
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
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Day $dayNumber',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Move to day menu
              if (totalDays > 1)
                PopupMenuButton<int>(
                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                  tooltip: 'Move to another day',
                  onSelected: onMoveToDay,
                  itemBuilder: (context) => [
                    for (int d = 1; d <= totalDays; d++)
                      PopupMenuItem(
                        value: d,
                        child: Text(
                          d == dayNumber
                              ? 'Day $d (Current)'
                              : 'Move to Day $d',
                          style: TextStyle(
                            fontWeight: d == dayNumber
                                ? FontWeight.w800
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
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

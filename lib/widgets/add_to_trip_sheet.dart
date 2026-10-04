import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';
import 'trip_form_sheet.dart';

/// Modal bottom sheet allowing users to select an existing trip or create a new one
/// to add a specific [Attraction].
class AddToTripSheet extends StatelessWidget {
  const AddToTripSheet({
    super.key,
    required this.attraction,
  });

  final Attraction attraction;

  /// Helper to show this bottom sheet.
  static Future<void> show(BuildContext context, Attraction attraction) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AddToTripSheet(attraction: attraction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.luggage_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add to Trip',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              attraction.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Trips List
            Flexible(
              child: StreamBuilder<List<Trip>>(
                stream: TripService.instance.streamTrips(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Failed to load trips: ${snapshot.error}',
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    );
                  }

                  final trips = snapshot.data ?? const <Trip>[];

                  if (trips.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.luggage_outlined,
                            size: 44,
                            color: theme.colorScheme.primary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No trips found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create a trip to add this attraction to your itinerary.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: trips.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final isAlreadyAdded =
                          trip.attractionIds.contains(attraction.id);

                      return Material(
                        color: isAlreadyAdded
                            ? Colors.grey.shade100
                            : theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isAlreadyAdded
                                ? Colors.grey.shade300
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isAlreadyAdded
                                ? Colors.grey.shade300
                                : theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.travel_explore_rounded,
                              color: isAlreadyAdded
                                  ? Colors.grey.shade600
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            trip.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isAlreadyAdded
                                  ? Colors.grey.shade700
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${trip.destination} · ${trip.attractionCount} attractions',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: isAlreadyAdded
                              ? Chip(
                                  label: const Text('Added'),
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                  backgroundColor: Colors.green.shade50,
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(color: Colors.green.shade200),
                                )
                              : Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                          onTap: () async {
                            if (isAlreadyAdded) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Already added to this trip.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            try {
                              await TripService.instance.addAttractionToTrip(
                                tripId: trip.id,
                                attractionId: attraction.id,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added "${attraction.name}" to ${trip.name}',
                                    ),
                                    backgroundColor: Colors.green.shade700,
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
                                          : 'Failed to add attraction: $e',
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Create New Trip Button
            OutlinedButton.icon(
              onPressed: () async {
                final createdTrip = await TripFormSheet.show(
                  context,
                  initialAttractionId: attraction.id,
                );
                if (createdTrip != null && context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Created "${createdTrip.name}" and added "${attraction.name}"',
                      ),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New Trip'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

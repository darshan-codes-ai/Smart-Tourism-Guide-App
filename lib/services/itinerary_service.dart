import 'dart:math';

import '../models/attraction.dart';
import '../models/travel_preference.dart';

/// Structured outcome of deterministic itinerary generation.
class GeneratedItinerary {
  const GeneratedItinerary({
    required this.destination,
    required this.durationInDays,
    required this.daySchedule,
    required this.allAttractions,
    required this.summary,
  });

  final String destination;
  final int durationInDays;

  /// Map of day number (1-indexed: 1, 2, ..., durationInDays) -> list of planned attractions.
  final Map<int, List<Attraction>> daySchedule;

  /// Flat list of all selected attractions across the entire itinerary.
  final List<Attraction> allAttractions;

  /// Human-readable explanation of how the itinerary was scheduled.
  final String summary;

  /// List of attraction IDs across all days.
  List<String> get allAttractionIds => allAttractions.map((a) => a.id).toList();

  /// Map of day number -> list of attraction IDs for direct persistence.
  Map<int, List<String>> get dayItineraryIds =>
      daySchedule.map((day, list) => MapEntry(day, list.map((a) => a.id).toList()));
}

/// Service that deterministically generates day-by-day travel itineraries.
///
/// Operates on real attraction data, respects destination and travel preferences,
/// balances attractions across trip days, prevents duplicate visits, and avoids
/// false claims of geographic routing optimization.
class ItineraryService {
  ItineraryService._();

  static final ItineraryService instance = ItineraryService._();

  /// Generates a deterministic day-by-day itinerary.
  GeneratedItinerary generateItinerary({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required List<Attraction> availableAttractions,
    Set<TravelInterest>? interests,
    double? budget,
    int? travelerCount,
    int attractionsPerDay = 3,
  }) {
    final diff = endDate.difference(startDate).inDays;
    final days = diff < 0 ? 1 : diff + 1;

    final trimmedDest = destination.trim();
    final destQuery = trimmedDest.toLowerCase();
    final isGenericDest = destQuery.isEmpty || destQuery == 'all destinations';

    // 1. Destination Candidate Filtering
    List<Attraction> candidates = [];
    if (!isGenericDest) {
      candidates = availableAttractions.where((a) {
        final matchesCountry = a.country.toLowerCase().contains(destQuery) ||
            destQuery.contains(a.country.toLowerCase());
        final matchesCity = a.city.toLowerCase().contains(destQuery) ||
            destQuery.contains(a.city.toLowerCase());
        final matchesLocation = a.location.toLowerCase().contains(destQuery) ||
            destQuery.contains(a.location.toLowerCase());
        final matchesName = a.name.toLowerCase().contains(destQuery);
        return matchesCountry || matchesCity || matchesLocation || matchesName;
      }).toList();
    }

    bool usedFallback = false;
    if (candidates.isEmpty) {
      candidates = List<Attraction>.from(availableAttractions);
      if (!isGenericDest) usedFallback = true;
    }

    // 2. Deterministic Candidate Scoring
    final activeInterests = interests ?? const <TravelInterest>{};
    final scored = <_ScoredCandidate>[];

    for (final attraction in candidates) {
      double score = 0.0;

      // Base rating score (0 to 25 pts)
      score += (attraction.rating.clamp(0.0, 5.0) / 5.0) * 25.0;

      // Popularity score (0 to 10 pts)
      score += min(attraction.reviewCount / 5000.0, 1.0) * 10.0;

      // Interest matching (up to 40 pts)
      if (activeInterests.isNotEmpty) {
        final categoryLower = attraction.category.toLowerCase();
        final descLower = attraction.description.toLowerCase();
        final nameLower = attraction.name.toLowerCase();

        for (final interest in activeInterests) {
          // Category match
          if (interest.categories.any((c) => c.toLowerCase() == categoryLower)) {
            score += 20.0;
          }

          // Keyword match
          int keywordHits = 0;
          for (final kw in interest.keywords) {
            if (descLower.contains(kw) || nameLower.contains(kw)) {
              keywordHits++;
            }
          }
          score += min(keywordHits * 3.0, 20.0);
        }
      }

      // Budget friendliness (0 to 10 pts)
      if (budget != null && budget > 0) {
        final feeLower = attraction.entryFee.toLowerCase();
        if (feeLower.contains('free') || feeLower == '0' || feeLower == '€0' || feeLower == r'$0') {
          score += 10.0;
        } else {
          score += 5.0;
        }
      }

      scored.add(_ScoredCandidate(attraction: attraction, score: score));
    }

    // Sort deterministically: score desc, rating desc, name asc
    scored.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      final ratingCmp = b.attraction.rating.compareTo(a.attraction.rating);
      if (ratingCmp != 0) return ratingCmp;
      return a.attraction.name.compareTo(b.attraction.name);
    });

    // 3. Deduplication & Capacity Allocation
    final targetPacing = attractionsPerDay.clamp(1, 5);
    final targetTotal = days * targetPacing;
    final selectedAttractions = <Attraction>[];
    final seenIds = <String>{};

    for (final item in scored) {
      if (selectedAttractions.length >= targetTotal) break;
      if (!seenIds.contains(item.attraction.id)) {
        seenIds.add(item.attraction.id);
        selectedAttractions.add(item.attraction);
      }
    }

    // 4. Day-by-Day Balanced Distribution
    final daySchedule = <int, List<Attraction>>{
      for (int i = 1; i <= days; i++) i: <Attraction>[],
    };

    for (int i = 0; i < selectedAttractions.length; i++) {
      final dayNumber = (i % days) + 1;
      daySchedule[dayNumber]!.add(selectedAttractions[i]);
    }

    // 5. Build Summary
    final summaryBuffer = StringBuffer();
    if (selectedAttractions.isEmpty) {
      summaryBuffer.write('No attractions found matching the criteria.');
    } else {
      summaryBuffer.write(
        'Generated a balanced $days-day itinerary for ${isGenericDest ? 'your journey' : trimmedDest} '
        'featuring ${selectedAttractions.length} attraction${selectedAttractions.length == 1 ? '' : 's'}',
      );
      if (activeInterests.isNotEmpty) {
        final names = activeInterests.map((i) => i.label).join(', ');
        summaryBuffer.write(' tailored to $names');
      }
      if (usedFallback) {
        summaryBuffer.write(' (featuring top global highlights as destination-specific matches were limited)');
      }
      summaryBuffer.write('.');
    }

    return GeneratedItinerary(
      destination: trimmedDest,
      durationInDays: days,
      daySchedule: daySchedule,
      allAttractions: selectedAttractions,
      summary: summaryBuffer.toString(),
    );
  }
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.attraction,
    required this.score,
  });

  final Attraction attraction;
  final double score;
}


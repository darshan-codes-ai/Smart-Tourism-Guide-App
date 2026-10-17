import 'package:flutter/foundation.dart';

import '../models/attraction.dart';
import '../models/travel_preference.dart';

/// Service responsible for personalized tourism recommendation scoring and ranking.
///
/// Implements a deterministic, explainable scoring engine that evaluates attractions
/// against user interests, destination choices, ratings, budget, and saved places.
class RecommendationService extends ChangeNotifier {
  RecommendationService._();

  static final RecommendationService instance = RecommendationService._();

  TravelPreference _currentPreference = const TravelPreference();

  TravelPreference get currentPreference => _currentPreference;

  void updatePreference(TravelPreference preference) {
    _currentPreference = preference;
    notifyListeners();
  }

  void toggleInterest(TravelInterest interest) {
    final updated = Set<TravelInterest>.from(_currentPreference.selectedInterests);
    if (updated.contains(interest)) {
      updated.remove(interest);
    } else {
      updated.add(interest);
    }
    _currentPreference = _currentPreference.copyWith(selectedInterests: updated);
    notifyListeners();
  }

  void setDestination(String destination) {
    _currentPreference = _currentPreference.copyWith(
      selectedDestination: destination,
    );
    notifyListeners();
  }

  void setBudget(BudgetPreference budget) {
    _currentPreference = _currentPreference.copyWith(budget: budget);
    notifyListeners();
  }

  void resetPreferences() {
    _currentPreference = const TravelPreference();
    notifyListeners();
  }

  /// Evaluates and ranks a list of [attractions] according to the given [preference].
  ///
  /// Returns a sorted list of [RecommendedAttraction] with score and explanation.
  List<RecommendedAttraction> rankAttractions({
    required List<Attraction> attractions,
    required TravelPreference preference,
    Set<String>? savedAttractionIds,
  }) {
    if (attractions.isEmpty) {
      return const <RecommendedAttraction>[];
    }

    final scoredList = <RecommendedAttraction>[];

    for (final attraction in attractions) {
      // 1. Minimum rating constraint
      if (preference.minRating > 0.0 && attraction.rating < preference.minRating) {
        continue;
      }

      // 2. Destination constraint
      if (preference.selectedDestination != 'All Destinations') {
        final destQuery = preference.selectedDestination.trim().toLowerCase();
        final matchesCountry = attraction.country.toLowerCase() == destQuery;
        final matchesCity = attraction.city.toLowerCase() == destQuery;
        final matchesLocation = attraction.location.toLowerCase().contains(destQuery);
        if (!matchesCountry && !matchesCity && !matchesLocation) {
          continue;
        }
      }

      // 3. Budget constraint
      if (preference.budget == BudgetPreference.freeOnly && !isFree(attraction)) {
        continue;
      }
      if (preference.budget == BudgetPreference.budgetFriendly && !isBudgetFriendly(attraction)) {
        continue;
      }

      // Calculate score and generate explanations
      final scoreResult = calculateScoreAndExplanation(
        attraction: attraction,
        preference: preference,
        savedAttractionIds: savedAttractionIds,
      );

      scoredList.add(scoreResult);
    }

    // Sort descending by score, tie-break on rating descending, then name ascending
    scoredList.sort((a, b) {
      final scoreCmp = b.matchScore.compareTo(a.matchScore);
      if (scoreCmp != 0) return scoreCmp;
      final ratingCmp = b.attraction.rating.compareTo(a.attraction.rating);
      if (ratingCmp != 0) return ratingCmp;
      return a.attraction.name.compareTo(b.attraction.name);
    });

    return scoredList;
  }

  /// Calculates the match score (0.0 - 100.0) and natural-language explanation for [attraction].
  RecommendedAttraction calculateScoreAndExplanation({
    required Attraction attraction,
    required TravelPreference preference,
    Set<String>? savedAttractionIds,
  }) {
    double score = 0.0;
    final matchedTags = <String>[];
    final matchedInterests = <TravelInterest>[];

    // A. Interest & Category Match (0 to 45 points)
    if (preference.selectedInterests.isEmpty) {
      // Baseline points when no specific interest filter is selected
      score += 25.0;
    } else {
      double bestInterestScore = 0.0;
      for (final interest in preference.selectedInterests) {
        double interestScore = 0.0;
        final attrCatLower = attraction.category.toLowerCase().trim();

        // Direct category match: +30 points
        final isDirectCatMatch = interest.categories.any(
          (cat) => cat.toLowerCase() == attrCatLower,
        );

        if (isDirectCatMatch) {
          interestScore += 30.0;
        }

        // Keyword match in name or description: +15 points
        final textToSearch =
            '${attraction.name} ${attraction.description} ${attraction.category}'.toLowerCase();
        final hasKeywordMatch = interest.keywords.any(
          (kw) => textToSearch.contains(kw),
        );

        if (hasKeywordMatch) {
          interestScore += isDirectCatMatch ? 15.0 : 25.0;
        }

        if (interestScore > 0) {
          matchedInterests.add(interest);
          matchedTags.add(interest.label);
          if (interestScore > bestInterestScore) {
            bestInterestScore = interestScore;
          }
        }
      }

      // Score for best match plus small bonus for multi-interest match (up to 45 pts total)
      final bonus = (matchedInterests.length - 1).clamp(0, 3) * 3.0;
      score += (bestInterestScore + bonus).clamp(0.0, 45.0);
    }

    // B. Destination Match (0 to 25 points)
    if (preference.selectedDestination == 'All Destinations') {
      score += 15.0;
    } else {
      score += 25.0;
      matchedTags.add(attraction.displayLocation.isNotEmpty
          ? attraction.displayLocation
          : preference.selectedDestination);
    }

    // C. Rating Points (0 to 20 points)
    final ratingScore = (attraction.rating.clamp(0.0, 5.0) / 5.0) * 20.0;
    score += ratingScore;
    if (attraction.rating >= 4.5) {
      matchedTags.add('${attraction.rating.toStringAsFixed(1)}★ Rated');
    }

    // D. Popularity & Reviews (0 to 5 points)
    final popScore = (attraction.popularity.clamp(0.0, 100.0) / 100.0) * 5.0;
    score += popScore;

    // E. Saved Attractions Affinity (0 to 5 points)
    final isSaved = savedAttractionIds?.contains(attraction.id) ?? attraction.isSaved;
    if (isSaved) {
      score += 5.0;
      matchedTags.add('Saved Place');
    }

    // Final normalized score between 0.0 and 100.0
    final finalScore = score.clamp(0.0, 100.0);

    // Build intelligent natural language explanation
    final explanation = buildExplanation(
      attraction: attraction,
      preference: preference,
      matchedInterests: matchedInterests,
      isSaved: isSaved,
    );

    return RecommendedAttraction(
      attraction: attraction,
      matchScore: double.parse(finalScore.toStringAsFixed(1)),
      matchReason: explanation,
      matchedTags: matchedTags.toSet().toList(),
    );
  }

  /// Constructs a human-readable explanation of why the attraction was recommended.
  String buildExplanation({
    required Attraction attraction,
    required TravelPreference preference,
    required List<TravelInterest> matchedInterests,
    required bool isSaved,
  }) {
    final locationStr = attraction.displayLocation.isNotEmpty
        ? attraction.displayLocation
        : attraction.location;

    if (matchedInterests.isNotEmpty) {
      final primaryInterest = matchedInterests.first.label;
      if (preference.selectedDestination != 'All Destinations') {
        return 'Top match for your interest in $primaryInterest (${attraction.rating.toStringAsFixed(1)}★) in $locationStr.';
      }
      return 'Matches your $primaryInterest interest with an impressive ${attraction.rating.toStringAsFixed(1)}★ rating in $locationStr.';
    }

    if (isSaved) {
      return 'Saved in your favorites with top ${attraction.rating.toStringAsFixed(1)}★ visitor rating.';
    }

    if (isFree(attraction)) {
      return 'Highly rated (${attraction.rating.toStringAsFixed(1)}★) free attraction in $locationStr.';
    }

    return 'Popular ${attraction.category} landmark rated ${attraction.rating.toStringAsFixed(1)}★ in $locationStr.';
  }

  /// Checks if the attraction entry fee indicates free admission.
  bool isFree(Attraction attraction) {
    final fee = attraction.entryFee.trim().toLowerCase();
    return fee == 'free' || fee == '0' || fee == '€0' || fee == '\$0' || fee.contains('free');
  }

  /// Checks if entry fee is free or within budget (<= 30 in native units).
  bool isBudgetFriendly(Attraction attraction) {
    if (isFree(attraction)) return true;
    final match = RegExp(r'([\d.]+)').firstMatch(attraction.entryFee);
    if (match != null) {
      final parsed = double.tryParse(match.group(1)!);
      if (parsed != null) {
        return parsed <= 30.0;
      }
    }
    // If not parseable but contains free/low cost
    return attraction.entryFee.toLowerCase().contains('free');
  }
}


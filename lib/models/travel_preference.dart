import 'package:flutter/material.dart';

import 'attraction.dart';

/// Travel interests that users can select to personalize recommendations.
enum TravelInterest {
  historyAndCulture(
    id: 'history_culture',
    label: 'History & Culture',
    icon: Icons.museum_rounded,
    categories: ['Historical', 'Museum', 'Monument', 'Cultural'],
    keywords: [
      'history',
      'historical',
      'culture',
      'cultural',
      'museum',
      'monument',
      'heritage',
      'palace',
      'castle',
      'ancient',
      'archaeological',
      'ruins',
      'memorial',
      'dynasty',
      'century',
    ],
  ),
  natureAndWildlife(
    id: 'nature_wildlife',
    label: 'Nature & Wildlife',
    icon: Icons.forest_rounded,
    categories: ['Nature', 'Park', 'Wildlife'],
    keywords: [
      'nature',
      'wildlife',
      'park',
      'national park',
      'mountain',
      'forest',
      'garden',
      'botanical',
      'zoo',
      'safari',
      'lake',
      'river',
      'waterfall',
      'canyon',
      'valley',
      'fuji',
      'trail',
      'scenic',
    ],
  ),
  beaches(
    id: 'beaches',
    label: 'Beaches & Coast',
    icon: Icons.beach_access_rounded,
    categories: ['Beach', 'Nature', 'Coastal'],
    keywords: [
      'beach',
      'coast',
      'coastal',
      'bay',
      'ocean',
      'sea',
      'island',
      'shore',
      'harbor',
      'cove',
      'sand',
      'marina',
      'promenade',
    ],
  ),
  adventure(
    id: 'adventure',
    label: 'Adventure',
    icon: Icons.hiking_rounded,
    categories: ['Adventure', 'Sports'],
    keywords: [
      'adventure',
      'outdoor',
      'hiking',
      'hike',
      'climb',
      'climbing',
      'trail',
      'trek',
      'trekking',
      'ski',
      'skiing',
      'dive',
      'diving',
      'rafting',
      'suspension bridge',
      'explorer',
    ],
  ),
  architecture(
    id: 'architecture',
    label: 'Architecture',
    icon: Icons.apartment_rounded,
    categories: ['Architecture', 'Monument', 'Historical'],
    keywords: [
      'architecture',
      'architectural',
      'tower',
      'skyscraper',
      'building',
      'structure',
      'facade',
      'dome',
      'bridge',
      'design',
      'cathedral',
      'basilica',
      'opera',
      'khalifa',
      'eiffel',
      'colosseum',
    ],
  ),
  religiousAndHeritage(
    id: 'religious_heritage',
    label: 'Religious & Heritage',
    icon: Icons.temple_hindu_rounded,
    categories: ['Religious', 'Historical', 'Heritage'],
    keywords: [
      'religious',
      'temple',
      'church',
      'cathedral',
      'mosque',
      'shrine',
      'basilica',
      'monastery',
      'spiritual',
      'sacred',
      'holy',
      'sanctuary',
      'pagoda',
      'synagogue',
      'charminar',
    ],
  );

  const TravelInterest({
    required this.id,
    required this.label,
    required this.icon,
    required this.categories,
    required this.keywords,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> categories;
  final List<String> keywords;
}

/// Budget filter preferences.
enum BudgetPreference {
  any(label: 'Any Budget'),
  freeOnly(label: 'Free Only'),
  budgetFriendly(label: 'Budget (≤ €30 / \$30)');

  const BudgetPreference({required this.label});
  final String label;
}

/// Model encapsulating user's selected travel preferences for recommendation matching.
class TravelPreference {
  const TravelPreference({
    this.selectedInterests = const <TravelInterest>{},
    this.selectedDestination = 'All Destinations',
    this.budget = BudgetPreference.any,
    this.minRating = 0.0,
  });

  final Set<TravelInterest> selectedInterests;
  final String selectedDestination;
  final BudgetPreference budget;
  final double minRating;

  bool get hasActiveFilters =>
      selectedInterests.isNotEmpty ||
      selectedDestination != 'All Destinations' ||
      budget != BudgetPreference.any ||
      minRating > 0.0;

  TravelPreference copyWith({
    Set<TravelInterest>? selectedInterests,
    String? selectedDestination,
    BudgetPreference? budget,
    double? minRating,
  }) {
    return TravelPreference(
      selectedInterests: selectedInterests ?? this.selectedInterests,
      selectedDestination: selectedDestination ?? this.selectedDestination,
      budget: budget ?? this.budget,
      minRating: minRating ?? this.minRating,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedInterests': selectedInterests.map((i) => i.id).toList(),
      'selectedDestination': selectedDestination,
      'budget': budget.name,
      'minRating': minRating,
    };
  }

  factory TravelPreference.fromMap(Map<String, dynamic> map) {
    final rawInterests = map['selectedInterests'] as List<dynamic>? ?? [];
    final interests = rawInterests
        .map((id) {
          try {
            return TravelInterest.values.firstWhere((i) => i.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<TravelInterest>()
        .toSet();

    final budgetName = map['budget'] as String? ?? 'any';
    final budget = BudgetPreference.values.firstWhere(
      (b) => b.name == budgetName,
      orElse: () => BudgetPreference.any,
    );

    return TravelPreference(
      selectedInterests: interests,
      selectedDestination:
          map['selectedDestination'] as String? ?? 'All Destinations',
      budget: budget,
      minRating: (map['minRating'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A recommendation result pairing an [Attraction] with its match score and explanation.
class RecommendedAttraction {
  const RecommendedAttraction({
    required this.attraction,
    required this.matchScore,
    required this.matchReason,
    required this.matchedTags,
  });

  final Attraction attraction;

  /// Match score ranging from 0.0 to 100.0.
  final double matchScore;

  /// Natural-language explanation for why this attraction was recommended.
  final String matchReason;

  /// Highlights explaining the match (e.g. ['History & Culture', '4.8★ Rated', 'Free Entry']).
  final List<String> matchedTags;
}


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/dummy_data.dart';
import '../../models/attraction.dart';
import '../../models/travel_preference.dart';
import '../../services/attraction_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/add_to_trip_sheet.dart';
import '../../widgets/attraction_card.dart';
import '../../widgets/trip_form_sheet.dart';
import '../main/trip_details_screen.dart';

/// Screen displaying personalized tourism recommendations powered by the [RecommendationService].
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  static const List<String> _destinations = [
    'All Destinations',
    'France',
    'Italy',
    'Japan',
    'United States',
    'United Kingdom',
    'United Arab Emirates',
    'India',
    'Australia',
    'Brazil',
    'Egypt',
    'Spain',
    'Singapore',
    'Turkey',
  ];

  Future<void> _handlePlanTrip(BuildContext context, TravelPreference preference) async {
    final isAuthenticated = TripService.instance.isAuthenticated;
    if (!isAuthenticated) {
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sign in Required'),
          content: const Text(
            'Please sign in to plan and create trips from your recommendations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.push(AppRouter.login);
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
      return;
    }

    final destination = preference.selectedDestination != 'All Destinations'
        ? preference.selectedDestination
        : null;

    final createdTrip = await TripFormSheet.show(
      context,
      initialDestination: destination,
    );
    if (createdTrip != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripDetailsScreen(
            tripId: createdTrip.id,
            initialTrip: createdTrip,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recService = RecommendationService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([recService, SavedPlacesStore.instance]),
      builder: (context, _) {
        final preference = recService.currentPreference;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('AI Travel Recommendations'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(AppRouter.home);
                }
              },
            ),
            actions: [
              IconButton(
                key: const Key('recommendations_plan_trip_button'),
                tooltip: 'Plan Trip',
                icon: const Icon(Icons.luggage_outlined),
                onPressed: () => _handlePlanTrip(context, preference),
              ),
              if (preference.hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    key: const Key('recommendations_appbar_reset_button'),
                    onPressed: () => recService.resetPreferences(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset'),
                  ),
                ),
            ],
          ),
          body: StreamBuilder<List<Attraction>>(
            stream: AttractionService.instance.watchAttractions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(key: Key('recommendations_loading_indicator')),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load attractions for recommendations:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allAttractions = snapshot.data ?? <Attraction>[];
              final savedIds = SavedPlacesStore.instance.savedIds;

              // Rank recommendations using the deterministic scoring engine
              final recommendations = recService.rankAttractions(
                attractions: allAttractions,
                preference: preference,
                savedAttractionIds: savedIds,
              );

              return CustomScrollView(
                slivers: [
                  // 1. Personalized Preferences Header
                  SliverToBoxAdapter(
                    child: _buildPreferencesSection(context, preference, recService),
                  ),

                  // 2. Recommendations Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 18,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tailored For You (${recommendations.length})',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preference.selectedInterests.isEmpty
                                      ? 'Showing top world attractions. Tap interests above to personalize!'
                                      : 'Ranked by interest match, visitor ratings, and destination fit.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Recommended Attractions List or Empty State
                  if (recommendations.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.travel_explore_rounded,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No matching attractions found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Try selecting different interests or clearing the destination/budget filter.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                key: const Key('recommendations_empty_reset_button'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                                onPressed: () => recService.resetPreferences(),
                                child: const Text('Reset Preferences'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      sliver: SliverList.separated(
                        itemCount: recommendations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = recommendations[index];
                          return _buildRecommendationCard(context, item);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    TravelPreference preference,
    RecommendationService recService,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Travel Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Select what excites you to get tailored suggestions',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Interest Chips (Multi-select)
          const Text(
            'Interests & Styles',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TravelInterest.values.map((interest) {
              final isSelected = preference.selectedInterests.contains(interest);
              return FilterChip(
                key: Key('preference_interest_${interest.id}'),
                avatar: Icon(
                  interest.icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppTheme.primary,
                ),
                label: Text(interest.label),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
                backgroundColor: AppTheme.background,
                onSelected: (_) => recService.toggleInterest(interest),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Destination & Budget Filters Row
          Row(
            children: [
              // Destination Dropdown
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destination',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('preference_destination_dropdown'),
                          value: preference.selectedDestination,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: (_destinations.contains(preference.selectedDestination)
                                  ? _destinations
                                  : [..._destinations, preference.selectedDestination])
                              .map((dest) {
                            return DropdownMenuItem<String>(
                              value: dest,
                              child: Text(
                                dest,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (dest) {
                            if (dest != null) {
                              recService.setDestination(dest);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Budget Filter
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<BudgetPreference>(
                          key: const Key('preference_budget_dropdown'),
                          value: preference.budget,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: BudgetPreference.values.map((b) {
                            return DropdownMenuItem<BudgetPreference>(
                              value: b,
                              child: Text(
                                b.label,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (b) {
                            if (b != null) {
                              recService.setBudget(b);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context, RecommendedAttraction item) {
    final attraction = item.attraction;
    final isSaved = SavedPlacesStore.instance.isSaved(attraction.id);

    return Material(
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        key: Key('recommended_card_${attraction.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => showAttractionDetails(context, attraction),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Match Score Badge & Favorite Heart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary,
                          AppTheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${item.matchScore.toStringAsFixed(0)}% Match',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Favorite Toggle
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: Key('recommended_favorite_button_${attraction.id}'),
                          icon: Icon(
                            isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isSaved ? Colors.redAccent : Colors.grey.shade600,
                            size: 22,
                          ),
                          onPressed: () => SavedPlacesStore.instance.toggle(attraction.id),
                          tooltip: isSaved ? 'Remove from favorites' : 'Save to favorites',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Middle: Thumbnail and Attraction Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Image.network(
                        attraction.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFFD7EBEA),
                          child: const Icon(
                            Icons.landscape_rounded,
                            size: 36,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attraction.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                attraction.displayLocation.isNotEmpty
                                    ? attraction.displayLocation
                                    : attraction.location,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A524)),
                            const SizedBox(width: 2),
                            Text(
                              attraction.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.payments_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              attraction.formattedFee,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Why Recommended Explanation Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.matchReason,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Actions Footer: Add to Trip and View Details
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: Key('recommended_add_to_trip_button_${attraction.id}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final isAuthenticated = TripService.instance.isAuthenticated;
                      if (!isAuthenticated) {
                        showDialog<void>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Sign in Required'),
                            content: const Text(
                              'Please sign in to add attractions to your trips and itineraries.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogCtx).pop();
                                  context.push(AppRouter.login);
                                },
                                child: const Text('Sign In'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      AddToTripSheet.show(context, attraction);
                    },
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: const Text('Add to Trip', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: Key('recommended_view_details_button_${attraction.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => showAttractionDetails(context, attraction),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Details', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

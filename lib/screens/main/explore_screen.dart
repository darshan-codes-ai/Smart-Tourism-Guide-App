import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/dummy_data.dart';
import '../../models/attraction.dart';
import '../../services/attraction_service.dart';
import '../../widgets/attraction_card.dart';
import '../../widgets/category_chip.dart';
import 'map_screen.dart';

enum ExploreSort { rating, distance }

enum ExploreViewMode { list, map }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  ExploreSort _sort = ExploreSort.rating;
  ExploreViewMode _viewMode = ExploreViewMode.list;
  int _retryKey = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static double _parseDistanceNum(String distance) {
    final match = RegExp(r'([\d.]+)').firstMatch(distance);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? double.infinity;
    }
    return double.infinity;
  }

  List<Attraction> _filterAndSort(List<Attraction> source) {
    final query = _searchController.text.trim().toLowerCase();
    final results = source.where((attraction) {
      final matchesCategory =
          _selectedCategory == null || attraction.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          attraction.name.toLowerCase().contains(query) ||
          attraction.category.toLowerCase().contains(query) ||
          attraction.location.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    results.sort((a, b) {
      if (_sort == ExploreSort.rating) {
        return b.rating.compareTo(a.rating);
      }
      final distA = _parseDistanceNum(a.distance);
      final distB = _parseDistanceNum(b.distance);
      final numCompare = distA.compareTo(distB);
      if (numCompare != 0) return numCompare;
      return a.distance.compareTo(b.distance);
    });
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Explore',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _ExploreViewToggle(
                      selectedView: _viewMode,
                      onChanged: (mode) => setState(() => _viewMode = mode),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Search, filter, and browse places across the city.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search places, attractions...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: AppConstants.categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = AppConstants.categories[index];
                            return CategoryChip(
                              label: category,
                              icon: CategoryChip.iconFor(category),
                              selected: _selectedCategory == category,
                              onTap: () {
                                setState(() {
                                  _selectedCategory =
                                      _selectedCategory == category
                                      ? null
                                      : category;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Sort',
                      onPressed: () => _showSortSheet(),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Attraction>>(
              key: ValueKey(_retryKey),
              stream: AttractionService.instance.watchAttractions(),
              builder: (context, snapshot) {
                final hasData = snapshot.hasData;
                final allAttractions = snapshot.data ?? const <Attraction>[];
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !hasData;
                final hasError = snapshot.hasError && !hasData;

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 56,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load attractions',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Could not retrieve attraction data from Firestore.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => setState(() => _retryKey++),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (allAttractions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.explore_off_rounded,
                            size: 56,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No attractions available yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No attraction documents found in Firestore.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _retryKey++),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                SavedPlacesStore.instance.registerAttractions(allAttractions);

                final attractions = _filterAndSort(allAttractions);

                if (_viewMode == ExploreViewMode.map) {
                  return MapScreen(attractions: attractions);
                }

                if (attractions.isEmpty) {
                  return const Center(
                    child: Text('No attractions match your filters yet.'),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final useGrid = constraints.maxWidth >= 700;
                    if (useGrid) {
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisExtent: 248,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: attractions.length,
                        itemBuilder: (context, index) {
                          return AttractionCard(
                            attraction: attractions[index],
                            layout: AttractionCardLayout.horizontal,
                          );
                        },
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: attractions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return AttractionCard(attraction: attractions[index]);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<ExploreSort>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.star_rounded),
                title: const Text('Sort by rating'),
                trailing: _sort == ExploreSort.rating
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, ExploreSort.rating),
              ),
              ListTile(
                leading: const Icon(Icons.near_me_rounded),
                title: const Text('Sort by distance'),
                trailing: _sort == ExploreSort.distance
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, ExploreSort.distance),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      setState(() => _sort = selected);
    }
  }
}

class _ExploreViewToggle extends StatelessWidget {
  const _ExploreViewToggle({
    required this.selectedView,
    required this.onChanged,
  });

  final ExploreViewMode selectedView;
  final ValueChanged<ExploreViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFF2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: 'List',
            icon: Icons.view_list_rounded,
            isSelected: selectedView == ExploreViewMode.list,
            onTap: () => onChanged(ExploreViewMode.list),
          ),
          _ToggleButton(
            label: 'Map',
            icon: Icons.map_rounded,
            isSelected: selectedView == ExploreViewMode.map,
            onTap: () => onChanged(ExploreViewMode.map),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

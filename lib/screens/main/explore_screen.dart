import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/dummy_data.dart';
import '../../models/attraction.dart';
import '../../widgets/attraction_card.dart';
import '../../widgets/category_chip.dart';

enum ExploreSort { rating, distance }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  ExploreSort _sort = ExploreSort.rating;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Attraction> get _filteredAttractions {
    final query = _searchController.text.trim().toLowerCase();
    var results = DummyData.attractions.where((attraction) {
      final matchesCategory =
          _selectedCategory == null ||
          attraction.category == _selectedCategory;
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
      return a.distance.compareTo(b.distance);
    });
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final attractions = _filteredAttractions;
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search, filter, and browse places. Maps and live data will connect later.',
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useGrid = constraints.maxWidth >= 700;
                if (attractions.isEmpty) {
                  return const Center(
                    child: Text('No attractions match your filters yet.'),
                  );
                }
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

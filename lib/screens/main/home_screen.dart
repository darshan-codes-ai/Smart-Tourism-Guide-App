import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/dummy_data.dart';
import '../../widgets/attraction_card.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSeeAllNearby});

  final VoidCallback? onSeeAllNearby;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCategory;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearby = _selectedCategory == null
        ? DummyData.nearby
        : DummyData.nearby
            .where((item) => item.category == _selectedCategory)
            .toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Where do you want to explore?',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppConstants.defaultCity,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Notifications will be connected later.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFF176B87),
                        child: Text(
                          'AS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search places, attractions...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
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
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Recommended',
                    onAction: widget.onSeeAllNearby,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 248,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                scrollDirection: Axis.horizontal,
                itemCount: DummyData.recommended.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return AttractionCard(
                    attraction: DummyData.recommended[index],
                    layout: AttractionCardLayout.horizontal,
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Nearby',
                onAction: widget.onSeeAllNearby,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.separated(
              itemCount: nearby.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return AttractionCard(attraction: nearby[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

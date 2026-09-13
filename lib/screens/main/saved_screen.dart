import 'package:flutter/material.dart';

import '../../data/dummy_data.dart';
import '../../widgets/attraction_card.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListenableBuilder(
        listenable: SavedPlacesStore.instance,
        builder: (context, _) {
          final saved = SavedPlacesStore.instance.savedAttractions;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Saved Places',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save places you love and find them here later.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: saved.isEmpty
                      ? _EmptySavedState(theme: theme)
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: saved.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return AttractionCard(attraction: saved[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No saved places yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Save places you love and find them here later.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

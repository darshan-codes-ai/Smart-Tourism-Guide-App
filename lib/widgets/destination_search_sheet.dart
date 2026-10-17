import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/destination_result.dart';
import '../services/geocoding_service.dart';
import 'trip_form_sheet.dart';
import 'weather_section.dart';

/// Interactive modal sheet enabling worldwide destination geocoding and weather inspection.
class DestinationSearchSheet extends StatefulWidget {
  const DestinationSearchSheet({
    super.key,
    this.initialQuery,
    this.onDestinationSelected,
  });

  final String? initialQuery;
  final ValueChanged<DestinationResult>? onDestinationSelected;

  static Future<DestinationResult?> show(
    BuildContext context, {
    String? initialQuery,
    ValueChanged<DestinationResult>? onDestinationSelected,
  }) {
    return showModalBottomSheet<DestinationResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DestinationSearchSheet(
        initialQuery: initialQuery,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;
  List<DestinationResult> _results = const [];
  bool _isLoading = false;
  String? _errorMessage;
  DestinationResult? _selectedDestination;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (_searchController.text.trim().length >= 2) {
      _executeSearch(_searchController.text.trim());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();

    if (trimmed.length < 2) {
      setState(() {
        _results = const [];
        _isLoading = false;
        _errorMessage = null;
        _selectedDestination = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(trimmed);
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedDestination = null;
    });

    try {
      final results = await GeocodingService.instance.searchDestinations(
        query,
        count: 6,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is GeocodingException
              ? e.message
              : 'Unable to complete geocoding search.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.travel_explore_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Destination Search & Weather',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Search any destination worldwide using Open-Meteo Geocoding to view live forecast and plan trips.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              key: const Key('destination_search_input_field'),
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search city or destination (e.g. Tokyo, Rome)...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Loading state
            if (_isLoading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Searching global destinations...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                ),
              ),
            ] else if (_selectedDestination != null) ...[
              // Destination Selected: Show Weather & Actions
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedDestination!.displayName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Coordinates: ${_selectedDestination!.latitude.toStringAsFixed(4)}, ${_selectedDestination!.longitude.toStringAsFixed(4)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedDestination = null),
                            child: const Text('Back to list'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      WeatherSection(
                        latitude: _selectedDestination!.latitude,
                        longitude: _selectedDestination!.longitude,
                        destinationName: _selectedDestination!.name,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                widget.onDestinationSelected?.call(
                                  _selectedDestination!,
                                );
                                Navigator.of(context).pop(_selectedDestination);
                              },
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                              label: const Text('Select Destination'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final dest = _selectedDestination!;
                                Navigator.of(context).pop(dest);
                                TripFormSheet.show(
                                  context,
                                  initialDestination: dest.name,
                                );
                              },
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Plan Trip'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_results.isNotEmpty) ...[
              // Results list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      key: Key('destination_result_tile_${item.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.place_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Text(
                        '${item.latitude.toStringAsFixed(2)}°, ${item.longitude.toStringAsFixed(2)}°',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedDestination = item);
                      },
                    );
                  },
                ),
              ),
            ] else if (_searchController.text.trim().length >= 2) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No destinations found matching "${_searchController.text.trim()}".',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

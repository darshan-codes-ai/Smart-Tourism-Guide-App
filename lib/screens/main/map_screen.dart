import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/dummy_data.dart';
import '../../models/attraction.dart';
import '../../services/attraction_service.dart';
import '../../widgets/attraction_card.dart';
import '../../widgets/category_chip.dart';

/// Interactive map screen showing attraction markers on OpenStreetMap tiles.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.attractions,
    this.initialSelectedAttraction,
    this.showAppBar = false,
  });

  /// Optional list of attractions (e.g. filtered by ExploreScreen).
  /// If null, streams directly from [AttractionService.instance.watchAttractions].
  final List<Attraction>? attractions;

  /// Optional attraction to focus and highlight initially.
  final Attraction? initialSelectedAttraction;

  /// Whether to display a top AppBar (useful when opened as a dedicated route).
  final bool showAppBar;

  static const LatLng hyderabadFallback = LatLng(17.3850, 78.4867);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Attraction? _selectedAttraction;
  LatLng? _currentLocation;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedAttraction = widget.initialSelectedAttraction;
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedAttraction != null &&
        widget.initialSelectedAttraction != _selectedAttraction) {
      _selectedAttraction = widget.initialSelectedAttraction;
      _moveToAttraction(_selectedAttraction!);
    }
  }

  void _moveToAttraction(Attraction attraction) {
    if (attraction.latitude != null && attraction.longitude != null) {
      _mapController.move(
        LatLng(attraction.latitude!, attraction.longitude!),
        14.5,
      );
    }
  }

  LatLng _computeInitialCenter(List<Attraction> list) {
    if (widget.initialSelectedAttraction != null &&
        widget.initialSelectedAttraction!.latitude != null &&
        widget.initialSelectedAttraction!.longitude != null) {
      return LatLng(
        widget.initialSelectedAttraction!.latitude!,
        widget.initialSelectedAttraction!.longitude!,
      );
    }

    final valid = list
        .where((a) => a.latitude != null && a.longitude != null)
        .toList();

    if (valid.isEmpty) {
      return MapScreen.hyderabadFallback;
    }

    double sumLat = 0.0;
    double sumLng = 0.0;
    for (final a in valid) {
      sumLat += a.latitude!;
      sumLng += a.longitude!;
    }
    return LatLng(sumLat / valid.length, sumLng / valid.length);
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showNotification('Location services are disabled on this device.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showNotification('Location permission was denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showNotification(
          'Location permissions are permanently denied. Please enable them in device settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() => _currentLocation = latLng);
      _mapController.move(latLng, 14.5);
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showNotification('Could not determine current location.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showNotification(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.attractions != null) {
      return _buildScaffold(context, theme, widget.attractions!);
    }

    return StreamBuilder<List<Attraction>>(
      stream: AttractionService.instance.watchAttractions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load attraction markers.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final attractions = snapshot.data ?? const <Attraction>[];
        return _buildScaffold(context, theme, attractions);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ThemeData theme,
    List<Attraction> attractions,
  ) {
    final initialCenter = _computeInitialCenter(attractions);

    // Build markers for valid coordinates only
    final markers = <Marker>[];

    for (final attraction in attractions) {
      if (attraction.latitude != null && attraction.longitude != null) {
        final isSelected = _selectedAttraction?.id == attraction.id;
        markers.add(
          Marker(
            point: LatLng(attraction.latitude!, attraction.longitude!),
            width: isSelected ? 48 : 40,
            height: isSelected ? 48 : 40,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedAttraction = attraction);
                _moveToAttraction(attraction);
              },
              child: _MarkerPin(
                attraction: attraction,
                isSelected: isSelected,
              ),
            ),
          ),
        );
      }
    }

    // User location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final content = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 12.5,
            minZoom: 4.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: (_, _) {
              if (_selectedAttraction != null) {
                setState(() => _selectedAttraction = null);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.tourmate',
            ),
            MarkerLayer(markers: markers),
            const SimpleAttributionWidget(
              source: Text('© OpenStreetMap contributors'),
              alignment: Alignment.bottomRight,
            ),
          ],
        ),

        // Floating current location button
        Positioned(
          right: 16,
          top: 16,
          child: Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: theme.colorScheme.surface,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _getCurrentLocation,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _isLocating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(
                        Icons.my_location_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
              ),
            ),
          ),
        ),

        // Floating preview card when marker is selected
        if (_selectedAttraction != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _MapAttractionPreviewCard(
              attraction: _selectedAttraction!,
              onClose: () => setState(() => _selectedAttraction = null),
              onTap: () => showAttractionDetails(context, _selectedAttraction!),
            ),
          ),
      ],
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Map View'),
        ),
        body: content,
      );
    }

    return content;
  }
}

/// Custom map marker pin styled with TourMate primary palette.
class _MarkerPin extends StatelessWidget {
  const _MarkerPin({
    required this.attraction,
    required this.isSelected,
  });

  final Attraction attraction;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = isSelected ? const Color(0xFFE53935) : theme.colorScheme.primary;

    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: isSelected ? 48 : 40,
            color: primaryColor,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          Positioned(
            top: isSelected ? 9 : 7,
            child: Icon(
              CategoryChip.iconFor(attraction.category),
              size: isSelected ? 17 : 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom preview card shown when an attraction marker is selected.
class _MapAttractionPreviewCard extends StatelessWidget {
  const _MapAttractionPreviewCard({
    required this.attraction,
    required this.onClose,
    required this.onTap,
  });

  final Attraction attraction;
  final VoidCallback onClose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: attraction.imageUrl.isNotEmpty
                      ? Image.network(
                          attraction.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _FallbackThumbnail(
                            category: attraction.category,
                          ),
                        )
                      : _FallbackThumbnail(category: attraction.category),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attraction.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attraction.category} · ${attraction.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF5A524),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          attraction.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.near_me_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            attraction.distance,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions (Heart + Close)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Close preview',
                  ),
                  ListenableBuilder(
                    listenable: SavedPlacesStore.instance,
                    builder: (context, _) {
                      final saved = SavedPlacesStore.instance.isSaved(attraction.id);
                      return IconButton(
                        icon: Icon(
                          saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: saved ? const Color(0xFFE53935) : theme.colorScheme.primary,
                          size: 22,
                        ),
                        onPressed: () => SavedPlacesStore.instance.toggle(attraction.id),
                        visualDensity: VisualDensity.compact,
                        tooltip: saved ? 'Remove from saved' : 'Save place',
                      );
                    },
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

class _FallbackThumbnail extends StatelessWidget {
  const _FallbackThumbnail({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFD7EBEA),
      child: Center(
        child: Icon(
          CategoryChip.iconFor(category),
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

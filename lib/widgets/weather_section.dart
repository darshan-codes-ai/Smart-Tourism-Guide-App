import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/weather.dart';
import '../services/geocoding_service.dart';
import '../services/weather_service.dart';

/// Reusable weather component displaying real-time weather and 7-day forecast.
///
/// Supports automatic geocoding fallback if [latitude] and [longitude] are omitted,
/// using [destinationName].
class WeatherSection extends StatefulWidget {
  const WeatherSection({
    super.key,
    this.latitude,
    this.longitude,
    this.destinationName,
    this.compact = false,
    this.showTitle = true,
  });

  final double? latitude;
  final double? longitude;
  final String? destinationName;
  final bool compact;
  final bool showTitle;

  @override
  State<WeatherSection> createState() => _WeatherSectionState();
}

class _WeatherSectionState extends State<WeatherSection> {
  WeatherData? _weatherData;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isStale = false;
  double? _resolvedLat;
  double? _resolvedLng;

  static const String _attributionUrl = 'https://open-meteo.com/';

  @override
  void initState() {
    super.initState();
    _resolvedLat = widget.latitude;
    _resolvedLng = widget.longitude;
    _loadWeather();
  }

  @override
  void didUpdateWidget(covariant WeatherSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.destinationName != widget.destinationName) {
      _resolvedLat = widget.latitude;
      _resolvedLng = widget.longitude;
      _loadWeather();
    }
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    // If no coordinates provided, attempt geocoding by destination name
    if ((_resolvedLat == null || _resolvedLng == null) &&
        widget.destinationName != null &&
        widget.destinationName!.trim().isNotEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final geocoded = await GeocodingService.instance.geocodeDestination(
          widget.destinationName!.trim(),
        );
        if (geocoded != null) {
          _resolvedLat = geocoded.latitude;
          _resolvedLng = geocoded.longitude;
        }
      } catch (_) {
        // Geocoding failure will be handled by coordinates check below
      }
    }

    if (_resolvedLat == null || _resolvedLng == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _weatherData = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await WeatherService.instance.getWeather(
        latitude: _resolvedLat!,
        longitude: _resolvedLng!,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
          _isStale = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Try fallback to stale cached data if available
        final stale = WeatherService.instance.getStaleWeather(
          _resolvedLat!,
          _resolvedLng!,
        );
        setState(() {
          _isLoading = false;
          if (stale != null) {
            _weatherData = stale;
            _isStale = true;
            _errorMessage = null;
          } else {
            _errorMessage = e is WeatherException ? e.message : 'Unable to load weather forecast. Please check your network connection.';
          }
        });
      }
    }
  }

  Future<void> _openAttribution() async {
    try {
      final uri = Uri.parse(_attributionUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      // Graceful fallback if URL launcher unavailable in test environment
    }
  }

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String _formatDayName(DateTime date, int index) {
    if (index == 0) return 'Today';
    return _weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Empty state: missing destination or coordinates
    if (_resolvedLat == null || _resolvedLng == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Weather forecast unavailable for this destination.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Loading state without existing data
    if (_isLoading && _weatherData == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 12),
              Text(
                'Loading weather forecast...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Error state without stale data
    if (_errorMessage != null && _weatherData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Weather information unavailable',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 13, color: Colors.red.shade800),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('weather_retry_button'),
                onPressed: () => _loadWeather(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    final weather = _weatherData!;
    final current = weather.current;
    final condition = current.condition;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Location / Title + Refresh action
          Row(
            children: [
              Icon(
                Icons.thermostat_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.destinationName != null &&
                          widget.destinationName!.isNotEmpty
                      ? '${widget.destinationName} Weather'
                      : 'Local Weather',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  key: const Key('weather_refresh_button'),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Refresh Weather',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _loadWeather(forceRefresh: true),
                ),
            ],
          ),

          // Stale data indicator
          if (_isStale) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 14,
                    color: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Offline — Showing cached weather',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Primary Conditions Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(condition.icon, size: 44, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${current.temperature.round()}°C',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (current.apparentTemperature != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Feels like ${current.apparentTemperature!.round()}°C',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      condition.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Secondary Metrics (Humidity, Wind, Precipitation, Min/Max)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (current.relativeHumidity != null)
                _MetricPill(
                  icon: Icons.water_drop_outlined,
                  label: '${current.relativeHumidity}% humidity',
                ),
              if (current.windSpeed != null)
                _MetricPill(
                  icon: Icons.air_rounded,
                  label: '${current.windSpeed!.round()} km/h wind',
                ),
              if (current.precipitation != null && current.precipitation! > 0)
                _MetricPill(
                  icon: Icons.grain_rounded,
                  label:
                      '${current.precipitation!.toStringAsFixed(1)} mm precip',
                ),
              if (weather.daily.isNotEmpty)
                _MetricPill(
                  icon: Icons.swap_vert_rounded,
                  label:
                      'H: ${weather.daily.first.maxTemperature.round()}°  L: ${weather.daily.first.minTemperature.round()}°',
                ),
            ],
          ),

          // Multi-day Forecast Section
          if (weather.daily.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              '7-Day Forecast',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: weather.daily.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = weather.daily[index];
                  final dayCondition = day.condition;
                  return Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: index == 0
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatDayName(day.date, index),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: index == 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: index == 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          dayCondition.icon,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.maxTemperature.round()}° / ${day.minTemperature.round()}°',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Attribution
          InkWell(
            key: const Key('open_meteo_attribution_link'),
            onTap: _openAttribution,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Weather data by Open-Meteo',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 11,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

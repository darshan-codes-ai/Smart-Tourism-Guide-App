import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/weather.dart';
import '../services/geocoding_service.dart';
import '../services/weather_service.dart';

/// Weather forecast card integrated directly into Trip details.
///
/// Correlates trip itinerary dates with the 7-day forecast horizon,
/// highlighting day-by-day weather for scheduled trip days.
class TripWeatherCard extends StatefulWidget {
  const TripWeatherCard({
    super.key,
    required this.trip,
    this.fallbackLatitude,
    this.fallbackLongitude,
  });

  final Trip trip;
  final double? fallbackLatitude;
  final double? fallbackLongitude;

  @override
  State<TripWeatherCard> createState() => _TripWeatherCardState();
}

class _TripWeatherCardState extends State<TripWeatherCard> {
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
    _resolvedLat = widget.fallbackLatitude;
    _resolvedLng = widget.fallbackLongitude;
    _loadWeather();
  }

  @override
  void didUpdateWidget(covariant TripWeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.destination != widget.trip.destination ||
        oldWidget.fallbackLatitude != widget.fallbackLatitude ||
        oldWidget.fallbackLongitude != widget.fallbackLongitude) {
      _resolvedLat = widget.fallbackLatitude;
      _resolvedLng = widget.fallbackLongitude;
      _loadWeather();
    }
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    // Resolve coordinates if missing
    if (_resolvedLat == null || _resolvedLng == null) {
      if (widget.trip.destination.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _weatherData = null;
          });
        }
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final geocoded = await GeocodingService.instance.geocodeDestination(
          widget.trip.destination.trim(),
        );
        if (geocoded != null) {
          _resolvedLat = geocoded.latitude;
          _resolvedLng = geocoded.longitude;
        }
      } catch (_) {
        // Handled below
      }
    }

    if (_resolvedLat == null || _resolvedLng == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
            _errorMessage = e is WeatherException
                ? e.message
                : 'Unable to load weather forecast for this destination.';
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
    } catch (_) {}
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDateShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trip = widget.trip;

    // Missing destination / coordinates
    if (_resolvedLat == null || _resolvedLng == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
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
                'Destination coordinates for "${trip.destination}" could not be located. Weather forecast unavailable.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (_isLoading && _weatherData == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Checking destination weather...',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_errorMessage != null && _weatherData == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade700,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(fontSize: 13, color: Colors.red.shade900),
              ),
            ),
            TextButton(
              key: const Key('trip_weather_retry_button'),
              onPressed: () => _loadWeather(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final weather = _weatherData!;
    final current = weather.current;
    final condition = current.condition;

    // Analyze dates relative to today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripStart = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );
    final tripEnd = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    final daysUntilTrip = tripStart.difference(today).inDays;
    final isTripConcluded = tripEnd.isBefore(today);
    final isBeyondForecast = daysUntilTrip > 6;

    // Collect daily forecast matches for scheduled trip days
    final scheduledMatches = <MapEntry<int, DailyForecast>>[];
    for (int dayIndex = 1; dayIndex <= trip.durationInDays; dayIndex++) {
      final scheduledDate = tripStart.add(Duration(days: dayIndex - 1));
      final forecast = weather.forecastForDate(scheduledDate);
      if (forecast != null) {
        scheduledMatches.add(MapEntry(dayIndex, forecast));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Refresh
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trip.destination} Weather Forecast',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const Key('trip_weather_refresh_button'),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Weather',
                visualDensity: VisualDensity.compact,
                onPressed: () => _loadWeather(forceRefresh: true),
              ),
            ],
          ),

          if (_isStale) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Offline — Displaying cached weather',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // Current Conditions Bar
          Row(
            children: [
              Icon(condition.icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${current.temperature.round()}°C',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        condition.description,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (current.apparentTemperature != null)
                    Text(
                      'Feels like ${current.apparentTemperature!.round()}°C · Wind: ${current.windSpeed?.round() ?? 0} km/h',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Itinerary Date Forecasts / Context Banners
          if (isTripConcluded) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This trip concluded on ${trip.formattedDateRange}. Showing live current destination weather.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isBeyondForecast) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip starts in $daysUntilTrip days (${_formatDateShort(trip.startDate)}) — beyond the 7-day forecast horizon. Showing current destination weather.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (scheduledMatches.isNotEmpty) ...[
            Text(
              'Forecast for your Trip Days:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: scheduledMatches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = scheduledMatches[index];
                  final dayNum = entry.key;
                  final forecast = entry.value;
                  return Container(
                    width: 94,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.25,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Day $dayNum (${forecast.date.day} ${_months[forecast.date.month - 1]})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          forecast.condition.icon,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${forecast.maxTemperature.round()}° / ${forecast.minTemperature.round()}°',
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

          const SizedBox(height: 10),

          // Attribution
          InkWell(
            key: const Key('trip_weather_open_meteo_attribution'),
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

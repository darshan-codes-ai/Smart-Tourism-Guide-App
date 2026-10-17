import 'package:flutter/material.dart';

/// Human-readable weather condition mapping and icon representation based on WMO 4677 weather codes.
class WeatherCondition {
  const WeatherCondition({
    required this.code,
    required this.description,
    required this.icon,
  });

  final int code;
  final String description;
  final IconData icon;

  /// Maps standard WMO weather interpretation codes to human-readable labels and icons.
  ///
  /// Reference: https://open-meteo.com/en/docs
  factory WeatherCondition.fromWmoCode(int? code) {
    if (code == null) {
      return const WeatherCondition(
        code: -1,
        description: 'Unknown',
        icon: Icons.help_outline_rounded,
      );
    }

    switch (code) {
      case 0:
        return const WeatherCondition(
          code: 0,
          description: 'Clear sky',
          icon: Icons.wb_sunny_rounded,
        );
      case 1:
        return const WeatherCondition(
          code: 1,
          description: 'Mainly clear',
          icon: Icons.wb_sunny_outlined,
        );
      case 2:
        return const WeatherCondition(
          code: 2,
          description: 'Partly cloudy',
          icon: Icons.wb_cloudy_rounded,
        );
      case 3:
        return const WeatherCondition(
          code: 3,
          description: 'Overcast',
          icon: Icons.cloud_rounded,
        );
      case 45:
        return const WeatherCondition(
          code: 45,
          description: 'Fog',
          icon: Icons.blur_on_rounded,
        );
      case 48:
        return const WeatherCondition(
          code: 48,
          description: 'Depositing rime fog',
          icon: Icons.blur_linear_rounded,
        );
      case 51:
        return const WeatherCondition(
          code: 51,
          description: 'Light drizzle',
          icon: Icons.grain_rounded,
        );
      case 53:
        return const WeatherCondition(
          code: 53,
          description: 'Moderate drizzle',
          icon: Icons.grain_rounded,
        );
      case 55:
        return const WeatherCondition(
          code: 55,
          description: 'Dense drizzle',
          icon: Icons.water_drop_outlined,
        );
      case 56:
      case 57:
        return const WeatherCondition(
          code: 56,
          description: 'Freezing drizzle',
          icon: Icons.ac_unit_rounded,
        );
      case 61:
        return const WeatherCondition(
          code: 61,
          description: 'Slight rain',
          icon: Icons.water_drop_outlined,
        );
      case 63:
        return const WeatherCondition(
          code: 63,
          description: 'Moderate rain',
          icon: Icons.water_drop_rounded,
        );
      case 65:
        return const WeatherCondition(
          code: 65,
          description: 'Heavy rain',
          icon: Icons.thunderstorm_outlined,
        );
      case 66:
      case 67:
        return const WeatherCondition(
          code: 66,
          description: 'Freezing rain',
          icon: Icons.ac_unit_rounded,
        );
      case 71:
        return const WeatherCondition(
          code: 71,
          description: 'Slight snow',
          icon: Icons.cloudy_snowing,
        );
      case 73:
        return const WeatherCondition(
          code: 73,
          description: 'Moderate snow',
          icon: Icons.cloudy_snowing,
        );
      case 75:
        return const WeatherCondition(
          code: 75,
          description: 'Heavy snow',
          icon: Icons.ac_unit_rounded,
        );
      case 77:
        return const WeatherCondition(
          code: 77,
          description: 'Snow grains',
          icon: Icons.ac_unit_rounded,
        );
      case 80:
        return const WeatherCondition(
          code: 80,
          description: 'Slight rain showers',
          icon: Icons.water_drop_outlined,
        );
      case 81:
        return const WeatherCondition(
          code: 81,
          description: 'Moderate rain showers',
          icon: Icons.water_drop_rounded,
        );
      case 82:
        return const WeatherCondition(
          code: 82,
          description: 'Violent rain showers',
          icon: Icons.thunderstorm_rounded,
        );
      case 85:
      case 86:
        return const WeatherCondition(
          code: 85,
          description: 'Snow showers',
          icon: Icons.cloudy_snowing,
        );
      case 95:
        return const WeatherCondition(
          code: 95,
          description: 'Thunderstorm',
          icon: Icons.thunderstorm_rounded,
        );
      case 96:
      case 99:
        return const WeatherCondition(
          code: 96,
          description: 'Thunderstorm with hail',
          icon: Icons.thunderstorm_rounded,
        );
      default:
        return WeatherCondition(
          code: code,
          description: 'Weather ($code)',
          icon: Icons.wb_cloudy_outlined,
        );
    }
  }
}

/// Current observed weather state at a destination.
class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    this.apparentTemperature,
    this.relativeHumidity,
    this.precipitation,
    this.windSpeed,
    required this.weatherCode,
    required this.time,
  });

  final double temperature;
  final double? apparentTemperature;
  final int? relativeHumidity;
  final double? precipitation;
  final double? windSpeed;
  final int weatherCode;
  final DateTime time;

  WeatherCondition get condition => WeatherCondition.fromWmoCode(weatherCode);

  /// Safe JSON parser for Open-Meteo `current` object.
  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final tempNum = json['temperature_2m'] ?? json['temperature'];
    if (tempNum == null ||
        (tempNum is! num && double.tryParse(tempNum.toString()) == null)) {
      throw const FormatException(
        'Current weather missing required temperature field.',
      );
    }

    final double temp = (tempNum is num)
        ? tempNum.toDouble()
        : double.parse(tempNum.toString());

    final codeNum = json['weather_code'] ?? json['weathercode'] ?? 0;
    final int code = (codeNum is num)
        ? codeNum.toInt()
        : (int.tryParse(codeNum.toString()) ?? 0);

    DateTime parsedTime;
    final timeRaw = json['time'];
    if (timeRaw is String) {
      parsedTime = DateTime.tryParse(timeRaw) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    double? parseOptionalDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseOptionalInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    return CurrentWeather(
      temperature: temp,
      apparentTemperature: parseOptionalDouble(json['apparent_temperature']),
      relativeHumidity: parseOptionalInt(
        json['relative_humidity_2m'] ?? json['relativehumidity_2m'],
      ),
      precipitation: parseOptionalDouble(json['precipitation']),
      windSpeed: parseOptionalDouble(
        json['wind_speed_10m'] ?? json['windspeed_10m'],
      ),
      weatherCode: code,
      time: parsedTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature_2m': temperature,
    'apparent_temperature': apparentTemperature,
    'relative_humidity_2m': relativeHumidity,
    'precipitation': precipitation,
    'wind_speed_10m': windSpeed,
    'weather_code': weatherCode,
    'time': time.toIso8601String(),
  };
}

/// Daily forecast for a single calendar date.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.minTemperature,
    required this.maxTemperature,
    this.precipitationSum,
  });

  final DateTime date;
  final int weatherCode;
  final double minTemperature;
  final double maxTemperature;
  final double? precipitationSum;

  WeatherCondition get condition => WeatherCondition.fromWmoCode(weatherCode);

  /// Safe JSON parser for a daily entry.
  factory DailyForecast.fromValues({
    required String dateStr,
    required dynamic codeVal,
    required dynamic minTempVal,
    required dynamic maxTempVal,
    dynamic precipitationVal,
  }) {
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    final minNum = (minTempVal is num)
        ? minTempVal.toDouble()
        : (double.tryParse(minTempVal?.toString() ?? '') ?? 0.0);

    final maxNum = (maxTempVal is num)
        ? maxTempVal.toDouble()
        : (double.tryParse(maxTempVal?.toString() ?? '') ?? 0.0);

    final code = (codeVal is num)
        ? codeVal.toInt()
        : (int.tryParse(codeVal?.toString() ?? '') ?? 0);

    double? precip;
    if (precipitationVal != null) {
      precip = (precipitationVal is num)
          ? precipitationVal.toDouble()
          : double.tryParse(precipitationVal.toString());
    }

    return DailyForecast(
      date: parsedDate,
      weatherCode: code,
      minTemperature: minNum,
      maxTemperature: maxNum,
      precipitationSum: precip,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weather_code': weatherCode,
    'min_temperature': minTemperature,
    'max_temperature': maxTemperature,
    'precipitation_sum': precipitationSum,
  };
}

/// Complete weather snapshot containing current conditions and multi-day forecast.
class WeatherData {
  WeatherData({
    required this.latitude,
    required this.longitude,
    this.timezone = 'UTC',
    this.timezoneAbbreviation,
    this.elevation,
    required this.current,
    this.daily = const <DailyForecast>[],
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  final double latitude;
  final double longitude;
  final String timezone;
  final String? timezoneAbbreviation;
  final double? elevation;
  final CurrentWeather current;
  final List<DailyForecast> daily;
  final DateTime fetchedAt;

  /// Coordinates key formatted to 3 decimal places (~110m accuracy) for caching.
  String get cacheKey =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  /// True if the forecast contains entries covering [targetDate].
  DailyForecast? forecastForDate(DateTime targetDate) {
    for (final day in daily) {
      if (day.date.year == targetDate.year &&
          day.date.month == targetDate.month &&
          day.date.day == targetDate.day) {
        return day;
      }
    }
    return null;
  }

  /// Parses Open-Meteo REST API JSON response.
  factory WeatherData.fromOpenMeteoJson(Map<String, dynamic> json) {
    final latRaw = json['latitude'];
    final lngRaw = json['longitude'];

    if (latRaw == null || lngRaw == null) {
      throw const FormatException(
        'Open-Meteo response missing latitude or longitude.',
      );
    }

    final double lat = (latRaw is num)
        ? latRaw.toDouble()
        : double.parse(latRaw.toString());
    final double lng = (lngRaw is num)
        ? lngRaw.toDouble()
        : double.parse(lngRaw.toString());

    final currentMap = json['current'] as Map<String, dynamic>?;
    if (currentMap == null) {
      throw const FormatException(
        'Open-Meteo response missing current weather block.',
      );
    }

    final current = CurrentWeather.fromJson(currentMap);

    // Parse daily forecast arrays
    final dailyList = <DailyForecast>[];
    final dailyMap = json['daily'] as Map<String, dynamic>?;
    if (dailyMap != null) {
      final times = dailyMap['time'] as List<dynamic>? ?? const [];
      final dynamic rawCodes =
          dailyMap['weather_code'] ?? dailyMap['weathercode'];
      final List<dynamic> codes = rawCodes is List ? rawCodes : const [];
      final maxTemps =
          dailyMap['temperature_2m_max'] as List<dynamic>? ?? const [];
      final minTemps =
          dailyMap['temperature_2m_min'] as List<dynamic>? ?? const [];
      final precips = dailyMap['precipitation_sum'] as List<dynamic>?;

      for (int i = 0; i < times.length; i++) {
        final timeStr = times[i]?.toString() ?? '';
        final codeVal = i < codes.length ? codes[i] : 0;
        final maxVal = i < maxTemps.length ? maxTemps[i] : 0.0;
        final minVal = i < minTemps.length ? minTemps[i] : 0.0;
        final precipVal = (precips != null && i < precips.length)
            ? precips[i]
            : null;

        dailyList.add(
          DailyForecast.fromValues(
            dateStr: timeStr,
            codeVal: codeVal,
            minTempVal: minVal,
            maxTempVal: maxVal,
            precipitationVal: precipVal,
          ),
        );
      }
    }

    return WeatherData(
      latitude: lat,
      longitude: lng,
      timezone: json['timezone']?.toString() ?? 'UTC',
      timezoneAbbreviation: json['timezone_abbreviation']?.toString(),
      elevation: (json['elevation'] as num?)?.toDouble(),
      current: current,
      daily: List.unmodifiable(dailyList),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'timezone_abbreviation': timezoneAbbreviation,
    'elevation': elevation,
    'current': current.toJson(),
    'daily': daily.map((d) => d.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };
}

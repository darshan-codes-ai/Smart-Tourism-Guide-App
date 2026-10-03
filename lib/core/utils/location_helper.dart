import 'dart:math' as math;

/// Utility to compute distance between geographic coordinates without assuming a fixed city.
class LocationHelper {
  LocationHelper._();

  /// Calculates the approximate distance in kilometers between two lat/lng points
  /// using the Haversine formula on a spherical Earth (mean radius 6,371 km).
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const double earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(endLatitude - startLatitude);
    final dLon = _degreesToRadians(endLongitude - startLongitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLatitude)) *
            math.cos(_degreesToRadians(endLatitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Formats distance into a human-readable string.
  ///
  /// Examples:
  /// - 0.8 km -> '800 m'
  /// - 12.4 km -> '12 km'
  /// - 1240.2 km -> '1,240 km'
  static String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    if (km < 10.0) {
      return '${km.toStringAsFixed(1)} km';
    }
    final rounded = km.round();
    return '${_formatNumber(rounded)} km';
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  static String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}


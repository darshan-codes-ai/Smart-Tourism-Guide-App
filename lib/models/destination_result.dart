/// Represents a geocoded destination result returned by the Open-Meteo Geocoding API.
class DestinationResult {
  const DestinationResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.countryCode,
    this.admin1,
    this.admin2,
    this.elevation,
    this.timezone,
    this.population,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? countryCode;
  final String? admin1; // State / Region / Department
  final String? admin2; // County / District
  final double? elevation;
  final String? timezone;
  final int? population;

  /// User-friendly display title including destination name, region, and country.
  String get displayName {
    final parts = <String>[name];
    if (admin1 != null && admin1!.trim().isNotEmpty && admin1 != name) {
      parts.add(admin1!.trim());
    }
    if (country != null && country!.trim().isNotEmpty && country != admin1) {
      parts.add(country!.trim());
    }
    return parts.join(', ');
  }

  /// Subtitle displaying administrative region and country.
  String get subtitle {
    final parts = <String>[];
    if (admin1 != null && admin1!.trim().isNotEmpty && admin1 != name) {
      parts.add(admin1!.trim());
    }
    if (country != null && country!.trim().isNotEmpty && country != admin1) {
      parts.add(country!.trim());
    }
    return parts.isEmpty ? 'Geocoded destination' : parts.join(', ');
  }

  /// Safe JSON parser for Open-Meteo geocoding search results.
  factory DestinationResult.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is num)
        ? rawId.toInt()
        : (int.tryParse(rawId?.toString() ?? '') ?? 0);

    final name = json['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      throw const FormatException(
        'Destination result missing required name field.',
      );
    }

    final latRaw = json['latitude'];
    final lngRaw = json['longitude'];
    if (latRaw == null || lngRaw == null) {
      throw const FormatException(
        'Destination result missing latitude or longitude.',
      );
    }

    final double lat = (latRaw is num)
        ? latRaw.toDouble()
        : double.parse(latRaw.toString());
    final double lng = (lngRaw is num)
        ? lngRaw.toDouble()
        : double.parse(lngRaw.toString());

    return DestinationResult(
      id: id,
      name: name,
      latitude: lat,
      longitude: lng,
      country: json['country']?.toString(),
      countryCode: json['country_code']?.toString(),
      admin1: json['admin1']?.toString(),
      admin2: json['admin2']?.toString(),
      elevation: (json['elevation'] as num?)?.toDouble(),
      timezone: json['timezone']?.toString(),
      population: (json['population'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'country': country,
    'country_code': countryCode,
    'admin1': admin1,
    'admin2': admin2,
    'elevation': elevation,
    'timezone': timezone,
    'population': population,
  };
}

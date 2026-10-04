import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/currency_formatter.dart';

class Attraction {
  const Attraction({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.rating,
    this.city = '',
    this.country = '',
    this.countryCode,
    this.reviewCount = 0,
    this.popularity = 0.0,
    this.currency,
    this.openingTime,
    this.closingTime,
    required this.distance,
    required this.location,
    required this.openingHours,
    required this.entryFee,
    this.latitude,
    this.longitude,
    this.isSaved = false,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final double rating;
  final String city;
  final String country;
  final String? countryCode;
  final int reviewCount;
  final double popularity;
  final String? currency;
  final String? openingTime;
  final String? closingTime;
  final String distance;
  final String location;
  final String openingHours;
  final String entryFee;
  final double? latitude;
  final double? longitude;
  final bool isSaved;

  /// Returns the formatted entry fee with native currency symbol (e.g. '$25', '€29', 'Free').
  String get formattedFee {
    final trimmed = entryFee.trim();
    if (trimmed.isEmpty) return 'Not available';
    if (trimmed.toLowerCase() == 'free') return 'Free';

    // If already contains a currency symbol or word (e.g. €29, $25, AED 30, Paid dining)
    final numMatch = RegExp(r'^[\d.]+$').firstMatch(trimmed);
    if (numMatch != null) {
      final parsed = double.tryParse(trimmed);
      return CurrencyFormatter.format(parsed, currency: currency);
    }
    return trimmed;
  }

  /// Returns a clean display location string (e.g. 'Paris, France' or 'Rome, Italy').
  String get displayLocation {
    if (city.isNotEmpty && country.isNotEmpty) {
      return '$city, $country';
    } else if (city.isNotEmpty) {
      return city;
    } else if (country.isNotEmpty) {
      return country;
    }
    return location;
  }

  factory Attraction.fromFirestore(String id, Map<String, dynamic> data) {
    double? lat = _parseDouble(data['latitude'] ?? data['lat']);
    double? lng = _parseDouble(data['longitude'] ?? data['lng']);

    final coordinates =
        data['coordinates'] ?? data['position'] ?? data['geoPoint'];
    if (coordinates is GeoPoint) {
      lat ??= coordinates.latitude;
      lng ??= coordinates.longitude;
    }

    final locationValue = data['location'];
    final String location;
    if (locationValue is GeoPoint) {
      lat ??= locationValue.latitude;
      lng ??= locationValue.longitude;
      location = '';
    } else {
      location = locationValue?.toString() ?? '';
    }

    final String country = data['country']?.toString() ?? '';
    final String city = data['city']?.toString() ?? '';
    final String? countryCode = data['countryCode']?.toString();
    final String? currency = data['currency']?.toString();

    final int reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
    final double popularity = (data['popularity'] as num?)?.toDouble() ?? 0.0;
    final String? openingTime = data['openingTime']?.toString();
    final String? closingTime = data['closingTime']?.toString();

    return Attraction(
      id: id,
      name: data['name']?.toString() ?? 'Unnamed attraction',
      category: data['category']?.toString() ?? 'Other',
      description: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      rating: _parseRating(data['rating']),
      city: city,
      country: country,
      countryCode: countryCode,
      reviewCount: reviewCount,
      popularity: popularity,
      currency: currency,
      openingTime: openingTime,
      closingTime: closingTime,
      distance: _parseDistance(data['distance']),
      location: location,
      openingHours: _parseOpeningHours(data['openingHours'] ?? data['openinghours']),
      entryFee: _parseEntryFee(data['entryFee'] ?? data['entryfee'], currency: currency),
      latitude: lat,
      longitude: lng,
      isSaved: _parseBool(data['isSaved']),
    );
  }

  static double _parseRating(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String _parseDistance(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      return trimmed;
    }
    if (value is num) {
      return '$value km';
    }
    return value.toString();
  }

  static String _parseOpeningHours(dynamic value) {
    if (value == null) return 'Not available';
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? 'Not available' : trimmed;
    }
    return value.toString();
  }

  static String _parseEntryFee(dynamic value, {String? currency}) {
    if (value == null) return 'Not available';
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? 'Not available' : trimmed;
    }
    if (value is num) {
      return CurrencyFormatter.format(value, currency: currency);
    }
    return value.toString();
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'popularity': popularity,
      'city': city,
      'country': country,
      if (countryCode != null) 'countryCode': countryCode,
      if (currency != null) 'currency': currency,
      'distance': distance,
      'location': location,
      'openingHours': openingHours,
      if (openingTime != null) 'openingTime': openingTime,
      if (closingTime != null) 'closingTime': closingTime,
      'entryFee': entryFee,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'isSaved': isSaved,
    };
  }

  Attraction copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? imageUrl,
    double? rating,
    String? city,
    String? country,
    String? countryCode,
    int? reviewCount,
    double? popularity,
    String? currency,
    String? openingTime,
    String? closingTime,
    String? distance,
    String? location,
    String? openingHours,
    String? entryFee,
    double? latitude,
    double? longitude,
    bool? isSaved,
  }) {
    return Attraction(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      city: city ?? this.city,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      reviewCount: reviewCount ?? this.reviewCount,
      popularity: popularity ?? this.popularity,
      currency: currency ?? this.currency,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      distance: distance ?? this.distance,
      location: location ?? this.location,
      openingHours: openingHours ?? this.openingHours,
      entryFee: entryFee ?? this.entryFee,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

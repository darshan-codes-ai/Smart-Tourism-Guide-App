import 'package:cloud_firestore/cloud_firestore.dart';

class Attraction {
  const Attraction({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.rating,
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
  final String distance;
  final String location;
  final String openingHours;
  final String entryFee;
  final double? latitude;
  final double? longitude;
  final bool isSaved;

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

    return Attraction(
      id: id,
      name: data['name']?.toString() ?? 'Unnamed attraction',
      category: data['category']?.toString() ?? 'Other',
      description: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      rating: _parseRating(data['rating']),
      distance: _parseDistance(data['distance']),
      location: location,
      openingHours: _parseOpeningHours(data['openingHours']),
      entryFee: _parseEntryFee(data['entryFee']),
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
    if (value == null) return 'Nearby';
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? 'Nearby' : trimmed;
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

  static String _parseEntryFee(dynamic value) {
    if (value == null) return 'Not available';
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? 'Not available' : trimmed;
    }
    if (value is num) {
      return value == 0 ? 'Free' : '₹$value';
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
      'distance': distance,
      'location': location,
      'openingHours': openingHours,
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

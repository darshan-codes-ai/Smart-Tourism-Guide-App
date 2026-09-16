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
    return Attraction(
      id: id,
      name: data['name'] as String? ?? 'Unnamed attraction',
      category: data['category'] as String? ?? 'Other',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      distance: data['distance'] as String? ?? 'Nearby',
      location: data['location'] as String? ?? '',
      openingHours: data['openingHours'] as String? ?? 'Not available',
      entryFee: data['entryFee'] as String? ?? 'Not available',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      isSaved: data['isSaved'] as bool? ?? false,
    );
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
      'latitude': latitude,
      'longitude': longitude,
      'isSaved': isSaved,
    };
  }

  Attraction copyWith({bool? isSaved}) {
    return Attraction(
      id: id,
      name: name,
      category: category,
      description: description,
      imageUrl: imageUrl,
      rating: rating,
      distance: distance,
      location: location,
      openingHours: openingHours,
      entryFee: entryFee,
      latitude: latitude,
      longitude: longitude,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

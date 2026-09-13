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
  final bool isSaved;

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
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

import 'package:flutter/foundation.dart';

import '../models/attraction.dart';

class DummyData {
  DummyData._();

  static const List<Attraction> attractions = [
    Attraction(
      id: '1',
      name: 'Charminar',
      category: 'Historical',
      description:
          'An iconic 16th-century mosque and monument at the heart of Hyderabad’s old city, known for its four grand minarets.',
      imageUrl:
          'https://images.unsplash.com/photo-1626192292711-1a3a7e0c4e3a?auto=format&fit=crop&w=1200&q=80',
      rating: 4.6,
      distance: '1.2 km',
      location: 'Hyderabad',
      openingHours: '9:30 AM - 5:30 PM',
      entryFee: '₹25',
      isSaved: true,
    ),
    Attraction(
      id: '2',
      name: 'Golconda Fort',
      category: 'Historical',
      description:
          'A sprawling hilltop fort with acoustic architecture, royal halls, and panoramic sunset views of the city.',
      imageUrl:
          'https://images.unsplash.com/photo-1603262110263-fb0112e7cc33?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      distance: '8.2 km',
      location: 'Hyderabad',
      openingHours: '9:00 AM - 5:30 PM',
      entryFee: '₹25',
    ),
    Attraction(
      id: '3',
      name: 'Hussain Sagar',
      category: 'Nature',
      description:
          'A heart-shaped lake connecting Hyderabad and Secunderabad, famous for the Buddha statue and lakeside promenade.',
      imageUrl:
          'https://images.unsplash.com/photo-1582510003544-4d00b7f74250?auto=format&fit=crop&w=1200&q=80',
      rating: 4.5,
      distance: '5.4 km',
      location: 'Hyderabad',
      openingHours: 'Open all day',
      entryFee: 'Free',
      isSaved: true,
    ),
    Attraction(
      id: '4',
      name: 'Birla Mandir',
      category: 'Religious',
      description:
          'A white marble temple dedicated to Lord Venkateswara, offering calm courtyards and city views from the hill.',
      imageUrl:
          'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80',
      rating: 4.6,
      distance: '3.8 km',
      location: 'Hyderabad',
      openingHours: '7:00 AM - 12:00 PM, 3:00 PM - 9:00 PM',
      entryFee: 'Free',
    ),
    Attraction(
      id: '5',
      name: 'Wonderla Hyderabad',
      category: 'Adventure',
      description:
          'A large amusement park with water rides, thrill attractions, and family-friendly entertainment.',
      imageUrl:
          'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?auto=format&fit=crop&w=1200&q=80',
      rating: 4.4,
      distance: '28.0 km',
      location: 'Hyderabad',
      openingHours: '11:00 AM - 6:00 PM',
      entryFee: '₹1,199',
    ),
    Attraction(
      id: '6',
      name: 'Shilparamam',
      category: 'Shopping',
      description:
          'An arts and crafts village where you can shop for handlooms, souvenirs, and regional artisan products.',
      imageUrl:
          'https://images.unsplash.com/photo-1488459716781-31db52582fe9?auto=format&fit=crop&w=1200&q=80',
      rating: 4.3,
      distance: '12.1 km',
      location: 'Hyderabad',
      openingHours: '10:30 AM - 8:00 PM',
      entryFee: '₹50',
    ),
    Attraction(
      id: '7',
      name: 'Paradise Biryani',
      category: 'Food',
      description:
          'A legendary Hyderabadi biryani destination loved by locals and visitors for its rich, aromatic flavors.',
      imageUrl:
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=1200&q=80',
      rating: 4.5,
      distance: '4.1 km',
      location: 'Hyderabad',
      openingHours: '11:00 AM - 11:00 PM',
      entryFee: 'Paid dining',
    ),
    Attraction(
      id: '8',
      name: 'KBR National Park',
      category: 'Nature',
      description:
          'A green lung in the city with walking trails, native flora, and a peaceful escape from traffic.',
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=80',
      rating: 4.4,
      distance: '7.6 km',
      location: 'Hyderabad',
      openingHours: '5:30 AM - 7:30 AM, 4:00 PM - 6:30 PM',
      entryFee: '₹20',
    ),
  ];

  static List<Attraction> get recommended => attractions.take(4).toList();

  static List<Attraction> get nearby => attractions;
}

/// Simple in-memory store so favorite toggles stay consistent across tabs.
/// This can later be replaced with Firestore without changing the UI much.
class SavedPlacesStore extends ChangeNotifier {
  SavedPlacesStore._() {
    for (final attraction in DummyData.attractions) {
      if (attraction.isSaved) {
        _savedIds.add(attraction.id);
      }
    }
  }

  static final SavedPlacesStore instance = SavedPlacesStore._();

  final Set<String> _savedIds = <String>{};

  bool isSaved(String id) => _savedIds.contains(id);

  List<Attraction> get savedAttractions {
    return DummyData.attractions
        .where((attraction) => _savedIds.contains(attraction.id))
        .toList();
  }

  void toggle(String id) {
    if (_savedIds.contains(id)) {
      _savedIds.remove(id);
    } else {
      _savedIds.add(id);
    }
    notifyListeners();
  }
}

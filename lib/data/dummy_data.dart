import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/attraction.dart';
import '../services/attraction_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class DummyData {
  DummyData._();

  static const List<Attraction> attractions = [
    Attraction(
      id: 'eiffel-tower',
      name: 'Eiffel Tower',
      category: 'Historical',
      description:
          'The iconic wrought-iron lattice tower on the Champ de Mars in Paris, offering breathtaking panoramic views of the City of Light.',
      imageUrl:
          'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      city: 'Paris',
      country: 'France',
      countryCode: 'FR',
      reviewCount: 324000,
      popularity: 98.5,
      currency: 'EUR',
      openingTime: '09:00',
      closingTime: '23:45',
      distance: '2.5 km',
      location: 'Paris, France',
      openingHours: '9:00 AM - 11:45 PM',
      entryFee: '€29',
      latitude: 48.8584,
      longitude: 2.2945,
      isSaved: true,
    ),
    Attraction(
      id: 'louvre-museum',
      name: 'Louvre Museum',
      category: 'Historical',
      description:
          "The world's most-visited museum and historic monument in Paris, home to Leonardo da Vinci's Mona Lisa and Venus de Milo.",
      imageUrl:
          'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Paris',
      country: 'France',
      countryCode: 'FR',
      reviewCount: 285000,
      popularity: 97.2,
      currency: 'EUR',
      openingTime: '09:00',
      closingTime: '18:00',
      distance: '3.1 km',
      location: 'Paris, France',
      openingHours: '9:00 AM - 6:00 PM',
      entryFee: '€22',
      latitude: 48.8606,
      longitude: 2.3376,
    ),
    Attraction(
      id: 'colosseum',
      name: 'Colosseum',
      category: 'Historical',
      description:
          'An ancient amphitheatre in the centre of Rome, the largest standing amphitheatre in the world despite its age.',
      imageUrl:
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Rome',
      country: 'Italy',
      countryCode: 'IT',
      reviewCount: 240000,
      popularity: 96.4,
      currency: 'EUR',
      openingTime: '08:30',
      closingTime: '19:00',
      distance: '1.8 km',
      location: 'Rome, Italy',
      openingHours: '8:30 AM - 7:00 PM',
      entryFee: '€18',
      latitude: 41.8902,
      longitude: 12.4922,
    ),
    Attraction(
      id: 'trevi-fountain',
      name: 'Trevi Fountain',
      category: 'Historical',
      description:
          'An 18th-century fountain in the Trevi district of Rome, renowned for its grand Baroque sculpture and coin-tossing tradition.',
      imageUrl:
          'https://images.unsplash.com/photo-1525874684015-58379d421a52?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Rome',
      country: 'Italy',
      countryCode: 'IT',
      reviewCount: 350000,
      popularity: 95.8,
      currency: 'EUR',
      openingTime: '00:00',
      closingTime: '23:59',
      distance: '0.8 km',
      location: 'Rome, Italy',
      openingHours: 'Open 24 Hours',
      entryFee: 'Free',
      latitude: 41.9009,
      longitude: 12.4833,
      isSaved: true,
    ),
    Attraction(
      id: 'tokyo-skytree',
      name: 'Tokyo Skytree',
      category: 'Adventure',
      description:
          'A broadcasting and observation tower in Sumida, Tokyo. It is the tallest structure in Japan with sensational 360-degree vistas.',
      imageUrl:
          'https://images.unsplash.com/photo-1542051841857-5f90071e7989?auto=format&fit=crop&w=1200&q=80',
      rating: 4.6,
      city: 'Tokyo',
      country: 'Japan',
      countryCode: 'JP',
      reviewCount: 95000,
      popularity: 93.1,
      currency: 'JPY',
      openingTime: '10:00',
      closingTime: '21:00',
      distance: '6.4 km',
      location: 'Tokyo, Japan',
      openingHours: '10:00 AM - 9:00 PM',
      entryFee: '¥2,100',
      latitude: 35.7100,
      longitude: 139.8107,
    ),
    Attraction(
      id: 'fushimi-inari',
      name: 'Fushimi Inari Shrine',
      category: 'Religious',
      description:
          'The head shrine of the kami Inari, famous for its thousands of vibrant vermilion torii gates winding up Mount Inari.',
      imageUrl:
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Kyoto',
      country: 'Japan',
      countryCode: 'JP',
      reviewCount: 112000,
      popularity: 95.5,
      currency: 'JPY',
      openingTime: '00:00',
      closingTime: '23:59',
      distance: '4.2 km',
      location: 'Kyoto, Japan',
      openingHours: 'Open 24 Hours',
      entryFee: 'Free',
      latitude: 34.9671,
      longitude: 135.7727,
    ),
    Attraction(
      id: 'tsukiji-market',
      name: 'Tsukiji Outer Market',
      category: 'Food',
      description:
          'A bustling marketplace packed with hundreds of food stalls, fresh sushi bars, knife shops, and gourmet street snacks.',
      imageUrl:
          'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80',
      rating: 4.5,
      city: 'Tokyo',
      country: 'Japan',
      countryCode: 'JP',
      reviewCount: 46000,
      popularity: 90.0,
      currency: 'JPY',
      openingTime: '05:00',
      closingTime: '14:00',
      distance: '3.0 km',
      location: 'Tokyo, Japan',
      openingHours: '5:00 AM - 2:00 PM',
      entryFee: 'Free',
      latitude: 35.6655,
      longitude: 139.7707,
    ),
    Attraction(
      id: 'statue-of-liberty',
      name: 'Statue of Liberty',
      category: 'Historical',
      description:
          'A colossal neoclassical sculpture on Liberty Island in New York Harbor, a universal symbol of freedom and democracy.',
      imageUrl:
          'https://images.unsplash.com/photo-1508873696983-2df5703bc20d?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      city: 'New York',
      country: 'United States',
      countryCode: 'US',
      reviewCount: 215000,
      popularity: 96.0,
      currency: 'USD',
      openingTime: '09:00',
      closingTime: '17:00',
      distance: '8.5 km',
      location: 'New York, United States',
      openingHours: '9:00 AM - 5:00 PM',
      entryFee: r'$25',
      latitude: 40.6892,
      longitude: -74.0445,
    ),
    Attraction(
      id: 'central-park',
      name: 'Central Park',
      category: 'Nature',
      description:
          'An urban park in Manhattan between the Upper West and Upper East Sides, featuring rolling meadows, lakes, and walking paths.',
      imageUrl:
          'https://images.unsplash.com/photo-1518391846015-55a9cc003b25?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'New York',
      country: 'United States',
      countryCode: 'US',
      reviewCount: 310000,
      popularity: 97.5,
      currency: 'USD',
      openingTime: '06:00',
      closingTime: '01:00',
      distance: '1.5 km',
      location: 'New York, United States',
      openingHours: '6:00 AM - 1:00 AM',
      entryFee: 'Free',
      latitude: 40.7851,
      longitude: -73.9683,
    ),
    Attraction(
      id: 'golden-gate-bridge',
      name: 'Golden Gate Bridge',
      category: 'Adventure',
      description:
          'A suspension bridge spanning the Golden Gate strait between San Francisco and Marin County, renowned worldwide for its Art Deco design.',
      imageUrl:
          'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'San Francisco',
      country: 'United States',
      countryCode: 'US',
      reviewCount: 145000,
      popularity: 94.3,
      currency: 'USD',
      openingTime: '00:00',
      closingTime: '23:59',
      distance: '7.2 km',
      location: 'San Francisco, United States',
      openingHours: 'Open 24 Hours',
      entryFee: 'Free',
      latitude: 37.8199,
      longitude: -122.4783,
    ),
    Attraction(
      id: 'big-ben',
      name: 'Big Ben & Elizabeth Tower',
      category: 'Historical',
      description:
          'The iconic clock tower at the north end of the Houses of Parliament in Westminster, London, famous for its four-faced chiming clock.',
      imageUrl:
          'https://images.unsplash.com/photo-1529655683826-aba9b3e77383?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      city: 'London',
      country: 'United Kingdom',
      countryCode: 'GB',
      reviewCount: 182000,
      popularity: 94.8,
      currency: 'GBP',
      openingTime: '09:00',
      closingTime: '16:30',
      distance: '2.1 km',
      location: 'London, United Kingdom',
      openingHours: '9:00 AM - 4:30 PM',
      entryFee: '£30',
      latitude: 51.5007,
      longitude: -0.1246,
    ),
    Attraction(
      id: 'borough-market',
      name: 'Borough Market',
      category: 'Food',
      description:
          'One of the largest and oldest food markets in London, offering artisanal cheese, fresh bakery treats, and international street cuisines.',
      imageUrl:
          'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=1200&q=80',
      rating: 4.6,
      city: 'London',
      country: 'United Kingdom',
      countryCode: 'GB',
      reviewCount: 88000,
      popularity: 91.2,
      currency: 'GBP',
      openingTime: '10:00',
      closingTime: '17:00',
      distance: '3.4 km',
      location: 'London, United Kingdom',
      openingHours: '10:00 AM - 5:00 PM',
      entryFee: 'Free',
      latitude: 51.5055,
      longitude: -0.0910,
    ),
    Attraction(
      id: 'burj-khalifa',
      name: 'Burj Khalifa',
      category: 'Adventure',
      description:
          "The world's tallest skyscraper in Dubai, with an observation deck on the 148th floor offering views across the Arabian Gulf.",
      imageUrl:
          'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      city: 'Dubai',
      country: 'United Arab Emirates',
      countryCode: 'AE',
      reviewCount: 165000,
      popularity: 96.8,
      currency: 'AED',
      openingTime: '08:30',
      closingTime: '23:00',
      distance: '4.8 km',
      location: 'Dubai, United Arab Emirates',
      openingHours: '8:30 AM - 11:00 PM',
      entryFee: 'AED 179',
      latitude: 25.1972,
      longitude: 55.2744,
    ),
    Attraction(
      id: 'sheikh-zayed-mosque',
      name: 'Sheikh Zayed Grand Mosque',
      category: 'Religious',
      description:
          'The largest mosque in the UAE, featuring 82 white marble domes, over 1,000 columns, gold-plated chandeliers, and hand-knotted carpet.',
      imageUrl:
          'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=1200&q=80',
      rating: 4.9,
      city: 'Abu Dhabi',
      country: 'United Arab Emirates',
      countryCode: 'AE',
      reviewCount: 78000,
      popularity: 95.3,
      currency: 'AED',
      openingTime: '09:00',
      closingTime: '22:00',
      distance: '12.0 km',
      location: 'Abu Dhabi, United Arab Emirates',
      openingHours: '9:00 AM - 10:00 PM',
      entryFee: 'Free',
      latitude: 24.4128,
      longitude: 54.4750,
    ),
    Attraction(
      id: 'taj-mahal',
      name: 'Taj Mahal',
      category: 'Historical',
      description:
          'An ivory-white marble mausoleum on the south bank of the Yamuna river in Agra, universally admired as an architectural masterpiece.',
      imageUrl:
          'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Agra',
      country: 'India',
      countryCode: 'IN',
      reviewCount: 295000,
      popularity: 98.1,
      currency: 'INR',
      openingTime: '06:00',
      closingTime: '18:30',
      distance: '5.2 km',
      location: 'Agra, India',
      openingHours: 'Sunrise to Sunset',
      entryFee: '₹50',
      latitude: 27.1751,
      longitude: 78.0421,
    ),
    Attraction(
      id: 'charminar',
      name: 'Charminar',
      category: 'Historical',
      description:
          'An iconic 16th-century mosque and monument at the heart of Hyderabad, known for its four grand stucco minarets and bustling bazaars.',
      imageUrl:
          'https://images.unsplash.com/photo-1626192292711-1a3a7e0c4e3a?auto=format&fit=crop&w=1200&q=80',
      rating: 4.6,
      city: 'Hyderabad',
      country: 'India',
      countryCode: 'IN',
      reviewCount: 125000,
      popularity: 91.5,
      currency: 'INR',
      openingTime: '09:30',
      closingTime: '17:30',
      distance: '1.2 km',
      location: 'Hyderabad, India',
      openingHours: '9:30 AM - 5:30 PM',
      entryFee: '₹25',
      latitude: 17.3616,
      longitude: 78.4747,
    ),
    Attraction(
      id: 'sydney-opera-house',
      name: 'Sydney Opera House',
      category: 'Historical',
      description:
          'A multi-venue performing arts centre in Sydney Harbour, famous for its distinctive shell-like roof sails and harbor views.',
      imageUrl:
          'https://images.unsplash.com/photo-1523482580672-f109ba8cb9be?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      city: 'Sydney',
      country: 'Australia',
      countryCode: 'AU',
      reviewCount: 132000,
      popularity: 95.0,
      currency: 'AUD',
      openingTime: '09:00',
      closingTime: '17:00',
      distance: '2.8 km',
      location: 'Sydney, Australia',
      openingHours: '9:00 AM - 5:00 PM',
      entryFee: r'A$43',
      latitude: -33.8568,
      longitude: 151.2153,
    ),
    Attraction(
      id: 'great-barrier-reef',
      name: 'Great Barrier Reef',
      category: 'Nature',
      description:
          "The world's largest coral reef system composed of over 2,900 individual reefs, renowned for scuba diving and marine biodiversity.",
      imageUrl:
          'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Cairns',
      country: 'Australia',
      countryCode: 'AU',
      reviewCount: 62000,
      popularity: 93.4,
      currency: 'AUD',
      openingTime: '08:00',
      closingTime: '18:00',
      distance: '25.0 km',
      location: 'Cairns, Australia',
      openingHours: 'Tours 8:00 AM - 6:00 PM',
      entryFee: r'A$150',
      latitude: -18.2871,
      longitude: 147.6992,
    ),
    Attraction(
      id: 'christ-the-redeemer',
      name: 'Christ the Redeemer',
      category: 'Religious',
      description:
          'An Art Deco statue of Jesus Christ in Rio de Janeiro atop Mount Corcovado, overlooking Guanabara Bay and Sugarloaf Mountain.',
      imageUrl:
          'https://images.unsplash.com/photo-1516306580123-e6e52b1b7b5f?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Rio de Janeiro',
      country: 'Brazil',
      countryCode: 'BR',
      reviewCount: 162000,
      popularity: 96.2,
      currency: 'BRL',
      openingTime: '08:00',
      closingTime: '19:00',
      distance: '6.0 km',
      location: 'Rio de Janeiro, Brazil',
      openingHours: '8:00 AM - 7:00 PM',
      entryFee: r'R$80',
      latitude: -22.9519,
      longitude: -43.2105,
    ),
    Attraction(
      id: 'pyramids-of-giza',
      name: 'Great Pyramids of Giza',
      category: 'Historical',
      description:
          'The oldest of the Seven Wonders of the Ancient World and the only one to remain largely intact, located on the Giza Plateau.',
      imageUrl:
          'https://images.unsplash.com/photo-1503177119275-0aa32b3a9368?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      city: 'Giza',
      country: 'Egypt',
      countryCode: 'EG',
      reviewCount: 195000,
      popularity: 97.4,
      currency: 'EGP',
      openingTime: '08:00',
      closingTime: '17:00',
      distance: '14.0 km',
      location: 'Giza, Egypt',
      openingHours: '8:00 AM - 5:00 PM',
      entryFee: 'EGP 240',
      latitude: 29.9792,
      longitude: 31.1342,
    ),
    Attraction(
      id: 'sagrada-familia',
      name: 'Basílica de la Sagrada Família',
      category: 'Religious',
      description:
          "Antoni Gaudí's renowned unfinished Roman Catholic minor basilica in Barcelona, showcasing transcendent modernist Catalan architecture.",
      imageUrl:
          'https://images.unsplash.com/photo-1583772260270-c7eb683e7cf5?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Barcelona',
      country: 'Spain',
      countryCode: 'ES',
      reviewCount: 228000,
      popularity: 96.6,
      currency: 'EUR',
      openingTime: '09:00',
      closingTime: '18:00',
      distance: '2.3 km',
      location: 'Barcelona, Spain',
      openingHours: '9:00 AM - 6:00 PM',
      entryFee: '€26',
      latitude: 41.4036,
      longitude: 2.1744,
    ),
    Attraction(
      id: 'gardens-by-the-bay',
      name: 'Gardens by the Bay',
      category: 'Nature',
      description:
          'A sanctuary for nature lovers with futuristic Supertree structures, the Cloud Forest cooled conservatory, and Flower Dome in Marina Bay.',
      imageUrl:
          'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      city: 'Singapore',
      country: 'Singapore',
      countryCode: 'SG',
      reviewCount: 178000,
      popularity: 95.7,
      currency: 'SGD',
      openingTime: '05:00',
      closingTime: '02:00',
      distance: '1.8 km',
      location: 'Singapore, Singapore',
      openingHours: '5:00 AM - 2:00 AM',
      entryFee: r'S$28',
      latitude: 1.2816,
      longitude: 103.8636,
    ),
    Attraction(
      id: 'grand-bazaar',
      name: 'Grand Bazaar',
      category: 'Shopping',
      description:
          'One of the largest and oldest covered markets in the world, with 61 covered streets and over 4,000 shops selling lanterns, carpets, and spices.',
      imageUrl:
          'https://images.unsplash.com/photo-1541432901042-2d8bd64b4a9b?auto=format&fit=crop&w=1200&q=80',
      rating: 4.4,
      city: 'Istanbul',
      country: 'Turkey',
      countryCode: 'TR',
      reviewCount: 110000,
      popularity: 92.0,
      currency: 'USD',
      openingTime: '08:30',
      closingTime: '19:00',
      distance: '2.0 km',
      location: 'Istanbul, Turkey',
      openingHours: '8:30 AM - 7:00 PM',
      entryFee: 'Free',
      latitude: 41.0108,
      longitude: 28.9680,
    ),
  ];

  static List<Attraction> get recommended => attractions.take(4).toList();

  static List<Attraction> get nearby => attractions;
}

/// Central store for user favorites that stays synchronized with Firestore
/// when authenticated, and falls back gracefully when unauthenticated.
class SavedPlacesStore extends ChangeNotifier {
  SavedPlacesStore._() {
    _initAuthListener();
  }

  static final SavedPlacesStore instance = SavedPlacesStore._();

  final Set<String> _savedIds = <String>{};
  final Map<String, Attraction> _knownAttractions = <String, Attraction>{};
  final Set<String> _pendingResolutionIds = <String>{};

  String? _currentUid;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<Set<String>>? _favoritesSubscription;
  bool _isResolving = false;

  bool get isResolving => _isResolving;

  bool get hasUnresolvedSavedIds =>
      _savedIds.any((id) => !_knownAttractions.containsKey(id));

  Set<String> get savedIds => Set<String>.unmodifiable(_savedIds);

  bool isSaved(String id) => _savedIds.contains(id);

  void _initAuthListener() {
    if (Firebase.apps.isEmpty) return;
    try {
      _authSubscription = AuthService.instance.authStateChanges.listen(
        _onAuthStateChanged,
        onError: (e) {
          debugPrint('SavedPlacesStore auth listener error: $e');
        },
      );
    } catch (_) {
      // Ignored if auth cannot be initialized (e.g. unit tests without Firebase)
    }
  }

  void _onAuthStateChanged(User? user) {
    handleUserUidChanged(user?.uid);
  }

  void handleUserUidChanged(String? newUid) {
    if (_currentUid == newUid) return;

    _currentUid = newUid;
    _favoritesSubscription?.cancel();
    _favoritesSubscription = null;

    if (newUid == null) {
      // User signs out -> local favorite state is cleared.
      _savedIds.clear();
      _isResolving = false;
      _pendingResolutionIds.clear();
      notifyListeners();
      return;
    }

    // User signs in -> favorites load automatically.
    _favoritesSubscription = FirestoreService.instance
        .watchFavoriteIds(newUid)
        .listen(
          (ids) {
            _savedIds
              ..clear()
              ..addAll(ids);
            notifyListeners();
            resolveMissingAttractions();
          },
          onError: (error) {
            debugPrint('SavedPlacesStore watchFavoriteIds error: $error');
          },
        );
  }

  void registerAttractions(Iterable<Attraction> attractions) {
    for (final attraction in attractions) {
      _knownAttractions[attraction.id] = attraction;
      if (attraction.id.toLowerCase() == 'charminar') {
        _knownAttractions['Charminar'] = attraction;
        _knownAttractions['charminar'] = attraction;
      }
      if (_currentUid == null && attraction.isSaved) {
        _savedIds.add(attraction.id);
      }
    }
  }

  List<Attraction> get savedAttractions {
    return _savedIds
        .map((id) => _knownAttractions[id])
        .whereType<Attraction>()
        .toList();
  }

  void toggle(String id) {
    final wasSaved = _savedIds.contains(id);
    if (wasSaved) {
      _savedIds.remove(id);
    } else {
      _savedIds.add(id);
    }
    // Tapping the heart -> UI should update immediately.
    notifyListeners();

    final uid = _currentUid;
    if (uid != null) {
      _persistToggle(uid, id, wasSaved);
    }
  }

  Future<void> _persistToggle(String uid, String id, bool wasSaved) async {
    try {
      if (wasSaved) {
        await FirestoreService.instance.removeFavorite(uid, id);
      } else {
        await FirestoreService.instance.addFavorite(uid, id);
        if (!_knownAttractions.containsKey(id)) {
          resolveMissingAttractions();
        }
      }
    } catch (error) {
      debugPrint('Failed to persist favorite toggle for $id: $error');
      // Revert optimistic update on failure
      if (wasSaved) {
        _savedIds.add(id);
      } else {
        _savedIds.remove(id);
      }
      notifyListeners();
    }
  }

  Future<void> resolveMissingAttractions() async {
    final missingIds = _savedIds
        .where(
          (id) =>
              !_knownAttractions.containsKey(id) &&
              !_pendingResolutionIds.contains(id),
        )
        .toList();

    if (missingIds.isEmpty) return;

    _pendingResolutionIds.addAll(missingIds);
    _isResolving = true;
    notifyListeners();

    try {
      await Future.wait(
        missingIds.map((id) async {
          try {
            final attraction = await AttractionService.instance.getAttraction(
              id,
            );
            if (attraction != null) {
              _knownAttractions[id] = attraction;
              if (id.toLowerCase() == 'charminar') {
                _knownAttractions['Charminar'] = attraction;
                _knownAttractions['charminar'] = attraction;
              }
            }
          } catch (e) {
            debugPrint('Error resolving attraction $id: $e');
          } finally {
            _pendingResolutionIds.remove(id);
          }
        }),
      );
    } finally {
      _isResolving = _pendingResolutionIds.isNotEmpty;
      notifyListeners();
    }
  }

  @visibleForTesting
  void resetForTest() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _favoritesSubscription?.cancel();
    _favoritesSubscription = null;
    _currentUid = null;
    _isResolving = false;
    _pendingResolutionIds.clear();
    _savedIds.clear();
    _knownAttractions.clear();
  }

  @visibleForTesting
  void handleUserUidChangedForTest(String? uid) {
    handleUserUidChanged(uid);
  }

  @visibleForTesting
  void listenToAuthStreamForTest(Stream<User?> stream) {
    _authSubscription?.cancel();
    _authSubscription = stream.listen(_onAuthStateChanged);
  }
}

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
      id: '1',
      name: 'Charminar',
      category: 'Historical',
      description: 'An iconic 16th-century mosque and monument at the heart of Hyderabad’s old city, known for its four grand minarets.',
      imageUrl: 'https://images.unsplash.com/photo-1626192292711-1a3a7e0c4e3a?auto=format&fit=crop&w=1200&q=80',
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
      description: 'A sprawling hilltop fort with acoustic architecture, royal halls, and panoramic sunset views of the city.',
      imageUrl: 'https://images.unsplash.com/photo-1603262110263-fb0112e7cc33?auto=format&fit=crop&w=1200&q=80',
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
      description: 'A heart-shaped lake connecting Hyderabad and Secunderabad, famous for the Buddha statue and lakeside promenade.',
      imageUrl: 'https://images.unsplash.com/photo-1582510003544-4d00b7f74250?auto=format&fit=crop&w=1200&q=80',
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
      description: 'A white marble temple dedicated to Lord Venkateswara, offering calm courtyards and city views from the hill.',
      imageUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80',
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
      description: 'A large amusement park with water rides, thrill attractions, and family-friendly entertainment.',
      imageUrl: 'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?auto=format&fit=crop&w=1200&q=80',
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
      description: 'An arts and crafts village where you can shop for handlooms, souvenirs, and regional artisan products.',
      imageUrl: 'https://images.unsplash.com/photo-1488459716781-31db52582fe9?auto=format&fit=crop&w=1200&q=80',
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
      description: 'A legendary Hyderabadi biryani destination loved by locals and visitors for its rich, aromatic flavors.',
      imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=1200&q=80',
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
      description: 'A green lung in the city with walking trails, native flora, and a peaceful escape from traffic.',
      imageUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=80',
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

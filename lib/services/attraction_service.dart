import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../data/dummy_data.dart';
import '../models/attraction.dart';

class AttractionService {
  AttractionService._();

  static final AttractionService instance = AttractionService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? get _attractions {
    if (Firebase.apps.isEmpty) return null;
    return _firestore.collection('attractions');
  }

  Stream<List<Attraction>> watchAttractions() {
    final collection = _attractions;
    if (collection == null) {
      return Stream.value(DummyData.attractions);
    }
    return collection.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return DummyData.attractions;
      }
      final attractions = snapshot.docs
          .map((doc) => Attraction.fromFirestore(doc.id, doc.data()))
          .toList();
      attractions.sort((a, b) => b.rating.compareTo(a.rating));
      return attractions;
    }).handleError((_) => DummyData.attractions);
  }

  Future<List<Attraction>> getAttractions() async {
    final collection = _attractions;
    if (collection == null) {
      return DummyData.attractions;
    }
    try {
      final snapshot = await collection.get();
      if (snapshot.docs.isEmpty) {
        return DummyData.attractions;
      }
      final attractions = snapshot.docs
          .map((doc) => Attraction.fromFirestore(doc.id, doc.data()))
          .toList();
      attractions.sort((a, b) => b.rating.compareTo(a.rating));
      return attractions;
    } catch (_) {
      return DummyData.attractions;
    }
  }

  Future<Attraction?> getAttraction(String id) async {
    final collection = _attractions;
    if (collection == null) {
      try {
        return DummyData.attractions.firstWhere((a) => a.id == id);
      } catch (_) {
        return null;
      }
    }
    try {
      final snapshot = await collection.doc(id).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        try {
          return DummyData.attractions.firstWhere((a) => a.id == id);
        } catch (_) {
          return null;
        }
      }
      return Attraction.fromFirestore(snapshot.id, data);
    } catch (_) {
      try {
        return DummyData.attractions.firstWhere((a) => a.id == id);
      } catch (_) {
        return null;
      }
    }
  }
}

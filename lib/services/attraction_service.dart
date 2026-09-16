import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attraction.dart';

class AttractionService {
  AttractionService._();

  static final AttractionService instance = AttractionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _attractions =>
      _firestore.collection('attractions');

  Stream<List<Attraction>> watchAttractions() {
    return _attractions.snapshots().map((snapshot) {
      final attractions = snapshot.docs
          .map((doc) => Attraction.fromFirestore(doc.id, doc.data()))
          .toList();
      attractions.sort((a, b) => b.rating.compareTo(a.rating));
      return attractions;
    });
  }

  Future<List<Attraction>> getAttractions() async {
    final snapshot = await _attractions.get();
    final attractions = snapshot.docs
        .map((doc) => Attraction.fromFirestore(doc.id, doc.data()))
        .toList();
    attractions.sort((a, b) => b.rating.compareTo(a.rating));
    return attractions;
  }

  Future<Attraction?> getAttraction(String id) async {
    final snapshot = await _attractions.doc(id).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return Attraction.fromFirestore(snapshot.id, data);
  }
}

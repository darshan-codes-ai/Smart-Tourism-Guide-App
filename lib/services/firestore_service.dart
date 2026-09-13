import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createUserProfile(AppUser user) async {
    final userRef = _users.doc(user.uid);
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      await _updateUserProfileDocument(userRef, user);
      return;
    }

    await userRef.set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureUserProfile(AppUser user) async {
    final userRef = _users.doc(user.uid);
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      await _updateUserProfileDocument(userRef, user);
      return;
    }

    await createUserProfile(user);
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return AppUser.fromMap(data);
  }

  Future<void> updateUserProfile(AppUser user) async {
    await _updateUserProfileDocument(_users.doc(user.uid), user);
  }

  Future<void> _updateUserProfileDocument(
    DocumentReference<Map<String, dynamic>> userRef,
    AppUser user,
  ) {
    return userRef.set({
      ...user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

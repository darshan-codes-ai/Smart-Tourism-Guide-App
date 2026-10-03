import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourmate/data/dummy_data.dart';
import 'package:tourmate/models/attraction.dart';
import 'package:tourmate/services/attraction_service.dart';

void main() {
  group('Attraction model tests', () {
    test('fromFirestore parses normal Firestore data correctly', () {
      final data = <String, dynamic>{
        'name': 'Golconda Fort',
        'category': 'Historical',
        'description': 'A sprawling hilltop fort.',
        'imageUrl': 'https://example.com/golconda.jpg',
        'rating': 4.7,
        'distance': '8.2 km',
        'location': 'Hyderabad',
        'openingHours': '9:00 AM - 5:30 PM',
        'entryFee': '₹25',
        'latitude': 17.3833,
        'longitude': 78.4011,
        'isSaved': true,
      };

      final attraction = Attraction.fromFirestore('attraction_1', data);

      expect(attraction.id, 'attraction_1');
      expect(attraction.name, 'Golconda Fort');
      expect(attraction.category, 'Historical');
      expect(attraction.description, 'A sprawling hilltop fort.');
      expect(attraction.imageUrl, 'https://example.com/golconda.jpg');
      expect(attraction.rating, 4.7);
      expect(attraction.distance, '8.2 km');
      expect(attraction.location, 'Hyderabad');
      expect(attraction.openingHours, '9:00 AM - 5:30 PM');
      expect(attraction.entryFee, '₹25');
      expect(attraction.latitude, 17.3833);
      expect(attraction.longitude, 78.4011);
      expect(attraction.isSaved, true);
    });

    test('fromFirestore safely handles missing and null fields', () {
      final data = <String, dynamic>{};

      final attraction = Attraction.fromFirestore('empty_doc', data);

      expect(attraction.id, 'empty_doc');
      expect(attraction.name, 'Unnamed attraction');
      expect(attraction.category, 'Other');
      expect(attraction.description, '');
      expect(attraction.imageUrl, '');
      expect(attraction.rating, 0.0);
      expect(attraction.distance, 'Nearby');
      expect(attraction.location, '');
      expect(attraction.openingHours, 'Not available');
      expect(attraction.entryFee, 'Not available');
      expect(attraction.latitude, isNull);
      expect(attraction.longitude, isNull);
      expect(attraction.isSaved, false);
    });

    test('fromFirestore handles varying data types safely', () {
      final data = <String, dynamic>{
        'name': 'Charminar',
        'rating': 4, // int instead of double
        'distance': 1.2, // num instead of String
        'entryFee': 25, // num instead of String
        'latitude': '17.3616', // String instead of num
        'longitude': '78.4747',
        'isSaved': 'true', // String instead of bool
      };

      final attraction = Attraction.fromFirestore('type_test', data);

      expect(attraction.rating, 4.0);
      expect(attraction.distance, '1.2 km');
      expect(attraction.entryFee, '₹25');
      expect(attraction.latitude, 17.3616);
      expect(attraction.longitude, 78.4747);
      expect(attraction.isSaved, true);
    });

    test('fromFirestore extracts GeoPoint coordinates correctly', () {
      const geoPoint = GeoPoint(17.3616, 78.4747);
      final data = <String, dynamic>{
        'name': 'Charminar with GeoPoint',
        'coordinates': geoPoint,
        'location': 'Hyderabad',
      };

      final attraction = Attraction.fromFirestore('geo_test', data);

      expect(attraction.latitude, 17.3616);
      expect(attraction.longitude, 78.4747);
      expect(attraction.location, 'Hyderabad');
    });

    test('toFirestore serializes data properly', () {
      const attraction = Attraction(
        id: 'test_id',
        name: 'Hussain Sagar',
        category: 'Nature',
        description: 'Heart-shaped lake',
        imageUrl: 'https://example.com/lake.jpg',
        rating: 4.5,
        distance: '5.4 km',
        location: 'Hyderabad',
        openingHours: 'Open all day',
        entryFee: 'Free',
        latitude: 17.4239,
        longitude: 78.4738,
        isSaved: false,
      );

      final map = attraction.toFirestore();

      expect(map['name'], 'Hussain Sagar');
      expect(map['category'], 'Nature');
      expect(map['description'], 'Heart-shaped lake');
      expect(map['imageUrl'], 'https://example.com/lake.jpg');
      expect(map['rating'], 4.5);
      expect(map['distance'], '5.4 km');
      expect(map['location'], 'Hyderabad');
      expect(map['openingHours'], 'Open all day');
      expect(map['entryFee'], 'Free');
      expect(map['latitude'], 17.4239);
      expect(map['longitude'], 78.4738);
      expect(map['isSaved'], false);
    });

    test('copyWith updates fields as expected', () {
      const attraction = Attraction(
        id: 'test_id',
        name: 'Birla Mandir',
        category: 'Religious',
        description: 'Temple',
        imageUrl: 'https://example.com/temple.jpg',
        rating: 4.6,
        distance: '3.8 km',
        location: 'Hyderabad',
        openingHours: '7:00 AM - 12:00 PM',
        entryFee: 'Free',
        isSaved: false,
      );

      final updated = attraction.copyWith(isSaved: true);

      expect(updated.id, attraction.id);
      expect(updated.name, attraction.name);
      expect(updated.isSaved, true);
    });
  });

  group('AttractionService tests', () {
    test('devFallbackEnabled returns dummy data when enabled in test', () async {
      AttractionService.devFallbackEnabled = true;

      final attractions = await AttractionService.instance.getAttractions();
      expect(attractions.isNotEmpty, true);
      expect(attractions.length, DummyData.attractions.length);

      final single = await AttractionService.instance.getAttraction('1');
      expect(single, isNotNull);
      expect(single!.name, 'Charminar');

      AttractionService.devFallbackEnabled = false;
    });

    test('uninitialized Firebase throws StateError when devFallbackEnabled is false', () async {
      AttractionService.devFallbackEnabled = false;

      expect(
        () => AttractionService.instance.getAttractions(),
        throwsStateError,
      );

      expect(
        () => AttractionService.instance.getAttraction('1'),
        throwsStateError,
      );
    });
  });

  group('SavedPlacesStore tests', () {
    test('registers attractions and handles toggle', () {
      final store = SavedPlacesStore.instance;
      store.resetForTest();

      expect(store.savedAttractions, isEmpty);

      const place1 = Attraction(
        id: 'p1',
        name: 'Place 1',
        category: 'Nature',
        description: '',
        imageUrl: '',
        rating: 4.0,
        distance: '1 km',
        location: '',
        openingHours: '',
        entryFee: '',
        isSaved: true,
      );
      const place2 = Attraction(
        id: 'p2',
        name: 'Place 2',
        category: 'Historical',
        description: '',
        imageUrl: '',
        rating: 4.5,
        distance: '2 km',
        location: '',
        openingHours: '',
        entryFee: '',
        isSaved: false,
      );

      store.registerAttractions([place1, place2]);

      expect(store.isSaved('p1'), true);
      expect(store.isSaved('p2'), false);
      expect(store.savedAttractions.length, 1);
      expect(store.savedAttractions.first.name, 'Place 1');

      store.toggle('p2');
      expect(store.isSaved('p2'), true);
      expect(store.savedAttractions.length, 2);

      store.toggle('p1');
      expect(store.isSaved('p1'), false);
      expect(store.savedAttractions.length, 1);

      store.resetForTest();
    });
  });
}


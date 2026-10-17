import 'package:cloud_firestore/cloud_firestore.dart';

/// Representation of a user's curated travel trip / itinerary.
class Trip {
  const Trip({
    required this.id,
    required this.userId,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.attractionIds = const <String>[],
    this.budget,
    this.travelerCount = 1,
    this.dayItinerary = const <int, List<String>>{},
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> attractionIds;
  final double? budget;
  final int travelerCount;
  final Map<int, List<String>> dayItinerary;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get attractionCount => attractionIds.length;

  int get durationInDays {
    final diff = endDate.difference(startDate).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  /// Formatted available budget string (e.g. "$1500" or empty if unset).
  String get formattedBudget {
    if (budget == null || budget! <= 0) return '';
    return '\$${budget!.toStringAsFixed(0)}';
  }

  /// Formatted travelers summary (e.g. "1 traveller", "4 travellers").
  String get formattedTravelers =>
      '$travelerCount ${travelerCount == 1 ? 'traveller' : 'travellers'}';

  /// Resolves the day-by-day itinerary.
  ///
  /// If [dayItinerary] is populated, returns it. Otherwise, partitions
  /// [attractionIds] across the trip's [durationInDays] days for a balanced
  /// default schedule.
  Map<int, List<String>> get resolvedDayItinerary {
    if (dayItinerary.isNotEmpty) {
      return Map<int, List<String>>.unmodifiable(
        dayItinerary.map((k, v) => MapEntry(k, List<String>.unmodifiable(v))),
      );
    }
    final days = durationInDays <= 0 ? 1 : durationInDays;
    final map = <int, List<String>>{};
    for (int i = 1; i <= days; i++) {
      map[i] = <String>[];
    }
    for (int i = 0; i < attractionIds.length; i++) {
      final dayIndex = (i % days) + 1;
      map[dayIndex]!.add(attractionIds[i]);
    }
    return Map<int, List<String>>.unmodifiable(
      map.map((k, v) => MapEntry(k, List<String>.unmodifiable(v))),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Human-readable date range formatting (e.g. "10 Oct – 14 Oct 2026").
  String get formattedDateRange {
    final startMonth = _months[startDate.month - 1];
    final endMonth = _months[endDate.month - 1];

    if (startDate.year == endDate.year) {
      if (startDate.month == endDate.month) {
        if (startDate.day == endDate.day) {
          return '${startDate.day} $startMonth ${startDate.year}';
        }
        return '${startDate.day} – ${endDate.day} $startMonth ${startDate.year}';
      }
      return '${startDate.day} $startMonth – ${endDate.day} $endMonth ${startDate.year}';
    }
    return '${startDate.day} $startMonth ${startDate.year} – ${endDate.day} $endMonth ${endDate.year}';
  }

  static DateTime _parseDateTime(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now();
  }

  /// Construct a [Trip] from a Firestore document snapshot data map.
  factory Trip.fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return Trip(
        id: id,
        userId: '',
        name: '',
        destination: '',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        attractionIds: const <String>[],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    final rawAttractions = data['attractionIds'];
    final List<String> parsedAttractions;
    if (rawAttractions is Iterable) {
      parsedAttractions = rawAttractions
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      parsedAttractions = const <String>[];
    }

    final rawDayItinerary = data['dayItinerary'];
    final parsedDayItinerary = <int, List<String>>{};
    if (rawDayItinerary is Map) {
      rawDayItinerary.forEach((key, val) {
        final dayNum = int.tryParse(key.toString());
        if (dayNum != null && val is Iterable) {
          final list = val
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
          parsedDayItinerary[dayNum] = list;
        }
      });
    }

    final now = DateTime.now();
    final start = _parseDateTime(data['startDate'], fallback: now);
    final end = _parseDateTime(data['endDate'], fallback: start);

    return Trip(
      id: id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString().trim() ?? '',
      destination: data['destination']?.toString().trim() ?? '',
      startDate: start,
      endDate: end,
      attractionIds: List.unmodifiable(parsedAttractions),
      budget: (data['budget'] as num?)?.toDouble(),
      travelerCount: (data['travelerCount'] as num?)?.toInt() ?? 1,
      dayItinerary: parsedDayItinerary,
      createdAt: _parseDateTime(data['createdAt'], fallback: now),
      updatedAt: _parseDateTime(data['updatedAt'], fallback: now),
    );
  }

  /// Construct a [Trip] from a standard JSON / in-memory map.
  factory Trip.fromMap(String id, Map<String, dynamic> map) =>
      Trip.fromFirestore(id, map);

  /// Converts the trip to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'name': name.trim(),
      'destination': destination.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'attractionIds': attractionIds,
      'travelerCount': travelerCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
    if (budget != null) map['budget'] = budget;
    if (dayItinerary.isNotEmpty) {
      map['dayItinerary'] = dayItinerary.map((k, v) => MapEntry(k.toString(), v));
    }
    return map;
  }

  /// Plain JSON-compatible map for serialization and offline tests.
  Map<String, dynamic> toRawMap() {
    final map = <String, dynamic>{
      'id': id,
      'userId': userId,
      'name': name.trim(),
      'destination': destination.trim(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'attractionIds': attractionIds,
      'travelerCount': travelerCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    if (budget != null) map['budget'] = budget;
    if (dayItinerary.isNotEmpty) {
      map['dayItinerary'] = dayItinerary.map((k, v) => MapEntry(k.toString(), v));
    }
    return map;
  }

  Trip copyWith({
    String? id,
    String? userId,
    String? name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? attractionIds,
    double? budget,
    bool clearBudget = false,
    int? travelerCount,
    Map<int, List<String>>? dayItinerary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      attractionIds: attractionIds ?? this.attractionIds,
      budget: clearBudget ? null : (budget ?? this.budget),
      travelerCount: travelerCount ?? this.travelerCount,
      dayItinerary: dayItinerary ?? this.dayItinerary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

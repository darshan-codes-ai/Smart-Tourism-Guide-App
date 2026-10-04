import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  const Review({
    required this.id,
    required this.attractionId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String attractionId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review copyWith({
    String? id,
    String? attractionId,
    String? userId,
    String? userName,
    double? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      attractionId: attractionId ?? this.attractionId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Review.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    String attractionId = '',
  }) {
    return Review(
      id: id,
      attractionId: attractionId,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? 'Traveler',
      rating: _parseRating(data['rating']),
      comment: data['comment']?.toString() ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt'] ?? data['createdAt']),
    );
  }

  static double _parseRating(dynamic value) {
    if (value is num) return value.toDouble().clamp(1.0, 5.0);
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed.clamp(1.0, 5.0);
    }
    return 5.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }
}


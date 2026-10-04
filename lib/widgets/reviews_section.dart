import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../models/review.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';

class ReviewsSection extends StatelessWidget {
  const ReviewsSection({
    super.key,
    required this.attractionId,
    this.attractionName,
  });

  final String attractionId;
  final String? attractionName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = AuthService.instance.currentUser;

    return StreamBuilder<List<Review>>(
      stream: ReviewService.instance.streamReviews(attractionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Failed to load reviews',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Please check your connection and try again.',
                  style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                ),
              ],
            ),
          );
        }

        final reviews = snapshot.data ?? const <Review>[];
        final totalReviews = reviews.length;
        final averageRating = totalReviews == 0
            ? 0.0
            : double.parse(
                (reviews.fold<double>(0.0, (acc, r) => acc + r.rating) /
                        totalReviews)
                    .toStringAsFixed(1),
              );

        Review? userReview;
        if (currentUser != null) {
          try {
            userReview = reviews.firstWhere((r) => r.userId == currentUser.uid);
          } catch (_) {
            userReview = null;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reviews',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _handleWriteOrEditReview(
                    context,
                    attractionId,
                    existingReview: userReview,
                  ),
                  icon: Icon(
                    userReview != null
                        ? Icons.edit_rounded
                        : Icons.rate_review_rounded,
                    size: 18,
                  ),
                  label: Text(
                    userReview != null ? 'Edit Your Review' : 'Write a Review',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RatingSummaryCard(
              averageRating: averageRating,
              totalReviews: totalReviews,
            ),
            const SizedBox(height: 16),
            if (reviews.isEmpty)
              const _EmptyReviewsCard()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  final isOwner = currentUser?.uid == review.userId;
                  return _ReviewCard(
                    review: review,
                    isOwner: isOwner,
                    onEdit: () => _handleWriteOrEditReview(
                      context,
                      attractionId,
                      existingReview: review,
                    ),
                    onDelete: () => _confirmDeleteReview(
                      context,
                      attractionId,
                      review.id,
                      review.userId,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _handleWriteOrEditReview(
    BuildContext context,
    String attractionId, {
    Review? existingReview,
  }) {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: Color(0xFF176B87)),
                SizedBox(width: 8),
                Text('Sign in Required'),
              ],
            ),
            content: const Text(
              'Please sign in to write a review and share your travel experience.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.push(AppRouter.login);
                },
                child: const Text('Sign In'),
              ),
            ],
          );
        },
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _WriteReviewSheet(
          attractionId: attractionId,
          existingReview: existingReview,
          currentUserId: currentUser.uid,
          currentUserName: currentUser.displayName ??
              currentUser.email?.split('@').first ??
              'Traveler',
        );
      },
    );
  }

  Future<void> _confirmDeleteReview(
    BuildContext context,
    String attractionId,
    String reviewId,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete Review'),
          content: const Text(
            'Are you sure you want to delete your review? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await ReviewService.instance.deleteReview(
          attractionId: attractionId,
          reviewId: reviewId,
          userId: userId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review deleted successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard({
    required this.averageRating,
    required this.totalReviews,
  });

  final double averageRating;
  final int totalReviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD3E7ED)),
      ),
      child: Row(
        children: [
          Text(
            totalReviews == 0 ? '—' : averageRating.toStringAsFixed(1),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF176B87),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StarRatingBar(
                  rating: averageRating,
                  size: 18,
                  color: const Color(0xFFF5A524),
                ),
                const SizedBox(height: 4),
                Text(
                  totalReviews == 0
                      ? 'No reviews yet'
                      : '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5B6B73),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviewsCard extends StatelessWidget {
  const _EmptyReviewsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EBEE)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 38,
            color: Color(0xFF9AA8AF),
          ),
          const SizedBox(height: 10),
          const Text(
            'No reviews yet.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1A2B33),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Be the first to review this attraction.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5B6B73),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  final Review review;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = review.userName.isNotEmpty
        ? review.userName[0].toUpperCase()
        : 'T';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwner ? const Color(0xFFBCE3E1) : const Color(0xFFE4EBEE),
          width: isOwner ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF176B87),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.userName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F4F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF176B87),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(review.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8B9CA3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRatingBar(
                rating: review.rating,
                size: 15,
                color: const Color(0xFFF5A524),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF2C3E50),
              height: 1.4,
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('Delete', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRatingBar extends StatelessWidget {
  const _StarRatingBar({
    required this.rating,
    this.size = 18,
    this.color = const Color(0xFFF5A524),
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        if (rating >= starValue) {
          return Icon(Icons.star_rounded, size: size, color: color);
        } else if (rating >= starValue - 0.5) {
          return Icon(Icons.star_half_rounded, size: size, color: color);
        } else {
          return Icon(Icons.star_outline_rounded,
              size: size, color: color.withValues(alpha: 0.5));
        }
      }),
    );
  }
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({
    required this.attractionId,
    this.existingReview,
    required this.currentUserId,
    required this.currentUserName,
  });

  final String attractionId;
  final Review? existingReview;
  final String currentUserId;
  final String currentUserName;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  late double _rating;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 5.0;
    _commentController = TextEditingController(
      text: widget.existingReview?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      setState(() => _errorMessage = 'Please enter your review comment.');
      return;
    }
    if (comment.length > 2000) {
      setState(
        () => _errorMessage = 'Comment cannot exceed 2000 characters.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.existingReview != null) {
        await ReviewService.instance.updateReview(
          attractionId: widget.attractionId,
          reviewId: widget.existingReview!.id,
          userId: widget.currentUserId,
          rating: _rating,
          comment: comment,
        );
      } else {
        await ReviewService.instance.createReview(
          attractionId: widget.attractionId,
          userId: widget.currentUserId,
          userName: widget.currentUserName,
          rating: _rating,
          comment: comment,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingReview != null
                  ? 'Review updated successfully!'
                  : 'Review submitted successfully!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingReview != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Edit Your Review' : 'Write a Review',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Share your experience to help fellow travelers.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B6B73),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Rating',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = _rating >= starIndex;
                return IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _rating = starIndex.toDouble()),
                  iconSize: 36,
                  icon: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected
                        ? const Color(0xFFF5A524)
                        : Colors.grey.shade400,
                  ),
                );
              }),
            ),
            Center(
              child: Text(
                '$_rating / 5.0',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF176B87),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your Review',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                    'What did you like or dislike? Any tips for other visitors?',
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEditing ? 'Save Changes' : 'Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}


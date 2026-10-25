import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/attraction.dart';
import '../../models/review.dart';
import '../../services/admin_service.dart';
import '../../services/attraction_service.dart';
import '../../services/firestore_service.dart';
import '../../services/review_service.dart';
import '../../services/seed_service.dart';
import 'attraction_form_dialog.dart';

/// Professional Admin Dashboard Screen with tabbed navigation:
/// 1. Attractions & Dataset Analytics (Overview & CRUD)
/// 2. Review Moderation (Inspection, Filtering & Removal)
/// 3. Users & Security (Access Control & RBAC Policy Audit)
///
/// Protected by [AdminService]: ordinary users or signed-out visitors cannot view
/// dashboard operations and are shown an unauthorized notice.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  final _reviewSearchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedCountry;

  String _reviewSearchQuery = '';
  String _reviewRatingFilter = 'All'; // 'All', 'Low (<=2)', '5 Stars'

  bool _isCheckingAuth = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
    _reviewSearchController.addListener(() {
      setState(() {
        _reviewSearchQuery = _reviewSearchController.text.trim();
      });
    });
    _verifyAdminAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reviewSearchController.dispose();
    super.dispose();
  }

  Future<void> _verifyAdminAccess() async {
    setState(() => _isCheckingAuth = true);
    final isAdmin = await AdminService.instance.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _isAuthorized = isAdmin;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await AttractionFormDialog.show(context);
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attraction created successfully!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  Future<void> _openEditDialog(Attraction attraction) async {
    final updated = await AttractionFormDialog.show(context, attraction: attraction);
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated "${attraction.name}" successfully!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Attraction attraction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Attraction'),
        content: Text(
          'Are you sure you want to delete "${attraction.name}"? '
          'This will permanently remove the attraction from the database.',
        ),
        actions: [
          TextButton(
            key: const Key('admin_delete_cancel_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('admin_delete_confirm_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await AttractionService.instance.deleteAttraction(attraction.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${attraction.name}".'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteReview(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Moderate Review'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove this review by "${review.userName}" '
          'for attraction "${review.attractionId}"?\n\n'
          'Comment: "${review.comment}"',
        ),
        actions: [
          TextButton(
            key: const Key('admin_mod_cancel_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('admin_mod_confirm_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove Review'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ReviewService.instance.moderateDeleteReview(
          attractionId: review.attractionId,
          reviewId: review.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Review by "${review.userName}" removed successfully.'),
              backgroundColor: AppTheme.primary,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove review: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSeedGlobalAttractions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Seed Global Attractions'),
          ],
        ),
        content: const Text(
          'This administrative operation populates the Firestore database with curated global attractions '
          'from the local catalog (~829 destinations).\n\n'
          '• Existing attractions will be detected and preserved (never overwritten).\n'
          '• Records are validated and written in safe batches (max 250 documents).\n'
          '• Safe and idempotent: you can run or retry this operation at any time.\n\n'
          'Do you want to proceed?',
        ),
        actions: [
          TextButton(
            key: const Key('admin_seed_cancel_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const Key('admin_seed_confirm_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Start Seeding'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show progress dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Seeding attractions into Firestore...\nPlease wait.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final report = await SeedService.instance.seedGlobalAttractions();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close progress
        showDialog<void>(
          context: context,
          builder: (resCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 10),
                Text('Seeding Complete'),
              ],
            ),
            content: Text(
              'Database seeding completed:\n\n'
              '• Total examined: ${report.totalExamined}\n'
              '• Newly seeded: ${report.seededCount}\n'
              '• Skipped (already exist): ${report.skippedCount}\n'
              '• Validation errors: ${report.errors.length}',
            ),
            actions: [
              FilledButton(
                key: const Key('admin_seed_result_ok_button'),
                onPressed: () {
                  Navigator.of(resCtx).pop();
                  setState(() {});
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seeding failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('admin_auth_checking_indicator')),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _navigateBack(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 56, color: Colors.red.shade600),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You do not have administrator permissions to access this dashboard. '
                  'Please contact support or sign in with an administrator account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('admin_unauthorized_return_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () => _navigateBack(),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _navigateBack(),
          ),
          actions: [
            IconButton(
              key: const Key('admin_refresh_button'),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: FilledButton.icon(
                key: const Key('admin_add_attraction_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Attraction'),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: Icon(Icons.dashboard_rounded, size: 20),
                text: 'Attractions & Overview',
              ),
              Tab(
                icon: Icon(Icons.rate_review_rounded, size: 20),
                text: 'Review Moderation',
              ),
              Tab(
                icon: Icon(Icons.security_rounded, size: 20),
                text: 'Users & Security',
              ),
            ],
          ),
        ),
        body: StreamBuilder<List<Attraction>>(
          stream: AttractionService.instance.watchAttractions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(key: Key('admin_stream_loading_indicator')),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load attractions:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allAttractions = snapshot.data ?? <Attraction>[];

            return TabBarView(
              children: [
                _buildOverviewAndAttractionsTab(allAttractions),
                _buildReviewModerationTab(),
                _buildUsersAndSecurityTab(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OVERVIEW & ATTRACTION MANAGEMENT
  // ---------------------------------------------------------------------------

  Widget _buildOverviewAndAttractionsTab(List<Attraction> allAttractions) {
    final totalCount = allAttractions.length;
    final avgRating = totalCount == 0
        ? 0.0
        : allAttractions.map((a) => a.rating).reduce((a, b) => a + b) / totalCount;

    final categoryCounts = <String, int>{};
    final countryCounts = <String, int>{};
    for (final a in allAttractions) {
      final cat = a.category.trim();
      if (cat.isNotEmpty) {
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
      final country = a.country.trim();
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }
    }

    String topCategory = 'None';
    int topCategoryCount = 0;
    categoryCounts.forEach((cat, count) {
      if (count > topCategoryCount) {
        topCategory = cat;
        topCategoryCount = count;
      }
    });

    String topCountry = 'None';
    int topCountryCount = 0;
    countryCounts.forEach((cntry, count) {
      if (count > topCountryCount) {
        topCountry = cntry;
        topCountryCount = count;
      }
    });

    // Filter attractions
    final filtered = allAttractions.where((a) {
      final matchesCategory = _selectedCategory == null ||
          _selectedCategory == 'All' ||
          a.category.toLowerCase() == _selectedCategory!.toLowerCase();
      final matchesCountry = _selectedCountry == null ||
          _selectedCountry == 'All' ||
          a.country.toLowerCase() == _selectedCountry!.toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          a.name.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q) ||
          a.city.toLowerCase().contains(q) ||
          a.country.toLowerCase().contains(q) ||
          a.location.toLowerCase().contains(q);
      return matchesCategory && matchesCountry && matchesSearch;
    }).toList();

    return CustomScrollView(
      slivers: [
        // Analytics Overview Cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dataset Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('admin_seed_database_button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleSeedGlobalAttractions,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text('Seed Database', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<AdminDashboardStats>(
                  initialData: AdminDashboardStats(
                    totalAttractions: totalCount,
                    averageRating: double.parse(avgRating.toStringAsFixed(2)),
                    totalReviews: 0,
                    topCategory: topCategory,
                    topCategoryCount: topCategoryCount,
                    topCountry: topCountry,
                    topCountryCount: topCountryCount,
                  ),
                  future: AdminService.instance.getDashboardStats(allAttractions),
                  builder: (context, statsSnapshot) {
                    final stats = statsSnapshot.data ??
                        AdminDashboardStats(
                          totalAttractions: totalCount,
                          averageRating: double.parse(avgRating.toStringAsFixed(2)),
                          totalReviews: 0,
                          topCategory: topCategory,
                          topCategoryCount: topCategoryCount,
                          topCountry: topCountry,
                          topCountryCount: topCountryCount,
                        );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        return GridView.count(
                          crossAxisCount: isWide ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: isWide ? 1.75 : 1.35,
                          children: [
                            _buildMetricCard(
                              title: 'Total Attractions',
                              value: stats.totalAttractions.toString(),
                              subtitle: 'Registered in database',
                              icon: Icons.landscape_rounded,
                              color: AppTheme.primary,
                            ),
                            _buildMetricCard(
                              title: 'Average Rating',
                              value: stats.averageRating.toStringAsFixed(2),
                              subtitle: 'Out of 5.0 stars',
                              icon: Icons.star_rounded,
                              color: Colors.amber.shade700,
                            ),
                            _buildMetricCard(
                              title: 'Total Reviews',
                              value: stats.totalReviews.toString(),
                              subtitle: 'Traveler feedback',
                              icon: Icons.rate_review_rounded,
                              color: Colors.blue.shade700,
                            ),
                            _buildMetricCard(
                              title: 'Users & Trips',
                              value: '${stats.totalUsers ?? "—"} / ${stats.totalTrips ?? "—"}',
                              subtitle: stats.usersRestricted
                                  ? 'Restricted by rules'
                                  : 'Active accounts / trips',
                              icon: Icons.people_alt_rounded,
                              color: Colors.indigo.shade600,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Search & Category/Country Filters
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('admin_search_field'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, category, city, country...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category & Country Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: const Text('All Categories'),
                          selected: _selectedCategory == null || _selectedCategory == 'All',
                          onSelected: (_) {
                            setState(() => _selectedCategory = 'All');
                          },
                        ),
                      ),
                      ...categoryCounts.keys.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text('$cat (${categoryCounts[cat]})'),
                            selected: _selectedCategory == cat,
                            onSelected: (sel) {
                              setState(() {
                                _selectedCategory = sel ? cat : 'All';
                              });
                            },
                          ),
                        );
                      }),
                      if (countryCounts.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: const Text('All Countries'),
                            selected: _selectedCountry == null || _selectedCountry == 'All',
                            onSelected: (_) {
                              setState(() => _selectedCountry = 'All');
                            },
                          ),
                        ),
                        ...countryCounts.keys.map((cntry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text('$cntry (${countryCounts[cntry]})'),
                              selected: _selectedCountry == cntry,
                              onSelected: (sel) {
                                setState(() {
                                  _selectedCountry = sel ? cntry : 'All';
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filtered.length} of $totalCount attractions',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Attractions List
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No attractions found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try adjusting your search criteria or clear filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    if (totalCount == 0) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const Key('admin_empty_seed_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(0, 42),
                        ),
                        onPressed: _handleSeedGlobalAttractions,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: const Text('Seed Global Attractions Catalog'),
                      ),
                    ] else if (_searchQuery.isNotEmpty ||
                        (_selectedCategory != null && _selectedCategory != 'All') ||
                        (_selectedCountry != null && _selectedCountry != 'All'))
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedCategory = 'All';
                            _selectedCountry = 'All';
                          });
                        },
                        child: const Text('Clear Filters'),
                      ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final attraction = filtered[index];
                  return _buildAttractionCard(attraction);
                },
                childCount: filtered.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 40),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: REVIEW MODERATION
  // ---------------------------------------------------------------------------

  Widget _buildReviewModerationTab() {
    return FutureBuilder<List<Review>>(
      future: ReviewService.instance.getRecentReviews(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allReviews = snapshot.data ?? const <Review>[];

        // Filter reviews
        final filteredReviews = allReviews.where((r) {
          final q = _reviewSearchQuery.toLowerCase();
          final matchesSearch = q.isEmpty ||
              r.comment.toLowerCase().contains(q) ||
              r.userName.toLowerCase().contains(q) ||
              r.attractionId.toLowerCase().contains(q);

          if (!matchesSearch) return false;

          if (_reviewRatingFilter == 'Low (<=2)') {
            return r.rating <= 2.0;
          } else if (_reviewRatingFilter == '5 Stars') {
            return r.rating >= 4.9;
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search field
            TextField(
              key: const Key('admin_review_search_field'),
              controller: _reviewSearchController,
              decoration: InputDecoration(
                hintText: 'Search reviews by comment, user, or attraction ID...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _reviewSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => _reviewSearchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Rating filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${allReviews.length})'),
                    selected: _reviewRatingFilter == 'All',
                    onSelected: (_) => setState(() => _reviewRatingFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Low Ratings (<=2 ★) (${allReviews.where((r) => r.rating <= 2.0).length})',
                    ),
                    selected: _reviewRatingFilter == 'Low (<=2)',
                    selectedColor: Colors.amber.shade100,
                    onSelected: (_) => setState(() => _reviewRatingFilter = 'Low (<=2)'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      '5 Stars (${allReviews.where((r) => r.rating >= 4.9).length})',
                    ),
                    selected: _reviewRatingFilter == '5 Stars',
                    onSelected: (_) => setState(() => _reviewRatingFilter = '5 Stars'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filteredReviews.length} reviews for moderation',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filteredReviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No reviews found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'No reviews match the current moderation criteria.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredReviews.map((r) => _buildReviewModerationCard(r)),
          ],
        );
      },
    );
  }

  Widget _buildReviewModerationCard(Review review) {
    final isLowRating = review.rating <= 2.0;

    return Card(
      key: Key('admin_review_card_${review.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLowRating ? Colors.amber.shade300 : Colors.grey.shade200,
          width: isLowRating ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    review.attractionId,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isLowRating)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Flagged: Low Rating',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.userName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                TextButton.icon(
                  key: Key('admin_delete_review_button_${review.id}'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _confirmDeleteReview(review),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove Review', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: USERS & SECURITY AUDIT
  // ---------------------------------------------------------------------------

  Widget _buildUsersAndSecurityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Security Architecture Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF176B87).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF176B87).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.security_rounded, color: Color(0xFF176B87), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Security & Access Control Architecture',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF176B87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '• Fail-Closed Authorization: Administrative privileges are checked via Firebase custom token claims and verified against the Firestore /users/{uid} profile document.\n'
                '• Immutability & Self-Promotion Prevention: Firestore security rules prevent users from granting themselves administrator roles (request.resource.data.role == resource.data.role).\n'
                '• Privacy Enforcement: Client apps cannot browse arbitrary user accounts or export passwords/tokens; user role administration requires the Firebase Admin SDK on a trusted backend.',
                style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Registered User Accounts (Audit Directory)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Users registered in the local test store or accessible via administrative credentials.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        FutureBuilder<List<AppUser>>(
          future: FirestoreService.instance.getUsersForAdmin(limit: 50),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final users = snapshot.data ?? const <AppUser>[];

            if (users.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No user accounts listed',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Direct client-side iteration of the /users collection is restricted by Firestore security rules. '
                      'User management operations must be performed using the Firebase Admin SDK in production.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: users.map((u) {
                final isUserAdmin = u.isAdmin;
                return Card(
                  key: Key('admin_user_card_${u.uid}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isUserAdmin ? AppTheme.primary.withValues(alpha: 0.5) : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isUserAdmin ? AppTheme.primary : Colors.grey.shade300,
                      child: Icon(
                        isUserAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      (u.name != null && u.name!.isNotEmpty) ? u.name! : 'User (${u.uid})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Email: ${(u.email != null && u.email!.isNotEmpty) ? u.email! : 'None'} • Provider: ${u.provider}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUserAdmin
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        u.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isUserAdmin ? AppTheme.primary : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED WIDGET HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttractionCard(Attraction attraction) {
    return Card(
      key: Key('admin_attraction_card_${attraction.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Image.network(
                  attraction.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.landscape_rounded, color: Colors.grey, size: 32),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          attraction.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          attraction.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          attraction.displayLocation.isNotEmpty
                              ? attraction.displayLocation
                              : attraction.location,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        attraction.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.payments_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        attraction.formattedFee,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('admin_edit_button_${attraction.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit',
                  color: AppTheme.primary,
                  onPressed: () => _openEditDialog(attraction),
                ),
                IconButton(
                  key: Key('admin_delete_button_${attraction.id}'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Delete',
                  color: Colors.red.shade600,
                  onPressed: () => _confirmDelete(attraction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRouter.home);
    }
  }
}

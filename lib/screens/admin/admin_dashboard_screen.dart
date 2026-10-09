import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attraction.dart';
import '../../services/admin_service.dart';
import '../../services/attraction_service.dart';
import 'attraction_form_dialog.dart';

/// Admin Dashboard Screen for managing tourist attractions and viewing dataset analytics.
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
  String _searchQuery = '';
  String? _selectedCategory;
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
    _verifyAdminAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

    return Scaffold(
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Attraction'),
            ),
          ),
        ],
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
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allAttractions = snapshot.data ?? <Attraction>[];

          // Compute analytics directly from dataset
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
            final q = _searchQuery.toLowerCase();
            final matchesSearch = q.isEmpty ||
                a.name.toLowerCase().contains(q) ||
                a.category.toLowerCase().contains(q) ||
                a.city.toLowerCase().contains(q) ||
                a.country.toLowerCase().contains(q) ||
                a.location.toLowerCase().contains(q);
            return matchesCategory && matchesSearch;
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
                      const Text(
                        'Dataset Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 650;
                          return GridView.count(
                            crossAxisCount: isWide ? 4 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: isWide ? 1.7 : 1.35,
                            children: [
                              _buildMetricCard(
                                title: 'Total Attractions',
                                value: totalCount.toString(),
                                subtitle: 'Registered in database',
                                icon: Icons.landscape_rounded,
                                color: AppTheme.primary,
                              ),
                              _buildMetricCard(
                                title: 'Average Rating',
                                value: avgRating.toStringAsFixed(2),
                                subtitle: 'Out of 5.0 stars',
                                icon: Icons.star_rounded,
                                color: Colors.amber.shade700,
                              ),
                              _buildMetricCard(
                                title: 'Top Category',
                                value: topCategory,
                                subtitle: topCategoryCount > 0 ? '$topCategoryCount attractions' : '-',
                                icon: Icons.category_rounded,
                                color: const Color(0xFF0F9D58),
                              ),
                              _buildMetricCard(
                                title: 'Top Country',
                                value: topCountry,
                                subtitle: topCountryCount > 0 ? '$topCountryCount attractions' : '-',
                                icon: Icons.public_rounded,
                                color: const Color(0xFF673AB7),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Search & Category Filters
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
                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: const Text('All Categories'),
                                selected: _selectedCategory == null || _selectedCategory == 'All',
                                onSelected: (sel) {
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          if (_searchQuery.isNotEmpty || (_selectedCategory != null && _selectedCategory != 'All'))
                            OutlinedButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _selectedCategory = 'All');
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
        },
      ),
    );
  }

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

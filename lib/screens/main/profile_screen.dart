import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            'Profile',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFF176B87),
                    child: Text(
                      'AS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.dummyUserName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConstants.dummyUserEmail,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ProfileTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            onTap: () => _showPlaceholder(context, 'Edit Profile'),
          ),
          _ProfileTile(
            icon: Icons.reviews_outlined,
            title: 'My Reviews',
            onTap: () => _showPlaceholder(context, 'My Reviews'),
          ),
          _ProfileTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            onTap: () => _showPlaceholder(context, 'Notifications'),
          ),
          _ProfileTile(
            icon: Icons.language_rounded,
            title: 'Language',
            onTap: () => _showPlaceholder(context, 'Language'),
          ),
          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => _showPlaceholder(context, 'Settings'),
          ),
          _ProfileTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () => _showPlaceholder(context, 'Help & Support'),
          ),
          const SizedBox(height: 8),
          _ProfileTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            destructive: true,
            onTap: () => context.go(AppRouter.login),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label will be available in a later phase.')),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: color),
        onTap: onTap,
      ),
    );
  }
}

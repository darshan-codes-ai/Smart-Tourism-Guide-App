import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final displayName = _displayNameFor(user);
        final email = user?.email ?? 'No email available';
        final photoUrl = user?.photoURL;

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
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFF176B87),
                        foregroundImage: photoUrl == null
                            ? null
                            : NetworkImage(photoUrl),
                        child: photoUrl == null
                            ? Text(
                                _initialsFor(displayName, email),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
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
                title: _isSigningOut ? 'Logging out...' : 'Logout',
                destructive: true,
                onTap: _isSigningOut ? null : _signOut,
              ),
            ],
          ),
        );
      },
    );
  }

  String _displayNameFor(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return AppConstants.appName;
  }

  String _initialsFor(String displayName, String email) {
    final source = displayName == AppConstants.appName ? email : displayName;
    final parts = source
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'TM';
    }

    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await AuthService.instance.signOut();
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      _showMessage(context, error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label will be available in a later phase.')),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
  final VoidCallback? onTap;
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student_profile.dart';
import '../providers/chat_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_confirmation_dialog.dart';
import '../widgets/notification_action_button.dart';
import 'admin_panel_screen.dart';
import 'campus_feed_screen.dart';
import 'settings_screen.dart';
import 'smart_tools_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onSignedOut});

  final Future<void> Function() onSignedOut;

  static const Color _pageBlue = Color(0xFFF6FBFF);
  static const Color _pageBlueSoft = Color(0xFFEFF6FF);
  static const Color _heroBlue = Color(0xFFE8F3FF);
  static const Color _heroBlueSoft = Color(0xFFDDEBFF);

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider provider, Widget? child) {
        final StudentProfile? profile = provider.studentProfile;
        final String email =
            profile?.email ?? AuthService.currentUser?.email ?? '';
        final String name = profile?.name ?? 'EWU Student';
        final String studentId = profile?.studentId.isNotEmpty == true
            ? profile!.studentId
            : 'Not available';
        final String department = profile?.department ?? 'Unknown';
        final String batch = profile?.batchYear ?? 'Unknown';
        final DateTime? joinedAt = profile?.joinedAt;
        final String role = profile?.role ?? AuthService.currentRole;
        final bool canAccessAdminPanel =
            profile?.canAccessAdminPanel ?? AuthService.canModerateContent;

        final List<_ProfileActionData> campusActions = <_ProfileActionData>[
          _ProfileActionData(
            icon: Icons.calendar_month_outlined,
            title: 'My Routine',
            subtitle: 'Open your saved weekly classes.',
            badge: 'Routine',
            destination: const CampusFeedScreen(initialTab: 2),
          ),
          _ProfileActionData(
            icon: Icons.groups_rounded,
            title: 'Community Hub',
            subtitle: 'Browse campus posts, notices, and routine.',
            badge: 'Campus',
            destination: const CampusFeedScreen(initialTab: 0),
          ),
          _ProfileActionData(
            icon: Icons.notifications_active_outlined,
            title: 'Notices',
            subtitle: 'See official announcements from the app.',
            badge: 'Official',
            destination: const CampusFeedScreen(initialTab: 1),
          ),
        ];

        final List<_ProfileActionData> toolActions = <_ProfileActionData>[
          _ProfileActionData(
            icon: Icons.dashboard_customize_outlined,
            title: 'Student Smart Tools',
            subtitle: 'CGPA, routine, faculty finder, and exam countdown.',
            badge: '4 tools',
            destination: const SmartToolsScreen(),
          ),
        ];

        final List<_ProfileActionData> adminActions = <_ProfileActionData>[
          if (canAccessAdminPanel)
            _ProfileActionData(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin Panel',
              subtitle: profile?.isSuperAdmin == true
                  ? 'Manage admins and moderate campus activity.'
                  : 'Open moderation tools for app content.',
              badge: profile?.isSuperAdmin == true ? 'Super Admin' : 'Admin',
              destination: AdminPanelScreen(currentProfile: profile),
            ),
        ];

        return Scaffold(
          backgroundColor: _pageBlue,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[_pageBlue, _pageBlueSoft],
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Profile',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Account, shortcuts, and campus access in one place.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      NotificationActionButton(),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => _openSettings(context),
                        icon: const Icon(Icons.tune_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[_heroBlue, _heroBlueSoft],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppTheme.primaryDark.withValues(alpha: 0.08),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x120A1F44),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppTheme.primaryDark,
                              backgroundImage:
                                  profile?.photoUrl.isNotEmpty == true
                                  ? NetworkImage(profile!.photoUrl)
                                  : null,
                              child: profile?.photoUrl.isEmpty != false
                                  ? Text(
                                      (name.isNotEmpty ? name : 'E')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppTheme.primaryDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _RolePill(label: _roleLabel(role)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetaChip(
                              icon: Icons.badge_outlined,
                              label: studentId,
                            ),
                            _MetaChip(
                              icon: Icons.school_outlined,
                              label: department,
                            ),
                            _MetaChip(
                              icon: Icons.calendar_month_outlined,
                              label: batch == 'Unknown'
                                  ? 'Batch -'
                                  : 'Batch $batch',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  _accessIcon(role),
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _accessTitle(role),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppTheme.primaryDark,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _accessSubtitle(role),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openSettings(context),
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('Settings'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryDark,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: AppTheme.primaryDark.withValues(
                                      alpha: 0.14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _handleSignOut(context),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Sign Out'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoGrid(
                    context,
                    studentId: studentId,
                    department: department,
                    joinedAt: joinedAt,
                  ),
                  const SizedBox(height: 18),
                  _SectionBlock(
                    title: 'Campus',
                    subtitle:
                        'The parts of EWU Assistant you can open right now.',
                    children: campusActions
                        .map(
                          (_ProfileActionData action) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProfileActionCard(
                              data: action,
                              onTap: () =>
                                  _openDestination(context, action.destination),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _SectionBlock(
                    title: 'Smart Tools',
                    subtitle:
                        'Practical academic tools already available in the app.',
                    children: toolActions
                        .map(
                          (_ProfileActionData action) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProfileActionCard(
                              data: action,
                              onTap: () =>
                                  _openDestination(context, action.destination),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (adminActions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _SectionBlock(
                      title: 'Admin',
                      subtitle:
                          'Moderation and admin controls available for your role.',
                      children: adminActions
                          .map(
                            (_ProfileActionData action) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ProfileActionCard(
                                data: action,
                                onTap: () => _openDestination(
                                  context,
                                  action.destination,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoGrid(
    BuildContext context, {
    required String studentId,
    required String department,
    required DateTime? joinedAt,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 12;
        final bool singleColumn = constraints.maxWidth < 400;
        final double itemWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * 2)) / 3;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            SizedBox(
              width: itemWidth,
              child: _InfoCard(
                label: 'Student ID',
                value: studentId,
                icon: Icons.badge_outlined,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _InfoCard(
                label: 'Department',
                value: department,
                icon: Icons.school_outlined,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _InfoCard(
                label: 'Joined',
                value: joinedAt == null ? 'Unknown' : _formatDate(joinedAt),
                icon: Icons.access_time_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<SettingsScreen>(
        builder: (_) => SettingsScreen(onSignedOut: onSignedOut),
      ),
    );
  }

  void _openDestination(BuildContext context, Widget destination) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Sign Out?',
      message:
          'You will return to the login screen and end your current session on this device.',
      confirmLabel: 'Sign Out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    await AuthService.signOut();
    if (!context.mounted) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    }
    await onSignedOut();
  }

  static String _formatDate(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  static String _roleLabel(String role) {
    switch (role) {
      case StudentProfile.superAdminRole:
        return 'Super Admin';
      case StudentProfile.adminRole:
        return 'Admin';
      default:
        return 'Student';
    }
  }

  static String _accessTitle(String role) {
    switch (role) {
      case StudentProfile.superAdminRole:
        return 'Super Admin Access';
      case StudentProfile.adminRole:
        return 'Admin Access';
      default:
        return 'Student Access';
    }
  }

  static String _accessSubtitle(String role) {
    switch (role) {
      case StudentProfile.superAdminRole:
        return 'Manage admins, notices, and content moderation across the app.';
      case StudentProfile.adminRole:
        return 'Moderate posts, notices, and app content where your role allows.';
      default:
        return 'Use messages, community, smart tools, voice assistance, and notes.';
    }
  }

  static IconData _accessIcon(String role) {
    switch (role) {
      case StudentProfile.superAdminRole:
        return Icons.verified_user_outlined;
      case StudentProfile.adminRole:
        return Icons.shield_outlined;
      default:
        return Icons.school_outlined;
    }
  }
}

class _ProfileActionData {
  const _ProfileActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget destination;
  final String? badge;
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppTheme.primaryDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.premiumCard.copyWith(
        color: Colors.white.withValues(alpha: 0.94),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.premiumCard.copyWith(
        color: Colors.white.withValues(alpha: 0.94),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({required this.data, required this.onTap});

  final _ProfileActionData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.primaryDark.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(data.icon, color: AppTheme.primaryDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          data.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (data.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppTheme.primaryDark.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                          child: Text(
                            data.badge!,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

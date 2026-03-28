import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_branding.dart';
import '../widgets/app_confirmation_dialog.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key, required this.currentProfile});

  final StudentProfile? currentProfile;

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _busyUserId;

  bool get _isSuperAdmin =>
      (widget.currentProfile?.isSuperAdmin ?? false) ||
      AuthService.isSuperAdmin;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handlePromote(UserDirectoryRecord record) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Grant Admin Access?',
      message:
          'This will let ${record.profile.firstName} moderate campus content and manage notices/community items.',
      confirmLabel: 'Make Admin',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _busyUserId = record.uid;
    });

    try {
      await AuthService.promoteToAdmin(
        uid: record.uid,
        email: record.profile.email,
      );
      _showMessage('${record.profile.name} is now an admin.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _busyUserId = null;
        });
      }
    }
  }

  Future<void> _handleRemove(UserDirectoryRecord record) async {
    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Remove Admin Access?',
      message:
          '${record.profile.firstName} will lose campus moderation permissions immediately.',
      confirmLabel: 'Remove Admin',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _busyUserId = record.uid;
    });

    try {
      await AuthService.removeAdminRole(
        uid: record.uid,
        email: record.profile.email,
      );
      _showMessage('${record.profile.name} was removed from admin access.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _busyUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentProfile? currentProfile = widget.currentProfile;
    final String currentRole = currentProfile?.role ?? AuthService.currentRole;
    final bool canAccessPanel =
        currentProfile?.canAccessAdminPanel ?? AuthService.canModerateContent;

    if (!canAccessPanel) {
      return Scaffold(
        backgroundColor: AppTheme.pageTint,
        appBar: AppBar(title: const Text('Admin Panel')),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: _AdminEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Access Restricted',
                description:
                    'Admin tools are only available for approved moderators and the super admin.',
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.pageTint,
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: StreamBuilder<RoleConfigData>(
          stream: AuthService.watchRoleConfig(),
          builder: (BuildContext context, AsyncSnapshot<RoleConfigData> configSnapshot) {
            final RoleConfigData config =
                configSnapshot.data ??
                const RoleConfigData(
                  superAdminEmail: AuthService.superAdminEmail,
                  adminEmails: <String>[],
                );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.navyCardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const AppLogoMark(
                            size: 42,
                            dark: true,
                            backgroundColor: Color(0x26FFFFFF),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'EWU Assistant',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Campus Administration',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isSuperAdmin
                            ? 'You can manage admin access, moderate campus content, and oversee the EWU Assistant community.'
                            : 'Your moderation tools are live for posts, gallery items, notices, and community activity.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _AdminTag(
                            label: _roleLabel(currentRole),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                          ),
                          _AdminTag(
                            label:
                                'Assigned admins ${config.adminCount}/${AuthService.maxAdminCount}',
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                          ),
                          _AdminTag(
                            label: 'Moderators ${config.adminCount + 1}',
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _AdminSectionTitle(
                  title: 'Moderation Access',
                  subtitle:
                      'These permissions are live for admins and the super admin throughout the app.',
                ),
                const SizedBox(height: 12),
                const _AdminActionCard(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Feed And Gallery Moderation',
                  subtitle:
                      'Live now. Admins and the super admin can remove any campus feed or gallery item.',
                ),
                const SizedBox(height: 12),
                const _AdminActionCard(
                  icon: Icons.notifications_active_outlined,
                  title: 'Manage Notices',
                  subtitle:
                      'Live now. Admins and the super admin can publish and remove official notices.',
                ),
                const SizedBox(height: 12),
                const _AdminActionCard(
                  icon: Icons.groups_2_outlined,
                  title: 'Moderate Community',
                  subtitle:
                      'Live now. Admins can review events, lost-found items, and community posts.',
                ),
                const SizedBox(height: 16),
                if (_isSuperAdmin) ...<Widget>[
                  const _AdminSectionTitle(
                    title: 'Role Management',
                    subtitle:
                        'Search the user directory, manage assigned admins, and keep the 3-admin limit enforced.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.premiumCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Super Admin',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          config.superAdminEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'You can assign up to ${AuthService.maxAdminCount} admins at a time.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                StreamBuilder<List<UserDirectoryRecord>>(
                  stream: AuthService.watchUsers(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<UserDirectoryRecord>> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return const _AdminEmptyState(
                            icon: Icons.error_outline_rounded,
                            title: 'Users Unavailable',
                            description:
                                'We could not load the user directory right now. Please try again in a moment.',
                          );
                        }

                        final List<UserDirectoryRecord> records =
                            snapshot.data ?? const <UserDirectoryRecord>[];
                        final List<UserDirectoryRecord> adminRecords = records
                            .where((UserDirectoryRecord record) {
                              return record.profile.isAdmin ||
                                  record.profile.isSuperAdmin;
                            })
                            .toList();
                        final int assignedAdminCount = adminRecords.where((
                          UserDirectoryRecord record,
                        ) {
                          return record.profile.isAdmin;
                        }).length;
                        final String query = _searchController.text
                            .trim()
                            .toLowerCase();
                        final List<UserDirectoryRecord> filteredRecords =
                            query.isEmpty
                            ? records
                            : records.where((UserDirectoryRecord record) {
                                return record.profile.name
                                        .toLowerCase()
                                        .contains(query) ||
                                    record.profile.email.toLowerCase().contains(
                                      query,
                                    ) ||
                                    record.profile.studentId
                                        .toLowerCase()
                                        .contains(query);
                              }).toList();

                        if (records.isEmpty) {
                          return const _AdminEmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'No Users Yet',
                            description:
                                'Signed-in students will appear here once their profiles are written to Firestore.',
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _AdminSectionTitle(
                              title: 'Current Admins',
                              subtitle: _isSuperAdmin
                                  ? 'The super admin plus $assignedAdminCount assigned admins are active right now.'
                                  : 'This is the current moderation team for EWU Assistant.',
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: AppTheme.premiumCard,
                              child: adminRecords.isEmpty
                                  ? Text(
                                      'No campus admins are assigned yet.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: adminRecords.map((
                                            UserDirectoryRecord record,
                                          ) {
                                            return _CompactAdminChip(
                                              label: record.profile.firstName,
                                              role: record.profile.role,
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 12),
                                        ...adminRecords.map((
                                          UserDirectoryRecord record,
                                        ) {
                                          final bool canRemove =
                                              _isSuperAdmin &&
                                              !record.profile.isSuperAdmin;
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  record == adminRecords.last
                                                  ? 0
                                                  : 12,
                                            ),
                                            child: _AdminTeamMemberRow(
                                              profile: record.profile,
                                              isBusy: _busyUserId == record.uid,
                                              canRemove: canRemove,
                                              onRemove: canRemove
                                                  ? () => _handleRemove(record)
                                                  : null,
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                            ),
                            if (_isSuperAdmin) ...<Widget>[
                              const SizedBox(height: 16),
                              const _AdminSectionTitle(
                                title: 'All Registered Users',
                                subtitle:
                                    'Search every user and promote or remove admin access from here.',
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search users by name, email, or student ID',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon:
                                      _searchController.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (filteredRecords.isEmpty)
                                const _AdminEmptyState(
                                  icon: Icons.person_search_outlined,
                                  title: 'No Users Match',
                                  description:
                                      'Try a different name, email, or student ID to find a registered user.',
                                )
                              else
                                ...filteredRecords.map((
                                  UserDirectoryRecord record,
                                ) {
                                  final StudentProfile profile = record.profile;
                                  final bool isBusy = _busyUserId == record.uid;
                                  final bool isSuperAdminUser =
                                      profile.isSuperAdmin;
                                  final bool isAdminUser = profile.isAdmin;
                                  final bool atCapacity =
                                      config.adminCount >=
                                          AuthService.maxAdminCount &&
                                      !isAdminUser;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _UserRoleCard(
                                      profile: profile,
                                      isBusy: isBusy,
                                      actionLabel: isSuperAdminUser
                                          ? null
                                          : isAdminUser
                                          ? 'Remove Admin'
                                          : 'Promote To Admin',
                                      actionEnabled:
                                          !isBusy &&
                                          !isSuperAdminUser &&
                                          (isAdminUser || !atCapacity),
                                      helperLabel: isSuperAdminUser
                                          ? 'Fixed super admin access'
                                          : isAdminUser
                                          ? 'Assigned campus moderator'
                                          : atCapacity
                                          ? 'Admin limit reached'
                                          : 'Standard student access',
                                      onAction: isSuperAdminUser
                                          ? null
                                          : () {
                                              if (isAdminUser) {
                                                _handleRemove(record);
                                              } else {
                                                _handlePromote(record);
                                              }
                                            },
                                    ),
                                  );
                                }),
                            ] else ...<Widget>[
                              const SizedBox(height: 16),
                              const _AdminEmptyState(
                                icon: Icons.shield_outlined,
                                title: 'Role Management Locked',
                                description:
                                    'Only the super admin can assign or remove admin roles. Your moderation tools remain active.',
                              ),
                            ],
                          ],
                        );
                      },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case StudentProfile.superAdminRole:
        return 'Super Admin';
      case StudentProfile.adminRole:
        return 'Admin';
      default:
        return 'User';
    }
  }
}

class _AdminTag extends StatelessWidget {
  const _AdminTag({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _AdminTeamMemberRow extends StatelessWidget {
  const _AdminTeamMemberRow({
    required this.profile,
    required this.isBusy,
    required this.canRemove,
    required this.onRemove,
  });

  final StudentProfile profile;
  final bool isBusy;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 420;
        final Widget identity = Row(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryDark,
              backgroundImage: profile.photoUrl.isNotEmpty
                  ? NetworkImage(profile.photoUrl)
                  : null,
              child: profile.photoUrl.isEmpty
                  ? Text(
                      profile.firstName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          profile.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!compact) _RoleChip(role: profile.role),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              identity,
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _RoleChip(role: profile.role),
                  if (canRemove)
                    OutlinedButton.icon(
                      onPressed: isBusy ? null : onRemove,
                      icon: isBusy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_remove_outlined),
                      label: const Text('Remove Admin'),
                    ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: identity),
            if (canRemove) ...<Widget>[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onRemove,
                icon: isBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_remove_outlined),
                label: const Text('Remove'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CompactAdminChip extends StatelessWidget {
  const _CompactAdminChip({required this.label, required this.role});

  final String label;
  final String role;

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = role == StudentProfile.superAdminRole;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSuperAdmin ? AppTheme.primaryDark : AppTheme.botBubble,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isSuperAdmin ? '$label - Super Admin' : '$label - Admin',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isSuperAdmin ? Colors.white : AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.premiumCard,
      child: Row(
        children: <Widget>[
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: AppTheme.botBubble,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppTheme.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
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

class _UserRoleCard extends StatelessWidget {
  const _UserRoleCard({
    required this.profile,
    required this.isBusy,
    required this.actionLabel,
    required this.actionEnabled,
    required this.helperLabel,
    required this.onAction,
  });

  final StudentProfile profile;
  final bool isBusy;
  final String? actionLabel;
  final bool actionEnabled;
  final String helperLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 420;
              final Widget header = Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryDark,
                    backgroundImage: profile.photoUrl.isNotEmpty
                        ? NetworkImage(profile.photoUrl)
                        : null,
                    child: profile.photoUrl.isEmpty
                        ? Text(
                            profile.firstName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
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
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                profile.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.studentId.isEmpty
                              ? helperLabel
                              : '${profile.studentId} | $helperLabel',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (!compact) {
                return Row(
                  children: <Widget>[
                    Expanded(child: header),
                    const SizedBox(width: 12),
                    _RoleChip(role: profile.role),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  header,
                  const SizedBox(height: 12),
                  _RoleChip(role: profile.role),
                ],
              );
            },
          ),
          if (actionLabel != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: actionEnabled ? onAction : null,
                child: isBusy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color foregroundColor;
    final String label;

    switch (role) {
      case StudentProfile.superAdminRole:
        backgroundColor = AppTheme.primaryDark;
        foregroundColor = Colors.white;
        label = 'Super Admin';
        break;
      case StudentProfile.adminRole:
        backgroundColor = AppTheme.botBubble;
        foregroundColor = AppTheme.primaryDark;
        label = 'Admin';
        break;
      default:
        backgroundColor = const Color(0xFFF1F4F9);
        foregroundColor = AppTheme.textSecondary;
        label = 'User';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.premiumCard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppTheme.botBubble,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: AppTheme.primaryDark, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

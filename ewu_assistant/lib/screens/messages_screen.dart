import 'package:flutter/material.dart';

import '../models/direct_chat.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_action_button.dart';
import 'direct_chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.initialSection = 0});

  final int initialSection;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const List<_MessageTabData> _sections = <_MessageTabData>[
    _MessageTabData(label: 'Chats', icon: Icons.chat_bubble_outline_rounded),
    _MessageTabData(label: 'People', icon: Icons.groups_2_outlined),
  ];

  final SocialService _socialService = SocialService();
  final TextEditingController _searchController = TextEditingController();

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSection.clamp(0, _sections.length - 1);
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _selectedIndex = widget.initialSection.clamp(0, _sections.length - 1);
      });
    }
  }

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

  Future<void> _openChat(UserDirectoryRecord user) async {
    try {
      final String chatId = await _socialService.ensureDirectChat(
        otherUid: user.uid,
        otherProfile: user.profile,
      );
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<DirectChatScreen>(
          builder: (_) => DirectChatScreen(
            chatId: chatId,
            otherUser: user,
            socialService: _socialService,
          ),
        ),
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = AuthService.currentUser?.uid ?? '';
    if (currentUid.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FBFF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: _EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Sign in to use networking',
                description:
                    'Your campus directory and direct chats will appear here after sign in.',
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<MessagesDashboardData>(
          stream: _socialService.watchDashboard(currentUid),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<MessagesDashboardData> snapshot,
              ) {
                final MessagesDashboardData dashboard =
                    snapshot.data ??
                    MessagesDashboardData.empty(currentUid: currentUid);

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Networking',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppTheme.primaryDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              NotificationActionButton(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Campus chats and people in app, all in one clean space.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _CompactTabs(
                      selectedIndex: _selectedIndex,
                      tabs: _sections,
                      onChanged: (int index) {
                        setState(() {
                          _selectedIndex = index;
                          if (index == 0) {
                            _searchController.clear();
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: _selectedIndex == 0
                          ? _buildChats(dashboard, snapshot)
                          : _buildPeople(dashboard, snapshot),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }

  Widget _buildChats(
    MessagesDashboardData dashboard,
    AsyncSnapshot<MessagesDashboardData> snapshot,
  ) {
    if (snapshot.hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'We could not sync chats',
            description: 'Pull to refresh or reopen Messages in a moment.',
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        dashboard.chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<_ResolvedChatItem> chats = dashboard.chats
        .map(
          (DirectChatThread chat) => _ResolvedChatItem(
            chat: chat,
            user: dashboard.userForId(
              chat.otherParticipantId(dashboard.currentUid) ?? '',
            ),
          ),
        )
        .where((_ResolvedChatItem item) => item.user != null)
        .toList();

    if (chats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _EmptyState(
            icon: Icons.mark_chat_unread_outlined,
            title: 'No chats yet',
            description:
                'Open People to start a direct conversation with someone in the app.',
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 118),
      itemCount: chats.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final _ResolvedChatItem item = chats[index];
        return _ChatRow(
          item: item,
          currentUid: dashboard.currentUid,
          onTap: () => _openChat(item.user!),
        );
      },
    );
  }

  Widget _buildPeople(
    MessagesDashboardData dashboard,
    AsyncSnapshot<MessagesDashboardData> snapshot,
  ) {
    if (snapshot.hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'We could not sync people in app',
            description: 'Please try reopening Messages in a moment.',
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        dashboard.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final String query = _searchController.text.trim().toLowerCase();
    final List<UserDirectoryRecord> users = dashboard.directoryUsers.where((
      UserDirectoryRecord record,
    ) {
      if (query.isEmpty) {
        return true;
      }
      final StudentProfile profile = record.profile;
      return profile.name.toLowerCase().contains(query) ||
          profile.email.toLowerCase().contains(query) ||
          profile.studentId.toLowerCase().contains(query) ||
          profile.department.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search people...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.primaryLight,
              ),
              fillColor: const Color(0xFFEFF4FF),
              suffixIcon: _searchController.text.trim().isEmpty
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
        ),
        Expanded(
          child: dashboard.directoryUsers.isEmpty && query.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: _EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No people in app yet',
                      description:
                          'As more EWU Assistant users join, they will appear here.',
                    ),
                  ),
                )
              : users.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: _EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No people found',
                      description:
                          'Try another search term or clear the search field.',
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 118),
                  itemCount: users.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final UserDirectoryRecord user = users[index];
                    return _PeopleRow(user: user, onTap: () => _openChat(user));
                  },
                ),
        ),
      ],
    );
  }
}

class _CompactTabs extends StatelessWidget {
  const _CompactTabs({
    required this.selectedIndex,
    required this.tabs,
    required this.onChanged,
  });

  final int selectedIndex;
  final List<_MessageTabData> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: List<Widget>.generate(tabs.length, (int index) {
            final bool selected = index == selectedIndex;
            final _MessageTabData tab = tabs[index];
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  gradient: selected ? AppTheme.navyGradient : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x180A1F44),
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: InkWell(
                  onTap: () => onChanged(index),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          tab.icon,
                          size: 19,
                          color: selected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.label,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.user, required this.onTap});

  final UserDirectoryRecord user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StudentProfile profile = user.profile;
    final String subtitle = _directorySubtitle(profile);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3ECF8)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x120A1F44),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: <Widget>[
                _Avatar(profile: profile, radius: 26),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (profile.role != StudentProfile.userRole)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _RoleBadge(role: profile.role),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.item,
    required this.currentUid,
    required this.onTap,
  });

  final _ResolvedChatItem item;
  final String currentUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StudentProfile? profile = item.user?.profile;
    final bool unread = item.chat.isUnreadFor(currentUid);
    final String title = profile?.name ?? 'Campus Chat';

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: unread ? const Color(0xFFDCE7FF) : const Color(0xFFE3ECF8),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x120A1F44),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    _Avatar(profile: profile, radius: 26),
                    if (unread)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryDark,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.chat.previewText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: unread
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      _formatTime(item.chat.lastMessageAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    unread
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'New',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          )
                        : const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.radius});

  final StudentProfile? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String fallbackLabel = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'E';
    final Color avatarColor = _avatarColor(profile);
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor,
      backgroundImage: profile?.photoUrl.isNotEmpty == true
          ? NetworkImage(profile!.photoUrl)
          : null,
      child: profile?.photoUrl.isEmpty != false
          ? Text(
              fallbackLabel.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = role == StudentProfile.superAdminRole;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSuperAdmin ? AppTheme.primaryDark : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isSuperAdmin ? 'Super' : 'Admin',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isSuperAdmin ? Colors.white : AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: AppTheme.botBubble,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: AppTheme.primaryDark),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _ResolvedChatItem {
  const _ResolvedChatItem({required this.chat, required this.user});

  final DirectChatThread chat;
  final UserDirectoryRecord? user;
}

class _MessageTabData {
  const _MessageTabData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

String _directorySubtitle(StudentProfile profile) {
  final List<String> parts = <String>[];
  if (profile.department.isNotEmpty) {
    parts.add(profile.department);
  }
  if (profile.studentId.isNotEmpty) {
    parts.add(profile.studentId);
  }
  if (parts.isEmpty) {
    parts.add(profile.email);
  }
  return parts.join(' | ');
}

Color _avatarColor(StudentProfile? profile) {
  const List<Color> palette = <Color>[
    Color(0xFF6C63FF),
    Color(0xFF0A1F44),
    Color(0xFF2B7FFF),
    Color(0xFF5B86FF),
    Color(0xFF3C7A89),
    Color(0xFF845EC2),
  ];
  final String seed =
      '${profile?.studentId ?? ''}${profile?.email ?? ''}${profile?.name ?? ''}';
  if (seed.isEmpty) {
    return palette.first;
  }
  return palette[seed.codeUnits.fold<int>(
        0,
        (int sum, int code) => sum + code,
      ) %
      palette.length];
}

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '';
  }
  final DateTime local = dateTime.toLocal();
  final DateTime now = DateTime.now();
  final bool isToday =
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;
  final String minute = local.minute.toString().padLeft(2, '0');
  final int rawHour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final String suffix = local.hour >= 12 ? 'PM' : 'AM';
  return isToday ? '$rawHour:$minute $suffix' : '${local.day}/${local.month}';
}

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'admin_panel_screen.dart';
import 'campus_feed_screen.dart';
import 'direct_chat_screen.dart';
import 'messages_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final SocialService _socialService = SocialService();

  Future<void> _markAllRead(String uid) async {
    await _notificationService.markAllAsRead(uid);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read.')),
    );
  }

  Future<void> _openNotification(AppNotificationItem item) async {
    await _notificationService.markAsRead(item.id);
    if (!mounted) {
      return;
    }

    switch (item.type) {
      case 'message_activity':
        final String currentUid = AuthService.currentUser?.uid ?? '';
        final String senderUid = item.senderUid.trim();
        final String chatId = item.relatedId.trim();
        final UserDirectoryRecord? sender = senderUid.isEmpty
            ? null
            : await _socialService.fetchUserByUid(senderUid);
        if (!mounted) {
          return;
        }
        if (sender != null && chatId.isNotEmpty && sender.uid != currentUid) {
          await Navigator.of(context).push(
            MaterialPageRoute<DirectChatScreen>(
              builder: (_) => DirectChatScreen(
                chatId: chatId,
                otherUser: sender,
                socialService: _socialService,
              ),
            ),
          );
          break;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<MessagesScreen>(
            builder: (_) => const MessagesScreen(initialSection: 0),
          ),
        );
        break;
      case 'notice_published':
        await Navigator.of(context).push(
          MaterialPageRoute<CampusFeedScreen>(
            builder: (_) => const CampusFeedScreen(initialTab: 1),
          ),
        );
        break;
      case 'community_event':
        await Navigator.of(context).push(
          MaterialPageRoute<CampusFeedScreen>(
            builder: (_) => const CampusFeedScreen(initialTab: 0),
          ),
        );
        break;
      case 'admin_promotion':
      case 'admin_update':
        final profile = await AuthService.getProfile();
        if (!mounted) {
          return;
        }
        if (profile != null && AuthService.canModerateContent) {
          await Navigator.of(context).push(
            MaterialPageRoute<AdminPanelScreen>(
              builder: (_) => AdminPanelScreen(currentProfile: profile),
            ),
          );
          break;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(item.body)));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked as read.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = AuthService.currentUser?.uid ?? '';
    final bool signedIn = uid.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.pageTint,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (signedIn)
            TextButton(
              onPressed: () => _markAllRead(uid),
              child: const Text(
                'Mark all',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: !signedIn
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: _NotificationEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'Sign In To See Notifications',
                    description:
                        'Messages, notices, and campus alerts will appear here once you are signed in.',
                  ),
                ),
              )
            : StreamBuilder<List<AppNotificationItem>>(
                stream: _notificationService.watchNotifications(uid),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<AppNotificationItem>> snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: _NotificationEmptyState(
                              icon: Icons.error_outline_rounded,
                              title: 'Notifications Unavailable',
                              description:
                                  'We could not load your in-app notifications right now. Please try again in a moment.',
                            ),
                          ),
                        );
                      }

                      final List<AppNotificationItem> notifications =
                          snapshot.data ?? const <AppNotificationItem>[];
                      final int unreadCount = notifications
                          .where((AppNotificationItem item) => !item.isRead)
                          .length;

                      if (notifications.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: _NotificationEmptyState(
                              icon: Icons.notifications_none_rounded,
                              title: 'No Notifications Yet',
                              description:
                                  'New messages, official notices, and campus updates will appear here as soon as activity starts.',
                            ),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: AppTheme.premiumCard,
                            child: Row(
                              children: <Widget>[
                                Container(
                                  height: 52,
                                  width: 52,
                                  decoration: BoxDecoration(
                                    color: AppTheme.botBubble,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_active_outlined,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'In-app activity',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        unreadCount == 0
                                            ? 'You are all caught up.'
                                            : '$unreadCount unread notifications waiting for you.',
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
                          ...notifications.map((AppNotificationItem item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NotificationCard(
                                notification: item,
                                onTap: () => _openNotification(item),
                              ),
                            );
                          }),
                        ],
                      );
                    },
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotificationItem notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _NotificationVisual visual = _visualForType(notification.type);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.premiumCard.copyWith(
          border: Border.all(
            color: notification.isRead
                ? AppTheme.primaryDark.withValues(alpha: 0.04)
                : AppTheme.primaryDark.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: visual.backgroundColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(visual.icon, color: visual.foregroundColor),
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
                          notification.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _NotificationTypeChip(label: visual.label),
                      _NotificationTypeChip(
                        label: _formatTime(notification.createdAt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _NotificationVisual _visualForType(String type) {
    switch (type) {
      case 'message_activity':
        return const _NotificationVisual(
          label: 'Message',
          icon: Icons.mark_chat_unread_outlined,
          backgroundColor: AppTheme.botBubble,
          foregroundColor: AppTheme.primaryDark,
        );
      case 'admin_promotion':
      case 'admin_update':
        return const _NotificationVisual(
          label: 'Admin update',
          icon: Icons.admin_panel_settings_outlined,
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
        );
      case 'notice_published':
        return const _NotificationVisual(
          label: 'Notice',
          icon: Icons.campaign_outlined,
          backgroundColor: AppTheme.botBubble,
          foregroundColor: AppTheme.primaryDark,
        );
      default:
        return const _NotificationVisual(
          label: 'Update',
          icon: Icons.notifications_none_rounded,
          backgroundColor: AppTheme.botBubble,
          foregroundColor: AppTheme.primaryDark,
        );
    }
  }

  static String _formatTime(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final DateTime now = DateTime.now();
    final bool isToday =
        now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    final String minute = local.minute.toString().padLeft(2, '0');
    final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String suffix = local.hour >= 12 ? 'PM' : 'AM';
    return isToday
        ? '$hour:$minute $suffix'
        : '${local.day}/${local.month}/${local.year}';
  }
}

class _NotificationTypeChip extends StatelessWidget {
  const _NotificationTypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.botBubble,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({
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
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.premiumCard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: AppTheme.botBubble,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: AppTheme.primaryDark, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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

class _NotificationVisual {
  const _NotificationVisual({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

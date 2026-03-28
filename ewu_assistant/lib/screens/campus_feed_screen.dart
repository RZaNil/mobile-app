import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/notification_action_button.dart';
import 'campus_social_feed_tab.dart';
import 'notices_tab.dart';
import 'routine_tab.dart';

class CampusFeedScreen extends StatefulWidget {
  const CampusFeedScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CampusFeedScreen> createState() => _CampusFeedScreenState();
}

class _CampusFeedScreenState extends State<CampusFeedScreen>
    with SingleTickerProviderStateMixin {
  static const List<_CampusTabData> _tabs = <_CampusTabData>[
    _CampusTabData(label: 'Feed', icon: Icons.view_agenda_outlined),
    _CampusTabData(label: 'Notices', icon: Icons.campaign_outlined),
    _CampusTabData(label: 'Routine', icon: Icons.calendar_month_outlined),
  ];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Campus Hub',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  NotificationActionButton(),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryDark,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryDark,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: _tabs.map((_CampusTabData tab) {
                return Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(tab.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(tab.label),
                    ],
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const <Widget>[
                  CampusSocialFeedTab(),
                  NoticesTabView(),
                  RoutineTabView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusTabData {
  const _CampusTabData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

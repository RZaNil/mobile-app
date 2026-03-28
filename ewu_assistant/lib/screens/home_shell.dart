import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import 'campus_feed_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'voice_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onSignedOut});

  final Future<void> Function() onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const double _navBarHeight = 84;

  int _currentIndex = 2;
  bool _didInitializeProvider = false;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = _buildScreens();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onSignedOut != widget.onSignedOut) {
      _screens = _buildScreens();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeProvider) {
      return;
    }
    _didInitializeProvider = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatProvider>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppTheme.pageTint,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RepaintBoundary(
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
      ),
      bottomNavigationBar: keyboardVisible
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  height: _navBarHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: AppTheme.floatingNavDecoration,
                  child: Row(
                    children: <Widget>[
                      _NavItem(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Messages',
                        selected: _currentIndex == 0,
                        onTap: () => _selectTab(0),
                      ),
                      _NavItem(
                        icon: Icons.groups_rounded,
                        label: 'Community',
                        selected: _currentIndex == 1,
                        onTap: () => _selectTab(1),
                      ),
                      _NavItem(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Chat',
                        selected: _currentIndex == 2,
                        emphasized: true,
                        onTap: () => _selectTab(2),
                      ),
                      _NavItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Services',
                        selected: _currentIndex == 3,
                        onTap: () => _selectTab(3),
                      ),
                      _NavItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        selected: _currentIndex == 4,
                        onTap: () => _selectTab(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _selectTab(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  List<Widget> _buildScreens() {
    return <Widget>[
      const MessagesScreen(),
      const CampusFeedScreen(),
      VoiceScreen(onSignedOut: widget.onSignedOut),
      const ServicesScreen(),
      ProfileScreen(onSignedOut: widget.onSignedOut),
    ];
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = emphasized ? Colors.white : AppTheme.primaryDark;
    final Color inactiveColor = AppTheme.navInactive;

    return Expanded(
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.97,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (emphasized)
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      gradient: AppTheme.navyGradient,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.primaryDark.withValues(alpha: 0.24),
                          blurRadius: selected ? 18 : 10,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.botBubble : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? activeColor : inactiveColor,
                    size: 24,
                  ),
                ),
              const SizedBox(height: 1),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 18 : 6,
                height: 2,
                decoration: BoxDecoration(
                  color: selected
                      ? (emphasized ? AppTheme.primaryDark : activeColor)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 11,
                  color: selected
                      ? (emphasized ? AppTheme.primaryDark : activeColor)
                      : inactiveColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'smart_tools_screen.dart';

class ServicesSmartToolsTab extends StatelessWidget {
  const ServicesSmartToolsTab({super.key});

  static const List<_ToolShortcut> _tools = <_ToolShortcut>[
    _ToolShortcut(
      type: SmartToolType.cgpaPredictor,
      title: 'CGPA Predictor',
      subtitle: 'Estimate your next CGPA with projected courses.',
      icon: Icons.analytics_outlined,
    ),
    _ToolShortcut(
      type: SmartToolType.routineGenerator,
      title: 'Routine Generator',
      subtitle: 'Draft classes by day and save them to your routine.',
      icon: Icons.auto_awesome_outlined,
    ),
    _ToolShortcut(
      type: SmartToolType.facultyFinder,
      title: 'Faculty Finder',
      subtitle: 'Keep faculty contacts, rooms, and attachments organized.',
      icon: Icons.contact_mail_outlined,
    ),
    _ToolShortcut(
      type: SmartToolType.examCountdown,
      title: 'Exam Countdown',
      subtitle: 'Track exam time left with days and hours remaining.',
      icon: Icons.timer_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: <Widget>[
        Text(
          'Smart Tools',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Open the tool you need without digging through extra sections.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tools.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 168,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _ToolShortcut tool = _tools[index];
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<SmartToolsScreen>(
                    builder: (_) => SmartToolsScreen(initialTool: tool.type),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.premiumCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.botBubble,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(tool.icon, color: AppTheme.primaryDark),
                    ),
                    const Spacer(),
                    Text(
                      tool.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tool.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ToolShortcut {
  const _ToolShortcut({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final SmartToolType type;
  final String title;
  final String subtitle;
  final IconData icon;
}

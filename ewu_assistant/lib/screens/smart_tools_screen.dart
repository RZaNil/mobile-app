import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'smart_tools_cgpa_tab.dart';
import 'smart_tools_exam_countdown_tab.dart';
import 'smart_tools_faculty_finder_tab.dart';
import 'smart_tools_routine_tab.dart';

enum SmartToolType {
  cgpaPredictor,
  routineGenerator,
  facultyFinder,
  examCountdown,
}

extension SmartToolTypeX on SmartToolType {
  String get label {
    switch (this) {
      case SmartToolType.cgpaPredictor:
        return 'CGPA Predictor';
      case SmartToolType.routineGenerator:
        return 'Routine Generator';
      case SmartToolType.facultyFinder:
        return 'Faculty Finder';
      case SmartToolType.examCountdown:
        return 'Exam Countdown';
    }
  }
}

class SmartToolsScreen extends StatefulWidget {
  const SmartToolsScreen({
    super.key,
    this.initialTool = SmartToolType.cgpaPredictor,
  });

  final SmartToolType initialTool;

  @override
  State<SmartToolsScreen> createState() => _SmartToolsScreenState();
}

class _SmartToolsScreenState extends State<SmartToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SmartToolType.values.length,
      vsync: this,
      initialIndex: widget.initialTool.index,
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
      backgroundColor: AppTheme.pageTint,
      appBar: AppBar(title: const Text('Smart Tools')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryDark.withValues(alpha: 0.05),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textPrimary,
                    tabs: SmartToolType.values
                        .map((SmartToolType tool) => Tab(text: tool.label))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const <Widget>[
                    SmartToolsCgpaTab(),
                    SmartToolsRoutineTab(),
                    SmartToolsFacultyFinderTab(),
                    SmartToolsExamCountdownTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

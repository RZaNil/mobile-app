import 'package:flutter/material.dart';

import '../models/routine_class_item.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_confirmation_dialog.dart';

class RoutineTabView extends StatefulWidget {
  const RoutineTabView({super.key});

  @override
  State<RoutineTabView> createState() => _RoutineTabViewState();
}

class _RoutineTabViewState extends State<RoutineTabView> {
  final CommunityService _communityService = CommunityService();

  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dayFromWeekday(DateTime.now().weekday);
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRoutineSheet({RoutineClassItem? existingItem}) async {
    final String? uid = AuthService.currentUser?.uid;
    if (uid == null) {
      _showMessage('Please sign in again to manage your routine.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _RoutineComposerSheet(
          uid: uid,
          initialDay: existingItem?.day ?? _selectedDay,
          item: existingItem,
          communityService: _communityService,
          onMessage: _showMessage,
        );
      },
    );
  }

  Future<void> _deleteClass(RoutineClassItem item) async {
    final String? uid = AuthService.currentUser?.uid;
    if (uid == null) {
      _showMessage('Please sign in again to manage your routine.');
      return;
    }

    final bool confirmed = await showAppConfirmationDialog(
      context,
      title: 'Delete Class?',
      message:
          'This will remove ${item.courseCode} from your ${item.day} routine.',
      confirmLabel: 'Delete Class',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await _communityService.deleteRoutineClass(uid, item.id);
      _showMessage('Class removed from your routine.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = AuthService.currentUser?.uid;
    if (!_communityService.isAvailable) {
      return const _RoutineEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Routine Needs Firebase',
        description:
            'Complete your Firebase setup to save and manage your class schedule.',
      );
    }

    if (uid == null) {
      return const _RoutineEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign In To See Your Routine',
        description:
            'Your personal class schedule is saved to your account so you can access it across devices.',
      );
    }

    return StreamBuilder<List<RoutineClassItem>>(
      stream: _communityService.getRoutineClasses(uid),
      builder: (BuildContext context, AsyncSnapshot<List<RoutineClassItem>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const _RoutineEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Routine Unavailable',
            description:
                'We could not load your routine right now. Please try again shortly.',
          );
        }

        final List<RoutineClassItem> allClasses =
            snapshot.data ?? const <RoutineClassItem>[];
        final Map<String, int> counts = <String, int>{
          for (final String day in RoutineClassItem.days)
            day: allClasses
                .where((RoutineClassItem item) => item.day == day)
                .length,
        };
        final List<RoutineClassItem> dayClasses =
            allClasses
                .where((RoutineClassItem item) => item.day == _selectedDay)
                .toList()
              ..sort((RoutineClassItem a, RoutineClassItem b) {
                return _timeSortValue(
                  a.startTime,
                ).compareTo(_timeSortValue(b.startTime));
              });

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'My Routine',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.botBubble,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${counts[_selectedDay] ?? 0} classes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _showRoutineSheet,
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _showMessage(
                        'Advanced routine import will be added in the next pass.',
                      );
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload to Add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _showMessage(
                        'Routine PDF export will be added in the next pass.',
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Generate PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: RoutineClassItem.days.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 10),
                itemBuilder: (BuildContext context, int index) {
                  final String day = RoutineClassItem.days[index];
                  final bool selected = day == _selectedDay;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(day),
                    onSelected: (bool _) {
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: dayClasses.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 56, 0, 118),
                        children: <Widget>[
                          _RoutineEmptyState(
                            icon: Icons.event_busy_outlined,
                            title: 'No classes on $_selectedDay',
                            description:
                                'Tap + to add a class or use Upload to Add when import is ready.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 118),
                        itemCount: dayClasses.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (BuildContext context, int index) {
                          final RoutineClassItem item = dayClasses[index];
                          return _RoutineClassCard(
                            item: item,
                            onEdit: () => _showRoutineSheet(existingItem: item),
                            onDelete: () => _deleteClass(item),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoutineClassCard extends StatelessWidget {
  const _RoutineClassCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final RoutineClassItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.premiumCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 12,
            height: 96,
            decoration: BoxDecoration(
              color: item.colorValue,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.courseCode,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.courseTitle,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _RoutineMetaChip(
                      icon: Icons.schedule_outlined,
                      label: '${item.startTime} - ${item.endTime}',
                    ),
                    _RoutineMetaChip(
                      icon: Icons.meeting_room_outlined,
                      label: item.room.isEmpty ? 'Room TBD' : item.room,
                    ),
                    _RoutineMetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: item.day,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineComposerSheet extends StatefulWidget {
  const _RoutineComposerSheet({
    required this.uid,
    required this.initialDay,
    required this.item,
    required this.communityService,
    required this.onMessage,
  });

  final String uid;
  final String initialDay;
  final RoutineClassItem? item;
  final CommunityService communityService;
  final ValueChanged<String> onMessage;

  @override
  State<_RoutineComposerSheet> createState() => _RoutineComposerSheetState();
}

class _RoutineComposerSheetState extends State<_RoutineComposerSheet> {
  static const Map<String, String> _colorOptions = <String, String>{
    '#0A1F44': 'Navy',
    '#1C3F7A': 'Royal Blue',
    '#2E7D32': 'Green',
    '#D32F2F': 'Red',
    '#8E24AA': 'Purple',
    '#F57C00': 'Orange',
  };

  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _courseTitleController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  late String _selectedDay;
  late String _selectedColor;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final RoutineClassItem? item = widget.item;
    _selectedDay = item?.day ?? widget.initialDay;
    _selectedColor = item?.color ?? _colorOptions.keys.first;
    _courseCodeController.text = item?.courseCode ?? '';
    _courseTitleController.text = item?.courseTitle ?? '';
    _roomController.text = item?.room ?? '';
    _startTimeController.text = item?.startTime ?? '';
    _endTimeController.text = item?.endTime ?? '';
  }

  @override
  void dispose() {
    _courseCodeController.dispose();
    _courseTitleController.dispose();
    _roomController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String courseCode = _courseCodeController.text.trim();
    final String courseTitle = _courseTitleController.text.trim();
    final String room = _roomController.text.trim();
    final String startTime = _startTimeController.text.trim();
    final String endTime = _endTimeController.text.trim();

    if (courseCode.isEmpty ||
        courseTitle.isEmpty ||
        startTime.isEmpty ||
        endTime.isEmpty) {
      widget.onMessage('Please add course code, title, and class times.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final RoutineClassItem? existing = widget.item;
      final RoutineClassItem item = existing == null
          ? RoutineClassItem(
              id: '',
              day: _selectedDay,
              courseCode: courseCode,
              courseTitle: courseTitle,
              room: room,
              startTime: startTime,
              endTime: endTime,
              color: _selectedColor,
              createdAt: DateTime.now(),
            )
          : existing.copyWith(
              day: _selectedDay,
              courseCode: courseCode,
              courseTitle: courseTitle,
              room: room,
              startTime: startTime,
              endTime: endTime,
              color: _selectedColor,
            );

      if (existing == null) {
        await widget.communityService.createRoutineClass(widget.uid, item);
      } else {
        await widget.communityService.updateRoutineClass(widget.uid, item);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onMessage(existing == null ? 'Class saved.' : 'Class updated.');
    } catch (error) {
      widget.onMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.item == null ? 'Add Class' : 'Edit Class',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _selectedDay,
              items: RoutineClassItem.days.map((String day) {
                return DropdownMenuItem<String>(value: day, child: Text(day));
              }).toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedDay = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Day'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _courseCodeController,
              decoration: const InputDecoration(
                labelText: 'Course code',
                hintText: 'CSE101',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _courseTitleController,
              decoration: const InputDecoration(
                labelText: 'Course title',
                hintText: 'Introduction to Computing',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room',
                hintText: 'A-502',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _startTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Start time',
                      hintText: '9:00 AM',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endTimeController,
                    decoration: const InputDecoration(
                      labelText: 'End time',
                      hintText: '10:20 AM',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedColor,
              items: _colorOptions.entries.map((
                MapEntry<String, String> entry,
              ) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(
                              entry.key.replaceFirst('#', 'FF'),
                              radix: 16,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(entry.value),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedColor = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Color'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(
                  _isSubmitting
                      ? 'Saving...'
                      : widget.item == null
                      ? 'Save Class'
                      : 'Update Class',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineMetaChip extends StatelessWidget {
  const _RoutineMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.botBubble,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppTheme.primaryDark),
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

class _RoutineEmptyState extends StatelessWidget {
  const _RoutineEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
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
              child: Icon(icon, color: AppTheme.primaryDark, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

String _dayFromWeekday(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    default:
      return 'Sun';
  }
}

int _timeSortValue(String raw) {
  final String value = raw.trim().toUpperCase();
  final RegExpMatch? twelveHour = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
  ).firstMatch(value);
  if (twelveHour != null) {
    int hour = int.tryParse(twelveHour.group(1) ?? '') ?? 0;
    final int minute = int.tryParse(twelveHour.group(2) ?? '') ?? 0;
    final String suffix = twelveHour.group(3) ?? 'AM';
    if (suffix == 'PM' && hour != 12) {
      hour += 12;
    }
    if (suffix == 'AM' && hour == 12) {
      hour = 0;
    }
    return (hour * 60) + minute;
  }

  final RegExpMatch? twentyFourHour = RegExp(
    r'^(\d{1,2}):(\d{2})$',
  ).firstMatch(value);
  if (twentyFourHour != null) {
    final int hour = int.tryParse(twentyFourHour.group(1) ?? '') ?? 0;
    final int minute = int.tryParse(twentyFourHour.group(2) ?? '') ?? 0;
    return (hour * 60) + minute;
  }

  return 24 * 60;
}

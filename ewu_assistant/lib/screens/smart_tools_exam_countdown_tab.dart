import 'package:flutter/material.dart';

import '../services/smart_tools_service.dart';
import '../theme/app_theme.dart';
import '../widgets/smart_tool_widgets.dart';

class SmartToolsExamCountdownTab extends StatefulWidget {
  const SmartToolsExamCountdownTab({super.key});

  @override
  State<SmartToolsExamCountdownTab> createState() =>
      _SmartToolsExamCountdownTabState();
}

class _SmartToolsExamCountdownTabState
    extends State<SmartToolsExamCountdownTab> {
  final SmartToolsService _smartToolsService = SmartToolsService();
  final List<_ExamCountdownItem> _items = <_ExamCountdownItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> raw = await _smartToolsService
          .loadExamCountdownItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(raw.map(_ExamCountdownItem.fromJson));
        _items.sort(
          (_ExamCountdownItem a, _ExamCountdownItem b) =>
              a.date.compareTo(b.date),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _persist() async {
    await _smartToolsService.saveExamCountdownItems(
      _items.map((_ExamCountdownItem item) => item.toJson()).toList(),
    );
  }

  Future<void> _openEditor({_ExamCountdownItem? item}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        return _ExamEditorSheet(
          existingItem: item,
          onSave: (_ExamCountdownItem savedItem) async {
            final List<_ExamCountdownItem> previousItems =
                List<_ExamCountdownItem>.from(_items);
            final int existingIndex = _items.indexWhere(
              (_ExamCountdownItem value) => value.id == savedItem.id,
            );
            setState(() {
              if (existingIndex == -1) {
                _items.add(savedItem);
              } else {
                _items[existingIndex] = savedItem;
              }
              _items.sort(
                (_ExamCountdownItem a, _ExamCountdownItem b) =>
                    a.date.compareTo(b.date),
              );
            });
            try {
              await _persist();
              if (!mounted) {
                return;
              }
              messenger.showSnackBar(
                SnackBar(
                  content: Text(item == null ? 'Exam added.' : 'Exam updated.'),
                ),
              );
            } catch (error) {
              if (!mounted) {
                return;
              }
              setState(() {
                _items
                  ..clear()
                  ..addAll(previousItems);
              });
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    error.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
              );
              rethrow;
            }
          },
        );
      },
    );
  }

  Future<void> _delete(_ExamCountdownItem item) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<_ExamCountdownItem> previousItems =
        List<_ExamCountdownItem>.from(_items);
    setState(() {
      _items.removeWhere((_ExamCountdownItem value) => value.id == item.id);
    });
    try {
      await _persist();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('Exam removed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(previousItems);
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _openEditor,
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Add Exam'),
          ),
        ),
        const SizedBox(height: 16),
        if (_items.isEmpty)
          const SmartToolEmptyState(
            icon: Icons.timer_outlined,
            title: 'No exam countdowns yet',
            description:
                'Add an exam to see the remaining days and hours at a glance.',
          )
        else
          ..._items.map((_ExamCountdownItem item) {
            final Duration difference = item.date.difference(DateTime.now());
            final bool completed = difference.isNegative;
            final int totalHours = difference.inHours;
            final int daysLeft = completed ? 0 : totalHours ~/ 24;
            final int hoursLeft = completed ? 0 : totalHours % 24;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.premiumCard,
                child: Row(
                  children: <Widget>[
                    Container(
                      height: 74,
                      width: 74,
                      decoration: BoxDecoration(
                        color: completed
                            ? AppTheme.error.withValues(alpha: 0.08)
                            : AppTheme.botBubble,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            completed ? 'Done' : '$daysLeft',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: completed
                                      ? AppTheme.error
                                      : AppTheme.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            completed ? '' : 'days',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: completed
                                      ? AppTheme.error
                                      : AppTheme.primaryDark,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.courseCode.isEmpty
                                ? '${_formatDate(item.date)} | ${_formatTime(item.date)}'
                                : '${item.courseCode} | ${_formatDate(item.date)} | ${_formatTime(item.date)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            completed
                                ? 'This exam date has passed.'
                                : '$daysLeft day${daysLeft == 1 ? '' : 's'} and $hoursLeft hour${hoursLeft == 1 ? '' : 's'} left',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: completed
                                      ? AppTheme.error
                                      : AppTheme.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        if (value == 'edit') {
                          _openEditor(item: item);
                        } else {
                          _delete(item);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ExamEditorSheet extends StatefulWidget {
  const _ExamEditorSheet({required this.existingItem, required this.onSave});

  final _ExamCountdownItem? existingItem;
  final Future<void> Function(_ExamCountdownItem) onSave;

  @override
  State<_ExamEditorSheet> createState() => _ExamEditorSheetState();
}

class _ExamEditorSheetState extends State<_ExamEditorSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.existingItem?.title ?? '';
    _courseCodeController.text = widget.existingItem?.courseCode ?? '';
    _selectedDate =
        widget.existingItem?.date ??
        DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(_selectedDate);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exam title.')),
      );
      return;
    }
    try {
      await widget.onSave(
        _ExamCountdownItem(
          id:
              widget.existingItem?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          courseCode: _courseCodeController.text.trim().toUpperCase(),
          date: _selectedDate,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      // Parent callback already shows a user-friendly error.
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
              widget.existingItem == null ? 'Add exam' : 'Edit exam',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Exam title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _courseCodeController,
              decoration: const InputDecoration(
                labelText: 'Course code (optional)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(_formatDate(_selectedDate)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_outlined),
              label: Text(_formatTime(_selectedDate)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save exam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCountdownItem {
  const _ExamCountdownItem({
    required this.id,
    required this.title,
    required this.courseCode,
    required this.date,
  });

  final String id;
  final String title;
  final String courseCode;
  final DateTime date;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'courseCode': courseCode,
      'date': date.toIso8601String(),
    };
  }

  factory _ExamCountdownItem.fromJson(Map<String, dynamic> json) {
    return _ExamCountdownItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      courseCode: json['courseCode']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String _formatTime(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  final int rawHour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final String minute = local.minute.toString().padLeft(2, '0');
  final String suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$rawHour:$minute $suffix';
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import '../tasks/detalle_tarea_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focused = DateTime.now();
  DateTime? _selected;

  bool _showFilter = false;
  String? _subjectFilter; // null => Todas

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
      ),
      body: StreamBuilder<List<Subject>>(
        stream: FirestoreService.instance.watchSubjects(),
        builder: (context, subjSnap) {
          final subjects = subjSnap.data ?? const <Subject>[];
          final subjectsById = <String, Subject>{
            for (final s in subjects) s.id: s,
          };
          return StreamBuilder<List<TaskItem>>(
            stream: FirestoreService.instance.watchTasks(),
            builder: (context, snap) {
              final allTasks = snap.data ?? const <TaskItem>[];
              final tasks = _subjectFilter == null
                  ? allTasks
                  : allTasks
                      .where((t) => t.subjectId == _subjectFilter)
                      .toList();

              final tasksByDay = <DateTime, List<TaskItem>>{};
              for (final t in tasks) {
                final d = DateTime(t.fechaLimite.year, t.fechaLimite.month,
                    t.fechaLimite.day);
                tasksByDay.putIfAbsent(d, () => []).add(t);
              }

              return Column(
                children: [
                  _Toolbar(
                    format: _format,
                    onFormatChanged: (f) => setState(() => _format = f),
                    showFilter: _showFilter,
                    onToggleFilter: () =>
                        setState(() => _showFilter = !_showFilter),
                  ),
                  if (_showFilter)
                    _SubjectFilterRow(
                      subjects: subjects,
                      selected: _subjectFilter,
                      onChanged: (id) => setState(() => _subjectFilter = id),
                    ),
                  TableCalendar<TaskItem>(
                    locale: 'es',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focused,
                    calendarFormat: _format,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Mes',
                      CalendarFormat.twoWeeks: '2 semanas',
                      CalendarFormat.week: 'Semana',
                    },
                    onFormatChanged: (f) => setState(() => _format = f),
                    selectedDayPredicate: (d) =>
                        _selected != null && _sameDay(d, _selected!),
                    onDaySelected: (sel, foc) {
                      setState(() {
                        _selected = sel;
                        _focused = foc;
                      });
                    },
                    eventLoader: (day) {
                      final key = DateTime(day.year, day.month, day.day);
                      return tasksByDay[key] ?? const <TaskItem>[];
                    },
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                    ),
                    calendarBuilders: CalendarBuilders<TaskItem>(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox.shrink();
                        // El color del primer evento dicta el dot.
                        Color color = AppColors.primary;
                        final s = subjectsById[events.first.subjectId];
                        if (s != null) color = s.color;
                        return Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _DayTasksList(
                      day: _selected ?? DateTime.now(),
                      tasksByDay: tasksByDay,
                      subjectsById: subjectsById,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final CalendarFormat format;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final bool showFilter;
  final VoidCallback onToggleFilter;
  const _Toolbar({
    required this.format,
    required this.onFormatChanged,
    required this.showFilter,
    required this.onToggleFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          SegmentedButton<CalendarFormat>(
            segments: const [
              ButtonSegment(
                value: CalendarFormat.month,
                label: Text('Mes'),
              ),
              ButtonSegment(
                value: CalendarFormat.twoWeeks,
                label: Text('Semana'),
              ),
              ButtonSegment(
                value: CalendarFormat.week,
                label: Text('Día'),
              ),
            ],
            selected: <CalendarFormat>{format},
            onSelectionChanged: (s) => onFormatChanged(s.first),
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: onToggleFilter,
            icon: Icon(showFilter
                ? Icons.filter_alt_off_outlined
                : Icons.filter_alt_outlined),
            label: const Text('Filtrar'),
          ),
        ],
      ),
    );
  }
}

class _SubjectFilterRow extends StatelessWidget {
  final List<Subject> subjects;
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _SubjectFilterRow({
    required this.subjects,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          ...subjects.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.nombre),
                  selected: selected == s.id,
                  onSelected: (_) => onChanged(s.id),
                  selectedColor: s.color.withValues(alpha: 0.25),
                ),
              )),
        ],
      ),
    );
  }
}

class _DayTasksList extends StatelessWidget {
  final DateTime day;
  final Map<DateTime, List<TaskItem>> tasksByDay;
  final Map<String, Subject> subjectsById;
  const _DayTasksList({
    required this.day,
    required this.tasksByDay,
    required this.subjectsById,
  });

  @override
  Widget build(BuildContext context) {
    final key = DateTime(day.year, day.month, day.day);
    final items = tasksByDay[key] ?? const <TaskItem>[];
    final df = DateFormat("EEEE d 'de' MMMM", 'es');
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Sin tareas el ${df.format(day)}',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = items[i];
        final subject = subjectsById[t.subjectId];
        return Card(
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              t.titulo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  PriorityBadge(importancia: t.importancia, small: true),
                  if (subject != null)
                    SubjectBadge(nombre: subject.nombre, color: subject.color),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetalleTareaScreen(taskId: t.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

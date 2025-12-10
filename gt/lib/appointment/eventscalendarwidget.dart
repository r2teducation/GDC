// events_calendar_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small model for calendar events (appointments).
class AppointmentEvent {
  final String id;
  final String patientName;
  final DateTime start;
  final DateTime end;
  /// 'N' = New, 'F' = Follow Up
  final String type;

  AppointmentEvent({
    required this.id,
    required this.patientName,
    required this.start,
    required this.end,
    required this.type,
  });
}

/// Calendar widget showing a month grid and events per day.
/// Provide a list of AppointmentEvent via the `events` parameter.
/// Colors: blue for New (N), orange for Follow Up (F).
class EventsCalendarWidget extends StatefulWidget {
  final List<AppointmentEvent> events;
  final DateTime? initialMonth;
  final void Function(AppointmentEvent)? onTapEvent;

  const EventsCalendarWidget({
    super.key,
    this.events = const [],
    this.initialMonth,
    this.onTapEvent,
  });

  @override
  State<EventsCalendarWidget> createState() => _EventsCalendarWidgetState();
}

class _EventsCalendarWidgetState extends State<EventsCalendarWidget> {
  late DateTime _visibleMonth; // first day of visible month
  final DateFormat _monthFormat = DateFormat('MMMM yyyy');
  final DateFormat _timeFormat = DateFormat('h:mm a');
  final List<String> _weekdaysShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final init = widget.initialMonth ?? DateTime(now.year, now.month, 1);
    _visibleMonth = DateTime(init.year, init.month, 1);
  }

  // group events by date key 'yyyy-MM-dd'
  Map<String, List<AppointmentEvent>> _groupEventsByDay() {
    final map = <String, List<AppointmentEvent>>{};
    for (final e in widget.events) {
      final key = _dayKey(e.start);
      map.putIfAbsent(key, () => []).add(e);
    }

    // sort each list by start time
    for (final v in map.values) {
      v.sort((a, b) => a.start.compareTo(b.start));
    }
    return map;
  }

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  Future<void> _pickMonth() async {
    // simple month picker using showDatePicker limited to 1st of month selection;
    // user selects a day; we switch to that month.
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visibleMonth,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select month',
      fieldLabelText: 'Month',
    );
    if (picked != null) {
      setState(() {
        _visibleMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Color _colorForType(String t) {
    if (t == 'N') return const Color(0xFF2563EB); // blue
    if (t == 'F') return const Color(0xFFF97316); // orange
    return const Color(0xFF6B7280); // gray fallback
  }

  @override
  Widget build(BuildContext context) {
    final eventsByDay = _groupEventsByDay();

    // compute grid start (Sunday) and 6x7 matrix
    final firstOfMonth = _visibleMonth;
    final startOffset = firstOfMonth.weekday % 7; // DateTime.weekday: Mon=1..Sun=7; we want Sun=0
    final gridStart = firstOfMonth.subtract(Duration(days: startOffset));
    final cells = List<DateTime>.generate(42, (i) => DateTime(gridStart.year, gridStart.month, gridStart.day + i));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: Month + nav
        Row(
          children: [
            IconButton(
              onPressed: _prevMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _pickMonth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _monthFormat.format(_visibleMonth),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _nextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Weekday headers
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: _weekdaysShort
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Big calendar grid
        AspectRatio(
          aspectRatio: 7 / 6, // approximate tall grid
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Use Expanded grid of 6 rows
                  Expanded(
                    child: Column(
                      children: List.generate(6, (row) {
                        final rowCells = cells.skip(row * 7).take(7).toList();
                        return Expanded(
                          child: Row(
                            children: rowCells.map((day) {
                              final key = _dayKey(day);
                              final dayEvents = eventsByDay[key] ?? [];
                              final isCurrentMonth = day.month == _visibleMonth.month;
                              final isToday = _isSameDay(day, DateTime.now());

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    // open day details
                                    _openDaySheet(day, dayEvents);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isCurrentMonth ? Colors.transparent : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isToday ? const Color(0xFF0EA5A4) : Colors.transparent, width: isToday ? 2 : 0),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // day number
                                        Row(
                                          children: [
                                            Text(
                                              '${day.day}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: isCurrentMonth ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (dayEvents.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: dayEvents.length > 0 ? Colors.black.withOpacity(0.03) : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${dayEvents.length}',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // events preview (up to 3)
                                        ...dayEvents.take(3).map((e) {
                                          final color = _colorForType(e.type);
                                          final timeRange = '${_timeFormat.format(e.start)} - ${_timeFormat.format(e.end)}';
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.12),
                                                border: Border.all(color: color.withOpacity(0.22)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          e.patientName,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 12,
                                                            color: Colors.black87,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          timeRange,
                                                          style: TextStyle(fontSize: 11, color: Colors.black54),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),

                                        // if more events exist show indicator
                                        if (dayEvents.length > 3)
                                          Text(
                                            '+ ${dayEvents.length - 3} more',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _openDaySheet(DateTime day, List<AppointmentEvent> dayEvents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(day),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (dayEvents.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text('No appointments', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: controller,
                        itemCount: dayEvents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final e = dayEvents[idx];
                          final color = _colorForType(e.type);
                          final timeRange = '${_timeFormat.format(e.start)} - ${_timeFormat.format(e.end)}';
                          return Material(
                            elevation: 0,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                if (widget.onTapEvent != null) widget.onTapEvent!(e);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color.withOpacity(0.16)),
                                ),
                                child: Row(
                                  children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.patientName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                          const SizedBox(height: 6),
                                          Text(timeRange, style: const TextStyle(color: Colors.black54)),
                                          const SizedBox(height: 6),
                                          Text(e.type == 'N' ? 'New Appointment' : 'Follow Up', style: TextStyle(color: color)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        // callback: user may open appointment details/edit
                                        if (widget.onTapEvent != null) widget.onTapEvent!(e);
                                      },
                                      icon: const Icon(Icons.edit, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// ---------------------------
/// Example usage with sample data:
/// ---------------------------
/// Place this widget inside a Scaffold body, e.g.:
///
/// EventsCalendarWidget(
///   events: sampleEvents,
///   onTapEvent: (ev) {
///     // navigate to edit page or show details
///   },
/// )
///
/// Sample data helper:
List<AppointmentEvent> sampleEventsForDemo() {
  final now = DateTime.now();
  return [
    AppointmentEvent(
      id: 'a1',
      patientName: 'Rama Gutta',
      start: DateTime(now.year, now.month, 5, 10, 0),
      end: DateTime(now.year, now.month, 5, 10, 30),
      type: 'N',
    ),
    AppointmentEvent(
      id: 'a2',
      patientName: 'Anita Sharma',
      start: DateTime(now.year, now.month, 5, 11, 0),
      end: DateTime(now.year, now.month, 5, 11, 30),
      type: 'F',
    ),
    AppointmentEvent(
      id: 'a3',
      patientName: 'Vikram Patel',
      start: DateTime(now.year, now.month, 12, 9, 0),
      end: DateTime(now.year, now.month, 12, 9, 40),
      type: 'N',
    ),
    AppointmentEvent(
      id: 'a4',
      patientName: 'Sita Rao',
      start: DateTime(now.year, now.month, 12, 10, 0),
      end: DateTime(now.year, now.month, 12, 10, 45),
      type: 'F',
    ),
    AppointmentEvent(
      id: 'a5',
      patientName: 'Dr. Alex',
      start: DateTime(now.year, now.month, 21, 14, 0),
      end: DateTime(now.year, now.month, 21, 14, 30),
      type: 'N',
    ),
  ];
}
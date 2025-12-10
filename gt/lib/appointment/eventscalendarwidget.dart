import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small event model
class CalendarEvent {
  final String patientName;
  final TimeOfDay start;
  final TimeOfDay end;
  final bool isFollowUp; // false -> New (blue), true -> Follow Up (orange)
  CalendarEvent({
    required this.patientName,
    required this.start,
    required this.end,
    this.isFollowUp = false,
  });
}

/// Events calendar widget
class EventsCalendarWidget extends StatefulWidget {
  const EventsCalendarWidget({super.key});

  @override
  State<EventsCalendarWidget> createState() => _EventsCalendarWidgetState();
}

class _EventsCalendarWidgetState extends State<EventsCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final DateFormat _headerFormatter = DateFormat('MMMM yyyy'); // e.g. December 2025
  final DateFormat _dayFormat = DateFormat('d');

  // sample events map keyed by yyyy-mm-dd string for simplicity
  // Replace this with Firestore-loaded events in your app
  Map<String, List<CalendarEvent>> _sampleEvents = {};

  @override
  void initState() {
    super.initState();

    // sample data for demo — two events on a couple of dates
    final today = DateTime.now();
    final key1 = _ymd(DateTime(today.year, today.month, 10));
    final key2 = _ymd(DateTime(today.year, today.month, 17));
    _sampleEvents = {
      key1: [
        CalendarEvent(
          patientName: 'Rama K.',
          start: const TimeOfDay(hour: 10, minute: 0),
          end: const TimeOfDay(hour: 10, minute: 30),
          isFollowUp: false,
        ),
        CalendarEvent(
          patientName: 'Sunita T.',
          start: const TimeOfDay(hour: 11, minute: 0),
          end: const TimeOfDay(hour: 11, minute: 30),
          isFollowUp: true,
        ),
        CalendarEvent(
          patientName: 'Vikas P.',
          start: const TimeOfDay(hour: 14, minute: 0),
          end: const TimeOfDay(hour: 14, minute: 30),
          isFollowUp: true,
        ),
      ],
      key2: [
        CalendarEvent(
          patientName: 'Amit R.',
          start: const TimeOfDay(hour: 9, minute: 30),
          end: const TimeOfDay(hour: 10, minute: 0),
          isFollowUp: false,
        ),
      ],
    };
  }

  /// Helper to produce an easy key for a date
  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  /// Build list of DateTimes that will fill a 6-row calendar (42 cells)
  List<DateTime> _buildCalendarDays(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Dart weekday: Monday=1 ... Sunday=7. We want week starting Sunday -> index 0
    final int weekdayOfFirst = firstOfMonth.weekday % 7; // Sunday -> 0
    final start = firstOfMonth.subtract(Duration(days: weekdayOfFirst));
    final days = List<DateTime>.generate(42, (i) => start.add(Duration(days: i)));
    return days;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays(_focusedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header with prev / month / next
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _goToPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: DateTime(_focusedMonth.year, _focusedMonth.month),
                      items: List.generate(24, (i) {
                        // show +/- 12 months from now — adjust range as needed
                        final m =
                            DateTime(DateTime.now().year, DateTime.now().month + i - 12);
                        return DropdownMenuItem<DateTime>(
                          value: DateTime(m.year, m.month),
                          child: Text(_headerFormatter.format(m)),
                        );
                      }),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _focusedMonth = DateTime(val.year, val.month));
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _goToNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // weekday labels
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: const [
              Expanded(child: Center(child: Text('Sun'))),
              Expanded(child: Center(child: Text('Mon'))),
              Expanded(child: Center(child: Text('Tue'))),
              Expanded(child: Center(child: Text('Wed'))),
              Expanded(child: Center(child: Text('Thu'))),
              Expanded(child: Center(child: Text('Fri'))),
              Expanded(child: Center(child: Text('Sat'))),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // The calendar grid is placed inside Expanded so it fills available space and can scroll
        // if child content is bigger than the available area — prevents RenderFlex overflow.
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // 1) calendar grid: using Expanded to allow inner scrolling if needed
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 7,
                      childAspectRatio: 1.25,
                      physics: const ClampingScrollPhysics(),
                      children: days.map((d) {
                        final ymd = _ymd(d);
                        final events = _sampleEvents[ymd] ?? [];
                        final isCurrentMonth = d.month == _focusedMonth.month;

                        // compute counts
                        final int newCount =
                            events.where((e) => e.isFollowUp == false).length;
                        final int followUpCount =
                            events.where((e) => e.isFollowUp == true).length;

                        return Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isCurrentMonth ? Colors.white : Colors.grey.shade100,
                              border: Border.all(
                                color: _isSameDate(d, DateTime.now())
                                    ? const Color(0xFF16A34A)
                                    : Colors.transparent,
                                width: _isSameDate(d, DateTime.now()) ? 2 : 0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // top row: day number and counts (right-aligned)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        _dayFormat.format(d),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isCurrentMonth ? Colors.black87 : Colors.grey,
                                        ),
                                      ),
                                      const Spacer(),
                                      // badges for counts (small)
                                      if (newCount > 0)
                                        _countBadge(newCount, Colors.blue, 'New'),
                                      const SizedBox(width: 6),
                                      if (followUpCount > 0)
                                        _countBadge(followUpCount, Colors.orange, 'Follow Up'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // events list (scroll inside cell if many)
                                if (events.isEmpty)
                                  const Expanded(child: SizedBox.shrink())
                                else
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: events.length,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      itemBuilder: (context, idx) {
                                        final ev = events[idx];
                                        final color = ev.isFollowUp ? Colors.orange : Colors.blue;
                                        // patient name bold + time range
                                        final start = ev.start.format(context);
                                        final end = ev.end.format(context);
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(ev.patientName,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: color.shade700)),
                                              const SizedBox(height: 2),
                                              Text('$start - $end',
                                                  style: TextStyle(fontSize: 11, color: Colors.black54)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  )
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // optional legend at bottom
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(Colors.blue, 'New'),
                      const SizedBox(width: 16),
                      _legendDot(Colors.orange, 'Follow Up'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _countBadge(int count, Color color, String tooltip) {
    return Tooltip(
      message: '$tooltip: $count',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Text(
          count.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}
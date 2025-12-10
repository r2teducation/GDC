import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small event model
class CalendarEvent {
  final String patientName;
  final TimeOfDay start;
  final TimeOfDay end;
  final bool isFollowUp; // false -> New (blue), true -> Follow Up (orange)
  final String notes; // appointment notes
  CalendarEvent({
    required this.patientName,
    required this.start,
    required this.end,
    this.isFollowUp = false,
    this.notes = '',
  });
}

/// Events calendar widget (wired to Firestore)
class EventsCalendarWidget extends StatefulWidget {
  const EventsCalendarWidget({super.key});

  @override
  State<EventsCalendarWidget> createState() => _EventsCalendarWidgetState();
}

class _EventsCalendarWidgetState extends State<EventsCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final DateFormat _headerFormatter = DateFormat('MMMM yyyy'); // e.g. December 2025
  final DateFormat _dayFormat = DateFormat('d');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Map keyed by yyyy-mm-dd -> list of events
  Map<String, List<CalendarEvent>> _eventsMap = {};

  // simple cache of patientId -> display name
  final Map<String, String> _patientsMap = {};

  // subscription to appointments snapshot
  StreamSubscription<QuerySnapshot>? _appointmentsSub;

  @override
  void initState() {
    super.initState();
    _loadPatientsThenListenAppointments();
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    super.dispose();
  }

  /// Load patient names once (cache), then start listening to appointments.
  Future<void> _loadPatientsThenListenAppointments() async {
    try {
      final patientsSnap = await _db.collection('patients').get();
      for (final doc in patientsSnap.docs) {
        final data = doc.data();
        final id = (data['patientId'] ?? doc.id).toString();
        final fullName = (data['fullName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();
        _patientsMap[id] = fullName.isNotEmpty ? fullName : id;
      }
    } catch (e) {
      // silently continue — patient names will fallback to id
      debugPrint('Failed to load patients: $e');
    }

    // Now listen to appointment changes
    _appointmentsSub = _db
        .collection('appointments')
        .orderBy('appointmentDateTime')
        .snapshots()
        .listen((snap) {
      _buildEventsFromSnapshot(snap);
    }, onError: (err) {
      debugPrint('Appointments snapshot error: $err');
    });
  }

  /// Construct internal events map from Firestore snapshot
  void _buildEventsFromSnapshot(QuerySnapshot snap) {
    final Map<String, List<CalendarEvent>> map = {};

    for (final doc in snap.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;

        // appointmentDateTime must be a Timestamp
        final ts = data['appointmentDateTime'];
        if (ts == null) continue;
        DateTime dt;
        if (ts is Timestamp) {
          dt = ts.toDate().toLocal();
        } else if (ts is DateTime) {
          dt = ts.toLocal();
        } else {
          // unsupported type
          continue;
        }

        final patientId = (data['patientId'] ?? '').toString();
        final patientName = _patientsMap[patientId] ?? patientId;

        final appointmentType = (data['appointmentType'] ?? '').toString();
        final isFollowUp = appointmentType.toUpperCase() == 'F';

        final notes = (data['notes'] ?? '').toString();

        // Use a default duration of 30 minutes; adjust if you store duration.
        final startTod = TimeOfDay(hour: dt.hour, minute: dt.minute);
        final endDt = dt.add(const Duration(minutes: 30));
        final endTod = TimeOfDay(hour: endDt.hour, minute: endDt.minute);

        final ev = CalendarEvent(
          patientName: patientName,
          start: startTod,
          end: endTod,
          isFollowUp: isFollowUp,
          notes: notes,
        );

        final key = _ymd(dt);
        map.putIfAbsent(key, () => []).add(ev);
      } catch (e) {
        debugPrint('Skipping appointment doc ${doc.id} due to error: $e');
      }
    }

    // sort events for each date by start time
    for (final list in map.values) {
      list.sort((a, b) {
        final aMin = a.start.hour * 60 + a.start.minute;
        final bMin = b.start.hour * 60 + b.start.minute;
        return aMin.compareTo(bMin);
      });
    }

    setState(() {
      _eventsMap = map;
    });
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

  /// Show a centered dialog listing that day's appointments.
  Future<void> _showDayDetails(BuildContext ctx, DateTime day) async {
    final key = _ymd(day);
    final events = (_eventsMap[key] ?? []).toList()
      ..sort((a, b) {
        final aMinutes = a.start.hour * 60 + a.start.minute;
        final bMinutes = b.start.hour * 60 + b.start.minute;
        return aMinutes.compareTo(bMinutes);
      });

    final media = MediaQuery.of(ctx);
    final maxWidth = media.size.width * 0.7;
    final maxHeight = media.size.height * 0.7;

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, d MMMM yyyy').format(day),
                              style:
                                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dctx).pop(),
                            icon: const Icon(Icons.close),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // body
                    Flexible(
                      child: events.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'No appointments scheduled.',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              shrinkWrap: true,
                              itemCount: events.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final ev = events[idx];
                                final color = ev.isFollowUp ? Colors.orange : Colors.blue;
                                final timeLabel =
                                    '${ev.start.format(context)} — ${ev.end.format(context)}';
                                return Material(
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withOpacity(0.03),
                                            blurRadius: 6)
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // left time column - narrow
                                        Container(
                                          width: 120,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              bottomLeft: Radius.circular(10),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                timeLabel,
                                                style:
                                                    TextStyle(fontSize: 12, color: Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // right name & notes column
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ev.patientName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: color.shade700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  ev.notes.isNotEmpty ? ev.notes : 'No notes',
                                                  style: TextStyle(
                                                      fontSize: 12, color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    // optional footer (close)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dctx).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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

        // weekday labels — Sun and Sat in red, all bold
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'Sun',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Mon', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Tue', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Wed', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Thu', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Fri', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Sat',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
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
                        final events = _eventsMap[ymd] ?? [];
                        final isCurrentMonth = d.month == _focusedMonth.month;

                        // compute counts
                        final int newCount =
                            events.where((e) => e.isFollowUp == false).length;
                        final int followUpCount =
                            events.where((e) => e.isFollowUp == true).length;

                        return Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: GestureDetector(
                            onTap: () => _showDayDetails(context, d),
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
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
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
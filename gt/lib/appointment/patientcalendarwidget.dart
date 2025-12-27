import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'createappointmentwidget.dart';

class CalendarEvent {
  final bool isFollowUp;
  CalendarEvent({required this.isFollowUp});
}

class DoctorBusyEntry {
  DoctorBusyEntry();
}

class PatientCalendarWidget extends StatefulWidget {
  const PatientCalendarWidget({super.key});

  @override
  State<PatientCalendarWidget> createState() => _PatientCalendarWidgetState();
}

class _PatientCalendarWidgetState extends State<PatientCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final DateFormat _headerFormatter = DateFormat('MMMM yyyy');
  final DateFormat _dayFormat = DateFormat('d');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, List<CalendarEvent>> _eventsMap = {};
  Map<String, List<DoctorBusyEntry>> _doctorBusyMap = {};

  StreamSubscription? _appointmentsSub;
  StreamSubscription? _doctorBusySub;

  @override
  void initState() {
    super.initState();
    _listenCalendarData();
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    _doctorBusySub?.cancel();
    super.dispose();
  }

  void _listenCalendarData() {
    _appointmentsSub =
        _db.collection('appointments').snapshots().listen((snap) {
      final map = <String, List<CalendarEvent>>{};
      for (final d in snap.docs) {
        final ts = d['appointmentDateTime'] as Timestamp;
        final isFollowUp =
            (d['appointmentType'] ?? '').toString().toUpperCase() == 'F';
        final key = _ymd(ts.toDate());
        map.putIfAbsent(key, () => []).add(
              CalendarEvent(isFollowUp: isFollowUp),
            );
      }
      setState(() => _eventsMap = map);
    });

    _doctorBusySub = _db
        .collection('doctor_unavailability')
        .snapshots()
        .listen((snap) {
      final map = <String, List<DoctorBusyEntry>>{};
      for (final d in snap.docs) {
        final ts = d['unavailableDateTime'] as Timestamp;
        final key = _ymd(ts.toDate());
        map.putIfAbsent(key, () => []).add(DoctorBusyEntry());
      }
      setState(() => _doctorBusyMap = map);
    });
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// exactly 5 rows (35 days)
  List<DateTime> _buildCalendarDays() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final offset = first.weekday % 7;
    return List.generate(
      35,
      (i) => first.subtract(Duration(days: offset - i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays();
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // ================= HEADER =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month - 1);
                  });
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _headerFormatter.format(_focusedMonth),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
        ),

        // ================= BODY (AUTO-RESIZING, NO SCROLL) =================
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bodyHeight = constraints.maxHeight;
              final tileHeight = bodyHeight / 5; // 5 rows
              final tileWidth = screenWidth / 7;
              final aspectRatio = tileWidth / tileHeight;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final d = days[index];
                  final key = _ymd(d);

                  final events = _eventsMap[key] ?? [];
                  final busy = _doctorBusyMap[key] ?? [];

                  final newCount =
                      events.where((e) => !e.isFollowUp).length;
                  final followCount =
                      events.where((e) => e.isFollowUp).length;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateAppointmentWidget(date: d),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _dayFormat.format(d),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (newCount > 0)
                                _badge(newCount, Colors.blue),
                              if (followCount > 0)
                                _badge(followCount, Colors.orange),
                              if (busy.isNotEmpty)
                                _badge(busy.length, Colors.red),
                            ],
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ================= FOOTER =================
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(Colors.blue, 'New Appointment'),
              const SizedBox(width: 16),
              _legend(Colors.orange, 'Follow-up'),
              const SizedBox(width: 16),
              _legend(Colors.red, 'Doctor Busy'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(int c, Color color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(
          '$c',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );

  Widget _legend(Color color, String label) => Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      );
}
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'createappointmentwidget.dart';

class CalendarEvent {
  final bool isFollowUp;
  final DateTime dateTime; // 👈 appointment date + time

  CalendarEvent({
    required this.isFollowUp,
    required this.dateTime,
  });
}

class DoctorBusyEntry {
  final DateTime dateTime;
  final String notes;

  DoctorBusyEntry({
    required this.dateTime,
    required this.notes,
  });

  TimeOfDay get time => TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
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

  TimeOfDay? _busyTime;
  final _busyNotesCtrl = TextEditingController();

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

  Future<void> _pickBusyTime(BuildContext ctx) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: _busyTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _busyTime = picked);
    }
  }

  Future<void> _saveDoctorBusy(DateTime day) async {
    if (_busyTime == null) return;

    final dateTime = DateTime(
      day.year,
      day.month,
      day.day,
      _busyTime!.hour,
      _busyTime!.minute,
    );

    await FirebaseFirestore.instance.collection('doctorbusyhours').add({
      'date': DateFormat('yyyy-MM-dd').format(day),
      'time': Timestamp.fromDate(dateTime),
      'notes': _busyNotesCtrl.text.trim(),
    });
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
              CalendarEvent(
                isFollowUp: isFollowUp,
                dateTime: ts.toDate(), // 👈 from appointmentDateTime
              ),
            );
      }
      setState(() => _eventsMap = map);
    });

    _doctorBusySub =
        _db.collection('doctorbusyhours').snapshots().listen((snap) {
      final map = <String, List<DoctorBusyEntry>>{};
      for (final d in snap.docs) {
        final ts = d['time'] as Timestamp;
        final notes = (d['notes'] ?? '').toString();
        final dt = ts.toDate();
        final key = _ymd(dt);

        map.putIfAbsent(key, () => []).add(
              DoctorBusyEntry(
                dateTime: dt,
                notes: notes,
              ),
            );
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
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month - 1);
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
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month + 1);
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

                  final newCount = events.where((e) => !e.isFollowUp).length;
                  final followCount = events.where((e) => e.isFollowUp).length;

                  return GestureDetector(
                    onTap: () {
                      _showDayDetailsDialog(context, d);
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (newCount > 0) _badge(newCount, Colors.blue),
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
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
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
  Future<void> _showDayDetailsDialog(BuildContext ctx, DateTime day) async {
    final key = _ymd(day);
    final events = _eventsMap[key] ?? [];
    final busy = _doctorBusyMap[key] ?? [];

    final maxWidth = MediaQuery.of(ctx).size.width * 0.9;
    final maxHeight = MediaQuery.of(ctx).size.height * 0.8;

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ================= HEADER (INVERTED) =================
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, d MMMM yyyy').format(day),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dctx).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // ================= BODY =================
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // -------- Appointments --------
                            const Text(
                              'Appointments',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),

                            if (events.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  'No appointments scheduled.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            else
                              Column(
                                children: events.map((ev) {
                                  final color = ev.isFollowUp
                                      ? Colors.orange
                                      : Colors.blue;

                                  final timeLabel =
                                      DateFormat('h:mm a').format(ev.dateTime);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 8,
                                        )
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 6,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                      title: Text(
                                        timeLabel,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          ev.isFollowUp
                                              ? 'Follow-up Appointment'
                                              : 'New Appointment',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 10),

                            // -------- Doctor Busy --------
                            const Text(
                              'Doctor busy hours',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),

                            if (busy.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  'No busy hours logged.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            else
                              Column(
                                children: busy.map((b) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.block,
                                          color: Colors.red),
                                      title: Text(
                                        DateFormat('h:mm a').format(b.dateTime),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(b.notes),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ================= FOOTER =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 🟥 Doctor Busy button
                          OutlinedButton(
                            onPressed: () async {
                              Navigator.of(dctx).pop();
                              await _logDoctorBusyHours(ctx, day);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 12),
                            ),
                            child: const Text('Doctor Busy'),
                          ),
                          const SizedBox(width: 12),

                          // ⚫ New Appointment
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.of(dctx).pop();
                              await Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CreateAppointmentWidget(date: day),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 26, vertical: 12),
                            ),
                            child: const Text('New'),
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

  Future<void> _logDoctorBusyHours(BuildContext ctx, DateTime day) async {
    final key = _ymd(day);
    final events = _eventsMap[key] ?? [];
    final busy = _doctorBusyMap[key] ?? [];

    _busyTime = null;
    _busyNotesCtrl.clear();

    final maxWidth = MediaQuery.of(ctx).size.width * 0.9;
    final maxHeight = MediaQuery.of(ctx).size.height * 0.8;

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              backgroundColor: Colors.transparent,
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ================= HEADER =================
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Log Doctor Busy Hours',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(dctx).pop(),
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        // ================= BODY =================
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Time',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton.icon(
                                  onPressed: () => _showSlotPicker(
                                    dctx,
                                    day,
                                    events,
                                    busy,
                                    dialogSetState,
                                  ),
                                  icon: const Icon(Icons.access_time),
                                  label: Text(
                                    _busyTime == null
                                        ? 'Select time'
                                        : _busyTime!.format(dctx),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Notes',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _busyNotesCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Optional notes',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ================= FOOTER =================
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: _busyTime == null
                                    ? null
                                    : () async {
                                        final dt = DateTime(
                                          day.year,
                                          day.month,
                                          day.day,
                                          _busyTime!.hour,
                                          _busyTime!.minute,
                                        );

                                        await _db
                                            .collection('doctorbusyhours')
                                            .add({
                                          'date': _ymd(day),
                                          'time': Timestamp.fromDate(dt),
                                          'notes': _busyNotesCtrl.text.trim(),
                                        });

                                        Navigator.of(dctx).pop();
                                        setState(() {});
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26, vertical: 12),
                                ),
                                child: const Text('Save'),
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
      },
    );
  }

  Future<void> _showSlotPicker(
    BuildContext ctx,
    DateTime day,
    List<CalendarEvent> events,
    List<DoctorBusyEntry> busy,
    void Function(void Function()) dialogSetState,
  ) async {
    final slots = _generateSlots();

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select time — ${DateFormat('d MMM yyyy').format(day)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: slots.map((slot) {
                    final blocked = _isSlotBlocked(day, slot, events, busy);

                    final selected = _busyTime != null &&
                        _busyTime!.hour == slot.hour &&
                        _busyTime!.minute == slot.minute;

                    return ChoiceChip(
                      label: Text(slot.format(ctx)),
                      selected: selected,
                      onSelected: blocked
                          ? null
                          : (_) {
                              dialogSetState(() => _busyTime = slot);
                              Navigator.pop(dctx);
                            },
                      selectedColor: Colors.black,
                      disabledColor: Colors.grey.shade300,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: blocked
                            ? Colors.grey
                            : selected
                                ? Colors.white
                                : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isSlotBlocked(
    DateTime day,
    TimeOfDay slot,
    List<CalendarEvent> events,
    List<DoctorBusyEntry> busy,
  ) {
    final booked = events.any((e) =>
        e.dateTime.hour == slot.hour && e.dateTime.minute == slot.minute);

    final doctorBusy = busy
        .any((b) => b.time.hour == slot.hour && b.time.minute == slot.minute);

    return booked || doctorBusy;
  }

  List<TimeOfDay> _generateSlots() {
    final slots = <TimeOfDay>[];
    for (int h = 9; h <= 17; h++) {
      slots.add(TimeOfDay(hour: h, minute: 0));
      if (!(h == 17)) {
        slots.add(TimeOfDay(hour: h, minute: 30));
      }
    }
    return slots;
  }
}

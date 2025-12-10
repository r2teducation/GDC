// lib/appointment/doctorcalendarwidget.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Simple busy-slot model for doctor unavailability
class DoctorBusyEntry {
  final DateTime start; // local DateTime
  final DateTime end; // local DateTime (start + duration)
  final String notes;

  DoctorBusyEntry({
    required this.start,
    required this.end,
    required this.notes,
  });
}

/// Doctor calendar widget — log doctor's unavailable/busy hours.
/// Looks & feels like PatientCalendarWidget.
class DoctorCalendarWidget extends StatefulWidget {
  const DoctorCalendarWidget({super.key});

  @override
  State<DoctorCalendarWidget> createState() => _DoctorCalendarWidgetState();
}

class _DoctorCalendarWidgetState extends State<DoctorCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final DateFormat _headerFormatter = DateFormat('MMMM yyyy');
  final DateFormat _dayFormat = DateFormat('d');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // doctor busy map keyed by yyyy-MM-dd -> list of DoctorBusyEntry
  Map<String, List<DoctorBusyEntry>> _busyMap = {};

  StreamSubscription<QuerySnapshot>? _busySub;

  // slot generation (same as appointment)
  final int _slotStartHour = 9;
  final int _slotEndHour = 17;
  final int _slotMinutesStep = 30;

  final TextEditingController _createNotesCtrl = TextEditingController();

  // used by create dialog
  final DateFormat _displayDateTime = DateFormat('EEEE, d MMM yyyy  h:mm a');

  @override
  void initState() {
    super.initState();
    _listenDoctorBusy();
  }

  @override
  void dispose() {
    _busySub?.cancel();
    _createNotesCtrl.dispose();
    super.dispose();
  }

  void _listenDoctorBusy() {
    // listen to collection 'doctor_unavailability'
    _busySub = _db
        .collection('doctor_unavailability')
        .orderBy('startDateTime')
        .snapshots()
        .listen((snap) {
      _buildBusyMapFromSnapshot(snap);
    }, onError: (err) {
      debugPrint('doctor_unavailability snapshot error: $err');
    });
  }

  void _buildBusyMapFromSnapshot(QuerySnapshot snap) {
    final Map<String, List<DoctorBusyEntry>> map = {};
    for (final doc in snap.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['startDateTime'];
        if (ts == null) continue;
        DateTime dt;
        if (ts is Timestamp) dt = ts.toDate().toLocal();
        else if (ts is DateTime) dt = ts.toLocal();
        else continue;

        // assume duration 30 minutes unless stored explicitly; if you later store 'endDateTime' prefer that
        DateTime end = dt.add(const Duration(minutes: 30));
        if (data['endDateTime'] != null) {
          final ets = data['endDateTime'];
          if (ets is Timestamp) end = ets.toDate().toLocal();
          else if (ets is DateTime) end = ets.toLocal();
        }

        final notes = (data['notes'] ?? '').toString();

        final entry = DoctorBusyEntry(start: dt, end: end, notes: notes);
        final key = _ymd(dt);
        map.putIfAbsent(key, () => []).add(entry);
      } catch (e) {
        debugPrint('Skipping doctor busy doc ${doc.id} due to $e');
      }
    }

    // sort each day's list by start
    for (final list in map.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    setState(() {
      _busyMap = map;
    });
  }

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

  List<DateTime> _buildCalendarDays(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final weekdayOfFirst = firstOfMonth.weekday % 7; // Sunday -> 0
    final start = firstOfMonth.subtract(Duration(days: weekdayOfFirst));
    return List<DateTime>.generate(42, (i) => start.add(Duration(days: i)));
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Build set of occupied hh:mm strings from doctor busy entries for a date.
  Set<String> _doctorBusySlotsForDate(DateTime date) {
    final key = _ymd(date);
    final list = _busyMap[key] ?? [];
    final Set<String> s = {};
    for (final e in list) {
      final hhmm =
          '${e.start.hour.toString().padLeft(2, '0')}:${e.start.minute.toString().padLeft(2, '0')}';
      s.add(hhmm);
    }
    return s;
  }

  List<TimeOfDay> _generateTimeSlots() {
    final List<TimeOfDay> slots = [];
    for (int h = _slotStartHour; h <= _slotEndHour; h++) {
      for (int m = 0; m < 60; m += _slotMinutesStep) {
        slots.add(TimeOfDay(hour: h, minute: m));
      }
    }
    return slots;
  }

  // time slot picker used in create dialog
  Future<TimeOfDay?> _showTimeSlotPickerDialog(
      BuildContext ctx, DateTime forDate, Set<String> occupied) async {
    final slots = _generateTimeSlots();
    return await showDialog<TimeOfDay>(
      context: ctx,
      builder: (dctx) {
        return AlertDialog(
          title: Text('Select time — ${DateFormat('d MMM yyyy').format(forDate)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((s) {
                  final hhmm =
                      '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
                  final taken = occupied.contains(hhmm);
                  final label = s.format(ctx);
                  return SizedBox(
                    width: 110,
                    child: ElevatedButton(
                      onPressed: taken ? null : () => Navigator.of(dctx).pop(s),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: taken ? Colors.grey.shade300 : Colors.white,
                        foregroundColor: taken ? Colors.grey.shade600 : Colors.black87,
                        elevation: taken ? 0 : 2,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(label,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dctx).pop(null), child: const Text('Cancel')),
          ],
        );
      },
    );
  }

  /// Show day details (list busy hours + Create button)
  Future<void> _showDayDetails(BuildContext ctx, DateTime day) async {
    final key = _ymd(day);
    final busyList = (_busyMap[key] ?? []).toList();
    final media = MediaQuery.of(ctx);
    final maxWidth = media.size.width * 0.6;
    final maxHeight = media.size.height * 0.6;

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
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
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                      child: busyList.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text('No Busy hours logged.', style: TextStyle(color: Colors.grey[600])),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              shrinkWrap: true,
                              itemCount: busyList.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final b = busyList[idx];
                                final startLabel = DateFormat('h:mm a').format(b.start);
                                final endLabel = DateFormat('h:mm a').format(b.end);
                                return Material(
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 120,
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.12),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              bottomLeft: Radius.circular(10),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('$startLabel — $endLabel',
                                                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Doctor busy',
                                                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade700),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(b.notes.isNotEmpty ? b.notes : 'No notes', style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
                    // footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Close')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(dctx).pop();
                              _showCreateBusyForDate(ctx, day);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Create busy entry dialog for a given date
  Future<void> _showCreateBusyForDate(BuildContext ctx, DateTime date) async {
    TimeOfDay? selectedTime;
    _createNotesCtrl.clear();

    final occupiedSlots = _doctorBusySlotsForDate(date);

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(builder: (dctx, setStateSB) {
          Future<void> pickTime() async {
            final t = await _showTimeSlotPickerDialog(dctx, date, occupiedSlots);
            if (t != null) setStateSB(() => selectedTime = t);
          }

          Future<void> save() async {
            if (selectedTime == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a time')));
              return;
            }

            final combinedStart = DateTime(date.year, date.month, date.day, selectedTime!.hour, selectedTime!.minute);
            final combinedEnd = combinedStart.add(const Duration(minutes: 30)); // default duration

            final hhmm = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
            // double-check server side conflict (we simply check local map)
            if (_doctorBusySlotsForDate(date).contains(hhmm)) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Selected slot is already logged as busy')));
              return;
            }

            try {
              await _db.collection('doctor_unavailability').add({
                'startDateTime': Timestamp.fromDate(combinedStart.toUtc()),
                'endDateTime': Timestamp.fromDate(combinedEnd.toUtc()),
                'notes': _createNotesCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Busy hours logged')));
              Navigator.of(dctx).pop();
            } catch (e) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed to save busy hours: $e')));
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(ctx).size.height * 0.7),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // header
                  Row(
                    children: [
                      Expanded(child: Text('Doctor Unavailability Hours — ${DateFormat('EEEE, d MMM yyyy').format(date)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      IconButton(onPressed: () => Navigator.of(dctx).pop(), icon: const Icon(Icons.close))
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Date & Time label (date fixed)
                  Align(alignment: Alignment.centerLeft, child: const Text('Date & Time', style: TextStyle(fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: pickTime,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(selectedTime == null ? 'Choose time slot' : '${_displayDateTime.format(DateTime(date.year, date.month, date.day, selectedTime!.hour, selectedTime!.minute))}'),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Notes
                  Align(alignment: Alignment.centerLeft, child: const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _createNotesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Enter notes (optional)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // actions
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)), child: const Text('Save')),
                  ])
                ]),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays(_focusedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconButton(onPressed: _goToPreviousMonth, icon: const Icon(Icons.chevron_left)),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: DateTime(_focusedMonth.year, _focusedMonth.month),
                      items: List.generate(24, (i) {
                        final m = DateTime(DateTime.now().year, DateTime.now().month + i - 12);
                        return DropdownMenuItem<DateTime>(value: DateTime(m.year, m.month), child: Text(_headerFormatter.format(m)));
                      }),
                      onChanged: (val) {
                        if (val != null) setState(() => _focusedMonth = DateTime(val.year, val.month));
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _goToNextMonth, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // weekday labels
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Center(child: Text('Sun', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)))),
            const Expanded(child: Center(child: Text('Mon', style: TextStyle(fontWeight: FontWeight.w700)))),
            const Expanded(child: Center(child: Text('Tue', style: TextStyle(fontWeight: FontWeight.w700)))),
            const Expanded(child: Center(child: Text('Wed', style: TextStyle(fontWeight: FontWeight.w700)))),
            const Expanded(child: Center(child: Text('Thu', style: TextStyle(fontWeight: FontWeight.w700)))),
            const Expanded(child: Center(child: Text('Fri', style: TextStyle(fontWeight: FontWeight.w700)))),
            Expanded(child: Center(child: Text('Sat', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)))),
          ]),
        ),

        const SizedBox(height: 8),

        // calendar grid
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 7,
                    childAspectRatio: 1.25,
                    physics: const ClampingScrollPhysics(),
                    children: days.map((d) {
                      final ymd = _ymd(d);
                      final busyList = _busyMap[ymd] ?? [];
                      final isCurrentMonth = d.month == _focusedMonth.month;
                      return Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: GestureDetector(
                          onTap: () => _showDayDetails(context, d),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isCurrentMonth ? Colors.white : Colors.grey.shade100,
                              border: Border.all(
                                color: _isSameDate(d, DateTime.now()) ? const Color(0xFF16A34A) : Colors.transparent,
                                width: _isSameDate(d, DateTime.now()) ? 2 : 0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  child: Row(children: [
                                    Text(_dayFormat.format(d), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isCurrentMonth ? Colors.black87 : Colors.grey)),
                                    const Spacer(),
                                    if (busyList.isNotEmpty) _busyBadge(busyList.length),
                                  ]),
                                ),
                                const SizedBox(height: 4),
                                if (busyList.isEmpty)
                                  const Expanded(child: SizedBox.shrink())
                                else
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      itemCount: busyList.length,
                                      itemBuilder: (context, idx) {
                                        final b = busyList[idx];
                                        final start = DateFormat('h:mm a').format(b.start);
                                        final end = DateFormat('h:mm a').format(b.end);
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text('Doctor busy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                                            const SizedBox(height: 2),
                                            Text('$start - $end', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                          ]),
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
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _legendDot(Colors.red, 'Doctor busy'),
                ]),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _busyBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
      child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
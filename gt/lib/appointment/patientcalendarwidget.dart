// lib/appointment/patientcalendarwidget.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
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

/// Patient calendar widget (wired to Firestore)
class PatientCalendarWidget extends StatefulWidget {
  const PatientCalendarWidget({super.key});

  @override
  State<PatientCalendarWidget> createState() => _PatientCalendarWidgetState();
}

class _PatientCalendarWidgetState extends State<PatientCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final DateFormat _headerFormatter = DateFormat('MMMM yyyy'); // e.g. December 2025
  final DateFormat _dayFormat = DateFormat('d');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Map keyed by yyyy-mm-dd -> list of events
  Map<String, List<CalendarEvent>> _eventsMap = {};

  // simple cache of patientId -> display name
  final Map<String, String> _patientsMap = {};

  // also prepare patient options for searchable dropdown in create dialog
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  final TextEditingController _createSearchCtrl = TextEditingController();

  // subscription to appointments snapshot
  StreamSubscription<QuerySnapshot>? _appointmentsSub;

  // Time slot generation config (same as AppointmentWidget)
  final int _slotStartHour = 9; // start at 9:00
  final int _slotEndHour = 17; // include up to 17:30 if step 30
  final int _slotMinutesStep = 30; // 30-minute slots

  @override
  void initState() {
    super.initState();
    _loadPatientsThenListenAppointments();
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    _createSearchCtrl.dispose();
    super.dispose();
  }

  /// Load patient names once (cache), then start listening to appointments.
  Future<void> _loadPatientsThenListenAppointments() async {
    try {
      final patientsSnap = await _db.collection('patients').orderBy('patientId').get();
      final List<_PatientOption> opts = [];
      for (final doc in patientsSnap.docs) {
        final data = doc.data();
        final id = (data['patientId'] ?? doc.id).toString();
        final fullName = (data['fullName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();
        final display = fullName.isNotEmpty ? fullName : id;
        _patientsMap[id] = display;

        // Build label "ID  Full Name"
        if (data['isActive'] == false) continue;
        final label = fullName.isNotEmpty ? '$id  $fullName' : id;
        opts.add(_PatientOption(id: id, label: label));
      }
      setState(() {
        _patientOptions = opts;
        _loadingPatients = false;
      });
    } catch (e) {
      setState(() => _loadingPatients = false);
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

        final ts = data['appointmentDateTime'];
        if (ts == null) continue;

        DateTime dt;
        if (ts is Timestamp) {
          dt = ts.toDate().toLocal();
        } else if (ts is DateTime) {
          dt = ts.toLocal();
        } else {
          continue;
        }

        final patientId = (data['patientId'] ?? '').toString();
        final patientName = _patientsMap[patientId] ?? patientId;

        final appointmentType = (data['appointmentType'] ?? '').toString();
        final isFollowUp = appointmentType.toUpperCase() == 'F';

        final notes = (data['notes'] ?? '').toString();

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

    // sort events
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

  /// date key helper
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
    final int weekdayOfFirst = firstOfMonth.weekday % 7; // Sunday → 0
    final start = firstOfMonth.subtract(Duration(days: weekdayOfFirst));
    return List<DateTime>.generate(42, (i) => start.add(Duration(days: i)));
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Day details popup
  Future<void> _showDayDetails(BuildContext ctx, DateTime day) async {
    final key = _ymd(day);
    final events = (_eventsMap[key] ?? []).toList()
      ..sort((a, b) {
        final aM = a.start.hour * 60 + a.start.minute;
        final bM = b.start.hour * 60 + b.start.minute;
        return aM.compareTo(bM);
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
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
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
                    // Body
                    Flexible(
                      child: events.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text('No appointments scheduled.',
                                    style: TextStyle(color: Colors.grey[600])),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: events.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final ev = events[idx];
                                final color = ev.isFollowUp ? Colors.orange : Colors.blue;
                                final timeLabel =
                                    '${ev.start.format(context)} — ${ev.end.format(context)}';

                                return Material(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 6,
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Time column
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
                                          child: Text(timeLabel,
                                              style: const TextStyle(
                                                  fontSize: 12, color: Colors.black87)),
                                        ),
                                        // Details column
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(ev.patientName,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      color: color.shade700,
                                                      fontSize: 14,
                                                    )),
                                                const SizedBox(height: 6),
                                                Text(
                                                  ev.notes.isNotEmpty ? ev.notes : 'No notes',
                                                  style: const TextStyle(
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
                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.of(dctx).pop(),
                              child: const Text('Close')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(dctx).pop();
                              _showCreateForDate(ctx, day);
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white),
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

  // Build occupied time slots
  Set<String> _occupiedSlotsFromMapForDate(DateTime date) {
    final key = _ymd(date);
    final list = _eventsMap[key] ?? [];
    return {
      for (final ev in list)
        '${ev.start.hour.toString().padLeft(2, '0')}:${ev.start.minute.toString().padLeft(2, '0')}'
    };
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

  // Slot picker dialog
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
                      foregroundColor:
                          taken ? Colors.grey.shade600 : Colors.black87,
                      elevation: taken ? 0 : 2,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dctx).pop(null),
                child: const Text('Cancel'))
          ],
        );
      },
    );
  }

  // Create appointment dialog
  Future<void> _showCreateForDate(BuildContext ctx, DateTime date) async {
    String? selectedPatientId;
    TimeOfDay? selectedTime;
    String appointmentType = 'N';
    final TextEditingController notesCtrl = TextEditingController();

    final occupied = _occupiedSlotsFromMapForDate(date);

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(builder: (dctx, setStateSB) {
          Future<void> pickTime() async {
            final t = await _showTimeSlotPickerDialog(dctx, date, occupied);
            if (t != null) {
              setStateSB(() => selectedTime = t);
            }
          }

          Future<void> save() async {
            if (selectedPatientId == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please select a patient')));
              return;
            }
            if (selectedTime == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please select a time slot')));
              return;
            }

            final combined = DateTime(
              date.year,
              date.month,
              date.day,
              selectedTime!.hour,
              selectedTime!.minute,
            );

            final hhmm =
                '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
            if (_occupiedSlotsFromMapForDate(date).contains(hhmm)) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Selected slot already taken.')));
              return;
            }

            try {
              await _db.collection('appointments').add({
                'patientId': selectedPatientId,
                'appointmentDateTime': Timestamp.fromDate(combined),
                'appointmentType': appointmentType,
                'notes': notesCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              ScaffoldMessenger.of(ctx)
                  .showSnackBar(const SnackBar(content: Text('Appointment created')));
              Navigator.of(dctx).pop();
            } catch (e) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to create appointment: $e')));
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: 620, maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Create Appointment — ${DateFormat('EEEE, d MMM yyyy').format(date)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                            onPressed: () => Navigator.of(dctx).pop(),
                            icon: const Icon(Icons.close))
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Patient dropdown
                    Align(
                        alignment: Alignment.centerLeft,
                        child: const Text('Patient',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),

                    if (_loadingPatients)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    else
                      DropdownButtonFormField2<String>(
                        isExpanded: true,
                        value: selectedPatientId,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Select patient',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _patientOptions
                            .map(
                              (p) => DropdownMenuItem<String>(
                                value: p.id,
                                child: _buildPatientOptionRow(p),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setStateSB(() => selectedPatientId = v),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 280,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(12),
                            thickness: MaterialStateProperty.all(4),
                            thumbVisibility: MaterialStateProperty.all(true),
                          ),
                        ),
                        dropdownSearchData: DropdownSearchData(
                          searchController: _createSearchCtrl,
                          searchInnerWidgetHeight: 52,
                          searchInnerWidget: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _createSearchCtrl,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search by ID / Name',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          searchMatchFn: (item, searchValue) {
                            final v = item.value ?? '';
                            final opt = _patientOptions.firstWhere(
                              (p) => p.id == v,
                              orElse: () => _PatientOption(id: v, label: v),
                            );
                            return opt.label.toLowerCase().contains(searchValue.toLowerCase());
                          },
                        ),
                        onMenuStateChange: (isOpen) {
                          if (!isOpen) _createSearchCtrl.clear();
                        },
                      ),

                    const SizedBox(height: 12),

                    // Time picker
                    Align(
                        alignment: Alignment.centerLeft,
                        child: const Text('Time',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: pickTime,
                            style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(selectedTime == null
                                  ? 'Choose time slot'
                                  : selectedTime!.format(ctx)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Builder(builder: (_) {
                          final key = _ymd(date);
                          final events = _eventsMap[key] ?? [];
                          final int newCount =
                              events.where((e) => e.isFollowUp == false).length;
                          final int followUpCount =
                              events.where((e) => e.isFollowUp == true).length;

                          return Row(
                            children: [
                              if (newCount > 0)
                                _countBadge(newCount, Colors.blue, 'New'),
                              const SizedBox(width: 6),
                              if (followUpCount > 0)
                                _countBadge(followUpCount, Colors.orange, 'Follow Up'),
                            ],
                          );
                        })
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Appointment type
                    Align(
                        alignment: Alignment.centerLeft,
                        child: const Text('Appointment Type',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('New'),
                            value: 'N',
                            groupValue: appointmentType,
                            onChanged: (v) =>
                                setStateSB(() => appointmentType = v ?? 'N'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Follow Up'),
                            value: 'F',
                            groupValue: appointmentType,
                            onChanged: (v) =>
                                setStateSB(() => appointmentType = v ?? 'F'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Notes
                    Align(
                        alignment: Alignment.centerLeft,
                        child: const Text('Notes (optional)',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter notes',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.of(dctx).pop(),
                            child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: save,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A)),
                          child: const Text('Save'),
                        ),
                      ],
                    )
                  ],
                ),
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
        // Month header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _goToPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: DateTime(_focusedMonth.year, _focusedMonth.month),
                      items: List.generate(24, (i) {
                        final m =
                            DateTime(DateTime.now().year, DateTime.now().month + i - 12);
                        return DropdownMenuItem<DateTime>(
                          value: DateTime(m.year, m.month),
                          child: Text(_headerFormatter.format(m)),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _focusedMonth = DateTime(val.year, val.month));
                        }
                      },
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _goToNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Weekday labels
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                  child: Center(
                      child: Text('Sun',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Mon', style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Tue', style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Wed', style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Thu', style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Fri', style: TextStyle(fontWeight: FontWeight.w700)))),
              Expanded(
                  child: Center(
                      child: Text('Sat',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700)))),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Calendar grid
        Expanded(
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 7,
                      childAspectRatio: 1.25,
                      children: days.map((d) {
                        final ymd = _ymd(d);
                        final events = _eventsMap[ymd] ?? [];
                        final bool isCurrentMonth = d.month == _focusedMonth.month;

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
                                color:
                                    isCurrentMonth ? Colors.white : Colors.grey.shade100,
                                border: Border.all(
                                  color: _isSameDate(d, DateTime.now())
                                      ? const Color(0xFF16A34A)
                                      : Colors.transparent,
                                  width: _isSameDate(d, DateTime.now()) ? 2 : 0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Row(
                                      children: [
                                        Text(_dayFormat.format(d),
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: isCurrentMonth
                                                    ? Colors.black87
                                                    : Colors.grey)),
                                        const Spacer(),
                                        if (newCount > 0)
                                          _countBadge(newCount, Colors.blue, 'New'),
                                        const SizedBox(width: 6),
                                        if (followUpCount > 0)
                                          _countBadge(
                                              followUpCount, Colors.orange, 'Follow Up'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  if (events.isEmpty)
                                    const Expanded(child: SizedBox.shrink())
                                  else
                                    Expanded(
                                      child: ListView.builder(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 8),
                                        itemCount: events.length,
                                        itemBuilder: (context, idx) {
                                          final ev = events[idx];
                                          final color =
                                              ev.isFollowUp ? Colors.orange : Colors.blue;
                                          final start = ev.start.format(context);
                                          final end = ev.end.format(context);

                                          return Container(
                                            margin:
                                                const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(ev.patientName,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: color.shade700)),
                                                Text('$start - $end',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.black54)),
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
        ),
        child: Text(
          count.toString(),
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }

  Widget _buildPatientOptionRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    final idPart = parts.isNotEmpty ? parts.first : p.id;
    final namePart =
        parts.length > 1 ? parts.sublist(1).join('  ') : '';
    return Row(
      children: [
        Text(idPart,
            style:
                const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(namePart,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
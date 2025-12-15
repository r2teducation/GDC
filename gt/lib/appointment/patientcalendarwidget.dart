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

/// Doctor busy entry model
class DoctorBusyEntry {
  final TimeOfDay time;
  final String notes;
  final String id;
  DoctorBusyEntry({required this.time, required this.notes, required this.id});
}

/// Patient calendar widget (wired to Firestore)
class PatientCalendarWidget extends StatefulWidget {
  const PatientCalendarWidget({super.key});

  @override
  State<PatientCalendarWidget> createState() => _PatientCalendarWidgetState();
}

class _PatientCalendarWidgetState extends State<PatientCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final DateFormat _headerFormatter =
      DateFormat('MMMM yyyy'); // e.g. December 2025
  final DateFormat _dayFormat = DateFormat('d');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Map keyed by yyyy-mm-dd -> list of events
  Map<String, List<CalendarEvent>> _eventsMap = {};

  // Map keyed by yyyy-mm-dd -> list of doctor busy entries
  Map<String, List<DoctorBusyEntry>> _doctorBusyMap = {};

  // simple cache of patientId -> display name
  final Map<String, String> _patientsMap = {};

  // also prepare patient options for searchable dropdown in create dialog
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  final TextEditingController _createSearchCtrl = TextEditingController();

  // subscriptions
  StreamSubscription<QuerySnapshot>? _appointmentsSub;
  StreamSubscription<QuerySnapshot>? _doctorBusySub;

  // Time slot generation config (same as AppointmentWidget)
  final int _slotStartHour = 9; // start at 9:00
  final int _slotEndHour = 17; // include up to 17:30 if step 30
  final int _slotMinutesStep = 30; // 30-minute slots

  // Firestore collection name for doctor busy/unavailable entries.
  // If your DoctorCalendar writes to a different collection name, change this.
  final String _doctorCollectionName = 'doctor_unavailability';

  // ===== NEW ====
  /// ===== NEW FORM CONTROLLERS (SECTIONS) =====

  // Section 1 – Vitals
  final bpSysCtrl = TextEditingController();
  final bpDiaCtrl = TextEditingController();
  double heartRate = 72;
  double breathingRate = 16;
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final fbsCtrl = TextEditingController();
  final rbsCtrl = TextEditingController();

  // Section 2 – Health Conditions
  final Map<String, bool> healthConditions = {
    'Diabetes': false,
    'Hypertension': false,
    'Heart Disease': false,
    'Asthma': false,
    'Kidney Disease': false,
    'Liver Disease': false,
    'Thyroid Disorder': false,
    'Bleeding Disorders': false,
    'Neurological Issues': false,
  };

  // Section 3 – Allergies
  bool drugAllergy = false;
  bool foodAllergy = false;
  bool latexAllergy = false;
  final allergyNotesCtrl = TextEditingController();

  // Section 4 – Surgery
  final surgeryCtrl = TextEditingController();

  // Section 6 – Dental History
  final Map<String, bool> dentalHistory = {
    'Root Canal': false,
    'Implants': false,
    'Crowns / Bridges': false,
    'Braces': false,
    'Dentures': false,
  };
  final dentalNotesCtrl = TextEditingController();

  // Section 9 – Consent
  bool consentGiven = false;
  final consentSignatureCtrl = TextEditingController();

  // ===== END NEW =====
  @override
  void initState() {
    super.initState();
    _loadPatientsThenListenAppointmentsAndDoctorBusy();
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    _doctorBusySub?.cancel();
    _createSearchCtrl.dispose();
    super.dispose();
  }

  /// Load patient names once (cache), then start listening to appointments and doctor busy docs.
  Future<void> _loadPatientsThenListenAppointmentsAndDoctorBusy() async {
    try {
      final patientsSnap =
          await _db.collection('patients').orderBy('patientId').get();
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

    // Listen to appointment changes
    _appointmentsSub = _db
        .collection('appointments')
        .orderBy('appointmentDateTime')
        .snapshots()
        .listen((snap) {
      _buildEventsFromSnapshot(snap);
    }, onError: (err) {
      debugPrint('Appointments snapshot error: $err');
    });

    // Listen to doctor busy/unavailability changes
    _doctorBusySub =
        _db.collection(_doctorCollectionName).snapshots().listen((snap) {
      _buildDoctorBusyFromSnapshot(snap);
    }, onError: (err) {
      debugPrint('Doctor busy snapshot error: $err');
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

  /// Build doctor busy map from snapshot
  void _buildDoctorBusyFromSnapshot(QuerySnapshot snap) {
    final Map<String, List<DoctorBusyEntry>> map = {};
    for (final doc in snap.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final DateTime? dt = _extractDateTimeFromDocMap(data);
        if (dt == null) continue;
        final key = _ymd(dt);
        final tod = TimeOfDay(hour: dt.hour, minute: dt.minute);
        final notes = (data['notes'] ?? data['note'] ?? '').toString();
        final entry = DoctorBusyEntry(time: tod, notes: notes, id: doc.id);
        map.putIfAbsent(key, () => []).add(entry);
      } catch (e) {
        debugPrint('Skipping doctor busy doc ${doc.id} due to error: $e');
      }
    }

    // sort entries by time
    for (final list in map.values) {
      list.sort((a, b) {
        final aMin = a.time.hour * 60 + a.time.minute;
        final bMin = b.time.hour * 60 + b.time.minute;
        return aMin.compareTo(bMin);
      });
    }

    setState(() {
      _doctorBusyMap = map;
    });
  }

  /// Helper: try multiple fields to extract a DateTime from a document map.
  DateTime? _extractDateTimeFromDocMap(Map<String, dynamic> data) {
    final List<String> candidates = [
      'dateTime',
      'start',
      'startDateTime',
      'unavailableDateTime',
      'unavailableAt',
      'from',
      'start_at',
      'appointmentDateTime',
      'date',
      'time',
    ];

    for (final f in candidates) {
      if (!data.containsKey(f)) continue;
      final v = data[f];
      if (v == null) continue;
      if (v is Timestamp) return v.toDate().toLocal();
      if (v is DateTime) return v.toLocal();
      if (v is String) {
        try {
          return DateTime.parse(v).toLocal();
        } catch (_) {
          // ignore parse error
        }
      }
    }

    // As a fallback, if the doc stored separate 'date' and 'time' string fields, try to combine.
    if (data.containsKey('date') && data.containsKey('time')) {
      final d = data['date'];
      final t = data['time'];
      if (d is String && t is String) {
        try {
          final dt = DateTime.parse('$d $t');
          return dt.toLocal();
        } catch (_) {}
      }
    }

    return null;
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

  /// Day details popup — now shows appointments then doctor busy hours
  Future<void> _showDayDetails(BuildContext ctx, DateTime day) async {
    final key = _ymd(day);
    final events = (_eventsMap[key] ?? []).toList()
      ..sort((a, b) {
        final aM = a.start.hour * 60 + a.start.minute;
        final bM = b.start.hour * 60 + b.start.minute;
        return aM.compareTo(bM);
      });

    final busy = (_doctorBusyMap[key] ?? []).toList();

    final media = MediaQuery.of(ctx);
    final maxWidth = media.size.width * 0.7;
    final maxHeight = media.size.height * 0.7;

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
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
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
                    // Body: appointments then doctor busy
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              // Appointments
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Appointments',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 8),
                              if (events.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text('No appointments scheduled.',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                )
                              else
                                Column(
                                  children: events.map((ev) {
                                    final color = ev.isFollowUp
                                        ? Colors.orange
                                        : Colors.blue;
                                    final timeLabel =
                                        '${ev.start.format(ctx)} — ${ev.end.format(ctx)}';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.03),
                                              blurRadius: 6)
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 120,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.12),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(10),
                                                      bottomLeft:
                                                          Radius.circular(10)),
                                            ),
                                            child: Text(timeLabel,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87)),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(ev.patientName,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              color.shade700)),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                      ev.notes.isNotEmpty
                                                          ? ev.notes
                                                          : 'No notes',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.black54)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),

                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Doctor busy section
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Doctor busy hours',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 8),
                              if (busy.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text('No busy hours logged.',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                )
                              else
                                Column(
                                  children: busy.map((b) {
                                    final timeLabel = b.time.format(ctx);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.03),
                                              blurRadius: 6)
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 120,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.red.withOpacity(0.12),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(10),
                                                      bottomLeft:
                                                          Radius.circular(10)),
                                            ),
                                            child: Text(timeLabel,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87)),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('Doctor busy',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .red.shade700)),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                      b.notes.isNotEmpty
                                                          ? b.notes
                                                          : 'No notes',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.black54)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
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
                            onPressed: () async {
                              Navigator.of(dctx).pop();
                              await _showCreateForDate(ctx, day);
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

  // Build occupied time slots (patient appointments only)
  Set<String> _occupiedSlotsFromMapForDate(DateTime date) {
    final key = _ymd(date);
    final list = _eventsMap[key] ?? [];
    return {
      for (final ev in list)
        '${ev.start.hour.toString().padLeft(2, '0')}:${ev.start.minute.toString().padLeft(2, '0')}'
    };
  }

  // Build doctor occupied slots (from in-memory map)
  Set<String> _doctorOccupiedSlotsFromMapForDate(DateTime date) {
    final key = _ymd(date);
    final list = _doctorBusyMap[key] ?? [];
    return {
      for (final b in list)
        '${b.time.hour.toString().padLeft(2, '0')}:${b.time.minute.toString().padLeft(2, '0')}'
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
          title:
              Text('Select time — ${DateFormat('d MMM yyyy').format(forDate)}'),
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
                      backgroundColor:
                          taken ? Colors.grey.shade300 : Colors.white,
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

  // Create appointment dialog — now considers doctor busy slots from in-memory map
  Future<void> _showCreateForDate(BuildContext ctx, DateTime date) async {
    String? selectedPatientId;
    TimeOfDay? selectedTime;
    String appointmentType = 'N';
    final TextEditingController notesCtrl = TextEditingController();

    final patientOccupied = _occupiedSlotsFromMapForDate(date);
    final doctorOccupied = _doctorOccupiedSlotsFromMapForDate(date);
    final occupied = {...patientOccupied, ...doctorOccupied};

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setStateSB) {
            Future<void> pickTime() async {
              final t = await _showTimeSlotPickerDialog(dctx, date, occupied);
              if (t != null) {
                setStateSB(() => selectedTime = t);
              }
            }

            Future<void> save() async {
              if (selectedPatientId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please select a patient')),
                );
                return;
              }
              if (selectedTime == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please select a time slot')),
                );
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

              final currentlyOccupied = {
                ..._occupiedSlotsFromMapForDate(date),
                ..._doctorOccupiedSlotsFromMapForDate(date),
              };

              if (currentlyOccupied.contains(hhmm)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Selected slot already taken. Please pick another.'),
                  ),
                );
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

                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Appointment created')),
                );
                Navigator.of(dctx).pop();
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to create appointment: $e')),
                );
              }
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 620,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: Column(
                  children: [
                    /// ================= HEADER =================
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Create Appointment — ${DateFormat('EEEE, d MMM yyyy').format(date)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
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

                    /// ================= SCROLLABLE FORM =================
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Patient',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            _loadingPatients
                                ? const LinearProgressIndicator()
                                : DropdownButtonFormField2<String>(
                                    isExpanded: true,
                                    value: selectedPatientId,
                                    decoration: _input('Select patient'),
                                    items: _patientOptions
                                        .map((p) => DropdownMenuItem(
                                              value: p.id,
                                              child: _buildPatientOptionRow(p),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setStateSB(() => selectedPatientId = v),
                                  ),
                            const SizedBox(height: 12),
                            const Text('Time',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: pickTime,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  selectedTime == null
                                      ? 'Choose time slot'
                                      : selectedTime!.format(ctx),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Appointment Type',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Text('New'),
                                    value: 'N',
                                    groupValue: appointmentType,
                                    onChanged: (v) =>
                                        setStateSB(() => appointmentType = v!),
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Text('Follow Up'),
                                    value: 'F',
                                    groupValue: appointmentType,
                                    onChanged: (v) =>
                                        setStateSB(() => appointmentType = v!),
                                  ),
                                ),
                              ],
                            ),
                            _section('Section 1 — Vitals'),
                            _two(bpSysCtrl, 'Systolic', bpDiaCtrl, 'Diastolic'),
                            const SizedBox(height: 12),
                            _slider('Heart Rate', heartRate, 40, 150,
                                (v) => setStateSB(() => heartRate = v)),
                            _slider('Breathing Rate', breathingRate, 10, 40,
                                (v) => setStateSB(() => breathingRate = v)),
                            _three(heightCtrl, 'Height (cm)', weightCtrl,
                                'Weight (kg)', 'BMI'),
                            const SizedBox(height: 12),
                            _two(fbsCtrl, 'FBS', rbsCtrl, 'RBS'),
                            _section('Section 2 — Health Conditions'),
                            _checkboxGrid(healthConditions, setStateSB),
                            _section('Section 3 — Allergies'),
                            CheckboxListTile(
                              value: drugAllergy,
                              onChanged: (v) =>
                                  setStateSB(() => drugAllergy = v!),
                              title: const Text('Drug Allergy'),
                            ),
                            CheckboxListTile(
                              value: foodAllergy,
                              onChanged: (v) =>
                                  setStateSB(() => foodAllergy = v!),
                              title: const Text('Food Allergy'),
                            ),
                            CheckboxListTile(
                              value: latexAllergy,
                              onChanged: (v) =>
                                  setStateSB(() => latexAllergy = v!),
                              title: const Text('Latex Allergy'),
                            ),
                            TextField(
                              controller: allergyNotesCtrl,
                              decoration: _input('Other allergies'),
                            ),
                            _section('Section 4 — Past Surgical History'),
                            TextField(
                              controller: surgeryCtrl,
                              maxLines: 3,
                              decoration: _input('Describe surgeries'),
                            ),
                            _section('Section 6 — Dental History'),
                            _checkboxGrid(dentalHistory, setStateSB),
                            TextField(
                              controller: dentalNotesCtrl,
                              decoration: _input('Dental complications'),
                            ),
                            _section('Section 9 — Patient Consent'),
                            CheckboxListTile(
                              value: consentGiven,
                              onChanged: (v) =>
                                  setStateSB(() => consentGiven = v!),
                              title:
                                  const Text('Patient declaration / consent'),
                            ),
                            TextField(
                              controller: consentSignatureCtrl,
                              decoration:
                                  _input('Patient signature / scanned ref'),
                            ),
                            const SizedBox(height: 16),
                            const Text('Notes (optional)',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            TextField(
                              controller: notesCtrl,
                              maxLines: 3,
                              decoration: _input('Enter notes'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    /// ================= FOOTER =================
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _two(TextEditingController a, String alabel, TextEditingController b,
          String blabel) =>
      Row(children: [
        Expanded(child: TextField(controller: a, decoration: _input(alabel))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: b, decoration: _input(blabel))),
      ]);

  Widget _three(TextEditingController a, String alabel, TextEditingController b,
          String blabel, String c) =>
      Row(children: [
        Expanded(child: TextField(controller: a, decoration: _input(alabel))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: b, decoration: _input(blabel))),
        const SizedBox(width: 12),
        Expanded(child: TextField(decoration: _input(c))),
      ]);

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label — ${value.toInt()}'),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      );
  Widget _checkboxGrid(
    Map<String, bool> items,
    void Function(VoidCallback fn) setStateSB,
  ) {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: items.keys.map((k) {
        return SizedBox(
          width: 220,
          child: CheckboxListTile(
            value: items[k],
            onChanged: (v) {
              setStateSB(() {
                items[k] = v ?? false;
              });
            },
            title: Text(k),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        );
      }).toList(),
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
                        final m = DateTime(
                            DateTime.now().year, DateTime.now().month + i - 12);
                        return DropdownMenuItem<DateTime>(
                          value: DateTime(m.year, m.month),
                          child: Text(_headerFormatter.format(m)),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() =>
                              _focusedMonth = DateTime(val.year, val.month));
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
                      child: Text('Mon',
                          style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Tue',
                          style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Wed',
                          style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Thu',
                          style: TextStyle(fontWeight: FontWeight.w700)))),
              const Expanded(
                  child: Center(
                      child: Text('Fri',
                          style: TextStyle(fontWeight: FontWeight.w700)))),
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
                        final busy = _doctorBusyMap[ymd] ?? [];
                        final bool isCurrentMonth =
                            d.month == _focusedMonth.month;

                        final int newCount =
                            events.where((e) => e.isFollowUp == false).length;
                        final int followUpCount =
                            events.where((e) => e.isFollowUp == true).length;
                        final int doctorCount = busy.length;

                        return Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: GestureDetector(
                            onTap: () => _showDayDetails(context, d),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: isCurrentMonth
                                    ? Colors.white
                                    : Colors.grey.shade100,
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
                                          _countBadge(
                                              newCount, Colors.blue, 'New'),
                                        const SizedBox(width: 6),
                                        if (followUpCount > 0)
                                          _countBadge(followUpCount,
                                              Colors.orange, 'Follow Up'),
                                        const SizedBox(width: 6),
                                        if (doctorCount > 0)
                                          _countBadge(doctorCount, Colors.red,
                                              'Doctor Busy'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // events list (scroll inside cell if many)
                                  if (events.isEmpty && busy.isEmpty)
                                    const Expanded(child: SizedBox.shrink())
                                  else
                                    Expanded(
                                      child: ListView(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        children: [
                                          // show appointments
                                          ...events.map((ev) {
                                            final color = ev.isFollowUp
                                                ? Colors.orange
                                                : Colors.blue;
                                            final start =
                                                ev.start.format(context);
                                            final end = ev.end.format(context);
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 6),
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
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              color.shade700)),
                                                  const SizedBox(height: 2),
                                                  Text('$start - $end',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.black54)),
                                                ],
                                              ),
                                            );
                                          }).toList(),

                                          // show doctor busy entries (compact)
                                          ...busy.map((b) {
                                            final t = b.time.format(context);
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 6),
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('Doctor busy',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .red.shade700)),
                                                  const SizedBox(height: 2),
                                                  Text(t,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.black54)),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
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
                      const SizedBox(width: 12),
                      _legendDot(Colors.orange, 'Follow Up'),
                      const SizedBox(width: 12),
                      _legendDot(Colors.red, 'Doctor Busy'),
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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
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
    final namePart = parts.length > 1 ? parts.sublist(1).join('  ') : '';
    return Row(
      children: [
        Text(idPart, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(child: Text(namePart, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}

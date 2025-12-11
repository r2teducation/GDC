// lib/dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({super.key});

  // Palette
  static const _bg = Color(0xFFF3F4F6);
  static const _title = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);

  // default tile colors (past => grey)
  static const List<Color> _defaultTileColors = [
    Color(0xFFBFDBFE), // blue pastel
    Color(0xFFFDE68A), // yellow pastel (we'll treat as orange)
    Color(0xFFFECACA), // red pastel
  ];

  // darker accent colors for patient name
  static const List<Color> _accentColors = [
    Color(0xFF2563EB), // blue
    Color(0xFFEA580C), // orange
    Color(0xFFDC2626), // red
  ];

  // grey palette for past events
  static const Color _pastBg = Color(0xFFF3F4F6);
  static const Color _pastAccent = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    // compute today's range in local time
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final startTs = Timestamp.fromDate(startOfDay);
    final endTs = Timestamp.fromDate(endOfDay);

    // Query using the same field your calendar widget writes:
    // 'appointmentDateTime' between startOfDay (inclusive) and endOfDay (exclusive).
    // This avoids missing documents due to field-name mismatch.
    final q = FirebaseFirestore.instance
        .collection('appointments')
        .where('appointmentDateTime', isGreaterThanOrEqualTo: startTs)
        .where('appointmentDateTime', isLessThan: endTs)
        .orderBy('appointmentDateTime', descending: false)
        .snapshots();

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _title,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Today's Appointments",
                style: TextStyle(color: _muted, fontSize: 16),
              ),
              const SizedBox(height: 20),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: q,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Failed to load appointments: ${snap.error}'),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snap.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                      ),
                      child: const Text('No appointments for today', style: TextStyle(color: _muted)),
                    );
                  }

                  // Build list from docs
                  // Firestore ordering should already be ascending by appointmentDateTime
                  return Column(
                    children: docs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final doc = entry.value;
                      final data = doc.data();

                      // color selection: if doc contains 'color' (hex string), try parse; otherwise cycle defaults
                      Color bgColor = _defaultTileColors[idx % _defaultTileColors.length];
                      Color accent = _accentColors[idx % _accentColors.length];
                      if (data.containsKey('color') && data['color'] is String) {
                        final hex = (data['color'] as String).trim();
                        try {
                          final parsed = _colorFromHex(hex);
                          bgColor = parsed.withOpacity(0.25);
                          accent = parsed;
                        } catch (_) {
                          // ignore parse errors
                        }
                      } else {
                        // If appointmentType indicates follow-up, pick orange; else blue.
                        final appointmentType = (data['appointmentType'] ?? '').toString().toUpperCase();
                        if (appointmentType == 'F') {
                          bgColor = _defaultTileColors[1];
                          accent = _accentColors[1];
                        } else {
                          bgColor = _defaultTileColors[0];
                          accent = _accentColors[0];
                        }
                      }

                      // parse appointmentDateTime (preferred), but accept other fields as fallback
                      dynamic startVal = data['appointmentDateTime'] ?? _extractStart(data);
                      dynamic endVal = data['end'] ?? data['appointmentEnd'] ?? _extractEnd(data);

                      DateTime? startDt = _toDateTime(startVal)?.toLocal();
                      DateTime? endDt = _toDateTime(endVal)?.toLocal();

                      // If start exists and end missing, default to +30 minutes.
                      if (startDt != null && endDt == null) endDt = startDt.add(const Duration(minutes: 30));

                      // If start is missing, skip this doc (shouldn't happen if your calendar writes appointmentDateTime)
                      if (startDt == null) return const SizedBox.shrink();

                      final isPast = endDt!.isBefore(DateTime.now());

                      final tileBg = isPast ? _pastBg : bgColor;
                      final tileAccent = isPast ? _pastAccent : accent;

                      final patientName = (data['patientName'] ?? data['title'] ?? data['name'] ?? data['patientId'] ?? 'Unknown').toString();
                      final notes = (data['notes'] ?? data['description'] ?? data['reason'] ?? '').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
                            border: Border.all(color: const Color(0xFFE9EEF3)),
                          ),
                          child: Row(
                            children: [
                              // left time pill
                              Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                width: 120,
                                decoration: BoxDecoration(
                                  color: tileBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatShortTime(startDt),
                                      style: TextStyle(fontWeight: FontWeight.w600, color: tileAccent),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '—',
                                      style: TextStyle(color: tileAccent.withOpacity(0.9)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatShortTime(endDt),
                                      style: TextStyle(fontWeight: FontWeight.w600, color: tileAccent),
                                    ),
                                  ],
                                ),
                              ),

                              // right content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(6, 18, 18, 18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        patientName,
                                        style: TextStyle(
                                          color: tileAccent,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        notes.isEmpty ? 'No notes' : notes,
                                        style: const TextStyle(color: _muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helpers ---

  // extract start-like fields from map (fallback)
  static dynamic _extractStart(Map<String, dynamic> data) {
    if (data.containsKey('start')) return data['start'];
    if (data.containsKey('startAt')) return data['startAt'];
    if (data.containsKey('startDateTime')) return data['startDateTime'];
    if (data.containsKey('appointmentDate')) return data['appointmentDate'];
    if (data.containsKey('date')) return data['date'];
    if (data.containsKey('from')) return data['from'];
    if (data.containsKey('time')) return data['time'];
    return null;
  }

  // extract end-like fields from map (fallback)
  static dynamic _extractEnd(Map<String, dynamic> data) {
    if (data.containsKey('end')) return data['end'];
    if (data.containsKey('endAt')) return data['endAt'];
    if (data.containsKey('appointmentEnd')) return data['appointmentEnd'];
    if (data.containsKey('to')) return data['to'];
    if (data.containsKey('durationMinutes')) {
      final start = _extractStart(data);
      final startDt = _toDateTime(start);
      final mins = (data['durationMinutes'] is num) ? (data['durationMinutes'] as num).toInt() : null;
      if (startDt != null && mins != null) return startDt.add(Duration(minutes: mins));
    }
    return null;
  }

  // parse Timestamp/DateTime/String/number into DateTime or null
  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      // treat as milliseconds since epoch, or seconds (detect length)
      final digits = v.toString().length;
      if (digits <= 10) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (v is String) {
      // try ISO parse
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
      // try to extract digits (e.g. "/Date(1234567890)/" or epoch string)
      try {
        final digits = RegExp(r'\d+').firstMatch(v)?.group(0);
        if (digits != null) {
          final ms = int.parse(digits);
          if (digits.length <= 10) return DateTime.fromMillisecondsSinceEpoch(ms * 1000);
          return DateTime.fromMillisecondsSinceEpoch(ms);
        }
      } catch (_) {}
    }
    return null;
  }

  // Format a compact time (e.g. 8:30 AM)
  static String _formatShortTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }

  // parse hex color like "#FF00AA" or "FF00AA" or "0xFF00AA"
  static Color _colorFromHex(String hexString) {
    var hex = hexString.replaceAll('#', '').replaceAll('0x', '');
    if (hex.length == 6) hex = 'FF$hex'; // add opacity
    final intVal = int.parse(hex, radix: 16);
    return Color(intVal);
  }
}
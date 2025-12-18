// lib/home_layout_widget.dart
import 'package:flutter/material.dart';
import 'package:gt/dashboard.dart';

// Patient widgets
import 'package:gt/patient/patientregisterwidget.dart';
import 'package:gt/patient/patientdetailswidget.dart';
import 'package:gt/patient/patientsummarywidget.dart'; // <-- Patient Summary

// Appointment widgets
import 'package:gt/appointment/patientcalendarwidget.dart';
import 'package:gt/appointment/doctorcalendarwidget.dart'; // <-- Doctor Calendar
import 'package:gt/payment/paymenthistorywidget.dart';
import 'package:gt/payment/paymentwidget.dart';

// Treatment widgets
import 'package:gt/treatment/followupwidget.dart'; // <-- CreateFollowUpWidget (new)

// Pharmacy: Medicine Stock
import 'package:gt/pharmacy/medicinestockwidget.dart';
import 'package:gt/treatment/treatmentwidget.dart'; 

class HomeLayoutWidget extends StatelessWidget {
  const HomeLayoutWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Global Dental Clinic',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        fontFamily: 'SF Pro',
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
      ),
      home: const HomeLayoutHome(),
    );
  }
}

class HomeLayoutHome extends StatefulWidget {
  const HomeLayoutHome({super.key});
  @override
  State<HomeLayoutHome> createState() => _HomeLayoutHomeState();
}

class _HomeLayoutHomeState extends State<HomeLayoutHome> {
  int selected = 0;

  // Patient module should be uncollapsed by default
  bool patientOpen = false;
  bool appointmentOpen = false;
  bool treatmentOpen = false;
  bool paymentOpen = false;
  bool pharmacyOpen = false;

  String? _route; // null → dashboard

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: selected,
            patientOpen: patientOpen,
            appointmentOpen: appointmentOpen,
            treatmentOpen: treatmentOpen,
            paymentOpen: paymentOpen,
            pharmacyOpen: pharmacyOpen,

            onSelect: (i) {
              setState(() {
                selected = i;
                _route = (i == 0) ? 'dashboard' : null;
              });
            },

            onTogglePatient: () => setState(() => patientOpen = !patientOpen),
            onToggleAppointment: () => setState(() => appointmentOpen = !appointmentOpen),
            onToggleTreatment: () => setState(() => treatmentOpen = !treatmentOpen),
            onTogglePayment: () => setState(() => paymentOpen = !paymentOpen),
            onTogglePharmacy: () => setState(() => pharmacyOpen = !pharmacyOpen),

            onOpenPatientRegister: () => setState(() => _route = 'patient_register'),
            onOpenPatientDetails: () => setState(() => _route = 'patient_details'),
            onOpenPatientHistory: () => setState(() => _route = 'patient_history'), // Patient Summary

            onOpenAppointmentSub3: () => setState(() => _route = 'appointment_sub_tab_3'),
            onOpenAppointmentSub4: () => setState(() => _route = 'appointment_sub_tab_4'),

            // Treatment sub-tabs (now 2)
            onOpenTreatmentSub1: () => setState(() => _route = 'treatment_sub_tab_1'),
            onOpenTreatmentSub3: () => setState(() => _route = 'treatment_sub_tab_3'),

            onOpenPaymentSub1: () => setState(() => _route = 'payment_sub_tab_1'),
            onOpenPaymentSub2: () => setState(() => _route = 'payment_sub_tab_2'),

            // Pharmacy: only one sub-tab remains (Medicine Stock)
            onOpenPharmacySub1: () => setState(() => _route = 'pharmacy_sub_tab_1'),
          ),

          // MAIN CONTENT AREA
          Expanded(
            // keep padding as before, but align content to top so inner widgets render from top
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Align(
                alignment: Alignment.topCenter,
                // Wrap switch result in a SizedBox to allow child widgets to control width (they usually use ConstrainedBox)
                child: SizedBox(
                  width: double.infinity,
                  child: switch (_route) {
                    'dashboard' => const DashboardWidget(),

                    'patient_register' => const PatientRegisterWidget(),
                    'patient_details' => const PatientDetailsWidget(),
                    'patient_history' => const PatientSummaryWidget(), // Patient Summary

                    // Appointment sub-tabs (only patient & doctor calendars remain)
                    'appointment_sub_tab_3' => const PatientCalendarWidget(),
                    'appointment_sub_tab_4' => const DoctorCalendarWidget(),

                    // Treatment
                    // treatment_sub_tab_1 => Treatment (CreateTreatmentWidget)
                    'treatment_sub_tab_1' => const TreatmentWidget(),
                    // treatment_sub_tab_2 => Treatment Details (placeholder)
                    'treatment_sub_tab_2' => const _PlaceholderScaffold(title: 'Treatment Details — in progress'),
                    // treatment_sub_tab_3 => Follow Up (CreateFollowUpWidget)
                    'treatment_sub_tab_3' => const FollowUpWidget(),
                    // treatment_sub_tab_4 => Follow Up Details (placeholder)
                    'treatment_sub_tab_4' => const _PlaceholderScaffold(title: 'Follow Up Details — in progress'),

                    // Payment
                    'payment_sub_tab_1' => const PaymentWidget(),
                    'payment_sub_tab_2' => const PaymentHistoryWidget(),

                    // Pharmacy
                    // wired to MedicineStockWidget and label changed in sidebar
                    'pharmacy_sub_tab_1' => const MedicineStockWidget(),

                    _ => const DashboardWidget(),
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

/// Reusable placeholder
class _PlaceholderScaffold extends StatelessWidget {
  final String title;
  const _PlaceholderScaffold({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Center(
        child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------
// SIDEBAR
// ------------------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  final bool patientOpen;
  final bool appointmentOpen;
  final bool treatmentOpen;
  final bool paymentOpen;
  final bool pharmacyOpen;

  final VoidCallback onTogglePatient;
  final VoidCallback onToggleAppointment;
  final VoidCallback onToggleTreatment;
  final VoidCallback onTogglePayment;
  final VoidCallback onTogglePharmacy;

  final VoidCallback onOpenPatientRegister;
  final VoidCallback onOpenPatientDetails;
  final VoidCallback onOpenPatientHistory; // Patient Summary callback

  final VoidCallback onOpenAppointmentSub3;
  final VoidCallback onOpenAppointmentSub4;

  // now includes 4 treatment callbacks
  final VoidCallback onOpenTreatmentSub1;
  final VoidCallback onOpenTreatmentSub3;

  final VoidCallback onOpenPaymentSub1;
  final VoidCallback onOpenPaymentSub2;

  final VoidCallback onOpenPharmacySub1;

  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.patientOpen,
    required this.appointmentOpen,
    required this.treatmentOpen,
    required this.paymentOpen,
    required this.pharmacyOpen,
    required this.onTogglePatient,
    required this.onToggleAppointment,
    required this.onToggleTreatment,
    required this.onTogglePayment,
    required this.onTogglePharmacy,
    required this.onOpenPatientRegister,
    required this.onOpenPatientDetails,
    required this.onOpenPatientHistory,
    required this.onOpenAppointmentSub3,
    required this.onOpenAppointmentSub4,
    required this.onOpenTreatmentSub1,
    required this.onOpenTreatmentSub3,
    required this.onOpenPaymentSub1,
    required this.onOpenPaymentSub2,
    required this.onOpenPharmacySub1,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);

    return Container(
      width: 280,
      color: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // BRAND PANEL
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(color: Color(0xFF0B1220)),
              child: Row(
                children: [
                  Image.asset('assets/images/gtlogo.png', height: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Global Dental Clinic',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // PROFILE CARD
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const CircleAvatar(radius: 18, backgroundImage: AssetImage('assets/images/akshara.png')),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ramesh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Row(children: [
                      _Dot(color: Color(0xFF22C55E)),
                      SizedBox(width: 6),
                      Text('Super Admin', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    ])
                  ]),
                  const Spacer(),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)))
                ],
              ),
            ),

            // MENU SECTIONS
            Expanded(
              child: ListView(
                children: [
                  _SideItem(
                    icon: Icons.space_dashboard_outlined,
                    label: 'Dashboard',
                    active: selected == 0,
                    onTap: () => onSelect(0),
                  ),

                  const SizedBox(height: 6),

                  // PATIENT GROUP
                  _Collapsible(
                    icon: Icons.people_alt_outlined,
                    label: 'Patient',
                    open: patientOpen,
                    onToggle: onTogglePatient,
                    children: [
                      _SideSubItem(label: 'Register', onTap: onOpenPatientRegister),
                      _SideSubItem(label: 'Details', onTap: onOpenPatientDetails),
                      _SideSubItem(label: 'History', onTap: onOpenPatientHistory), // Patient Summary
                    ],
                  ),

                  const SizedBox(height: 12),

                  // APPOINTMENT GROUP
                  _Collapsible(
                    icon: Icons.event_note_outlined,
                    label: 'Appointment',
                    open: appointmentOpen,
                    onToggle: onToggleAppointment,
                    children: [
                      // Removed Book Appointment & Appointment Details sub-tabs.
                      _SideSubItem(label: 'Patient Calendar', onTap: onOpenAppointmentSub3),
                      _SideSubItem(label: 'Doctor Calendar', onTap: onOpenAppointmentSub4),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // TREATMENT GROUP
                  _Collapsible(
                    icon: Icons.medical_services_outlined,
                    label: 'Treatment',
                    open: treatmentOpen,
                    onToggle: onToggleTreatment,
                    children: [
                      // Friendly names for sub-items
                      _SideSubItem(label: 'Treatment', onTap: onOpenTreatmentSub1),
                      _SideSubItem(label: 'Follow Up', onTap: onOpenTreatmentSub3),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // PAYMENT GROUP
                  _Collapsible(
                    icon: Icons.receipt_long_outlined,
                    label: 'Payment',
                    open: paymentOpen,
                    onToggle: onTogglePayment,
                    children: [
                      _SideSubItem(label: 'Payment', onTap: onOpenPaymentSub1),
                      _SideSubItem(label: 'Payment History', onTap: onOpenPaymentSub2),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // PHARMACY GROUP
                  _Collapsible(
                    icon: Icons.local_pharmacy_outlined,
                    label: 'Pharmacy',
                    open: pharmacyOpen,
                    onToggle: onTogglePharmacy,
                    children: [
                      // renamed and wired to MedicineStockWidget
                      _SideSubItem(label: 'Medicine Stock', onTap: onOpenPharmacySub1),
                      // pharmacy_sub_tab_2 removed intentionally
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('Powered by R2T © 2025', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        Spacer(),
                        Text('v 1.1.0', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------
// COMPONENTS (Side items, collapsible, dots)
// ------------------------------------------------------------------------------------

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _SideItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFF0D2630) : Colors.transparent;
    final borderColor = active ? const Color(0xFF14B8A6) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor, width: 4)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                if (active)
                  const Icon(Icons.check, size: 16, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Collapsible extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool open;
  final VoidCallback? onToggle;
  final List<Widget> children;
  final Widget? trailingBadge;

  const _Collapsible({
    required this.icon,
    required this.label,
    required this.open,
    this.onToggle,
    required this.children,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    if (trailingBadge != null) trailingBadge!,
                    Icon(open ? Icons.expand_more : Icons.chevron_right, color: const Color(0xFF9CA3AF)),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(children: children),
          ),
      ],
    );
  }
}

class _SideSubItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SideSubItem({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 8),
      child: Material(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
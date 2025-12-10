import 'package:flutter/material.dart';
import 'package:gt/dashboard.dart';

// Make sure these paths match where you saved the widgets
import 'package:gt/patient/patientregisterwidget.dart';
import 'package:gt/patient/patientdetailswidget.dart';
// wire appointment widgets (paths you specified)
import 'package:gt/appointment/AppointmentWidget.dart';
import 'package:gt/appointment/appointmentdetailswidget.dart';

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

  // collapsible open flags for groups
  bool patientOpen = true;
  bool appointmentOpen = false;
  bool treatmentOpen = false;
  bool paymentOpen = false;
  bool pharmacyOpen = false;

  String? _route; // null -> dashboard

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
            // toggles for groups
            onTogglePatient: () => setState(() => patientOpen = !patientOpen),
            onToggleAppointment: () =>
                setState(() => appointmentOpen = !appointmentOpen),
            onToggleTreatment: () => setState(() => treatmentOpen = !treatmentOpen),
            onTogglePayment: () => setState(() => paymentOpen = !paymentOpen),
            onTogglePharmacy: () => setState(() => pharmacyOpen = !pharmacyOpen),

            // open sub-tabs (routes)
            onOpenPatientRegister: () => setState(() => _route = 'patient_register'),
            onOpenPatientDetails: () => setState(() => _route = 'patient_details'),

            onOpenAppointmentSub1: () => setState(() => _route = 'appointment_sub_tab_1'),
            onOpenAppointmentSub2: () => setState(() => _route = 'appointment_sub_tab_2'),

            onOpenTreatmentSub1: () => setState(() => _route = 'treatment_sub_tab_1'),
            onOpenTreatmentSub2: () => setState(() => _route = 'treatment_sub_tab_2'),

            onOpenPaymentSub1: () => setState(() => _route = 'payment_sub_tab_1'),
            onOpenPaymentSub2: () => setState(() => _route = 'payment_sub_tab_2'),

            onOpenPharmacySub1: () => setState(() => _route = 'pharmacy_sub_tab_1'),
            onOpenPharmacySub2: () => setState(() => _route = 'pharmacy_sub_tab_2'),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 0),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: switch (_route) {
                      'dashboard' => const DashboardWidget(),
                      'patient_register' => const PatientRegisterWidget(),
                      'patient_details' => const PatientDetailsWidget(),

                      // appointment — wired: first sub tab -> Book Appointment (AppointmentWidget)
                      'appointment_sub_tab_1' =>
                        const AppointmentWidget(),

                      // appointment details (wired to AppointmentDetailsWidget)
                      'appointment_sub_tab_2' =>
                        const AppointmentDetailsWidget(),

                      // treatment placeholders
                      'treatment_sub_tab_1' =>
                        const _PlaceholderScaffold(title: 'Treatment — Sub Tab 1'),
                      'treatment_sub_tab_2' =>
                        const _PlaceholderScaffold(title: 'Treatment — Sub Tab 2'),

                      // payment placeholders
                      'payment_sub_tab_1' =>
                        const _PlaceholderScaffold(title: 'Payment — Sub Tab 1'),
                      'payment_sub_tab_2' =>
                        const _PlaceholderScaffold(title: 'Payment — Sub Tab 2'),

                      // pharmacy placeholders
                      'pharmacy_sub_tab_1' =>
                        const _PlaceholderScaffold(title: 'Pharmacy — Sub Tab 1'),
                      'pharmacy_sub_tab_2' =>
                        const _PlaceholderScaffold(title: 'Pharmacy — Sub Tab 2'),

                      _ => const DashboardWidget(),
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// Simple placeholder widget used for new tabs while you wire real screens.
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

class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  // open flags for groups
  final bool patientOpen;
  final bool appointmentOpen;
  final bool treatmentOpen;
  final bool paymentOpen;
  final bool pharmacyOpen;

  // toggles
  final VoidCallback onTogglePatient;
  final VoidCallback onToggleAppointment;
  final VoidCallback onToggleTreatment;
  final VoidCallback onTogglePayment;
  final VoidCallback onTogglePharmacy;

  // patient sub-tab openers
  final VoidCallback onOpenPatientRegister;
  final VoidCallback onOpenPatientDetails;

  // appointment sub-tab openers
  final VoidCallback onOpenAppointmentSub1;
  final VoidCallback onOpenAppointmentSub2;

  // treatment sub-tab openers
  final VoidCallback onOpenTreatmentSub1;
  final VoidCallback onOpenTreatmentSub2;

  // payment sub-tab openers
  final VoidCallback onOpenPaymentSub1;
  final VoidCallback onOpenPaymentSub2;

  // pharmacy sub-tab openers
  final VoidCallback onOpenPharmacySub1;
  final VoidCallback onOpenPharmacySub2;

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
    required this.onOpenAppointmentSub1,
    required this.onOpenAppointmentSub2,
    required this.onOpenTreatmentSub1,
    required this.onOpenTreatmentSub2,
    required this.onOpenPaymentSub1,
    required this.onOpenPaymentSub2,
    required this.onOpenPharmacySub1,
    required this.onOpenPharmacySub2,
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
            // BRAND BAR
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(color: Color(0xFF0B1220)),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/gtlogo.png',
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Global Dental Clinic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PROFILE CARD
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundImage: AssetImage('assets/images/akshara.png'),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ramesh',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          _Dot(color: Color(0xFF22C55E)),
                          SizedBox(width: 6),
                          Text('Super Admin',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                      onPressed: () {},
                      icon:
                          const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)))
                ],
              ),
            ),

            // MENU
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
                      _SideSubItem(
                        label: 'Register',
                        onTap: onOpenPatientRegister,
                      ),
                      _SideSubItem(
                        label: 'Details',
                        onTap: onOpenPatientDetails,
                      ),
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
                      _SideSubItem(label: 'Book Appointment', onTap: onOpenAppointmentSub1),
                      _SideSubItem(label: 'Appointment Details', onTap: onOpenAppointmentSub2),
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
                      _SideSubItem(label: 'treatment_sub_tab_1', onTap: onOpenTreatmentSub1),
                      _SideSubItem(label: 'treatment_sub_tab_2', onTap: onOpenTreatmentSub2),
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
                      _SideSubItem(label: 'payment_sub_tab_1', onTap: onOpenPaymentSub1),
                      _SideSubItem(label: 'payment_sub_tab_2', onTap: onOpenPaymentSub2),
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
                      _SideSubItem(label: 'pharmacy_sub_tab_1', onTap: onOpenPharmacySub1),
                      _SideSubItem(label: 'pharmacy_sub_tab_2', onTap: onOpenPharmacySub2),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('Powered by Gutta © 2022',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12)),
                        Spacer(),
                        Text('v 1.1.2',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12)),
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
                  child: Text(label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      )),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (trailingBadge != null) trailingBadge!,
                    Icon(
                      open ? Icons.expand_more : Icons.chevron_right,
                      color: const Color(0xFF9CA3AF),
                      size: 20,
                    ),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Text(
                  label,
                  style:
                      const TextStyle(color: Color(0xFFE5E7EB), fontSize: 14),
                ),
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
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
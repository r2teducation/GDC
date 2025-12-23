import 'package:flutter/material.dart';
import 'package:gt/dashboard.dart';

// Patient
import 'package:gt/patient/patientregisterwidget.dart';
import 'package:gt/patient/patientdetailswidget.dart';
import 'package:gt/patient/patientsummarywidget.dart';

// Appointment
import 'package:gt/appointment/patientcalendarwidget.dart';
import 'package:gt/appointment/doctorcalendarwidget.dart';
import 'package:gt/templatewidget.dart';

// Treatment
import 'package:gt/treatment/treatmentwidget.dart';
import 'package:gt/treatment/followupwidget.dart';

// Payment
import 'package:gt/payment/paymentwidget.dart';
import 'package:gt/payment/paymenthistorywidget.dart';

// Pharmacy
import 'package:gt/pharmacy/pharmacywidget.dart';
import 'package:gt/pharmacy/medicinestockwidget.dart';

/// ---------------------------------------------------------------------------
/// APP ENTRY
/// ---------------------------------------------------------------------------

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
      //  fontFamily: 'SF Pro',
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

/// ---------------------------------------------------------------------------
/// HOME LAYOUT
/// ---------------------------------------------------------------------------

class HomeLayoutHome extends StatefulWidget {
  const HomeLayoutHome({super.key});

  @override
  State<HomeLayoutHome> createState() => _HomeLayoutHomeState();
}

class _HomeLayoutHomeState extends State<HomeLayoutHome> {
  String _route = 'dashboard';

  // Centralized route → widget mapping
  final Map<String, Widget> _routes = {
    'dashboard': const DashboardWidget(),
    'patient_register': const PatientRegisterWidget(),
    'patient_details': const PatientDetailsWidget(),
    'patient_history': const TemplateWidget(),
    'appointment_sub_tab_3': const PatientCalendarWidget(),
    'appointment_sub_tab_4': const DoctorCalendarWidget(),
    'treatment_sub_tab_1': const TreatmentWidget(),
    'treatment_sub_tab_3': const FollowUpWidget(),
    'payment_sub_tab_1': const PaymentWidget(),
    'payment_sub_tab_2': const PaymentHistoryWidget(),
    'pharmacy_sub_tab_1': const PharmacyWidget(),
    'pharmacy_sub_tab_2': const MedicineStockWidget(),
  };

  void _navigate(String route) {
    setState(() => _route = route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _TopNavBar(
            currentRoute: _route,
            onNavigate: _navigate,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _routes[_route] ?? const DashboardWidget(),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// TOP NAV BAR
/// ---------------------------------------------------------------------------

class _TopNavBar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onNavigate;

  const _TopNavBar({
    required this.currentRoute,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);

    return Container(
      height: 64,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Image.asset('assets/images/gtlogo.png', height: 28),
          const SizedBox(width: 12),
          const Text(
            'GDC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 24),
          _TopTab(
            label: 'Dashboard',
            active: currentRoute == 'dashboard',
            onTap: () => onNavigate('dashboard'),
          ),
          _ClickMenuTab(
            label: 'Patient',
            items: patientMenu,
            onNavigate: onNavigate,
          ),
          _ClickMenuTab(
            label: 'Appointment',
            items: appointmentMenu,
            onNavigate: onNavigate,
          ),
          _ClickMenuTab(
            label: 'Treatment',
            items: treatmentMenu,
            onNavigate: onNavigate,
          ),
          _ClickMenuTab(
            label: 'Payment',
            items: paymentMenu,
            onNavigate: onNavigate,
          ),
          _ClickMenuTab(
            label: 'Pharmacy',
            items: pharmacyMenu,
            onNavigate: onNavigate,
          ),
          const Spacer(),
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFF22C55E)),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// POPUP MENU CONFIG
/// ---------------------------------------------------------------------------

Widget _popupTab({
  required String label,
  required List<_MenuItem> items,
  required ValueChanged<String> onNavigate,
}) {
  return PopupMenuButton<String>(
    position: PopupMenuPosition.under,

    // 🔥 KEY FIX
    offset: const Offset(-16, 6),

    elevation: 20,
    color: const Color(0xFF1C1C1E),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFF2C2C2E)),
    ),
    constraints: const BoxConstraints(
      minWidth: 200,
      maxWidth: 240,
    ),
    onSelected: onNavigate,

    itemBuilder: (context) {
      return List.generate(items.length, (index) {
        final item = items[index];
        return PopupMenuItem<String>(
          value: item.route,
          height: 42,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              if (index != items.length - 1)
                const Divider(
                  height: 1,
                  thickness: 0.4,
                  color: Color(0xFF3A3A3C),
                ),
            ],
          ),
        );
      });
    },

    child: _TopTab(
      label: label,
      onTap: null,
    ),
  );
}

/// ---------------------------------------------------------------------------
/// TOP TAB
/// ---------------------------------------------------------------------------

class _TopTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final GlobalKey? keyRef;

  const _TopTab({
    required this.label,
    this.active = false,
    this.onTap,
    this.keyRef,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: keyRef,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFFCBD5E1),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// MENU MODELS
/// ---------------------------------------------------------------------------

class _MenuItem {
  final String label;
  final String route;
  const _MenuItem(this.label, this.route);
}

/// ---------------------------------------------------------------------------
/// MENU DEFINITIONS
/// ---------------------------------------------------------------------------

const patientMenu = [
  _MenuItem('Register', 'patient_register'),
  _MenuItem('Details', 'patient_details'),
  _MenuItem('History', 'patient_history'),
];

const appointmentMenu = [
  _MenuItem('Patient Calendar', 'appointment_sub_tab_3'),
  _MenuItem('Doctor Calendar', 'appointment_sub_tab_4'),
];

const treatmentMenu = [
  _MenuItem('Treatment', 'treatment_sub_tab_1'),
  _MenuItem('Follow Up', 'treatment_sub_tab_3'),
];

const paymentMenu = [
  _MenuItem('Payment', 'payment_sub_tab_1'),
  _MenuItem('Payment History', 'payment_sub_tab_2'),
];

const pharmacyMenu = [
  _MenuItem('Pharmacy', 'pharmacy_sub_tab_1'),
  _MenuItem('Medicine Stock', 'pharmacy_sub_tab_2'),
];

class _ClickMenuTab extends StatefulWidget {
  final String label;
  final List<_MenuItem> items;
  final ValueChanged<String> onNavigate;

  const _ClickMenuTab({
    required this.label,
    required this.items,
    required this.onNavigate,
  });

  @override
  State<_ClickMenuTab> createState() => _ClickMenuTabState();
}

class _ClickMenuTabState extends State<_ClickMenuTab> {
  final GlobalKey _key = GlobalKey();
  bool _menuOpen = false;

  Future<void> _openMenu() async {
    if (_menuOpen) return;
    _menuOpen = true;

    final box = _key.currentContext!.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    final selected = await showMenu<String>(
      context: context,
      color: const Color(0xFF1C1C1E),
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF2C2C2E)),
      ),
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + size.height + 6,
        pos.dx + size.width,
        0,
      ),
      items: widget.items.map((item) {
        return PopupMenuItem<String>(
          value: item.route,
          height: 42,
          padding: EdgeInsets.zero,
          child: Container(
            height: 42,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );

    _menuOpen = false;

    if (selected != null) {
      widget.onNavigate(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: _key,
      onTap: _openMenu, // ✅ CLICK ONLY
      borderRadius: BorderRadius.circular(8),
      child: _TopTab(
        label: widget.label,
        onTap: null, // handled here
      ),
    );
  }
}

class HoverMenuController {
  static VoidCallback? _closeActiveMenu;

  static void register(VoidCallback closeFn) {
    _closeActiveMenu?.call(); // 🔥 close previous
    _closeActiveMenu = closeFn;
  }

  static void clear(VoidCallback closeFn) {
    if (_closeActiveMenu == closeFn) {
      _closeActiveMenu = null;
    }
  }
}

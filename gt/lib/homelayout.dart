import 'package:flutter/material.dart';
import 'package:gt/dashboard.dart';
import 'package:gt/login.dart';

// Patient
import 'package:gt/patient/patientregisterwidget.dart';
import 'package:gt/patient/patientdetailswidget.dart';
import 'package:gt/patient/patientsummarywidget.dart';

// Appointment
import 'package:gt/appointment/patientcalendarwidget.dart';
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
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
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
  final _NavOverlayState _navState = _NavOverlayState();
  final GlobalKey<_TopStickerNavBarState> _topNavKey =
      GlobalKey<_TopStickerNavBarState>();

  String _route = 'dashboard';

  @override
  void initState() {
    super.initState();
    _navState.bind(() {
      if (mounted) setState(() {});
    });
  }

  final Map<String, Widget> _routes = {
    'dashboard': const DashboardWidget(),
    'patient_register': const PatientRegisterWidget(),
    'patient_details': const PatientDetailsWidget(),
    'patient_history': const PatientSummaryWidget(),
    'appointment_calendar': const PatientCalendarWidget(),
    'treatment_main': const TreatmentWidget(),
    'treatment_followup': const FollowUpWidget(),
    'payment_main': const PaymentWidget(),
    'payment_history': const TemplateWidget(),
    'pharmacy_main': const PharmacyWidget(),
    'pharmacy_stock': const MedicineStockWidget(),
  };

  void _navigate(String route) {
    setState(() => _route = route);
  }

  void _logout(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NewLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopStickerNavBar(
                  key: _topNavKey,
                  currentRoute: _route,
                  onNavigate: _navigate,
                  onLogout: () => _logout(context),
                  overlay: _navState,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _routes[_route] ?? const DashboardWidget(),
                  ),
                ),
              ],
            ),

            // 🔥 SUB TAB OVERLAY
            if (_navState.showSubTabs)
              Positioned(
                top: 56,
                left: _navState.left,
                child: _SubTabsPanel(
                  width: _navState.width,
                  items: _navState.items,
                  onSelect: (r) {
                    _navigate(r);
                    _navState.close();
                    _topNavKey.currentState?.clearActiveTab(); // 🔥 KEY LINE
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// NAV OVERLAY STATE
/// ---------------------------------------------------------------------------

class _NavOverlayState {
  bool showSubTabs = false;
  double left = 0;
  double width = 0;
  List<_SubTab> items = [];

  VoidCallback? _notify;

  void bind(VoidCallback notify) {
    _notify = notify;
  }

  void open(double l, double w, List<_SubTab> i) {
    left = l;
    width = w;
    items = i;
    showSubTabs = true;
    _notify?.call();
  }

  void close() {
    showSubTabs = false;
    _notify?.call();
  }
}

/// ---------------------------------------------------------------------------
/// TOP STICKER NAV BAR
/// ---------------------------------------------------------------------------

class _TopStickerNavBar extends StatefulWidget {
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final _NavOverlayState overlay;

  const _TopStickerNavBar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    required this.onLogout,
    required this.overlay,
  });

  @override
  State<_TopStickerNavBar> createState() => _TopStickerNavBarState();
}

class _TopStickerNavBarState extends State<_TopStickerNavBar> {
  int _activeTab = -1;
  final List<GlobalKey> _tabKeys = List.generate(5, (_) => GlobalKey());

  final List<_MainTab> _tabs = [
    const _MainTab('Patient', [
      _SubTab('Register', 'patient_register'),
      _SubTab('Details', 'patient_details'),
      _SubTab('History', 'patient_history'),
    ]),
    const _MainTab('Appointment', [
      _SubTab('Calendar', 'appointment_calendar'),
    ]),
    const _MainTab('Treatment', [
      _SubTab('Treatment', 'treatment_main'),
      _SubTab('Follow Up', 'treatment_followup'),
    ]),
    const _MainTab('Payment', [
      _SubTab('Payment', 'payment_main'),
      _SubTab('Payment History', 'payment_history'),
    ]),
    const _MainTab('Pharmacy', [
      _SubTab('Pharmacy', 'pharmacy_main'),
      _SubTab('Medicine Stock', 'pharmacy_stock'),
    ]),
  ];

  void clearActiveTab() {
    setState(() => _activeTab = -1);
  }

  void _openTab(int index) {
    final box = _tabKeys[index].currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    widget.overlay.open(offset.dx, box.size.width, _tabs[index].subs);
    setState(() => _activeTab = index);
  }

  void _goHome() {
    widget.overlay.close();
    widget.onNavigate('dashboard');
    setState(() => _activeTab = -1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Text(
            'GDC',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),

          _icon(Icons.home_outlined, _goHome),
          const SizedBox(width: 20),

          Expanded(
            child: Row(
              children: List.generate(
                _tabs.length,
                (i) => Expanded(
                  child: InkWell(
                    key: _tabKeys[i],
                    onTap: () => _openTab(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeTab == i
                            ? Colors.white
                            : const Color(0xFF111827),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        _tabs[i].label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _activeTab == i
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),
          _icon(Icons.power_settings_new, widget.onLogout),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SUB TABS PANEL
/// ---------------------------------------------------------------------------

class _SubTabsPanel extends StatelessWidget {
  final double width;
  final List<_SubTab> items;
  final ValueChanged<String> onSelect;

  const _SubTabsPanel({
    required this.width,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: const Color(0xFF1F2933)),
        ),
        child: Column(
          children: items.map((item) {
            return InkWell(
              onTap: () => onSelect(item.route),
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// MODELS
/// ---------------------------------------------------------------------------

class _MainTab {
  final String label;
  final List<_SubTab> subs;
  const _MainTab(this.label, this.subs);
}

class _SubTab {
  final String label;
  final String route;
  const _SubTab(this.label, this.route);
}
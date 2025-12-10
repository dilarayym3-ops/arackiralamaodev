import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import '../../../models/session.dart';
import '../../../models/ui_router.dart';
import '../../../data/repositories/notifications_repository.dart';
import 'vehicles_page.dart';
import 'reservations_page.dart';
import 'fines_page.dart';
import 'insurances_page.dart';
import 'rentals_page.dart';
import 'campaigns_page.dart';
import 'employees_page.dart';
import 'branches_page.dart';
import 'notifications_page.dart';
import 'maintenance_page.dart';
import 'payments_page.dart';
import 'accidents_page.dart';
import 'history_page.dart';
import 'logs_page.dart';
import 'login_page.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});
  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final router = UiRouter();
  final _notifRepo = NotificationsRepository();

  int _index = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    router.index. addListener(_onRouterChange);
    router.unread.addListener(_onUnreadChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
      _refreshUnread();
    });
  }

  @override
  void dispose() {
    router.index.removeListener(_onRouterChange);
    router.unread.removeListener(_onUnreadChange);
    super.dispose();
  }

  void _checkSession() {
    if (Session().current == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder:  (_) => const LoginPage()),
      );
    }
  }

  void _onRouterChange() {
    final i = router.index.value;
    final maxIdx = _getItems().length - 1;
    setState(() => _index = i.clamp(0, maxIdx));
  }

  void _onUnreadChange() {
    setState(() => _unread = router. unread.value);
  }

  Future<void> _refreshUnread() async {
    try {
      final subeId = Session().current?.subeId;
      if (subeId == null) return;
      final rows = await _notifRepo.listByBranch(subeId, onlyUnread: true);
      router.setUnread(rows. length);
    } catch (_) {}
  }

  Future<void> _logout() async {
    Session().logout();
    if (!mounted) return;
    Navigator. of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _exitApp() async {
    try {
      await windowManager.close();
    } catch (_) {
      exit(0);
    }
  }

  List<_NavItem> _getItems() {
    return [
      _NavItem('Ana Sayfa', Icons.dashboard, _buildHomeCards()),
      _NavItem('Araclar', Icons.directions_car, const VehiclesPage()),
      _NavItem('Rezervasyonlar', Icons.event_available, const ReservationsPage()),
      _NavItem('Cezalar', Icons.report, const FinesPage()),
      _NavItem('Sigortalar', Icons.local_police, const InsurancesPage()),
      _NavItem('Kiralama', Icons.key, const RentalsPage()),
      _NavItem('Kampanyalar', Icons.local_offer, const CampaignsPage()),
      _NavItem('Calisanlar', Icons.badge, const EmployeesPage()),
      _NavItem('Subeler', Icons.home_work, const BranchesPage()),
      _NavItem('Bildirimler', Icons.notifications, const NotificationsPage()),
      _NavItem('Bakim', Icons.build, const MaintenancePage()),
      _NavItem('Odemeler', Icons.payments, const PaymentsPage()),
      _NavItem('Kaza', Icons.warning, const AccidentsPage()),
      _NavItem('Gecmis', Icons.history, const HistoryPage()),
      _NavItem('Loglar', Icons.list_alt, const LogsPage()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = Session().current;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = _getItems();
    final safeIndex = _index.clamp(0, items.length - 1);
    final current = items[safeIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Arac Kiralama - ${current. title} - Sube: ${user.subeAdi}'),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: 'Bildirimler',
                onPressed: () {
                  final idx = items.indexWhere((e) => e.title == 'Bildirimler');
                  if (idx >= 0) setState(() => _index = idx);
                  _refreshUnread();
                },
                icon: const Icon(Icons. notifications),
              ),
              if (_unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_unread', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
          IconButton(tooltip: 'Cikis Yap', onPressed: _logout, icon: const Icon(Icons. logout)),
          IconButton(tooltip: 'Uygulamayi Kapat', onPressed: _exitApp, icon: const Icon(Icons.close)),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.indigo,
                    child: const Text('Menu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child:  ListView. builder(
                      itemCount:  items.length,
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final selected = i == safeIndex;
                        return ListTile(
                          leading: Icon(it.icon, color: selected ? Colors.indigo : Colors. grey),
                          title: Text(it.title, style: TextStyle(color: selected ? Colors.indigo : Colors. black87)),
                          selected: selected,
                          selectedTileColor: Colors.indigo. withOpacity(0.1),
                          onTap: () => setState(() => _index = i),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: current.builder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeCards() {
    final user = Session().current;
    final subeAdi = user?.subeAdi ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children:  [
              const Icon(Icons. dashboard, color: Colors.indigo, size: 32),
              const SizedBox(width: 12),
              Text('Kontrol Paneli', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              Chip(
                avatar: const Icon(Icons.home_work, size: 18, color: Colors.white),
                label: Text(subeAdi, style: const TextStyle(color:  Colors.white)),
                backgroundColor: Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _tile(Icons.directions_car, 'Araclar', 'Arac yonetimi', 1),
              _tile(Icons. event_available, 'Rezervasyonlar', 'Rezervasyon islemleri', 2),
              _tile(Icons.report, 'Cezalar', 'Ceza takibi', 3),
              _tile(Icons.local_police, 'Sigortalar', 'Sigorta yonetimi', 4),
              _tile(Icons.key, 'Kiralama', 'Kiralama islemleri', 5),
              _tile(Icons.campaign, 'Kampanyalar', 'Kampanya yonetimi', 6),
              _tile(Icons.badge, 'Calisanlar', 'Calisan yonetimi', 7),
              _tile(Icons. home_work, 'Subeler', 'Sube yonetimi', 8),
              _tile(Icons. notifications, 'Bildirimler', 'Bildirim merkezi', 9),
              _tile(Icons.build, 'Bakim', 'Bakim kayitlari', 10),
              _tile(Icons.payments, 'Odemeler', 'Odeme takibi', 11),
              _tile(Icons.warning, 'Kaza', 'Kaza kayitlari', 12),
              _tile(Icons.history, 'Gecmis', 'Kiralama gecmisi', 13),
              _tile(Icons.list_alt, 'Loglar', 'Sistem loglari', 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, int index) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => setState(() => _index = index),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 280,
          child:  Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo. withOpacity(0.1),
                  child: Icon(icon, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:  CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(subtitle, style:  const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final Widget builder;
  _NavItem(this.title, this.icon, this.builder);
}
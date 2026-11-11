import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'calendar_screen.dart';
import 'diagnose_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// Tabs of [MainShell], for [HomeScreen.onOpenTab].
class Tabs {
  static const home = 0;
  static const scans = 1;
  static const calendar = 2;
  static const account = 3;
}

/// The signed-in app: bottom navigation between Home, Scans, Calendar and
/// Account, with the Scan button in the middle. Scanning opens full screen
/// on top, without the tab bar.
class MainShell extends StatefulWidget {
  final String lang;
  final ValueChanged<String> onLang;
  const MainShell({super.key, required this.lang, required this.onLang});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = Tabs.home;
  int _visit = 0; // bumped to rebuild the tab with fresh data

  void _open(int tab) => setState(() {
        _tab = tab;
        _visit++;
      });

  Future<void> _scan() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => DiagnoseScreen(lang: widget.lang)));
    if (mounted) setState(() => _visit++);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n(widget.lang);
    final lang = widget.lang;
    // Each tab is rebuilt when selected, so it shows fresh data (e.g. a scan
    // just made appears under Scans).
    final pages = <Widget>[
      HomeScreen(lang: lang, onLang: widget.onLang, onOpenTab: _open),
      HistoryScreen(lang: lang),
      CalendarScreen(lang: lang),
      if (Backend.enabled)
        AccountScreen(lang: lang, onLang: widget.onLang),
    ];
    final tab = _tab.clamp(0, pages.length - 1);
    // Navigation slots: Home, Scans, [Scan], Calendar, Account.
    final selected = tab < 2 ? tab : tab + 1;
    return Scaffold(
      body: KeyedSubtree(
          key: ValueKey('$tab-$lang-$_visit'), child: pages[tab]),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) {
            if (i == 2) {
              _scan();
            } else {
              _open(i < 2 ? i : i - 1);
            }
          },
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: t.get('tabHome')),
            NavigationDestination(
                icon: const Icon(Icons.history),
                label: t.get('tabScans')),
            NavigationDestination(
                icon: const _ScanIcon(), label: t.get('tabScan')),
            NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: t.get('tabCalendar')),
            if (Backend.enabled)
              NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: t.get('tabAccount')),
          ],
        ),
      ),
    );
  }
}

/// The middle Scan button: a green circle with a camera.
class _ScanIcon extends StatelessWidget {
  const _ScanIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Icon(Icons.photo_camera_outlined,
            size: 21, color: AppColors.onPrimary),
      );
}

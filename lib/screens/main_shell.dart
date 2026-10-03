import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import 'account_screen.dart';
import 'calendar_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// The signed-in app: bottom navigation between Home, Calendar, Scans and
/// Account. Scanning opens full screen on top, without the tab bar.
class MainShell extends StatefulWidget {
  final String lang;
  final ValueChanged<String> onLang;
  const MainShell({super.key, required this.lang, required this.onLang});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  void _open(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final t = L10n(widget.lang);
    final lang = widget.lang;
    // Each tab is rebuilt when selected, so it shows fresh data (e.g. a scan
    // just made from Home appears under Scans).
    final pages = <Widget>[
      HomeScreen(lang: lang, onLang: widget.onLang, onOpenTab: _open),
      CalendarScreen(lang: lang),
      HistoryScreen(lang: lang),
      if (Backend.enabled) AccountScreen(lang: lang),
    ];
    final tab = _tab.clamp(0, pages.length - 1);
    return Scaffold(
      body: KeyedSubtree(key: ValueKey('$tab-$lang'), child: pages[tab]),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: _open,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: t.get('tabHome')),
            NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: t.get('tabCalendar')),
            NavigationDestination(
                icon: const Icon(Icons.history),
                selectedIcon: const Icon(Icons.history),
                label: t.get('tabScans')),
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

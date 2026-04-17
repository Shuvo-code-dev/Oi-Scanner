import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import './scanner_screen.dart';
import './generator_screen.dart';
import './history_screen.dart';
import './settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/language_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final List<Widget> _screens = [
    const ScannerScreen(),
    const GeneratorScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final langProvider = context.watch<LanguageProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          langProvider.getText('app_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        centerTitle: true,
      ),
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return SharedAxisTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey(navProvider.currentIndex),
          child: _screens[navProvider.currentIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navProvider.currentIndex,
        onTap: (index) {
          navProvider.setIndex(index);
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.qr_code_scanner), label: langProvider.getText('tab_scan')),
          BottomNavigationBarItem(icon: const Icon(Icons.add_box_outlined), label: langProvider.getText('tab_generate')),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: langProvider.getText('tab_history')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), label: langProvider.getText('tab_settings')),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './theme/app_theme.dart';
import './providers/history_provider.dart';
import './providers/navigation_provider.dart';
import './providers/language_provider.dart';
import './screens/splash_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: const OiScannerApp(),
    ),
  );
}

class OiScannerApp extends StatelessWidget {
  const OiScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oi QR Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

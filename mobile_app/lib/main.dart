import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:plant_disease_mobile/l10n/app_localizations.dart';
import 'package:plant_disease_mobile/theme/app_theme.dart';
import 'package:plant_disease_mobile/ui/screens/history_screen.dart';
import 'package:plant_disease_mobile/ui/screens/home_screen.dart';
import 'package:plant_disease_mobile/ui/screens/splash_screen.dart';
import 'package:plant_disease_mobile/settings_controller.dart';
import 'package:plant_disease_mobile/ui/screens/settings_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final settingsController = SettingsController(prefs);

  runApp(PlantDiseaseApp(settingsController: settingsController));
}

class PlantDiseaseApp extends StatelessWidget {
  const PlantDiseaseApp({super.key, required this.settingsController});

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        final isArabic = settingsController.locale.languageCode == 'ar';
        
        return MaterialApp(
          title: 'Plant Disease Detector',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(isArabic: isArabic),
          darkTheme: AppTheme.dark(isArabic: isArabic),
          themeMode: settingsController.themeMode,
          locale: settingsController.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const HistoryScreen(),
      SettingsScreen(
        controller: context.findAncestorWidgetOfExactType<PlantDiseaseApp>()!.settingsController,
      ),
    ];

    return Scaffold(
      extendBody: true, // Allows body to extend behind the navbar
      body: pages[_index],
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: NavigationBar(
            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
            indicatorColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.9),
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.document_scanner_outlined),
                selectedIcon: const Icon(Icons.document_scanner),
                label: AppLocalizations.of(context)!.scan,
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history),
                label: AppLocalizations.of(context)!.history,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: AppLocalizations.of(context)!.settings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


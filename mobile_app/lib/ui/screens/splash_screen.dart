import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plant_disease_mobile/data/scan_history.dart';
import 'package:plant_disease_mobile/l10n/app_localizations.dart';
import 'package:plant_disease_mobile/main.dart';
import 'package:plant_disease_mobile/ui/screens/auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.eco,
                    size: 120,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 32),
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    textAlign: TextAlign.center,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: AnimatedTextKit(
                        animatedTexts: [
                          FadeAnimatedText(AppLocalizations.of(context)!.welcomeMessage, duration: const Duration(milliseconds: 1500), textAlign: TextAlign.center),
                          FadeAnimatedText(AppLocalizations.of(context)!.appTitle, duration: const Duration(milliseconds: 1500), textAlign: TextAlign.center),
                          TyperAnimatedText(AppLocalizations.of(context)!.intelligentDiagnosisSystem, speed: const Duration(milliseconds: 100), textAlign: TextAlign.center),
                        ],
                        totalRepeatCount: 1,
                        onFinished: () async {
                          final currentUser = FirebaseAuth.instance.currentUser;

                          if (currentUser != null) {
                            // Load this user's saved scan history before showing the app
                            await ScanHistoryStore.instance
                                .loadForUser(currentUser.uid);
                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const AppShell()),
                            );
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context)!.createdBy,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yousef Ellawah • Omar Walid\n• Mohamed Emad •Nour Mohamed \nMenna Mohamed • Ahmed Abdul-Wahab',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.supervisedBy,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

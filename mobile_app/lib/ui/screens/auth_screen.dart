import 'package:flutter/material.dart';
import 'package:plant_disease_mobile/data/scan_history.dart';
import 'package:plant_disease_mobile/l10n/app_localizations.dart';
import 'package:plant_disease_mobile/main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  bool isLogin = true;

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _getErrorMessage(BuildContext context, FirebaseAuthException e) {
    final l10n = AppLocalizations.of(context)!;
    switch (e.code) {
      case 'invalid-email':
        return l10n.errorInvalidEmail;
      case 'user-not-found':
        return l10n.errorUserNotFound;
      case 'wrong-password':
      case 'invalid-credential':
        return l10n.errorWrongPassword;
      case 'email-already-in-use':
        return l10n.errorEmailAlreadyInUse;
      case 'weak-password':
        return l10n.errorWeakPassword;
      default:
        return l10n.errorDefault;
    }
  }

  Future login() async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Load this account's saved scan history
      await ScanHistoryStore.instance.loadForUser(cred.user?.uid);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, _getErrorMessage(context, e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, AppLocalizations.of(context)!.errorDefault);
    }
  }

  Future signup() async {
    try {
      if (nameController.text.trim().isEmpty) {
        _showErrorSnackBar(context, 'Please enter your name');
        return;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      
      await cred.user?.updateDisplayName(nameController.text.trim());

      // Start a fresh history scope for the new account
      await ScanHistoryStore.instance.loadForUser(cred.user?.uid);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, _getErrorMessage(context, e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, AppLocalizations.of(context)!.errorDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.login),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              const SizedBox(height: 60),

              Icon(
                Icons.account_circle,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 16),

              Text(
                AppLocalizations.of(context)!.pleaseLogin,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 48),

              if (!isLogin) ...[
                /// NAME FIELD
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.name,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              /// EMAIL FIELD
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              /// PASSWORD FIELD
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              /// MAIN BUTTON (LOGIN OR SIGNUP)
              ElevatedButton(
                onPressed: isLogin ? login : signup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isLogin 
                    ? AppLocalizations.of(context)!.login 
                    : AppLocalizations.of(context)!.signup,
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 16),

              /// TOGGLE BUTTON
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin 
                    ? AppLocalizations.of(context)!.dontHaveAccount
                    : AppLocalizations.of(context)!.alreadyHaveAccount,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              /// GUEST LOGIN
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AppShell()),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.guestLogin,
                  style: const TextStyle(
                      fontSize: 16,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
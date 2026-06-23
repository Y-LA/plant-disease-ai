import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_disease_mobile/data/scan_history.dart';
import 'package:plant_disease_mobile/l10n/app_localizations.dart';
import 'package:plant_disease_mobile/settings_controller.dart';
import 'package:plant_disease_mobile/ui/screens/auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user   = FirebaseAuth.instance.currentUser;
    final isAr   = Localizations.localeOf(context).languageCode == 'ar';

    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ──────────────────────────────────────────────
                Text(
                  isAr ? 'الإعدادات' : 'Settings',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  isAr ? 'تخصيص تجربتك في التطبيق' : 'Customize your app experience',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),

                const SizedBox(height: 20),

                // ── Profile Card / Guest Card ────────────────────────────
                if (user != null) ...[
                  _ProfileCard(user: user, scheme: scheme, isAr: isAr),
                  const SizedBox(height: 20),
                ] else ...[
                  _GuestCard(scheme: scheme, isAr: isAr),
                  const SizedBox(height: 20),
                ],

                // ── Appearance ───────────────────────────────────────────
                _SectionLabel(
                  icon: Icons.palette_outlined,
                  label: isAr ? 'المظهر' : 'Appearance',
                  scheme: scheme,
                ),
                const SizedBox(height: 10),
                _ThemeSelector(controller: controller, scheme: scheme, isAr: isAr),

                const SizedBox(height: 20),

                // ── Language ─────────────────────────────────────────────
                _SectionLabel(
                  icon: Icons.language_outlined,
                  label: isAr ? 'اللغة' : 'Language',
                  scheme: scheme,
                ),
                const SizedBox(height: 10),
                _LanguageSelector(controller: controller, scheme: scheme, isAr: isAr),

                const SizedBox(height: 28),

                // ── Logout / Sign In ─────────────────────────────────────
                if (user != null)
                  _LogoutButton(isAr: isAr, scheme: scheme, context: context)
                else
                  _SignInButton(isAr: isAr, scheme: scheme),

                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Profile Card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final User user;
  final ColorScheme scheme;
  final bool isAr;

  const _ProfileCard({
    required this.user,
    required this.scheme,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final name  = user.displayName?.isNotEmpty == true ? user.displayName! : (isAr ? 'مستخدم' : 'User');
    final email = user.email ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.25),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAr ? 'مسجّل الدخول' : 'Signed in',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guest Card ────────────────────────────────────────────────────────────────

class _GuestCard extends StatelessWidget {
  final ColorScheme scheme;
  final bool isAr;

  const _GuestCard({required this.scheme, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary.withOpacity(0.15),
            child: Icon(Icons.person_outline, color: scheme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'مستخدم ضيف' : 'Guest User',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  isAr
                      ? 'سجّل الدخول لحفظ نتائجك ومزامنتها'
                      : 'Sign in to save and sync your results',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme scheme;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

// ── Theme Selector ────────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final SettingsController controller;
  final ColorScheme scheme;
  final bool isAr;

  const _ThemeSelector({
    required this.controller,
    required this.scheme,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        mode: ThemeMode.system,
        icon: Icons.brightness_auto_outlined,
        label: isAr ? 'تلقائي' : 'System',
      ),
      (
        mode: ThemeMode.light,
        icon: Icons.light_mode_outlined,
        label: isAr ? 'فاتح' : 'Light',
      ),
      (
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_outlined,
        label: isAr ? 'داكن' : 'Dark',
      ),
    ];

    return Row(
      children: options.map((opt) {
        final selected = controller.themeMode == opt.mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => controller.updateThemeMode(opt.mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                left: opt.mode != ThemeMode.system ? 6 : 0,
                right: opt.mode != ThemeMode.dark ? 6 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.outlineVariant.withOpacity(0.4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    opt.icon,
                    size: 22,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Language Selector ─────────────────────────────────────────────────────────

class _LanguageSelector extends StatelessWidget {
  final SettingsController controller;
  final ColorScheme scheme;
  final bool isAr;

  const _LanguageSelector({
    required this.controller,
    required this.scheme,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (locale: const Locale('en'), badge: 'EN', label: 'English'),
      (locale: const Locale('ar'), badge: 'ع', label: 'العربية'),
    ];

    return Row(
      children: options.map((opt) {
        final selected = controller.locale?.languageCode == opt.locale.languageCode;
        final isFirst  = opt.locale.languageCode == 'en';
        return Expanded(
          child: GestureDetector(
            onTap: () => controller.updateLocale(opt.locale),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: isFirst ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.outlineVariant.withOpacity(0.4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.outline.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        opt.badge,
                        style: TextStyle(
                          color: selected ? Colors.white : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      opt.label,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, size: 16, color: scheme.primary),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final bool isAr;
  final ColorScheme scheme;
  final BuildContext context;

  const _LogoutButton({
    required this.isAr,
    required this.scheme,
    required this.context,
  });

  Future<void> _confirmLogout(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(isAr ? 'تسجيل الخروج' : 'Sign Out'),
        content: Text(
          isAr
              ? 'هتتسجل خروج من حسابك. عايز تكمل؟'
              : 'You will be signed out of your account. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: scheme.error),
            child: Text(isAr ? 'خروج' : 'Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      // Hide this user's scans from the in-memory list (the saved history on
      // disk is kept and restored when they sign back in).
      ScanHistoryStore.instance.detach();
      if (!ctx.mounted) return;
      Navigator.of(ctx).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: () => _confirmLogout(ctx),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: scheme.error, size: 20),
            const SizedBox(width: 10),
            Text(
              isAr ? 'تسجيل الخروج' : 'Sign Out',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sign In Button (Guest) ──────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final bool isAr;
  final ColorScheme scheme;

  const _SignInButton({required this.isAr, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login_rounded, color: scheme.onPrimary, size: 20),
            const SizedBox(width: 10),
            Text(
              isAr ? 'تسجيل الدخول / إنشاء حساب' : 'Sign In / Create Account',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

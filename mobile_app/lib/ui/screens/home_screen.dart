import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plant_disease_mobile/data/api_config.dart';
import 'package:plant_disease_mobile/data/prediction_api.dart';
import 'package:plant_disease_mobile/domain/prediction.dart';
import 'package:plant_disease_mobile/l10n/app_localizations.dart';
import 'package:plant_disease_mobile/ui/screens/preview_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user        = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    final scheme      = Theme.of(context).colorScheme;
    final isAr        = Localizations.localeOf(context).languageCode == 'ar';

    final greetingText = displayName.isNotEmpty
        ? (AppLocalizations.of(context)?.welcomeUser(displayName) ?? 'Welcome, $displayName')
        : (AppLocalizations.of(context)?.welcomeMessage ?? 'Welcome');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Top Bar ───────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.person,
                      size: 26, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    greetingText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Hero Section ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.appTitle ??
                              'AI Plant Disease Detector',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)?.homeDescription ??
                              'Take a photo of a leaf to detect disease instantly.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.yard_outlined,
                        color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Live ESP32 status ─────────────────────────────────────
            const _EspStatusCard(),

            const SizedBox(height: 24),

            // ── Scan Buttons ──────────────────────────────────────────
            Text(
              isAr ? 'افحص نبتتك' : 'Scan your plant',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ScanButton(
                    icon: Icons.photo_camera_outlined,
                    label: AppLocalizations.of(context)?.camera ?? 'Camera',
                    subtitle: isAr ? 'صوّر ورقة' : 'Take a photo',
                    color: scheme.primary,
                    onTap: () => _pickAndGo(context, source: ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScanButton(
                    icon: Icons.photo_library_outlined,
                    label: AppLocalizations.of(context)?.gallery ?? 'Gallery',
                    subtitle: isAr ? 'من الألبوم' : 'From gallery',
                    color: Colors.teal.shade600,
                    onTap: () => _pickAndGo(context, source: ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Tips ─────────────────────────────────────────────────
            _TipsCard(isAr: isAr, context: context),

            const SizedBox(height: 16),

            // ── Privacy ───────────────────────────────────────────────
            Center(
              child: Text(
                AppLocalizations.of(context)?.privacyNotice ??
                    'Images are used only for analysis.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndGo(BuildContext context,
      {required ImageSource source}) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    try {
      final picker = ImagePicker();
      final xfile  = await picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1600,
      );
      if (xfile == null) return; // user cancelled
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PreviewScreen(imageFile: xfile)),
      );
    } catch (e) {
      // e.g. camera/photos permission denied, or no camera available
      if (!context.mounted) return;
      final msg = source == ImageSource.camera
          ? (isAr
              ? 'تعذّر فتح الكاميرا. تأكد من السماح بإذن الكاميرا من إعدادات التطبيق.'
              : 'Could not open the camera. Please allow camera permission in settings.')
          : (isAr
              ? 'تعذّر فتح المعرض. تأكد من السماح بإذن الصور من إعدادات التطبيق.'
              : 'Could not open the gallery. Please allow photos permission in settings.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

// ── Live ESP32 Status Card ────────────────────────────────────────────────────

class _EspStatusCard extends StatefulWidget {
  const _EspStatusCard();

  @override
  State<_EspStatusCard> createState() => _EspStatusCardState();
}

class _EspStatusCardState extends State<_EspStatusCard> {
  final PredictionApi _api = PredictionApi(baseUrl: ApiConfig.backendUri);
  Timer? _timer;
  SensorData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _poll(); // immediate first read
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final data = await _api.fetchSensor();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr      = Localizations.localeOf(context).languageCode == 'ar';
    final scheme    = Theme.of(context).colorScheme;
    final connected = _data != null;
    final accent    = connected ? Colors.green.shade600 : scheme.outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: connected ? Colors.green.shade500 : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.sensors, size: 18, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _loading
                      ? (isAr ? 'جاري الاتصال بجهاز ESP32…' : 'Connecting to ESP32…')
                      : connected
                          ? (isAr ? 'ESP32 متصل' : 'ESP32 Connected')
                          : (isAr ? 'ESP32 غير متصل' : 'ESP32 Not Connected'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: connected ? Colors.green.shade700 : scheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _EspMetric(
                  icon: Icons.thermostat_outlined,
                  label: isAr ? 'الحرارة' : 'Temp',
                  value: '${_data!.temperature.toStringAsFixed(1)}°C',
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                _EspMetric(
                  icon: Icons.water_drop_outlined,
                  label: isAr ? 'الرطوبة' : 'Humidity',
                  value: '${_data!.humidity.toStringAsFixed(1)}%',
                  color: Colors.blue.shade500,
                ),
                const SizedBox(width: 8),
                _EspMetric(
                  icon: Icons.wb_sunny_outlined,
                  label: isAr ? 'الضوء' : 'Light',
                  value: _data!.lightLabel,
                  color: Colors.amber.shade700,
                ),
              ],
            ),
          ] else if (!_loading) ...[
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'تأكد أن الجهاز يعمل وعلى نفس الشبكة. يتحدث تلقائيًا.'
                  : 'Make sure the device is on and on the same network. Updates automatically.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _EspMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _EspMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ── Scan Button ───────────────────────────────────────────────────────────────

class _ScanButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ScanButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tips Card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  final bool isAr;
  final BuildContext context;

  const _TipsCard({required this.isAr, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final tips = [
      (
        icon: Icons.light_mode_outlined,
        color: Colors.amber.shade600,
        text: AppLocalizations.of(context)?.tip1 ??
            'Use good lighting — avoid harsh shadows.',
      ),
      (
        icon: Icons.center_focus_strong_outlined,
        color: Colors.blue.shade600,
        text: AppLocalizations.of(context)?.tip2 ??
            'Keep the leaf centered and in focus.',
      ),
      (
        icon: Icons.filter_1_outlined,
        color: Colors.green.shade600,
        text: AppLocalizations.of(context)?.tip3 ??
            'One leaf per photo for best accuracy.',
      ),
      (
        icon: Icons.crop_free_outlined,
        color: Colors.purple.shade400,
        text: AppLocalizations.of(context)?.tip4 ??
            'Plain background gives better results.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tips_and_updates_outlined,
                size: 18, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)?.tipsTitle ?? 'Tips for best results',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tip.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tip.icon, size: 18, color: tip.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip.text,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

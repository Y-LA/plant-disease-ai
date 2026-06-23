import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker/image_picker.dart';
import 'package:plant_disease_mobile/data/api_config.dart';
import 'package:plant_disease_mobile/data/prediction_api.dart';
import 'package:plant_disease_mobile/domain/prediction.dart';
import 'package:plant_disease_mobile/ui/screens/result_screen.dart';

class PreviewScreen extends StatefulWidget {
  final XFile imageFile;
  const PreviewScreen({super.key, required this.imageFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  final _api = PredictionApi(baseUrl: ApiConfig.backendUri);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAr   = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [

            // ── Top Bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: scheme.onSurface),
                  ),
                  Expanded(
                    child: Text(
                      isAr ? 'معاينة الصورة' : 'Preview',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 44), // balance
                ],
              ),
            ),

            // ── Image ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Image container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        color: scheme.surfaceContainerHighest.withOpacity(0.4),
                        child: kIsWeb
                            ? Image.network(
                                widget.imageFile.path,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(widget.imageFile.path),
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),

                    // Loading overlay
                    if (_loading)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ScaleTransition(
                                scale: _pulseAnim,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: scheme.primary.withOpacity(0.5),
                                        width: 2),
                                  ),
                                  child: Icon(Icons.auto_awesome_outlined,
                                      color: scheme.primary, size: 36),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isAr ? 'جاري التحليل...' : 'Analyzing...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isAr
                                    ? 'النموذج بيفحص الورقة'
                                    : 'AI model is scanning the leaf',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Corner scan lines (decoration)
                    if (!_loading)
                      Positioned.fill(
                        child: _ScanFrame(color: scheme.primary),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Hint ─────────────────────────────────────────────────────
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      isAr
                          ? 'تأكد إن الورقة واضحة وفي المنتصف'
                          : 'Make sure the leaf is clear and centered.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: scheme.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: scheme.onErrorContainer, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Buttons ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  // Retake
                  Expanded(
                    child: GestureDetector(
                      onTap: _loading ? null : () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withOpacity(0.6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: scheme.outlineVariant.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 20,
                                color: _loading
                                    ? scheme.onSurfaceVariant.withOpacity(0.4)
                                    : scheme.onSurface),
                            const SizedBox(width: 8),
                            Text(
                              isAr ? 'إعادة' : 'Retake',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: _loading
                                    ? scheme.onSurfaceVariant.withOpacity(0.4)
                                    : scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Analyze
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _loading ? null : _analyze,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: _loading
                              ? null
                              : LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.primary.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _loading
                              ? scheme.primary.withOpacity(0.4)
                              : null,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _loading
                              ? []
                              : [
                                  BoxShadow(
                                    color: scheme.primary.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _loading
                                  ? Icons.hourglass_top_rounded
                                  : Icons.auto_awesome_outlined,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _loading
                                  ? (isAr ? 'جاري التحليل...' : 'Analyzing...')
                                  : (isAr ? 'تحليل الصورة' : 'Analyze'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      final prediction = await _api.predictLeaf(widget.imageFile).timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw ApiException('Request timeout'),
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imageFile: widget.imageFile,
            prediction: prediction,
            usedDemo: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to contact AI server: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Scan Frame Decoration ─────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  final Color color;
  const _ScanFrame({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CornerPainter(color: color));
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color     = color.withOpacity(0.7)
      ..strokeWidth = 3
      ..style     = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    const r   = 20.0;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(r + len, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, r + len), paint);
    canvas.drawArc(Rect.fromLTWH(0, 0, r * 2, r * 2),
        3.14159, 3.14159 / 2, false, paint);

    // Top-right
    canvas.drawLine(Offset(size.width - r - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2),
        -3.14159 / 2, 3.14159 / 2, false, paint);

    // Bottom-left
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawLine(Offset(0, size.height - r), Offset(0, size.height - r - len), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2),
        3.14159 / 2, 3.14159 / 2, false, paint);

    // Bottom-right
    canvas.drawLine(
        Offset(size.width - r - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawLine(
        Offset(size.width, size.height - r), Offset(size.width, size.height - r - len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2),
        0, 3.14159 / 2, false, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

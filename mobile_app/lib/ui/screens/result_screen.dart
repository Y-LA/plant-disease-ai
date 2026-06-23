import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:plant_disease_mobile/data/scan_history.dart';
import 'package:plant_disease_mobile/domain/disease_info.dart';
import 'package:plant_disease_mobile/domain/prediction.dart';
import 'package:plant_disease_mobile/ui/widgets/metric_chip.dart';

class ResultScreen extends StatefulWidget {
  final XFile imageFile;
  final Prediction prediction;
  final bool usedDemo;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.prediction,
    required this.usedDemo,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final DateTime _createdAt;

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    // Save to history once, not on every rebuild
    ScanHistoryStore.instance.add(
      ScanHistoryItem(
        createdAt: _createdAt,
        imagePath: widget.imageFile.path,
        prediction: widget.prediction,
      ),
    );
  }

  Future<void> _shareResult() async {
    final info          = DiseaseCatalog.resolve(widget.prediction.label);
    final lang          = Localizations.localeOf(context).languageCode;
    final isAr          = lang == 'ar';
    final confidencePct = (widget.prediction.confidence * 100).clamp(0, 100);
    final dateStr       = DateFormat('yyyy-MM-dd HH:mm').format(_createdAt);

    // Non-plant image: share a short message only, no disease/treatment info.
    if (info.isNotPlant) {
      final msg = isAr
          ? '🌿 نتيجة الفحص: الصورة ليست نبتة.\n'
              'من فضلك صوّر ورقة نبات وأعد المحاولة.\n'
              'التاريخ: $dateStr\n— تطبيق كشف أمراض النباتات'
          : '🌿 Scan result: this image is not a plant.\n'
              'Please take a photo of a plant leaf and try again.\n'
              'Date: $dateStr\n— Plant Disease Detection App';
      try {
        if (!kIsWeb && File(widget.imageFile.path).existsSync()) {
          await Share.shareXFiles([XFile(widget.imageFile.path)], text: msg);
        } else {
          await Share.share(msg);
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تعذّرت المشاركة' : 'Could not share')),
        );
      }
      return;
    }

    final b = StringBuffer();
    if (isAr) {
      b.writeln('🌿 نتيجة فحص النبتة');
      b.writeln('المحصول: ${info.crop(lang)}');
      b.writeln('الحالة: ${info.disease(lang)}');
      b.writeln('نسبة الثقة: ${confidencePct.toStringAsFixed(1)}%');
      if (!info.isHealthy) {
        b.writeln('العلاج (كيميائي): ${info.chemicalTreatmentAr}');
        b.writeln('الوقاية: ${info.prevention(lang)}');
      }
      final env = widget.prediction.envAnalysis;
      if (env != null) b.writeln('التحليل البيئي: ${env.summary(lang)}');
      b.writeln('التاريخ: $dateStr');
      b.write('— تطبيق كشف أمراض النباتات');
    } else {
      b.writeln('🌿 Plant Scan Result');
      b.writeln('Crop: ${info.crop(lang)}');
      b.writeln('Status: ${info.disease(lang)}');
      b.writeln('Confidence: ${confidencePct.toStringAsFixed(1)}%');
      if (!info.isHealthy) {
        b.writeln('Treatment (chemical): ${info.chemicalTreatmentEn}');
        b.writeln('Prevention: ${info.prevention(lang)}');
      }
      final env = widget.prediction.envAnalysis;
      if (env != null) b.writeln('Environmental analysis: ${env.summary(lang)}');
      b.writeln('Date: $dateStr');
      b.write('— Plant Disease Detection App');
    }

    final text = b.toString();

    try {
      // Share the plant image together with the result text when available.
      if (!kIsWeb && File(widget.imageFile.path).existsSync()) {
        await Share.shareXFiles(
          [XFile(widget.imageFile.path)],
          text: text,
        );
      } else {
        await Share.share(text);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'تعذّرت المشاركة' : 'Could not share'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info          = DiseaseCatalog.resolve(widget.prediction.label);
    final lang          = Localizations.localeOf(context).languageCode;
    final confidencePct = (widget.prediction.confidence * 100).clamp(0, 100);
    final isAr          = lang == 'ar';
    final scheme        = Theme.of(context).colorScheme;

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
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: scheme.onSurface),
                  ),
                  Expanded(
                    child: Text(
                      isAr ? 'نتيجة الفحص' : 'Scan Result',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: _shareResult,
                    icon: Icon(Icons.ios_share_outlined,
                        size: 20, color: scheme.onSurface),
                  ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                children: [

                  // Header card
                  _HeaderCard(
                    imageFile: widget.imageFile,
                    label: info.disease(lang),
                    cropLabel: info.crop(lang),
                    confidence: confidencePct.toDouble(),
                    usedDemo: widget.usedDemo,
                    severity: info.severity,
                    isHealthy: info.isHealthy,
                    isNotPlant: info.isNotPlant,
                    isAr: isAr,
                  ),

                  const SizedBox(height: 12),

                  if (info.isNotPlant) ...[
                    _NotPlantCard(isAr: isAr),
                  ] else ...[

                  // Metric chips
                  Row(
                    children: [
                      MetricChip(
                        label: isAr ? 'الثقة' : 'Confidence',
                        value: '${confidencePct.toStringAsFixed(1)}%',
                        icon: Icons.percent,
                      ),
                      const SizedBox(width: 8),
                      MetricChip(
                        label: isAr ? 'الوقت' : 'Time',
                        value: DateFormat('HH:mm').format(_createdAt),
                        icon: Icons.schedule,
                      ),
                      const SizedBox(width: 8),
                      MetricChip(
                        label: isAr ? 'الموسم' : 'Season',
                        value: info.season(lang),
                        icon: Icons.calendar_month_outlined,
                      ),
                    ],
                  ),

                  // Sensor + Env Analysis
                  if (widget.prediction.sensorData != null ||
                      widget.prediction.envAnalysis != null) ...[
                    const SizedBox(height: 12),
                    _EnvAnalysisCard(
                      sensorData: widget.prediction.sensorData,
                      envAnalysis: widget.prediction.envAnalysis,
                      lang: lang,
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    _SensorDisconnectedBanner(isAr: isAr),
                  ],

                  // Disease / Healthy info
                  const SizedBox(height: 12),
                  if (!info.isHealthy) ...[
                    _InfoCard(
                      icon: Icons.biotech_outlined,
                      title: isAr ? 'المسبب المرضي' : 'Pathogen',
                      content: info.pathogen(lang),
                      accentColor: Colors.purple,
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      icon: Icons.sick_outlined,
                      title: isAr ? 'الأعراض' : 'Symptoms',
                      content: info.symptoms(lang),
                      accentColor: Colors.orange,
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      icon: Icons.wb_cloudy_outlined,
                      title: isAr ? 'الأسباب والعوامل البيئية' : 'Causes & Environmental Factors',
                      content: info.causes(lang),
                      accentColor: Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    _TreatmentCard(
                      chemicalEn: info.chemicalTreatmentEn,
                      chemicalAr: info.chemicalTreatmentAr,
                      organicEn: info.organicTreatmentEn,
                      organicAr: info.organicTreatmentAr,
                      lang: lang,
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      icon: Icons.shield_outlined,
                      title: isAr ? 'الوقاية' : 'Prevention',
                      content: info.prevention(lang),
                      accentColor: Colors.green,
                    ),
                  ] else ...[
                    _InfoCard(
                      icon: Icons.check_circle_outline,
                      title: isAr ? 'الحالة' : 'Status',
                      content: info.symptoms(lang),
                      accentColor: Colors.green,
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      icon: Icons.shield_outlined,
                      title: isAr ? 'نصائح الوقاية' : 'Prevention Tips',
                      content: info.prevention(lang),
                      accentColor: Colors.teal,
                    ),
                  ],
                  ],

                  const SizedBox(height: 16),

                  // Footer note
                  Center(
                    child: Text(
                      widget.usedDemo
                          ? (isAr
                              ? 'الخادم غير متاح: عرض تجريبي.'
                              : 'Backend not reachable: showing a demo prediction.')
                          : (isAr
                              ? 'تم التشخيص بواسطة نموذج الذكاء الاصطناعي.'
                              : 'Prediction generated by AI model.'),
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

            // ── Bottom Button ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary,
                        scheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.document_scanner_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'فحص جديد' : 'New Scan',
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
    );
  }
}

// ── Header Card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final XFile imageFile;
  final String label;
  final String cropLabel;
  final double confidence;
  final bool usedDemo;
  final String severity;
  final bool isHealthy;
  final bool isNotPlant;
  final bool isAr;

  const _HeaderCard({
    required this.imageFile,
    required this.label,
    required this.cropLabel,
    required this.confidence,
    required this.usedDemo,
    required this.severity,
    required this.isHealthy,
    required this.isNotPlant,
    required this.isAr,
  });

  Color get _sevColor {
    if (isNotPlant) return Colors.blueGrey.shade500;
    if (isHealthy) return Colors.green.shade600;
    switch (severity) {
      case 'High':   return Colors.red.shade600;
      case 'Medium': return Colors.orange.shade600;
      case 'Low':    return Colors.yellow.shade700;
      default:       return Colors.grey;
    }
  }

  String get _sevLabel {
    if (isNotPlant) return isAr ? 'غير نبتة' : 'Not a plant';
    if (isHealthy) return isAr ? 'سليمة' : 'Healthy';
    if (isAr) {
      switch (severity) {
        case 'High':   return 'شديد';
        case 'Medium': return 'متوسط';
        case 'Low':    return 'خفيف';
        default:       return severity;
      }
    }
    return severity;
  }

  @override
  Widget build(BuildContext context) {
    final scheme     = Theme.of(context).colorScheme;
    final sevColor   = _sevColor;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Hero(
                tag: 'result_image',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: kIsWeb
                      ? Image.network(imageFile.path,
                          width: 90, height: 90, fit: BoxFit.cover)
                      : Image.file(File(imageFile.path),
                          width: 90, height: 90, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (usedDemo)
                          _Badge(
                            label: 'DEMO',
                            color: scheme.tertiary,
                            textColor: scheme.onTertiary,
                          ),
                        _Badge(
                          label: _sevLabel,
                          color: sevColor.withOpacity(0.15),
                          textColor: sevColor,
                          icon: isNotPlant
                              ? Icons.image_not_supported_outlined
                              : isHealthy
                                  ? Icons.check_circle
                                  : Icons.warning_amber_rounded,
                          borderColor: sevColor.withOpacity(0.35),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cropLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Confidence bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (confidence / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withOpacity(0.6),
                    valueColor: AlwaysStoppedAnimation<Color>(sevColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sevColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isAr ? 'نسبة ثقة النموذج' : 'Model confidence',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final Color? borderColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Not-a-Plant Card ──────────────────────────────────────────────────────────

class _NotPlantCard extends StatelessWidget {
  final bool isAr;

  const _NotPlantCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Colors.blueGrey.shade500;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.image_not_supported_outlined,
                size: 30, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            isAr ? 'الصورة ليست نبتة' : 'This image is not a plant',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'لم نتمكن من التعرف على ورقة نبات في هذه الصورة. من فضلك التقط صورة واضحة لورقة نبات وأعد المحاولة.'
                : 'We could not detect a plant leaf in this image. Please take a clear photo of a plant leaf and try again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color accentColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Treatment Card ────────────────────────────────────────────────────────────

class _TreatmentCard extends StatefulWidget {
  final String chemicalEn;
  final String chemicalAr;
  final String organicEn;
  final String organicAr;
  final String lang;

  const _TreatmentCard({
    required this.chemicalEn,
    required this.chemicalAr,
    required this.organicEn,
    required this.organicAr,
    required this.lang,
  });

  @override
  State<_TreatmentCard> createState() => _TreatmentCardState();
}

class _TreatmentCardState extends State<_TreatmentCard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr   = widget.lang == 'ar';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.medical_services_outlined,
                    size: 17, color: Colors.red.shade600),
              ),
              const SizedBox(width: 10),
              Text(
                isAr ? 'العلاج' : 'Treatment',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: [
              Tab(text: isAr ? 'كيميائي' : 'Chemical'),
              Tab(text: isAr ? 'عضوي' : 'Organic'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: TabBarView(
              controller: _tabs,
              children: [
                SingleChildScrollView(
                  child: Text(
                    isAr ? widget.chemicalAr : widget.chemicalEn,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                SingleChildScrollView(
                  child: Text(
                    isAr ? widget.organicAr : widget.organicEn,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Environmental Analysis Card ───────────────────────────────────────────────

class _EnvAnalysisCard extends StatelessWidget {
  final SensorData? sensorData;
  final EnvAnalysis? envAnalysis;
  final String lang;

  const _EnvAnalysisCard({
    required this.sensorData,
    required this.envAnalysis,
    required this.lang,
  });

  bool get isAr => lang == 'ar';

  Color _riskColor(String risk) {
    switch (risk) {
      case 'high':   return Colors.red.shade600;
      case 'medium': return Colors.orange.shade600;
      case 'low':    return Colors.green.shade600;
      default:       return Colors.grey.shade500;
    }
  }

  String _riskLabel(String risk) {
    if (isAr) {
      switch (risk) {
        case 'high':   return 'خطر عالي';
        case 'medium': return 'خطر متوسط';
        case 'low':    return 'خطر منخفض';
        case 'none':   return 'لا خطر';
        default:       return 'غير معروف';
      }
    }
    switch (risk) {
      case 'high':   return 'High Risk';
      case 'medium': return 'Medium Risk';
      case 'low':    return 'Low Risk';
      case 'none':   return 'No Risk';
      default:       return 'Unknown';
    }
  }

  ({Color color, String label, IconData icon}) _statusMeta(String status) {
    switch (status) {
      case 'favorable':
      case 'unfavorable':
        return (
          color: Colors.orange.shade600,
          label: isAr ? 'يساعد المرض' : 'Aids disease',
          icon: Icons.warning_amber_rounded,
        );
      case 'low':
        return (
          color: Colors.blue.shade500,
          label: isAr ? 'منخفض' : 'Low',
          icon: Icons.arrow_downward_rounded,
        );
      case 'high':
        return (
          color: Colors.red.shade400,
          label: isAr ? 'مرتفع' : 'High',
          icon: Icons.arrow_upward_rounded,
        );
      case 'normal':
        return (
          color: Colors.green.shade600,
          label: isAr ? 'طبيعي' : 'Normal',
          icon: Icons.check_rounded,
        );
      default:
        return (
          color: Colors.grey.shade400,
          label: isAr ? 'غير متاح' : 'N/A',
          icon: Icons.remove,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // If no env analysis, just show sensor banner
    if (envAnalysis == null && sensorData != null) {
      return _SensorBanner(sensorData: sensorData!, isAr: isAr);
    }

    if (envAnalysis == null) return const SizedBox.shrink();

    final env       = envAnalysis!;
    final risk      = env.environmentalRisk;
    final riskColor = _riskColor(risk);
    final tips      = env.tips(lang);
    final summary   = env.summary(lang);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.sensors, size: 17, color: riskColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'التحليل البيئي' : 'Environmental Analysis',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: riskColor.withOpacity(0.35)),
                ),
                child: Text(
                  _riskLabel(risk),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sensor tiles
          if (sensorData != null) ...[
            Row(
              children: [
                Expanded(
                  child: _EnvTile(
                    icon: Icons.thermostat_outlined,
                    label: isAr ? 'الحرارة' : 'Temp',
                    value: '${sensorData!.temperature.toStringAsFixed(1)}°C',
                    meta: _statusMeta(env.temperatureStatus),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EnvTile(
                    icon: Icons.water_drop_outlined,
                    label: isAr ? 'الرطوبة' : 'Humidity',
                    value: '${sensorData!.humidity.toStringAsFixed(1)}%',
                    meta: _statusMeta(env.humidityStatus),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EnvTile(
                    icon: Icons.wb_sunny_outlined,
                    label: isAr ? 'الضوء' : 'Light',
                    value: sensorData!.lightLabel,
                    meta: _statusMeta(env.lightStatus),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Row(
              children: [
                Icon(Icons.sensors_off_outlined,
                    size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'لم تصل بيانات من ESP32 بعد' : 'No ESP32 data yet',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Summary box
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: env.isEnvContributing
                  ? Colors.orange.withOpacity(0.08)
                  : Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: env.isEnvContributing
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  env.isEnvContributing
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 16,
                  color: env.isEnvContributing
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: env.isEnvContributing
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tips
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: scheme.outlineVariant.withOpacity(0.4)),
            const SizedBox(height: 10),
            Text(
              isAr ? 'توصيات لتحسين البيئة' : 'How to improve',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: riskColor,
              ),
            ),
            const SizedBox(height: 8),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right_rounded,
                        size: 18, color: riskColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tip,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sensor Banner (when no env analysis) ─────────────────────────────────────

class _SensorBanner extends StatelessWidget {
  final SensorData sensorData;
  final bool isAr;

  const _SensorBanner({required this.sensorData, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'ESP32  •  '
            '${sensorData.temperature.toStringAsFixed(1)}°C  '
            '${sensorData.humidity.toStringAsFixed(1)}%  '
            '${sensorData.lightLabel}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sensor Disconnected Banner ───────────────────────────────────────────────

class _SensorDisconnectedBanner extends StatelessWidget {
  final bool isAr;

  const _SensorDisconnectedBanner({required this.isAr});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.sensors_off_outlined,
              size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAr
                  ? 'جهاز ESP32 غير متصل — لا توجد بيانات بيئية حيّة'
                  : 'ESP32 not connected — no live environmental data',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Env Tile ──────────────────────────────────────────────────────────────────

class _EnvTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ({Color color, String label, IconData icon}) meta;

  const _EnvTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: meta.color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: meta.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(meta.icon, size: 11, color: meta.color),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: meta.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:plant_disease_mobile/data/scan_history.dart';
import 'package:plant_disease_mobile/domain/disease_info.dart';
import 'package:plant_disease_mobile/l10n/app_localizations.dart';
import 'package:plant_disease_mobile/ui/screens/history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final items  = ScanHistoryStore.instance.items;
    final scheme = Theme.of(context).colorScheme;
    final isAr   = Localizations.localeOf(context).languageCode == 'ar';
    final lang   = isAr ? 'ar' : 'en';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'السجل' : 'History',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        isAr
                            ? 'الفحوصات السابقة على هذا الجهاز'
                            : 'Your recent scans on this device',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmClear(context, isAr),
                    icon: Icon(Icons.delete_outline,
                        color: scheme.onSurfaceVariant),
                    tooltip: isAr ? 'مسح الكل' : 'Clear all',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── List / Empty ──────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(
                      isAr: isAr,
                      onGoScan: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final info =
                            DiseaseCatalog.resolve(item.prediction.label);
                        final pct = (item.prediction.confidence * 100)
                            .clamp(0, 100);
                        final sevColor = _severityColor(info.severity, info.isHealthy);

                        return _HistoryCard(
                          item: item,
                          info: info,
                          lang: lang,
                          pct: pct.toDouble(),
                          sevColor: sevColor,
                          isAr: isAr,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HistoryDetailScreen(item: item),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String severity, bool isHealthy) {
    if (isHealthy) return Colors.green.shade600;
    switch (severity) {
      case 'High':   return Colors.red.shade600;
      case 'Medium': return Colors.orange.shade600;
      case 'Low':    return Colors.yellow.shade700;
      default:       return Colors.grey;
    }
  }

  Future<void> _confirmClear(BuildContext context, bool isAr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAr ? 'مسح السجل' : 'Clear History'),
        content: Text(
          isAr ? 'هتُمسح كل الفحوصات. متنداش.' : 'All scans will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600),
            child: Text(isAr ? 'مسح' : 'Clear'),
          ),
        ],
      ),
    );
    if (confirm == true) setState(() => ScanHistoryStore.instance.clear());
  }
}

// ── History Card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final ScanHistoryItem item;
  final DiseaseInfo info;
  final String lang;
  final double pct;
  final Color sevColor;
  final bool isAr;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.item,
    required this.info,
    required this.lang,
    required this.pct,
    required this.sevColor,
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: scheme.outlineVariant.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Severity accent bar
            Container(
              width: 5,
              height: 80,
              decoration: BoxDecoration(
                color: sevColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),

            // Image
            Padding(
              padding: const EdgeInsets.all(12),
              child: Hero(
                tag: 'history_image_${item.createdAt.millisecondsSinceEpoch}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(item.imagePath),
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.image_not_supported,
                          color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.crop(lang),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.disease(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Severity badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: sevColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            info.isHealthy
                                ? (isAr ? 'سليمة' : 'Healthy')
                                : (isAr
                                    ? _severityAr(info.severity)
                                    : info.severity),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: sevColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM • HH:mm')
                              .format(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _severityAr(String severity) {
    switch (severity) {
      case 'High':   return 'شديد';
      case 'Medium': return 'متوسط';
      case 'Low':    return 'خفيف';
      default:       return severity;
    }
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isAr;
  final VoidCallback onGoScan;

  const _EmptyState({required this.isAr, required this.onGoScan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off,
                size: 48, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'لا يوجد فحوصات بعد' : 'No scans yet',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'افحص ورقة نبتة لتظهر النتائج هنا'
                : 'Scan a leaf to see your results here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onGoScan,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(isAr ? 'ابدأ الفحص' : 'Start Scanning'),
          ),
        ],
      ),
    );
  }
}

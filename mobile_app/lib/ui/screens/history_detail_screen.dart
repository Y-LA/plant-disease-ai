import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:plant_disease_mobile/data/scan_history.dart';
import 'package:plant_disease_mobile/domain/disease_info.dart';

class HistoryDetailScreen extends StatelessWidget {
  final ScanHistoryItem item;

  const HistoryDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final info = DiseaseCatalog.resolve(item.prediction.label);
    final lang = Localizations.localeOf(context).languageCode;
    final pct = (item.prediction.confidence * 100).clamp(0, 100);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'history_image_${item.createdAt.millisecondsSinceEpoch}',
              child: Image.file(
                File(item.imagePath),
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 300,
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported, size: 64),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          info.disease(lang),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  if (info.isNotPlant) ...[
                    Text(
                      lang == 'ar'
                          ? 'الصورة ليست نبتة. لا توجد معلومات أو علاج لعرضها. من فضلك صوّر ورقة نبات وأعد المحاولة.'
                          : 'This image is not a plant. No information or treatment to show. Please photograph a plant leaf and try again.',
                      style: TextStyle(height: 1.5, color: scheme.onSurfaceVariant),
                    ),
                  ] else ...[
                    Text(
                      lang == 'ar' ? 'الأعراض' : 'Symptoms',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.symptoms(lang),
                      style: TextStyle(height: 1.5, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      lang == 'ar' ? 'العلاج الكيميائي' : 'Chemical Treatment',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.chemicalTreatment(lang),
                      style: TextStyle(height: 1.5, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      lang == 'ar' ? 'العلاج العضوي' : 'Organic Treatment',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.organicTreatment(lang),
                      style: TextStyle(height: 1.5, color: scheme.onSurface),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

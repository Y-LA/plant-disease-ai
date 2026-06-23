class SensorData {
  final double temperature; // °C
  final double humidity;    // %
  final int light;          // ADC raw 0-4095
  final String? timestamp;

  const SensorData({
    required this.temperature,
    required this.humidity,
    required this.light,
    this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
        temperature: (json['temperature'] as num).toDouble(),
        humidity:    (json['humidity'] as num).toDouble(),
        light:       (json['light'] as num).toInt(),
        timestamp:   json['timestamp'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'humidity': humidity,
        'light': light,
        'timestamp': timestamp,
      };

  /// Human-readable light level label
  String get lightLabel {
    if (light < 800)  return 'Low';
    if (light > 2800) return 'High';
    return 'Normal';
  }
}

class EnvAnalysis {
  final bool envDriven;
  final bool isEnvContributing;
  final String environmentalRisk; // "high" | "medium" | "low" | "none"
  final String temperatureStatus; // "favorable" | "low" | "high" | "unknown"
  final String humidityStatus;
  final String lightStatus;       // "favorable" | "unfavorable" | "low" | "normal" | "high" | "unknown"
  final bool canImproveByEnv;
  final String summaryEn;
  final String summaryAr;
  final List<String> improvementTipsEn;
  final List<String> improvementTipsAr;

  const EnvAnalysis({
    required this.envDriven,
    required this.isEnvContributing,
    required this.environmentalRisk,
    required this.temperatureStatus,
    required this.humidityStatus,
    required this.lightStatus,
    required this.canImproveByEnv,
    required this.summaryEn,
    required this.summaryAr,
    required this.improvementTipsEn,
    required this.improvementTipsAr,
  });

  factory EnvAnalysis.fromJson(Map<String, dynamic> json) => EnvAnalysis(
        envDriven:          json['env_driven'] as bool? ?? false,
        isEnvContributing:  json['is_env_contributing'] as bool? ?? false,
        environmentalRisk:  json['environmental_risk'] as String? ?? 'unknown',
        temperatureStatus:  json['temperature_status'] as String? ?? 'unknown',
        humidityStatus:     json['humidity_status'] as String? ?? 'unknown',
        lightStatus:        json['light_status'] as String? ?? 'unknown',
        canImproveByEnv:    json['can_improve_by_env'] as bool? ?? false,
        summaryEn:          json['summary_en'] as String? ?? '',
        summaryAr:          json['summary_ar'] as String? ?? '',
        improvementTipsEn:  List<String>.from(json['improvement_tips_en'] ?? []),
        improvementTipsAr:  List<String>.from(json['improvement_tips_ar'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'env_driven': envDriven,
        'is_env_contributing': isEnvContributing,
        'environmental_risk': environmentalRisk,
        'temperature_status': temperatureStatus,
        'humidity_status': humidityStatus,
        'light_status': lightStatus,
        'can_improve_by_env': canImproveByEnv,
        'summary_en': summaryEn,
        'summary_ar': summaryAr,
        'improvement_tips_en': improvementTipsEn,
        'improvement_tips_ar': improvementTipsAr,
      };

  String summary(String lang) => lang == 'ar' ? summaryAr : summaryEn;
  List<String> tips(String lang) =>
      lang == 'ar' ? improvementTipsAr : improvementTipsEn;
}

class Prediction {
  final String label;
  final double confidence; // 0..1
  final SensorData? sensorData;
  final EnvAnalysis? envAnalysis;

  const Prediction({
    required this.label,
    required this.confidence,
    this.sensorData,
    this.envAnalysis,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'sensor_data': sensorData?.toJson(),
        'env_analysis': envAnalysis?.toJson(),
      };

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
        label: json['label'] as String? ?? 'Unknown',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        sensorData: json['sensor_data'] != null
            ? SensorData.fromJson(json['sensor_data'] as Map<String, dynamic>)
            : null,
        envAnalysis: json['env_analysis'] != null
            ? EnvAnalysis.fromJson(json['env_analysis'] as Map<String, dynamic>)
            : null,
      );
}

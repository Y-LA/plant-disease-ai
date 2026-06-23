import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:plant_disease_mobile/domain/prediction.dart';

class PredictionApi {
  final Uri baseUrl;
  final http.Client _client;

  /// A sensor reading older than this is treated as "ESP32 disconnected".
  /// The backend may return the last cached reading even when the device is
  /// offline, so we drop anything staler than this window.
  static const Duration sensorFreshness = Duration(minutes: 2);

  PredictionApi({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Returns true when an ISO 8601 [timestamp] is older than [sensorFreshness].
  /// Null/unparseable timestamps are treated as fresh (we don't hide data we
  /// can't evaluate).
  static bool _isStale(String? timestamp) {
    if (timestamp == null) return false;
    var ts = DateTime.tryParse(timestamp);
    if (ts == null) return false;
    // The backend sends the timestamp in UTC. If the string had no timezone
    // marker, Dart parses it as LOCAL time — which would wrongly shift it by the
    // device's UTC offset and make fresh readings look hours old. Reinterpret
    // the same wall-clock values as UTC in that case.
    if (!ts.isUtc) {
      ts = DateTime.utc(ts.year, ts.month, ts.day, ts.hour, ts.minute,
          ts.second, ts.millisecond, ts.microsecond);
    }
    return DateTime.now().toUtc().difference(ts) > sensorFreshness;
  }

  /// Fetches the latest ESP32 sensor reading from the backend.
  /// Returns null if the backend is unreachable, there's no reading yet, or the
  /// reading is stale (older than [sensorFreshness] → ESP treated as offline).
  Future<SensorData?> fetchSensor() async {
    try {
      final res = await _client
          .get(baseUrl.resolve('/sensor-data'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['status'] != 'ok' || json['data'] == null) return null;
      final sensor = SensorData.fromJson(json['data'] as Map<String, dynamic>);
      if (_isStale(sensor.timestamp)) return null;
      return sensor;
    } catch (_) {
      return null; // network error / timeout → treated as disconnected
    }
  }

  Future<Prediction> predictLeaf(XFile imageFile) async {
    http.Response response;

    if (kIsWeb) {
      // WEB VERSION — send raw bytes
      final bytes = await imageFile.readAsBytes();
      response = await _client.post(
        baseUrl.resolve('/predict'),
        headers: {'Content-Type': 'application/octet-stream'},
        body: bytes,
      );
    } else {
      // MOBILE VERSION — multipart form
      final request = http.MultipartRequest(
        'POST',
        baseUrl.resolve('/predict'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Prediction failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final label      = json['disease'] as String? ?? 'Unknown';
    final confidence = json['confidence'] != null
        ? (json['confidence'] as num).toDouble()
        : 1.0;

    // Parse optional sensor data (null if ESP32 not connected yet)
    SensorData? sensorData;
    if (json['sensor_data'] != null) {
      sensorData = SensorData.fromJson(
        json['sensor_data'] as Map<String, dynamic>,
      );
    }

    // Parse optional environmental analysis
    EnvAnalysis? envAnalysis;
    if (json['env_analysis'] != null) {
      envAnalysis = EnvAnalysis.fromJson(
        json['env_analysis'] as Map<String, dynamic>,
      );
    }

    // If the latest hardware reading is stale, treat the ESP32 as
    // disconnected: drop both the sensor reading and the env analysis that
    // was derived from it, so the UI shows the "not connected" state.
    if (sensorData != null && _isStale(sensorData.timestamp)) {
      sensorData = null;
      envAnalysis = null;
    }

    return Prediction(
      label:       label,
      confidence:  confidence,
      sensorData:  sensorData,
      envAnalysis: envAnalysis,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'ApiException($message, statusCode: $statusCode)';
}

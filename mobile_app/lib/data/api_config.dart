import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Single source of truth for the backend (FastAPI) base URL.
///
/// - Web / iOS Simulator (debug) → localhost (127.0.0.1)
/// - Real physical device        → the Mac's local Wi‑Fi IP
///
/// ⚠️ If you run on a real phone, change [_deviceLanUrl] to your computer's
/// current local IP (the phone and the computer must be on the same Wi‑Fi).
class ApiConfig {
  static const String _deviceLanUrl = 'http://172.20.10.4:8000';

  static String get backendUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (!kReleaseMode && Platform.isIOS) return 'http://127.0.0.1:8000';
    return _deviceLanUrl;
  }

  static Uri get backendUri => Uri.parse(backendUrl);
}

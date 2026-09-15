import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _productionUrl = "https://smart-wardrobe-backend-wlxq.onrender.com/api/v1/";
  static const String _macLocalIp = "192.168.18.68";

  static String get baseUrl {
    // 1. Compile-time argument override: --dart-define=BASE_URL=https://...
    const String envUrl = String.fromEnvironment('BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl.endsWith('/') ? envUrl : '$envUrl/';
    }

    // 2. Default to Render backend for Release builds
    if (kReleaseMode) {
      return _productionUrl;
    }

    // 3. Local Debugging Overrides (Toggle to true when testing against local FastAPI server)
    const bool useLocalBackend = false;

    if (useLocalBackend) {
      if (kIsWeb) return "http://localhost:8000/api/v1/";
      if (Platform.isIOS || Platform.isAndroid) {
        return "http://$_macLocalIp:8000/api/v1/";
      }
      return "http://127.0.0.1:8000/api/v1/";
    }

    return _productionUrl;
  }
}
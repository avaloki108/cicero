import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CiceroApiClient {
  CiceroApiClient({String? baseUrl})
    : baseUrl = _normalizeBaseUrl(baseUrl ?? CiceroApiClient.defaultBaseUrl);

  final String baseUrl;

  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('CICERO_BASE_URL');
    if (envUrl.isNotEmpty) return _normalizeBaseUrl(envUrl);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator cannot reach localhost directly
      return 'http://10.0.2.2:8013';
      // Using local IP for physical device testing
      // return 'http://192.168.1.24:8013';
    }

    return 'http://127.0.0.1:8013';
  }

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  Future<CiceroResponse> sendMessage(String message, String? state) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'state': state ?? 'US',
              'history': [],
            }),
          )
          .timeout(
            const Duration(seconds: 10),
          ); // Add timeout so it doesn't hang forever

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CiceroResponse.fromJson(data);
      } else {
        throw Exception('Server Error ${response.statusCode} from $baseUrl');
      }
    } catch (e) {
      throw Exception(
        'Connection Failed to $baseUrl. Is the server reachable?\nError: $e',
      );
    }
  }
}

class CiceroResponse {
  final String response;
  final List<String> citations;

  CiceroResponse({required this.response, required this.citations});

  factory CiceroResponse.fromJson(Map<String, dynamic> json) {
    return CiceroResponse(
      response: json['response'] ?? '',
      citations: List<String>.from(json['citations'] ?? []),
    );
  }
}

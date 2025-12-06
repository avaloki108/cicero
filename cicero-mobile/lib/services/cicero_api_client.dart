import 'dart:convert';
import 'package:http/http.dart' as http;

class CiceroResponse {
  final String response;
  final List<String> citations;

  CiceroResponse({required this.response, required this.citations});

  factory CiceroResponse.fromJson(Map<String, dynamic> json) {
    return CiceroResponse(
      response: json['response'] as String,
      citations:
          (json['citations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class CiceroApiClient {
  // Use your computer's local IP address for physical device testing
  // Run `ip addr` or `ifconfig` to find it (e.g., 192.168.1.x)
  static const String baseUrl =
      'http://192.168.1.18:8000'; // REPLACE THIS with your actual IP

  Future<CiceroResponse> sendMessage(String message, String stateAbbr) async {
    final url = Uri.parse('$baseUrl/chat');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message, 'state': stateAbbr}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CiceroResponse.fromJson(data);
      } else {
        throw Exception('Failed to load response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to Cicero: $e');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class CiceroApiClient {
  // thanks to 'adb reverse tcp:8000 tcp:8000', we can use localhost!
  final String baseUrl = 'http://127.0.0.1:8000';

  Future<CiceroResponse> sendMessage(String message, String? state) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'state': state ?? 'US',
          'history': [] 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CiceroResponse.fromJson(data);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection Failed. Did you run "adb reverse tcp:8000 tcp:8000"?\nError: $e');
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
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiChatService {
  Future<String> ask({
    required List<Map<String, String>> messages,
  }) async {
    final uri = _resolveEndpoint();
    final response = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'messages': messages}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('AI endpoint failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid AI response payload');
    }

    final text = (decoded['response'] ?? '').toString().trim();
    if (text.isEmpty) {
      throw Exception('Empty AI response');
    }
    return text;
  }

  Uri _resolveEndpoint() {
    final explicit = dotenv.env['AI_PROXY_URL']?.trim() ?? '';
    if (explicit.isNotEmpty) {
      return Uri.parse(explicit);
    }
    return Uri.base.resolve('/api/ai');
  }
}

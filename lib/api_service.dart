// lib/api_service.dart
// ধাপ: API-র সঙ্গে কথা বলার আলাদা ফাইল।
// এই ফাইলে কোনো API key লেখা নেই। key আসে Settings থেকে,
// ফোনে নিরাপদে সেভ থাকে, কোডে থাকে না।

import 'dart:convert';
import 'package:http/http.dart' as http;

/// OpenAI-এর মতো chat completions API-র সঙ্গে কথা বলে।
/// Meta Model API-ও এই একই নিয়মে চলে, শুধু baseUrl আর model বদলায়।
class ApiService {
  /// text পাঠিয়ে উত্তর আনে। imageBase64 থাকলে ছবিও পাঠায়।
  static Future<String> chat({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String userText,
    String? imageBase64,
  }) async {
    final url = Uri.parse('$baseUrl/chat/completions');

    // মেসেজ তৈরি: লেখা + (থাকলে) ছবি
    final List<Map<String, dynamic>> content = [
      {'type': 'text', 'text': userText},
    ];
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
      });
    }

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'Tumi Juno Mini, ekjon bondhusulov Bangla chat sahokari. Banglay uttor dao, choto kore.',
              },
              {
                'role': 'user',
                'content': content,
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      // 401 মানে key ভুল / বাতিল, 404 মানে model/baseUrl ভুল
      throw Exception(
          'API error ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('API থেকে কোনো উত্তর আসেনি।');
    }
    final message = choices[0]['message'] as Map<String, dynamic>?;
    final text = message?['content']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw Exception('API খালি উত্তর দিয়েছে।');
    }
    return text;
  }
}

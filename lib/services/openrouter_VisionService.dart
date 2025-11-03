// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OpenRouterVisionService {
  final String modelName = "gpt-4o-mini";
  final http.Client _client = http.Client();

  Future<String> analyzeImage(File imageFile) async {
    const endpoint = "https://openrouter.ai/api/v1/chat/completions";
    const apiKey =
        "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";

    if (!await imageFile.exists()) {
      return "⚠️ Image file not found.";
    }

    // Convert image to Base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final headers = {
      "Authorization": "Bearer $apiKey",
      // "Content-Type": "application/json",
    };

    final body = jsonEncode({
      "model": modelName,
      "max_tokens": 200,
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "Only return the name of the prominent object in the image",
            },
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
            },
          ],
        },
      ],
    });

    try {
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: headers,
        body: body,
      );
      print("🔹 Endpoint: $endpoint");
      print("🔹 Headers: $headers");
      print("🔹 Body length: ${body.length}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result == null) {
          throw Exception("Empty response from Vision API");
        }

        if (result['error'] != null) {
          throw Exception("API Error: ${result['error']}");
        }

        if (result['choices'] == null || result['choices'].isEmpty) {
          throw Exception("No choices returned from API: $result");
        }

        return result['choices'][0]['message']['content'];
      } else {
        print("⚠️ Error ${response.statusCode}: ${response.body}");
        return "⚠️ Server error: ${response.statusCode}";
      }
    } catch (e, stack) {
      print("❌ Exception: $e");
      print("🧱 Stack trace: $stack");
      return "⚠️ Something went wrong: $e";
    }
  }

  void dispose() {
    _client.close();
  }
}

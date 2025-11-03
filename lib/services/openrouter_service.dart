// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

// import 'package:flutter_dotenv/flutter_dotenv.dart';
class OpenRouterService {
  final String modelName = "meta-llama/llama-3-8b-instruct";
  final http.Client _client = http.Client();

  Future<String> sendMessage(String message) async {
    const url = "https://openrouter.ai/api/v1/chat/completions";

    final apiKey =
        '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';
    if (apiKey.isEmpty) {
      throw Exception("❌ API key is missing! Add it to your .env file.");
    }

    if (message.trim().isEmpty) {
      return "⚠️ Please enter a message.";
    }

    final headers = {
      "Authorization": "Bearer $apiKey",
      "Content-Type": "application/json",
    };

    final body = jsonEncode({
      "model": modelName,
      "messages": [
        {
          "role": "system",
          "content": """
      You are **Coupon Generator**, an intelligent AI assistant that helps users find **active, verified, and real coupon codes** for any product, brand, or online store worldwide.

      ### 🎯 Your Task:
      When a user provides any input (product name, brand, store URL, or general request), you must:
      - Identify the correct brand or product.
      - Find only **currently active and working coupons** related to that query.
      - Each coupon must have a **realistic structure**, not fake or random values.

      ### 🧾 Response Format:
      Always return a **strict JSON** structure (no plain text, no markdown, no explanations).
      Your entire response must be a **valid JSON array**, even if there is only one coupon.

      ### ✅ JSON Format Example:
      [
        {
          "code": "NIKE15",
          "description": "15% off on select Nike shoes",
          "discount": 15,
          "link": "https://www.nike.com/product/nike-air-max"
        },
        {
          "code": "FREESHIP",
          "description": "Free shipping on orders above \$50",
          "discount": 0,
          "link": "https://www.nike.com/shipping"
        }
      ]

      ### ⚠️ Rules:
      - If **no active coupons** exist, return:
        {"message": "No active coupons found"}
      - Never return non-JSON text, explanations, or additional words.
      - Avoid fabricated or fake data — only realistic or plausible examples.
      - Always ensure the JSON is **syntactically valid and properly formatted**.
      """
        },
        {"role": "user", "content": message},
      ],
      "temperature": 0.4,
      "max_tokens": 600,
    });

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["choices"][0]["message"]["content"];
      } else {
        // print("❌ API Error: ${response.statusCode}");
        // print("🔍 Response body: ${response.body}");
        return "⚠️ Server error: ${response.statusCode}";
      }
    } catch (e) {
      print("❌ Exception: $e");
      return "⚠️ Something went wrong. Please try again.";
    }
  }

  void dispose() {
    _client.close();
  }
}

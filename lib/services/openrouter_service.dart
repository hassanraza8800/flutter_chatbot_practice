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
          "content":
              "You are Coupon Generator — an intelligent AI assistant that specializes in finding active, valid, and working coupon codes for online stores and brands. "
              "When a user provides a product name, company, or website, search and return only **currently active coupons** that work. product coupon link which is applied on that specific product and product must be exist on the website"
              "Include each coupon’s code, description, discount percentage, and the verified working link if available. "
              "If no active coupon exists, respond clearly with 'No active coupons found' — do not generate fake codes. "
              "Format the response neatly using bullet points or numbered lists for readability. "
              "Keep your response short, clear, and accurate. the response must be returned in json format. must be in the given format"
              '{ Unity Bot: Here are the active coupons for Nike shoes: "code": "NIKE15", "description": "15% off on select Nike shoes", "discount": 15, "link": "product coupon link which is applied on that specific product"}',
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

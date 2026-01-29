import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // ⚠️ الكود ده شغال، بس لو هترفع التطبيق على GitHub امسح المفتاح عشان ميتسرقش
  static const String _apiKey = 'AIzaSyALkuePnIpmlRWV3maMomoxKBCzj6A-PsA';

  static Future<Map<String, dynamic>?> analyzeText(String text) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        // 🔥 1. تفعيل وضع JSON لضمان دقة البيانات
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json', 
        ),
      );

      // 🔥 2. تحسين الأمر (Prompt) عشان يفصل العنوان ويظبط البيانات
      final prompt = '''
        You are an intelligent order parser for a shipping system.
        Analyze the following text (Arabic or English) and extract the data into a strict JSON object.
        
        Rules:
        - "name": Client Name (or "Unknown").
        - "phone": Extract the phone number and convert Eastern Arabic digits (٠١٢) to Western (012). Only digits.
        - "price": Total Price as a NUMBER (e.g. 150.0). If not found, use 0.
        - "gov": The Governorate/Province (e.g., Cairo, Giza, Alexandria). Try to infer it from the address.
        - "region": The City/District/Area (e.g., Maadi, Nasr City, Smouha).
        - "address": The detailed street address / building info.
        - "details": Summary of the products/items ordered.

        Input Text: """$text"""
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        // تنظيف بسيط تحسباً لأي مسافات زيادة
        String cleanJson = response.text!.trim();
        
        // لو الموديل رجع علامات كود (رغم إن الـ config بيمنع ده غالباً)
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.replaceAll('```json', '').replaceAll('```', '');
        }

        return jsonDecode(cleanJson);
      }
    } catch (e) {
      print("❌ AI Error: $e");
    }
    return null;
  }
}
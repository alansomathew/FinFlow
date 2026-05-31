import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api_key.dart';

class GeminiAI {
  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=';

  /// Suggests a 50/30/20 category (needs/wants/savings) for a transaction
  static Future<String?> suggestCategory({
    required String title,
    required String? note,
    required double amount,
  }) async {
    final prompt = '''
You are a personal finance assistant. Given a transaction with the following details, classify it as one of: Needs, Wants, or Savings (50/30/20 rule).

Transaction:
Title: $title
Note: ${note ?? ''}
Amount: $amount

Respond with only one word: Needs, Wants, or Savings.
''';
    final response = await http.post(
      Uri.parse(_endpoint + apiKey),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text != null && (text.contains('Needs') || text.contains('Wants') || text.contains('Savings'))) {
        if (text.contains('Needs')) return 'Needs';
        if (text.contains('Wants')) return 'Wants';
        if (text.contains('Savings')) return 'Savings';
      }
    }
    return null;
  }

  /// Generates a short insight about the user's 50/30/20 spending
  static Future<String?> spendingInsight({
    required double needs,
    required double wants,
    required double savings,
    required double income,
  }) async {
    final prompt = '''
You are a personal finance assistant. Given the following monthly spending breakdown, write a short, friendly insight (1-2 sentences) for the user. Mention if they are overspending in any category, and which category they spent the most on.

Monthly Income: ₹$income
Needs: ₹$needs
Wants: ₹$wants
Savings: ₹$savings

Insight:
''';
    final response = await http.post(
      Uri.parse(_endpoint + apiKey),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      return text;
    }
    return null;
  }

  /// Suggests a monthly budget allocation (in INR) for a category
  static Future<Map<String, dynamic>?> suggestCategoryBudget({
    required String categoryName,
    required double monthlyIncome,
    required String bucketType,
  }) async {
    final prompt = '''
You are a personal finance assistant. Suggest a reasonable monthly budget allocation (in INR) for the category "$categoryName" under the 50/30/20 rule.
The user has a monthly income of ₹$monthlyIncome.
This category is classified under "$bucketType".

Respond with a JSON object containing two fields:
"reason": A short 1-sentence reason for this suggestion
"suggestedAmount": The suggested monthly amount (double/number)

Respond with only the raw JSON.
''';
    try {
      final response = await http.post(
        Uri.parse(_endpoint + apiKey),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (text != null) {
          final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
          return jsonDecode(cleanText) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Generates a personalized financial tip based on user's current month statistics
  static Future<Map<String, dynamic>?> getPersonalizedFinancialTip({
    required double income,
    required double needsSpent,
    required double wantsSpent,
    required double savingsSpent,
    required Map<String, double> categorySpend,
  }) async {
    final categorySpendStr = categorySpend.entries
        .map((e) => '- ${e.key}: ₹${e.value.toStringAsFixed(2)}')
        .join('\n');

    final prompt = '''
You are a personal finance expert and wealth coach. Analyze the user's financial status:
Monthly Income: ₹${income.toStringAsFixed(2)}
Spent on Needs (50% target): ₹${needsSpent.toStringAsFixed(2)}
Spent on Wants (30% target): ₹${wantsSpent.toStringAsFixed(2)}
Spent on Savings (20% target): ₹${savingsSpent.toStringAsFixed(2)}

Detailed spending by Category ID:
$categorySpendStr

Based on this data, generate a premium, hyper-personalized, and highly actionable daily financial tip.
Provide the output as a JSON object with:
"title": A catchy, short title (e.g., "Wants are creeping up!", "Savings Champ!", "Utilities Leak Detected")
"message": A 1-2 sentence friendly advice outlining the current status or suggesting where to adjust.
"actionItem": A clear, single-sentence task they can complete today (e.g., "Review your subscription list", "Transfer ₹2000 to your savings account right now")
"category": The type of advice, like "Savings Boost", "Wants Alert", "Investment Idea", or "Budget Balance"
"emoji": A suitable single emoji (e.g., "💡", "⚠️", "🚀", "🎯")

Respond with only the raw JSON. Do not wrap in markdown or any other tags.
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint + apiKey),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (text != null) {
          final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
          return jsonDecode(cleanText) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }
}

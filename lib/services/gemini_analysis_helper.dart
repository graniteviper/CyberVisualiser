import '../models/attack_event.dart';
import 'gemini_service.dart';
import '../templates/gemini_prompt_template.dart';

/// Calls the Gemini service using the generated prompt template for the top 10 events of a category.
Future<String> fetchCategoryThreatSummary({
  required GeminiService geminiService,
  required String category,
  required List<AttackEvent> events,
}) async {
  final topEvents = events.take(10).toList();
  final prompt = GeminiPromptTemplate.fillCategoryAnalysisTemplate(
    category,
    topEvents,
  );
  return await geminiService.generateThreatSummary(prompt);
}

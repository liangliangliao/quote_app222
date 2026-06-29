import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'new_tablets_dao.dart';
import 'new_tablets_prompt_config.dart';

class NewTabletsAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final NewTabletsPromptConfig _prompts = NewTabletsPromptConfig();

  String detectScene(String input) {
    final text = input.trim();
    if (RegExp('废物|不配|羞耻|内疚|自责|惩罚|罪').hasMatch(text)) return 'bad_conscience';
    if (RegExp('别人|大家|父母|社会|同龄|必须|买房|稳定|认可').hasMatch(text)) return 'herd';
    if (RegExp('过去|后悔|浪费|当初|倒霉').hasMatch(text)) return 'past_regret';
    if (RegExp('学很多|看课|阅读|信息|没有输出|不行动').hasMatch(text)) return 'learning_output';
    if (RegExp('目标|计划|承诺|每天|长期|90天|30天').hasMatch(text)) return 'commitment';
    if (RegExp('偷懒|拖延|不想|逃避|无法开始|手机').hasMatch(text)) return 'procrastination';
    return 'value_confusion';
  }

  Future<String> generateCoachText({
    required String userInput,
    required NewTabletsState state,
  }) async {
    final scene = detectScene(userInput);
    final prompt = await _prompts.buildPrompt(
      scene: scene,
      userInput: userInput,
      profileJson: _profileJson(state),
      recentContextJson: _recentContextJson(state),
      outputMode: scene == 'commitment' ? 'commitment' : 'standard',
    );
    return _ai.generateText(
      prompt: prompt,
      purpose: 'new_tablets.$scene',
      systemPrompt: await _prompts.getPrompt(NewTabletsPromptConfig.globalId),
      maxTokens: 1600,
      temperature: 0.55,
    );
  }

  String _profileJson(NewTabletsState state) => jsonEncode(<String, dynamic>{
    'old_tablets': state.oldTablets.map((e) => e.toJson()).toList(growable: false),
    'new_tablets': state.newTablets.map((e) => e.toJson()).toList(growable: false),
    'commitments': state.commitments.map((e) => e.toJson()).toList(growable: false),
    'bad_conscience_rewrites': state.rewrites.take(20).map((e) => e.toJson()).toList(growable: false),
  });

  String _recentContextJson(NewTabletsState state) => jsonEncode(<String, dynamic>{
    'daily_commands': state.dailyCommands.take(20).map((e) => e.toJson()).toList(growable: false),
    'creative_outputs': state.creativeOutputs.take(20).map((e) => e.toJson()).toList(growable: false),
    'metrics': <String, dynamic>{
      'old_tablet_count': state.oldTablets.length,
      'new_tablet_count': state.newTablets.length,
      'commitment_count': state.commitments.length,
      'creative_output_count': state.creativeOutputs.length,
      'average_reliability': state.commitments.isEmpty ? 0 : state.commitments.map((e) => e.rate).reduce((a, b) => a + b) / state.commitments.length,
      'repair_count': state.commitments.fold<int>(0, (sum, e) => sum + e.repairs),
    },
  });
}

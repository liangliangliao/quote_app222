import 'dart:math' as math;

Map<String, dynamic> depthPlan(String userInput) => {
      'source_anchor':
          userInput.length <= 80 ? userInput : userInput.substring(0, 80),
      'meaning': '想把“$userInput”带入当下的体验，而不只是在道理上同意。',
      'tension': '也许想给自己一点位置，同时担心这样会失去对自己的要求；不贴近时可以放下这个假设。',
      'protective_intention': '也许纠正自己的冲动想保护认真与被认可的需要。',
      'cognitive_bridge': {
        'old_rule': '也许只有先把一切做好，才可以停下来。',
        'wider_view': '承担责任与承认此刻有限，可以同时存在。',
      },
      'experiment': {
        'scene': '一个轻微、暂时无需处理的小小未完成，或眼前纸面的一处空白。',
        'scene_meaning': '暂不补齐它，试试自己是否仍有被支撑的位置。',
        'sensory_cues': ['纸面光影', '座面托住身体的触感'],
        'baseline': '先留意想赶快纠正的冲动和手指原来的用力。',
        'invitation': '只在这一次呼气里，允许这一处暂时未完成。',
        'body_check': '停留后手指、身体用力是否有不同，也可能相同。',
        'emotion_check': '留意不安、怀疑或其他真实情绪，不要求消失。',
        'meaning_check': '此刻的支持是否必须等到做得完美才有，尚不确定也可以。',
      },
      'response_options': {
        'unchanged': '没有变化时，留意是否又出现催促自己的要求。',
        'too_much': '不舒服时放下这个场景，睁眼看一个普通物体，选择暂停。',
      },
      'daily_transfer': '稍后面对一个小小未完成时，先承认有限，再选择愿意承担的下一步。',
    };

/// Citations for controlled responses. Semantic quality is not measured by
/// this fixture helper; tests exercise phase linkage and revision recovery.
Map<String, String> depthEvidence(List<dynamic> segments) {
  String quote(String phase) {
    final segment = segments.firstWhere((s) => s['phase'] == phase);
    final text = segment['text'] as String;
    final end = text.indexOf(RegExp(r'[。！？!?]'));
    return text.substring(0, math.min(24, end >= 3 ? end + 1 : text.length));
  }

  return {
    'pattern': quote('body_emotion'),
    'experiment': quote('embodied_shift'),
    'emotional_contact': quote('allow_experience'),
    'meaning': quote('integration'),
    'transfer': quote('real_life_rehearsal'),
  };
}

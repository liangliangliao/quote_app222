class LifeThoughtMatch {
  final String title;
  final String reason;
  final String useCase;

  const LifeThoughtMatch({
    required this.title,
    required this.reason,
    required this.useCase,
  });

  factory LifeThoughtMatch.fromAny(dynamic value) {
    if (value is Map) {
      return LifeThoughtMatch(
        title: _str(value['title'] ?? value['name'] ?? value['thought']),
        reason: _str(value['reason'] ?? value['why_related'] ?? value['analysis']),
        useCase: _str(value['use_case'] ?? value['practice'] ?? value['how_to_use']),
      );
    }
    return LifeThoughtMatch(title: _str(value), reason: '', useCase: '');
  }
}

class LifeBookRecommendation {
  final String title;
  final String author;
  final String type;
  final String reason;
  final String readingTip;

  const LifeBookRecommendation({
    required this.title,
    required this.author,
    required this.type,
    required this.reason,
    required this.readingTip,
  });

  factory LifeBookRecommendation.fromAny(dynamic value) {
    if (value is Map) {
      return LifeBookRecommendation(
        title: _str(value['title'] ?? value['book_title'] ?? value['name']),
        author: _str(value['author']),
        type: _str(value['type'] ?? value['category'] ?? value['healing_type']),
        reason: _str(value['reason'] ?? value['why_related'] ?? value['analysis']),
        readingTip: _str(value['reading_tip'] ?? value['tip'] ?? value['how_to_read']),
      );
    }
    return LifeBookRecommendation(title: _str(value), author: '', type: '', reason: '', readingTip: '');
  }
}

class LifeNoteReport {
  final String safetyLevel;
  final String title;
  final String heardSummary;
  final List<String> coreEmotions;
  final List<String> lifeThemes;
  final List<String> deeperNeeds;
  final String corePattern;
  final String gentleReframe;
  final String theoryElevation;
  final List<LifeThoughtMatch> relatedThoughts;
  final List<LifeBookRecommendation> healingBooks;
  final List<String> explorationQuestions;
  final List<String> smallPractices;
  final String summary;
  final List<String> safetyNotices;

  const LifeNoteReport({
    required this.safetyLevel,
    required this.title,
    required this.heardSummary,
    required this.coreEmotions,
    required this.lifeThemes,
    required this.deeperNeeds,
    required this.corePattern,
    required this.gentleReframe,
    required this.theoryElevation,
    required this.relatedThoughts,
    required this.healingBooks,
    required this.explorationQuestions,
    required this.smallPractices,
    required this.summary,
    required this.safetyNotices,
  });

  factory LifeNoteReport.fromJson(Map<String, dynamic> json) {
    return LifeNoteReport(
      safetyLevel: _str(json['safety_level'] ?? json['safetyLevel'] ?? 'normal'),
      title: _str(json['title'] ?? '人生注解'),
      heardSummary: _str(json['heard_summary'] ?? json['heardSummary'] ?? json['what_i_heard']),
      coreEmotions: _strList(json['core_emotions'] ?? json['emotions']),
      lifeThemes: _strList(json['life_themes'] ?? json['themes']),
      deeperNeeds: _strList(json['deeper_needs'] ?? json['needs']),
      corePattern: _str(json['core_pattern'] ?? json['pattern_summary']),
      gentleReframe: _str(json['gentle_reframe'] ?? json['reframe']),
      theoryElevation: _str(json['theory_elevation'] ?? json['concept_summary']),
      relatedThoughts: _list(json['related_thoughts'] ?? json['thoughts'])
          .map(LifeThoughtMatch.fromAny)
          .where((e) => e.title.trim().isNotEmpty)
          .toList(),
      healingBooks: _list(json['healing_books'] ?? json['books'])
          .map(LifeBookRecommendation.fromAny)
          .where((e) => e.title.trim().isNotEmpty)
          .toList(),
      explorationQuestions: _strList(json['exploration_questions'] ?? json['questions']),
      smallPractices: _strList(json['small_practices'] ?? json['practices']),
      summary: _str(json['summary'] ?? json['final_summary']),
      safetyNotices: _strList(json['safety_notices'] ?? json['warnings']),
    );
  }

  static LifeNoteReport emptyWithMessage(String message) {
    return LifeNoteReport(
      safetyLevel: 'normal',
      title: '人生注解',
      heardSummary: message,
      coreEmotions: const <String>[],
      lifeThemes: const <String>[],
      deeperNeeds: const <String>[],
      corePattern: '',
      gentleReframe: '',
      theoryElevation: '',
      relatedThoughts: const <LifeThoughtMatch>[],
      healingBooks: const <LifeBookRecommendation>[],
      explorationQuestions: const <String>[],
      smallPractices: const <String>[],
      summary: '',
      safetyNotices: const <String>[],
    );
  }
}

String _str(dynamic value) => value == null ? '' : value.toString().trim();

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  if (value == null) return const <dynamic>[];
  final text = value.toString().trim();
  if (text.isEmpty) return const <dynamic>[];
  return <dynamic>[text];
}

List<String> _strList(dynamic value) {
  return _list(value)
      .map((e) => _str(e))
      .where((e) => e.isNotEmpty)
      .toList();
}

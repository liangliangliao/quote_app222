import 'dart:convert';

import 'package:flutter/services.dart';

import 'xiangji_models.dart';

class XiangjiEvidenceRecord {
  const XiangjiEvidenceRecord({
    required this.id,
    required this.sourceId,
    required this.locator,
    required this.claim,
    required this.summary,
    required this.boundary,
    this.thinkerId = '',
    this.themeId = '',
    this.sectionTitle = '',
    this.rank = 0,
  });

  final String id;
  final String sourceId;
  final String locator;
  final String claim;
  final String summary;
  final String boundary;
  final String thinkerId;
  final String themeId;
  final String sectionTitle;
  final int rank;

  factory XiangjiEvidenceRecord.fromLegacyJson(Map<String, dynamic> json) {
    return XiangjiEvidenceRecord(
      id: (json['evidence_id'] ?? '').toString(),
      sourceId: (json['source_id'] ?? '').toString(),
      locator: (json['locator'] ?? '').toString(),
      claim: (json['claim'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      boundary: (json['boundary'] ?? '').toString(),
    );
  }
}

class XiangjiGoalCoreProfile {
  const XiangjiGoalCoreProfile({
    required this.thinkerId,
    required this.name,
    required this.mentorTitle,
    required this.centralQuestion,
    required this.centralAnswer,
    required this.whyGoalMatters,
    required this.fromConfusionToDirection,
    required this.realityTranslation,
    required this.oneSentenceSummary,
    required this.sourceBasis,
  });

  final String thinkerId;
  final String name;
  final String mentorTitle;
  final String centralQuestion;
  final String centralAnswer;
  final String whyGoalMatters;
  final String fromConfusionToDirection;
  final String realityTranslation;
  final String oneSentenceSummary;
  final String sourceBasis;

  factory XiangjiGoalCoreProfile.fromJson(Map<String, dynamic> json) {
    return XiangjiGoalCoreProfile(
      thinkerId: _text(json['thinker_id']),
      name: _text(json['name_zh']),
      mentorTitle: _text(json['mentor_title']),
      centralQuestion: _text(json['central_goal_question']),
      centralAnswer: _text(json['central_goal_answer']),
      whyGoalMatters: _text(json['why_goal_matters']),
      fromConfusionToDirection: _text(json['from_confusion_to_direction']),
      realityTranslation: _text(json['reality_translation_principle']),
      oneSentenceSummary: _text(json['one_sentence_summary']),
      sourceBasis: _text(json['source_basis']),
    );
  }
}

class XiangjiGoalTheme {
  const XiangjiGoalTheme({
    required this.id,
    required this.sequence,
    required this.priorityTier,
    required this.role,
    required this.title,
    required this.coreQuestion,
    required this.coreAnswer,
    required this.deepAnalysis,
    required this.targetTranslation,
    required this.realLifeApplication,
    required this.confusionGuidance,
    required this.boundaries,
    required this.supportingModuleIds,
  });

  final String id;
  final int sequence;
  final String priorityTier;
  final String role;
  final String title;
  final String coreQuestion;
  final String coreAnswer;
  final String deepAnalysis;
  final String targetTranslation;
  final String realLifeApplication;
  final String confusionGuidance;
  final String boundaries;
  final List<String> supportingModuleIds;

  bool get isPrimary => priorityTier == 'primary';

  factory XiangjiGoalTheme.fromJson(Map<String, dynamic> json) {
    return XiangjiGoalTheme(
      id: _text(json['theme_id']),
      sequence: _integer(json['sequence']),
      priorityTier: _text(json['priority_tier']),
      role: _text(json['theme_role']),
      title: _text(json['title']),
      coreQuestion: _text(json['core_question']),
      coreAnswer: _text(json['core_answer']),
      deepAnalysis: _text(json['deep_analysis']),
      targetTranslation: _text(json['target_setting_translation']),
      realLifeApplication: _text(json['real_life_application']),
      confusionGuidance: _text(json['confusion_guidance']),
      boundaries: _text(json['boundaries']),
      supportingModuleIds: _strings(json['supporting_module_ids']),
    );
  }
}

class XiangjiGoalJourney {
  const XiangjiGoalJourney({
    required this.title,
    required this.firstPrompt,
    required this.successDefinition,
    required this.stages,
  });

  final String title;
  final String firstPrompt;
  final String successDefinition;
  final List<String> stages;

  factory XiangjiGoalJourney.fromJson(Map<String, dynamic> json) {
    return XiangjiGoalJourney(
      title: _text(json['journey_title']),
      firstPrompt: _text(json['first_user_prompt']),
      successDefinition: _text(json['success_definition']),
      stages: _strings(json['stages']),
    );
  }
}

class XiangjiDeepModule {
  const XiangjiDeepModule({
    required this.id,
    required this.category,
    required this.title,
    required this.coreClaim,
    required this.explanation,
    required this.distinctions,
    required this.application,
    required this.questions,
    required this.signals,
  });

  final String id;
  final String category;
  final String title;
  final String coreClaim;
  final String explanation;
  final String distinctions;
  final String application;
  final List<String> questions;
  final List<String> signals;

  factory XiangjiDeepModule.fromJson(Map<String, dynamic> json) {
    return XiangjiDeepModule(
      id: _text(json['module_id']),
      category: _text(json['category']),
      title: _text(json['title']),
      coreClaim: _text(json['core_claim']),
      explanation: _text(json['deep_explanation']),
      distinctions: _text(json['distinctions']),
      application: _text(json['application']),
      questions: _jsonStrings(json['questions_json']),
      signals: _jsonStrings(json['signals_json']),
    );
  }
}

class XiangjiMentorSettingStep {
  const XiangjiMentorSettingStep({
    required this.title,
    required this.purpose,
    required this.mentorQuestion,
    required this.operation,
    required this.outputArtifact,
    required this.acceptanceCriteria,
    required this.caution,
  });

  final String title;
  final String purpose;
  final String mentorQuestion;
  final String operation;
  final String outputArtifact;
  final String acceptanceCriteria;
  final String caution;

  factory XiangjiMentorSettingStep.fromJson(Map<String, dynamic> json) {
    return XiangjiMentorSettingStep(
      title: _text(json['title']),
      purpose: _text(json['purpose']),
      mentorQuestion: _text(json['mentor_question']),
      operation: _text(json['operation']),
      outputArtifact: _text(json['output_artifact']),
      acceptanceCriteria: _text(json['acceptance_criteria']),
      caution: _text(json['caution']),
    );
  }
}

class XiangjiMentorPractice {
  const XiangjiMentorPractice({
    required this.cadence,
    required this.title,
    required this.instruction,
    required this.reflectionQuestion,
    required this.evidenceType,
    required this.caution,
  });

  final String cadence;
  final String title;
  final String instruction;
  final String reflectionQuestion;
  final String evidenceType;
  final String caution;

  factory XiangjiMentorPractice.fromJson(Map<String, dynamic> json) {
    return XiangjiMentorPractice(
      cadence: _text(json['cadence']),
      title: _text(json['title']),
      instruction: _text(json['instruction']),
      reflectionQuestion: _text(json['reflection_question']),
      evidenceType: _text(json['evidence_type']),
      caution: _text(json['caution']),
    );
  }
}

class XiangjiDiagnosticRoute {
  const XiangjiDiagnosticRoute({
    required this.problemType,
    required this.userSignals,
    required this.interpretation,
    required this.keyQuestions,
    required this.guidanceSequence,
    required this.caution,
  });

  final String problemType;
  final List<String> userSignals;
  final String interpretation;
  final List<String> keyQuestions;
  final List<String> guidanceSequence;
  final String caution;

  factory XiangjiDiagnosticRoute.fromJson(Map<String, dynamic> json) {
    return XiangjiDiagnosticRoute(
      problemType: _text(json['problem_type']),
      userSignals: _strings(json['user_signals']),
      interpretation: _text(json['mentor_interpretation']),
      keyQuestions: _strings(json['key_questions']),
      guidanceSequence: _strings(json['guidance_sequence']),
      caution: _text(json['caution']),
    );
  }
}

class XiangjiMentorCase {
  const XiangjiMentorCase({
    required this.title,
    required this.userStatement,
    required this.diagnosis,
    required this.targetReframe,
    required this.nextStep,
    required this.deeperLesson,
    required this.caution,
  });

  final String title;
  final String userStatement;
  final String diagnosis;
  final String targetReframe;
  final String nextStep;
  final String deeperLesson;
  final String caution;

  factory XiangjiMentorCase.fromJson(Map<String, dynamic> json) {
    return XiangjiMentorCase(
      title: _text(json['case_title']),
      userStatement: _text(json['user_statement']),
      diagnosis: _text(json['diagnosis']),
      targetReframe: _text(json['target_reframe']),
      nextStep: _text(json['next_step']),
      deeperLesson: _text(json['deeper_lesson']),
      caution: _text(json['caution']),
    );
  }
}

class XiangjiConciseProfile {
  const XiangjiConciseProfile({
    required this.thinkerId,
    required this.name,
    required this.coreQuestion,
    required this.summary,
    required this.oneSentenceSummary,
    required this.differenceFocus,
    required this.defaultHidden,
    required this.keyFeatures,
  });

  final String thinkerId;
  final String name;
  final String coreQuestion;
  final String summary;
  final String oneSentenceSummary;
  final String differenceFocus;
  final bool defaultHidden;
  final List<String> keyFeatures;

  factory XiangjiConciseProfile.fromJson(Map<String, dynamic> json) {
    return XiangjiConciseProfile(
      thinkerId: _text(json['thinker_id']),
      name: _text(json['name_zh']),
      coreQuestion: _text(json['core_question']),
      summary: _text(json['concise_summary']),
      oneSentenceSummary: _text(json['one_sentence_summary']),
      differenceFocus: _text(json['difference_focus']),
      defaultHidden: _integer(json['default_hidden']) == 1,
      keyFeatures: _strings(json['key_features']),
    );
  }
}

class XiangjiKnowledgeSystem {
  const XiangjiKnowledgeSystem({
    required this.id,
    required this.displayName,
    required this.thinker,
    required this.coreValues,
    required this.coreIdeas,
    required this.knowledgeView,
    required this.actionView,
    required this.splitDiagnosis,
    required this.transformationPath,
    required this.decisionCue,
    required this.tensions,
    required this.sourceIds,
    required this.evidence,
    this.profile,
    this.themes = const <XiangjiGoalTheme>[],
    this.journey,
    this.modules = const <XiangjiDeepModule>[],
    this.settingSteps = const <XiangjiMentorSettingStep>[],
    this.practices = const <XiangjiMentorPractice>[],
    this.diagnosticRoutes = const <XiangjiDiagnosticRoute>[],
    this.cases = const <XiangjiMentorCase>[],
  });

  final String id;
  final String displayName;
  final String thinker;
  final List<String> coreValues;
  final List<String> coreIdeas;
  final String knowledgeView;
  final String actionView;
  final String splitDiagnosis;
  final String transformationPath;
  final String decisionCue;
  final List<String> tensions;
  final List<String> sourceIds;
  final List<XiangjiEvidenceRecord> evidence;
  final XiangjiGoalCoreProfile? profile;
  final List<XiangjiGoalTheme> themes;
  final XiangjiGoalJourney? journey;
  final List<XiangjiDeepModule> modules;
  final List<XiangjiMentorSettingStep> settingSteps;
  final List<XiangjiMentorPractice> practices;
  final List<XiangjiDiagnosticRoute> diagnosticRoutes;
  final List<XiangjiMentorCase> cases;

  List<XiangjiGoalTheme> get primaryThemes =>
      themes.where((item) => item.isPrimary).toList(growable: false);

  List<XiangjiGoalTheme> get secondaryThemes =>
      themes.where((item) => !item.isPrimary).toList(growable: false);

  factory XiangjiKnowledgeSystem.fromLegacyJson(Map<String, dynamic> json) {
    return XiangjiKnowledgeSystem(
      id: _text(json['systemId']),
      displayName: _text(json['displayName']),
      thinker: _text(json['thinker']),
      coreValues: _strings(json['coreValues']),
      coreIdeas: _strings(json['coreIdeas']),
      knowledgeView: _text(json['knowledgeView']),
      actionView: _text(json['actionView']),
      splitDiagnosis: _text(json['splitDiagnosis']),
      transformationPath: _text(json['transformationPath']),
      decisionCue: _text(json['decisionCue']),
      tensions: _strings(json['tensions']),
      sourceIds: _strings(json['sourceIds']),
      evidence: _maps(json['evidenceHighlights'])
          .map(XiangjiEvidenceRecord.fromLegacyJson)
          .toList(growable: false),
    );
  }
}

class XiangjiKnowledgeCatalog {
  const XiangjiKnowledgeCatalog({
    required this.version,
    required this.title,
    required this.systems,
    required this.books,
    this.defaultLayer = 'mentor_goal_core_v21',
    this.conciseProfiles = const <XiangjiConciseProfile>[],
  });

  final String version;
  final String title;
  final String defaultLayer;
  final List<XiangjiKnowledgeSystem> systems;
  final List<XiangjiBookInfo> books;
  final List<XiangjiConciseProfile> conciseProfiles;

  int get primaryThemeCount =>
      systems.fold<int>(0, (sum, item) => sum + item.primaryThemes.length);
  int get secondaryThemeCount =>
      systems.fold<int>(0, (sum, item) => sum + item.secondaryThemes.length);
  int get evidenceCount =>
      systems.fold<int>(0, (sum, item) => sum + item.evidence.length);

  XiangjiKnowledgeSystem? system(String id) {
    for (final item in systems) {
      if (item.id == id) return item;
    }
    return null;
  }

  XiangjiBookInfo? book(String id) {
    for (final item in books) {
      if (item.id == id) return item;
    }
    return null;
  }

  XiangjiConciseProfile? conciseProfile(String thinkerId) {
    for (final item in conciseProfiles) {
      if (item.thinkerId == thinkerId) return item;
    }
    return null;
  }

  List<XiangjiSourceCitation> citationsFor(
    XiangjiKnowledgeSystem system, {
    int limit = 3,
  }) {
    final records = List<XiangjiEvidenceRecord>.of(system.evidence)
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final citations = <XiangjiSourceCitation>[];
    for (final item in records) {
      if (citations.length >= limit) break;
      final source = book(item.sourceId);
      if (source == null || item.id.isEmpty || item.locator.isEmpty) continue;
      citations.add(
        XiangjiSourceCitation(
          evidenceId: item.id,
          sourceId: item.sourceId,
          bookTitle: source.title,
          author: source.author,
          locator: item.locator,
          claim: item.claim,
          summary: _shortExcerpt(item.summary),
          boundary: item.boundary,
          contentType: 'source_paraphrase',
        ),
      );
    }
    return citations;
  }
}

class XiangjiKnowledgeRepository {
  static const String goalFirstAssetPath =
      'assets/xiangji_goal_mentor/goal_first_mentor_knowledge_v2_1.json';
  static const String deepMentorAssetPath =
      'assets/xiangji_goal_mentor/deep_mentor_knowledge_v2.json';
  static const String conciseAssetPath =
      'assets/xiangji_goal_mentor/thinker_concise_profiles.example.json';

  static const Map<String, String> legacySystemDisplayNames = <String, String>{
    'yangming': '王阳明 · 知行合一总纲',
    'william_james': '威廉·詹姆斯 · 观念如何成为动作',
    'beck_cognitive_therapy': '贝克 · 认知检验与行为实验',
    'ellis_rebt': '埃利斯 · 从“必须”退回偏好',
    'laozi': '老子 · 无为、减法与柔韧行动',
    'act': 'ACT · 带着不适走向价值',
    'self_determination': '自我决定理论 · 从外控到内化',
    'nietzsche': '尼采 · 谱系、自我克服与价值创造',
    'frankl': '弗兰克尔 · 意义、责任与受限自由',
    'dewey': '杜威 · 探究、习惯与环境重构',
    'gollwitzer': 'Gollwitzer · 把意图编译成现场行动',
    'bandura': '班杜拉 · 榜样、效能与能动性',
    'oettingen': 'Oettingen · 心理对照与 WOOP',
    'behavioral_activation': '行为激活 · 从回避循环重新接触生活',
    'maslow': '马斯洛 · 需要、容量与成长条件',
    'harvard_positive_psychology': '哈佛积极心理学 · 从信息到转化',
    'comb_bcw': 'COM-B/BCW · 行为工程编排',
  };

  static String legacySystemDisplayName(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return '旧版本未记录导师';
    return legacySystemDisplayNames[normalized] ?? '旧版导师（$normalized）';
  }

  XiangjiKnowledgeCatalog? _cache;

  Future<XiangjiKnowledgeCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await Future.wait<String>(<Future<String>>[
      rootBundle.loadString(goalFirstAssetPath),
      rootBundle.loadString(deepMentorAssetPath),
      rootBundle.loadString(conciseAssetPath),
    ]);
    final goalRoot = _objectMap(jsonDecode(raw[0]));
    final deepRoot = _objectMap(jsonDecode(raw[1]));
    final conciseRoot = jsonDecode(raw[2]);
    if (goalRoot.isEmpty || deepRoot.isEmpty || conciseRoot is! List) {
      throw const FormatException('向己 V2.1 知识资产格式无效');
    }
    final catalog = fromV21(
      goalRoot,
      deepRoot,
      conciseRoot,
    );
    _cache = catalog;
    return catalog;
  }

  XiangjiKnowledgeCatalog fromV21(
    Map<String, dynamic> goalRoot,
    Map<String, dynamic> deepRoot,
    List<dynamic> conciseRoot,
  ) {
    final concise = conciseRoot
        .whereType<Map>()
        .map((item) => XiangjiConciseProfile.fromJson(_objectMap(item)))
        .toList(growable: false);
    final systems = <XiangjiKnowledgeSystem>[];
    final bookAuthors = <String, String>{};

    for (final mentorJson in _maps(goalRoot['mentors'])) {
      final profile =
          XiangjiGoalCoreProfile.fromJson(_objectMap(mentorJson['profile']));
      final deep = _objectMap(deepRoot[profile.thinkerId]);
      final themes = _maps(mentorJson['core_themes'])
          .map(XiangjiGoalTheme.fromJson)
          .toList(growable: false)
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      final themeById = <String, XiangjiGoalTheme>{
        for (final theme in themes) theme.id: theme,
      };
      final evidence = _maps(mentorJson['core_evidence']).map((json) {
        final themeId = _text(json['theme_id']);
        final theme = themeById[themeId];
        return XiangjiEvidenceRecord(
          id: _text(json['evidence_id']),
          sourceId: _text(json['book_id']),
          locator: _text(json['source_locator']),
          claim: _text(json['relevance_note']).isNotEmpty
              ? _text(json['relevance_note'])
              : (theme?.coreAnswer ?? ''),
          summary: _text(json['source_excerpt']),
          boundary: theme?.boundaries ?? '',
          thinkerId: profile.thinkerId,
          themeId: themeId,
          sectionTitle: _text(json['section_title']),
          rank: _integer(json['evidence_rank']),
        );
      }).toList(growable: false);
      final sourceIds = evidence
          .map((item) => item.sourceId)
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
      for (final sourceId in sourceIds) {
        bookAuthors.putIfAbsent(sourceId, () => profile.name);
      }
      final modules = _maps(mentorJson['supporting_modules'])
          .map(XiangjiDeepModule.fromJson)
          .toList(growable: false);
      final settingSteps = _maps(deep['goal_setting_steps'])
          .map(XiangjiMentorSettingStep.fromJson)
          .toList(growable: false);
      final practices = _maps(deep['life_practices'])
          .map(XiangjiMentorPractice.fromJson)
          .toList(growable: false);
      final routes = _maps(deep['diagnostic_routes'])
          .map(XiangjiDiagnosticRoute.fromJson)
          .toList(growable: false);
      final cases = _maps(deep['cases'])
          .map(XiangjiMentorCase.fromJson)
          .toList(growable: false);
      final primary = themes.where((item) => item.isPrimary).toList();
      systems.add(
        XiangjiKnowledgeSystem(
          id: profile.thinkerId,
          displayName: profile.name,
          thinker: profile.name,
          coreValues: primary.map((item) => item.title).toList(growable: false),
          coreIdeas:
              primary.map((item) => item.coreAnswer).toList(growable: false),
          knowledgeView: profile.centralAnswer,
          actionView: profile.realityTranslation,
          splitDiagnosis: profile.fromConfusionToDirection,
          transformationPath:
              XiangjiGoalJourney.fromJson(_objectMap(mentorJson['journey']))
                  .stages
                  .join(' → '),
          decisionCue: profile.centralQuestion,
          tensions: themes
              .map((item) => item.boundaries)
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(growable: false),
          sourceIds: sourceIds,
          evidence: evidence,
          profile: profile,
          themes: themes,
          journey:
              XiangjiGoalJourney.fromJson(_objectMap(mentorJson['journey'])),
          modules: modules,
          settingSteps: settingSteps,
          practices: practices,
          diagnosticRoutes: routes,
          cases: cases,
        ),
      );
    }

    final books = bookAuthors.entries
        .map(
          (entry) => XiangjiBookInfo(
            id: entry.key,
            title: _bookTitle(entry.key),
            author: entry.value,
            edition: 'KB V2.1 受控原典定位',
            sourceStatus: 'primary_source_opened',
            builtIn: true,
            parseStatus: 'verified',
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.title.compareTo(b.title));
    final catalog = XiangjiKnowledgeCatalog(
      version: _text(goalRoot['version']),
      title: '向己目标优先导师知识库',
      defaultLayer: _text(goalRoot['default_layer']),
      systems: systems,
      books: books,
      conciseProfiles: concise,
    );
    _validateV21(catalog);
    return catalog;
  }

  XiangjiKnowledgeCatalog fromJson(Map<String, dynamic> json) {
    final systems = _maps(json['systems'])
        .map(XiangjiKnowledgeSystem.fromLegacyJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
    final books = _maps(json['works'])
        .map(
          (item) => XiangjiBookInfo(
            id: _text(item['source_id']),
            title: _text(item['title']),
            author: _text(item['author']),
            edition: _text(item['edition']),
            sourceStatus: _text(item['source_status']),
            builtIn: true,
            contentHash: _text(item['source_sha256']),
            parseStatus: 'verified',
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
    if (systems.isEmpty || books.isEmpty) {
      throw const FormatException('向己知识资产缺少思想体系或书籍来源');
    }
    return XiangjiKnowledgeCatalog(
      version: _text(json['knowledge_version']).isEmpty
          ? 'unknown'
          : _text(json['knowledge_version']),
      title: _text(json['knowledge_title']).isEmpty
          ? '本地目标知识库'
          : _text(json['knowledge_title']),
      systems: systems,
      books: books,
    );
  }

  void _validateV21(XiangjiKnowledgeCatalog catalog) {
    final deepComplete = catalog.systems.every(
      (item) =>
          item.primaryThemes.length == 4 &&
          item.secondaryThemes.length == 3 &&
          item.modules.length == 16 &&
          item.settingSteps.length == 8 &&
          item.practices.length == 6 &&
          item.diagnosticRoutes.length == 6 &&
          item.cases.length == 4,
    );
    if (catalog.defaultLayer != 'mentor_goal_core_v21' ||
        catalog.systems.length != 10 ||
        catalog.primaryThemeCount != 40 ||
        catalog.secondaryThemeCount != 30 ||
        catalog.evidenceCount != 350 ||
        catalog.conciseProfiles.length != 10 ||
        catalog.conciseProfiles.any((item) => !item.defaultHidden) ||
        !deepComplete) {
      throw const FormatException('向己 V2.1 知识资产完整性校验失败');
    }
  }
}

String _text(Object? value) => (value ?? '').toString().trim();

int _integer(Object? value) {
  if (value is int) return value;
  return int.tryParse(_text(value)) ?? 0;
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map(_text)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _jsonStrings(Object? value) {
  if (value is List) return _strings(value);
  final raw = _text(value);
  if (raw.isEmpty) return const <String>[];
  try {
    return _strings(jsonDecode(raw));
  } catch (_) {
    return const <String>[];
  }
}

Map<String, dynamic> _objectMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map(_objectMap)
      .toList(growable: false);
}

String _shortExcerpt(String value, {int maxRunes = 180}) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = normalized.runes.toList(growable: false);
  if (runes.length <= maxRunes) return normalized;
  return '${String.fromCharCodes(runes.take(maxRunes))}…';
}

String _bookTitle(String id) {
  const titles = <String, String>{
    'adler_life_meaning': '《生活对你意味着什么》',
    'adler_understanding': '《理解人性》',
    'aristotle_nicomachean': '《尼各马可伦理学》',
    'carver_scheier_self_regulation': '《行为的自我调节》',
    'dewey_human_nature': '《人性与行为》',
    'epictetus_enchiridion': '《手册》',
    'frankl_search_meaning': '《活出意义来》',
    'frankl_will_meaning': '《追寻意义的意志》',
    'girard_deceit_desire': '《浪漫的谎言与小说的真实》',
    'locke_latham_goal_setting': '《目标设定与任务绩效》',
    'nietzsche_gay_science': '《快乐的科学》',
    'nietzsche_genealogy': '《道德的谱系》',
    'nietzsche_twilight': '《偶像的黄昏》',
    'nietzsche_zarathustra': '《查拉图斯特拉如是说》',
    'positive_psychology_1504': '《积极心理学课程资料》',
  };
  return titles[id] ?? id;
}

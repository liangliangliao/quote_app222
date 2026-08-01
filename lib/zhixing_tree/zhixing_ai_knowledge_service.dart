import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai_assistant/ai_assistant_file_text_extractor.dart';
import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'zhixing_dao.dart';
import 'zhixing_engines.dart';
import 'zhixing_extended_models.dart';
import 'zhixing_models.dart';
import 'zhixing_review_engine.dart';
import 'zhixing_thinker_catalog.dart';

class ZxAiKnowledgeService {
  ZxAiKnowledgeService({
    ZxDao? dao,
    UnifiedAiService? ai,
    GlobalAiSettings? settings,
  })  : _dao = dao ?? ZxDao(),
        _ai = ai ?? UnifiedAiService(),
        _settings = settings ?? GlobalAiSettings();

  static const int maxImportedBytes = 30 * 1024 * 1024;
  static const int maxPromptCharacters = 48000;
  static const int maxAttachedBytes = 12 * 1024 * 1024;

  final ZxDao _dao;
  final UnifiedAiService _ai;
  final GlobalAiSettings _settings;
  final AiAssistantFileTextExtractor _extractor =
      AiAssistantFileTextExtractor();
  final ZxActionGenerator _validator = const ZxActionGenerator();
  final ZxLocalReviewEngine _localReview = const ZxLocalReviewEngine();

  Future<ZxAiBook> importBook({
    required File source,
    required String thinker,
    String title = '',
  }) async {
    if (thinker.trim().isEmpty) {
      throw ArgumentError('请先填写思想家或理论体系名称。');
    }
    if (!await source.exists()) throw ArgumentError('所选著作文件不存在。');
    final size = await source.length();
    if (size <= 0 || size > maxImportedBytes) {
      throw ArgumentError('著作文件需小于30 MB且不能是空文件。');
    }
    final digest = await sha256.bind(source.openRead()).first;
    final sha = digest.toString();
    final existing =
        (await _dao.aiBooks()).where((item) => item.sha256 == sha).toList();
    if (existing.isNotEmpty) return existing.first;

    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(root.path, 'zhixing_tree', 'ai_books'),
    );
    await directory.create(recursive: true);
    final safeName = _safeFileName(p.basename(source.path));
    final storedName = sha.substring(0, 12) + '_' + safeName;
    final destination = File(p.join(directory.path, storedName));
    await source.copy(destination.path);
    final mime = _mimeForName(safeName);
    final extracted = await _extractor.extract(
      destination,
      safeName,
      mimeType: mime,
      sizeBytes: size,
    );
    final draft = ZxAiBook(
      thinker: thinker.trim(),
      title: title.trim().isEmpty
          ? p.basenameWithoutExtension(safeName)
          : title.trim(),
      fileName: safeName,
      localPath: destination.path,
      mimeType: mime,
      byteSize: size,
      sha256: sha,
      extractedCharacters: extracted?.length ?? 0,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final id = await _dao.saveAiBook(draft);
    return (await _dao.aiBooks()).firstWhere(
      (item) => item.id == id,
      orElse: () => draft,
    );
  }

  Future<ZxAiKnowledgeDraft> analyzeAndSave({
    required String thinker,
    required List<ZxAiBook> books,
  }) async {
    if (books.isEmpty) throw ArgumentError('请至少选择一本已保存著作。');
    final state = await _settings.getState();
    if (state['available'] != '1') {
      throw StateError('请先在全局AI设置中配置可用的模型与密钥。');
    }
    final normalizedThinker = thinker.trim().isEmpty
        ? books.map((item) => item.thinker).first
        : thinker.trim();
    final sourceBlocks = <Map<String, Object?>>[];
    final parts = <UnifiedAiContentPart>[];
    var remaining = maxPromptCharacters;
    final perBook =
        math.max(6000, maxPromptCharacters ~/ books.length).toInt();
    for (final book in books) {
      final file = File(book.localPath);
      final extracted = await _extractor.extract(
        file,
        book.fileName,
        mimeType: book.mimeType,
        sizeBytes: book.byteSize,
      );
      if ((extracted ?? '').trim().isNotEmpty && remaining > 0) {
        final allowed = math.min(perBook, remaining);
        final text = _clip(extracted!.trim(), allowed);
        remaining -= text.length;
        sourceBlocks.add(<String, Object?>{
          'book_id': book.id,
          'title': book.title,
          'filename': book.fileName,
          'extracted_text': text,
        });
      }
      if (book.byteSize <= maxAttachedBytes && await file.exists()) {
        final bytes = await file.readAsBytes();
        parts.add(
          UnifiedAiContentPart.fileData(
            filename: book.fileName,
            dataUrl: 'data:' +
                book.mimeType +
                ';base64,' +
                base64Encode(bytes),
            mimeType: book.mimeType,
          ),
        );
      }
    }
    if (sourceBlocks.isEmpty && parts.isEmpty) {
      throw const FormatException('无法从所选文件提取文字，也无法作为模型附件发送。');
    }

    final raw = await _ai.generateChatMessages(
      purpose: 'zhixing_tree.ai_derived_knowledge',
      maxTokens: 4200,
      temperature: 0.1,
      messages: <UnifiedAiChatMessage>[
        const UnifiedAiChatMessage(
          role: 'system',
          content: _knowledgeSystemPrompt,
        ),
        UnifiedAiChatMessage(
          role: 'user',
          content: jsonEncode(<String, Object?>{
            'thinker': normalizedThinker,
            'books': books
                .map(
                  (item) => <String, Object?>{
                    'id': item.id,
                    'title': item.title,
                    'filename': item.fileName,
                  },
                )
                .toList(growable: false),
            'extracted_sources': sourceBlocks,
          }),
          parts: parts,
        ),
      ],
    );
    final map = _parseObject(raw);
    if (map == null) throw const FormatException('AI没有返回有效JSON对象。');
    final draft = ZxAiKnowledgeDraft.fromAiJson(
      map,
      thinker: normalizedThinker,
      bookIds: books.map((item) => item.id).toList(growable: false),
      provider: state['provider'] ?? '',
      modelLabel: state['label'] ?? state['model'] ?? '',
    );
    final id = await _dao.saveAiKnowledgeDraft(draft);
    return await _dao.aiKnowledgeDraft(id) ?? draft;
  }

  Future<ZxActionPrescription> generateAction({
    required ZxAiKnowledgeDraft knowledge,
    required ZxActionPrescription localBaseline,
    required ZxSituationInput input,
    required ZxDiagnosisResult diagnosis,
  }) async {
    if (!diagnosis.safety.actionAllowed) return localBaseline;
    final state = await _settings.getState();
    if (state['available'] != '1') {
      throw StateError('AI当前不可用，已保留本地规则版行动。');
    }
    final raw = await _ai.generateText(
      purpose: 'zhixing_tree.ai_derived_action',
      systemPrompt: _actionSystemPrompt,
      maxTokens: 1300,
      expectJson: true,
      temperature: 0.15,
      prompt: jsonEncode(<String, Object?>{
        'ai_derived_knowledge': knowledge.toMap(),
        'user_goal_and_steps': input.toJson(),
        'local_safety_baseline': localBaseline.toJson(),
        'safety': diagnosis.safety.toJson(),
      }),
    );
    final map = _parseObject(raw);
    if (map == null) throw const FormatException('AI行动方案不是有效JSON。');
    String value(String key, String fallback) {
      final text = (map[key] ?? '').toString().trim();
      return text.isEmpty ? fallback : text;
    }
    final candidate = ZxActionPrescription(
      id: localBaseline.id,
      goalId: localBaseline.goalId,
      goalTitle: localBaseline.goalTitle,
      targetBehavior: localBaseline.targetBehavior,
      primaryLensId: localBaseline.primaryLensId,
      complementaryLensId: localBaseline.complementaryLensId,
      primaryBarrier: localBaseline.primaryBarrier,
      stage: localBaseline.stage,
      difficulty: localBaseline.difficulty,
      risk: localBaseline.risk,
      thoughtLens: value('thought_lens', knowledge.actionView),
      mainAction: value('main_action', localBaseline.mainAction),
      lowerLoadAlternative: value(
        'lower_load_alternative',
        localBaseline.lowerLoadAlternative,
      ),
      challengeAlternative: value(
        'challenge_alternative',
        localBaseline.challengeAlternative,
      ),
      cue: value('cue', localBaseline.cue),
      response: value('main_action', localBaseline.response),
      supportChanges: _stringList(map['support_changes']).isEmpty
          ? localBaseline.supportChanges
          : _stringList(map['support_changes']),
      stopConditions: localBaseline.stopConditions,
      proofOptions: localBaseline.proofOptions,
      completionDefinition: value(
        'completion_definition',
        localBaseline.completionDefinition,
      ),
      reviewQuestion: value(
        'review_question',
        localBaseline.reviewQuestion,
      ),
      evidenceLocators: localBaseline.evidenceLocators,
      uncertainty: math.max(localBaseline.uncertainty, 0.35),
      guidanceOrigin: 'ai_derived',
      guidanceKnowledgeRefId: knowledge.id,
      aiProvider: state['provider'] ?? knowledge.provider,
      aiModelLabel: state['label'] ?? knowledge.modelLabel,
      status: localBaseline.status,
      createdAtMs: localBaseline.createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final issues = _validator.validate(candidate);
    if (issues.isNotEmpty) {
      throw FormatException('AI方案未通过本地安全结构校验：' + issues.join('；'));
    }
    return candidate;
  }

  Future<ZxReviewReport> generateReviewReport({
    required ZxAiKnowledgeDraft knowledge,
    required ZxActionPrescription action,
    required ZxReviewInput review,
  }) async {
    final localFallback = _localReview.generate(action: action, review: review);
    final state = await _settings.getState();
    if (state['available'] != '1') return localFallback;
    final catalog = ZxThinkerCatalog.guides
        .map(
          (guide) => <String, Object?>{
            'system_id': guide.systemId,
            'name': guide.displayName,
            'decision_cue': guide.decisionCue,
            'yangming_connection': guide.yangmingConnection,
          },
        )
        .toList(growable: false);
    try {
      final raw = await _ai.generateText(
        purpose: 'zhixing_tree.ai_derived_review',
        systemPrompt: _reviewSystemPrompt,
        maxTokens: 1500,
        expectJson: true,
        temperature: 0.1,
        prompt: jsonEncode(<String, Object?>{
          'ai_derived_knowledge': knowledge.toMap(),
          'action': action.toJson(),
          'feedback': review.toJson(),
          'reviewed_local_catalog_for_recommendation': catalog,
          'local_report_fallback': localFallback.toMap(),
        }),
      );
      final map = _parseObject(raw);
      if (map == null) return localFallback;
      final decision =
          ZxReviewDecisionX.parse(map['recommended_decision']);
      final validIds = _stringList(map['recommended_system_ids'])
          .where(
            (id) =>
                ZxThinkerCatalog.guides.any((guide) => guide.systemId == id),
          )
          .take(3)
          .toList(growable: false);
      String value(String key, String fallback) {
        final text = (map[key] ?? '').toString().trim();
        return text.isEmpty ? fallback : text;
      }
      return ZxReviewReport(
        actionUid: action.id,
        origin: ZxKnowledgeOrigin.aiDerived,
        knowledgeRefId: knowledge.id,
        summary: value('summary', localFallback.summary),
        progressEvidence:
            value('progress_evidence', localFallback.progressEvidence),
        barrierFinding:
            value('barrier_finding', localFallback.barrierFinding),
        recommendedDecision: decision,
        currentSystemId: localFallback.currentSystemId,
        recommendedSystemIds:
            validIds.isEmpty ? localFallback.recommendedSystemIds : validIds,
        rationale: value('rationale', localFallback.rationale),
        nextAction: value('next_action', localFallback.nextAction),
        provider: state['provider'] ?? '',
        modelLabel: state['label'] ?? state['model'] ?? '',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return localFallback;
    }
  }

  static Map<String, dynamic>? _parseObject(String raw) {
    final text = raw.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  String _clip(String text, int length) =>
      text.length <= length ? text : text.substring(0, length);

  String _safeFileName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9A-Za-z\u4e00-\u9fff._-]'), '_');
    return cleaned.isEmpty ? 'book.txt' : cleaned;
  }

  String _mimeForName(String name) {
    final ext = p.extension(name).toLowerCase();
    const map = <String, String>{
      '.pdf': 'application/pdf',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.doc': 'application/msword',
      '.epub': 'application/epub+zip',
      '.mobi': 'application/x-mobipocket-ebook',
      '.azw': 'application/vnd.amazon.ebook',
      '.azw3': 'application/vnd.amazon.ebook',
      '.fb2': 'application/xml',
      '.rtf': 'application/rtf',
      '.txt': 'text/plain',
      '.md': 'text/markdown',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  static const String _knowledgeSystemPrompt = '''
你是“知行树”的著作研究助手。只依据用户上传的著作附件和提取文字，围绕“知行合一如何理解、如何行动、如何由行动反馈深化认识”进行跨书统一归纳。同一作者的多本书必须融合为一套体系，不按书割裂。

要求：
1. 清楚区分作者原意、你的归纳和产品化行动解释；不虚构引文、页码或出处。
2. 只做摘要与归纳，不输出长篇原文，不把医疗诊断或治疗建议包装成行动指导。
3. 以王阳明知行合一为主轴，写清共同点、差异、承接关系和带来的认识跃迁。
4. 核心价值至少4条，核心思想至少8条；行动路径必须具体，可用于目标转化和行动复盘。
5. 只输出一个JSON对象，不要Markdown、代码块或额外说明。

JSON字段：
{
  "thinker": "思想家或理论体系",
  "title": "融合后的思想体系名称",
  "core_values": ["价值1"],
  "core_ideas": ["完整思想1"],
  "knowledge_view": "怎样理解知",
  "action_view": "怎样理解行",
  "transformation_path": "从认识到行动再到反馈深化的完整路径",
  "decision_cue": "什么情况下适合选用",
  "yangming_connection": "与王阳明知行合一的承接、互补和质变",
  "common_ground": ["共同点1"],
  "differences": ["差异1"],
  "boundaries": ["适用边界或证据限制1"]
}
''';

  static const String _actionSystemPrompt = '''
你是知行树行动导师。依据指定的AI派生思想体系，把用户目标或已有具体步骤转成一个现在可执行的行动。AI派生知识不能改写本地审核知识；本地安全边界、停止条件和风险等级不可放宽。不要诊断疾病，不要增加问卷。

只输出JSON：
{
  "thought_lens":"本思想如何指导这一步",
  "main_action":"一个具体、可见、可在给定时间内完成的动作",
  "lower_load_alternative":"负荷过高时更小但仍有效的动作",
  "challenge_alternative":"条件充分时的升级动作",
  "cue":"何时何地触发",
  "support_changes":["一个环境支持"],
  "completion_definition":"可观察完成标准",
  "review_question":"完成后一个关键复盘问题"
}
''';

  static const String _reviewSystemPrompt = '''
你是知行树复盘导师。只根据实际行动反馈、选中的AI派生思想和本地审核思想目录，生成简短报告。不得把未发生的行动写成事实。判断应为continue、switch或blend；推荐思想ID只能来自本地目录。复盘用于调整下一轮，不是诊断疾病。

只输出JSON：
{
  "summary":"本轮一句话总结",
  "progress_evidence":"实际形成的行动证据",
  "barrier_finding":"最关键阻碍或有效条件",
  "recommended_decision":"continue|switch|blend",
  "recommended_system_ids":["本地目录system_id"],
  "rationale":"为什么继续、切换或融合",
  "next_action":"下一轮最小动作"
}
''';
}

import 'dart:convert';

import '../../concept_engine_service.dart';
import '../models/action_engine_models.dart';

class ActionEngineRepository {
  ActionEngineRepository({ConceptEngineService? service}) : _service = service ?? ConceptEngineService();

  final ConceptEngineService _service;

  static final Map<String, ActionConcept> _concepts = {
    for (final raw in _builtinConcepts)
      ActionConcept.fromJson(jsonDecode(raw) as Map<String, dynamic>).concept:
          ActionConcept.fromJson(jsonDecode(raw) as Map<String, dynamic>),
  };

  List<String> get recommendedConcepts => ['责任感', '边界感', '自律'];

  ActionConcept? getConcept(String concept) {
    final normalized = concept.trim();
    if (_concepts.containsKey(normalized)) return _concepts[normalized];
    for (final entry in _concepts.entries) {
      if (entry.key.contains(normalized) || normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  List<ActionConcept> listConcepts() => _concepts.values.toList();

  Future<ActionConcept> generateConceptTree({
    required String concept,
    required String goal,
    required String domain,
    List<String> dimensions = const [],
    String? sessionId,
  }) async {
    final normalizedConcept = concept.trim();
    final normalizedGoal = goal.trim();
    final normalizedDomain = domain.trim().isEmpty ? '日常' : domain.trim();
    final cleanDimensions = dimensions.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    try {
      final generated = await _service.generateActionConceptTreeOverview(
        concept: normalizedConcept,
        goal: normalizedGoal,
        domain: normalizedDomain,
        dimensions: cleanDimensions,
        sessionId: sessionId,
      );
      return _normalizeGeneratedConcept(generated, normalizedConcept, normalizedGoal, normalizedDomain, cleanDimensions);
    } catch (_) {
      final builtin = getConcept(normalizedConcept);
      if (builtin != null) {
        return _normalizeGeneratedConcept(
          ActionConcept(
            concept: builtin.concept,
            shortDescription: builtin.shortDescription,
            directions: builtin.directions,
            dimensions: cleanDimensions,
            generatedByAi: false,
            generationNote: 'AI 生成失败，已切换到内置行动树。',
          ),
          normalizedConcept,
          normalizedGoal,
          normalizedDomain,
          cleanDimensions,
        );
      }
      return _buildFallbackConcept(
        concept: normalizedConcept,
        goal: normalizedGoal,
        domain: normalizedDomain,
        dimensions: cleanDimensions,
      );
    }
  }



  Future<ActionDirection> expandDirection({
    required ActionConcept concept,
    required ActionDirection direction,
    required String goal,
    required String domain,
    String? sessionId,
  }) async {
    try {
      final expanded = await _service.expandActionDirection(
        concept: concept.concept,
        goal: goal,
        domain: domain,
        dimensions: concept.dimensions,
        direction: direction,
        sessionId: sessionId,
      );
      return _normalizeExpandedDirection(expanded, concept.concept, direction.title);
    } catch (_) {
      return _normalizeExpandedDirection(_fallbackExpandDirection(concept.concept, direction), concept.concept, direction.title);
    }
  }


  Future<ActionDirection> expandDirectionMorePaths({
    required ActionConcept concept,
    required ActionDirection direction,
    required String goal,
    required String domain,
    String? sessionId,
  }) async {
    try {
      final expanded = await _service.expandActionDirectionMorePaths(
        concept: concept.concept,
        goal: goal,
        domain: domain,
        dimensions: concept.dimensions,
        direction: direction,
        sessionId: sessionId,
      );
      return _mergeDirectionPaths(
        _normalizeExpandedDirection(direction, concept.concept, direction.title),
        _normalizeExpandedDirection(expanded, concept.concept, direction.title),
        concept.concept,
      );
    } catch (_) {
      return _mergeDirectionPaths(
        _normalizeExpandedDirection(direction, concept.concept, direction.title),
        _fallbackMorePaths(concept.concept, direction),
        concept.concept,
      );
    }
  }

  Future<List<ActionStep>> expandCustomStep({
    required ActionConcept concept,
    required String goal,
    required String domain,
    required String customStep,
    String? sessionId,
  }) async {
    try {
      final steps = await _service.expandCustomActionStep(
        concept: concept.concept,
        goal: goal,
        domain: domain,
        dimensions: concept.dimensions,
        customStep: customStep,
        sessionId: sessionId,
      );
      if (steps.isNotEmpty) return _normalizeExpandedSteps(steps, concept.concept, directionTitle: customStep, directionDescription: 'custom');
    } catch (_) {}
    return [
      ActionStep(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}_1',
        text: customStep,
        isCustom: true,
        minimalVersion: customStep,
        tags: const ['custom'],
      ),
      ActionStep(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}_2',
        text: '把这一步再拆成一个最小动作后先执行那个最小动作。',
        isCustom: true,
        minimalVersion: '先做最小动作。',
        tags: const ['custom', 'breakdown'],
      ),
      ActionStep(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}_3',
        text: '执行后用一句话记录结果，再决定下一步。',
        isCustom: true,
        minimalVersion: '先记一句结果。',
        tags: const ['custom', 'review'],
      ),
    ];
  }

  

  String _directionRealityMeaning({
    required String concept,
    required String directionTitle,
    required String description,
    String? existing,
  }) {
    if ((existing ?? '').trim().isNotEmpty) return existing!.trim();
    final title = directionTitle.trim().isEmpty ? concept : directionTitle.trim();
    return '“$title”这一层，不是在想法里重复“$concept”，而是让“$concept”开始在现实里发生：有人会做出一个动作、推进一次表达，或留下一个能看见的结果。';
  }

  List<String> _directionObservableChanges({
    required String concept,
    required String directionTitle,
    required String goal,
    List<String> existing = const [],
  }) {
    if (existing.where((e) => e.trim().isNotEmpty).isNotEmpty) {
      return existing.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
    }
    final title = directionTitle.trim().isEmpty ? concept : directionTitle.trim();
    return [
      '和“$title”相关的现实动作会在今天真正发生一次，而不是停在“应该做”。',
      '会出现一个看得见的痕迹，例如一条消息、一条记录、一个已打开的入口，或一个已完成的小闭环。',
      goal.trim().isNotEmpty ? '它会把你当前的目标“$goal”往前推进一点，而不是只增加理解。' : '它会把“$concept”从抽象期待压成能看见变化的现实动作。',
    ];
  }

  String _directionExperienceFact({
    required String concept,
    required String directionTitle,
    required String goal,
    String? existing,
  }) {
    if ((existing ?? '').trim().isNotEmpty) return existing!.trim();
    final title = directionTitle.trim().isEmpty ? concept : directionTitle.trim();
    if (goal.trim().isNotEmpty) {
      return '当“$title”真的成立时，你会看到一个具体事实：今天已经有人把这件事做出来了，当前目标“$goal”已经因此往前推进，并且留下了可见结果。';
    }
    return '当“$title”真的成立时，你会看到一个具体事实：今天已经有人把这件事做出来了，并留下一个可见结果，而不是只停在想法里。';
  }

  String _directionFactDoneSignal({
    required String concept,
    required String directionTitle,
    String? existing,
  }) {
    if ((existing ?? '').trim().isNotEmpty) return existing!.trim();
    final title = directionTitle.trim().isEmpty ? concept : directionTitle.trim();
    return '你已经能指出一个与“$title”相关的现实结果：一条消息已发出、一条记录已写下、一个入口已打开，或一个小闭环已完成。';
  }

  ActionModule _normalizeModuleWithMeaning(
    ActionModule module, {
    required String concept,
    required String directionTitle,
    required String directionDescription,
    required String goal,
    required String fallbackId,
  }) {
    final title = module.title.isEmpty ? '可执行模块' : module.title;
    final steps = module.steps.isEmpty
        ? _buildConcreteSeedSteps(
            concept: concept,
            directionTitle: directionTitle,
            goal: goal,
            idPrefix: '${fallbackId}_auto_',
          )
        : _normalizeExpandedSteps(
            module.steps,
            concept,
            directionTitle: directionTitle,
            directionDescription: directionDescription,
          );
    return ActionModule(
      id: module.id.isEmpty ? fallbackId : module.id,
      title: title,
      realityMeaning: module.realityMeaning.trim().isNotEmpty
          ? module.realityMeaning.trim()
          : '这一层不是继续谈“$concept”，而是把“$title”压成现实里真的会发生的动作、表达或推进。',
      observableChanges: module.observableChanges.where((e) => e.trim().isNotEmpty).isNotEmpty
          ? module.observableChanges.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList()
          : [
              '会出现一个可观察变化：有人开始做这件事，而不是只想做。',
              '会留下一点现实痕迹，例如已打开入口、已发出消息、已写下一句记录，或已完成一个小闭环。',
              goal.trim().isNotEmpty ? '目标“$goal”会因此往前推进一点。' : '现实会因此出现一点推进。'
            ],
      experienceFact: module.experienceFact.trim().isNotEmpty
          ? module.experienceFact.trim()
          : '把“$title”压到最后，应当变成一个可以直接想象的经验事实：今天这件事已经发生了，并且留下了可见结果。',
      factDoneSignal: module.factDoneSignal.trim().isNotEmpty
          ? module.factDoneSignal.trim()
          : '做到这一步时，你已经能指出一个与“$title”相关的真实结果，例如一条记录、一条消息、一个已打开入口，或一个已完成的小动作。',
      steps: steps,
    );
  }
ActionConcept _normalizeGeneratedConcept(
    ActionConcept concept,
    String rawConcept,
    String goal,
    String domain,
    List<String> dimensions,
  ) {
    final dirs = List<ActionDirection>.from(concept.directions);
    final usedIds = dirs.map((e) => e.id).toSet();
    final fallback = _fallbackDirections(rawConcept, goal, domain, dimensions);
    for (final d in fallback) {
      if (dirs.length >= 10) break;
      if (usedIds.add(d.id)) dirs.add(d);
    }
    final normalizedDirs = <ActionDirection>[];
    for (var i = 0; i < dirs.length; i++) {
      final d = dirs[i];
      final keepCollapsed = concept.generatedByAi && d.needsExpansion && d.modules.isEmpty;
      final modules = keepCollapsed
          ? <ActionModule>[]
          : (d.modules.isEmpty
              ? [
                  _normalizeModuleWithMeaning(
                    ActionModule(
                      id: '${d.id}_module_1',
                      title: '让经验事实发生的动作',
                      steps: _buildConcreteSeedSteps(
                        concept: rawConcept,
                        directionTitle: d.title,
                        goal: goal,
                        idPrefix: '${d.id}_seed_',
                      ),
                    ),
                    concept: rawConcept,
                    directionTitle: d.title,
                    directionDescription: d.description,
                    goal: goal,
                    fallbackId: '${d.id}_module_1',
                  ),
                ]
              : d.modules
                  .map((m) => _normalizeModuleWithMeaning(
                        ActionModule(
                          id: m.id.isEmpty ? '${d.id}_module_auto' : m.id,
                          title: m.title.isEmpty ? '让经验事实发生的动作' : m.title,
                          realityMeaning: m.realityMeaning,
                          observableChanges: m.observableChanges,
                          experienceFact: m.experienceFact,
                          factDoneSignal: m.factDoneSignal,
                          steps: m.steps.isEmpty
                              ? _buildConcreteSeedSteps(
                                  concept: rawConcept,
                                  directionTitle: d.title,
                                  goal: goal,
                                  idPrefix: '${d.id}_auto_',
                                )
                              : _normalizeExpandedSteps(m.steps, rawConcept, directionTitle: d.title, directionDescription: d.description),
                        ),
                        concept: rawConcept,
                        directionTitle: d.title,
                        directionDescription: d.description,
                        goal: goal,
                        fallbackId: m.id.isEmpty ? '${d.id}_module_auto' : m.id,
                      ))
                  .toList());
      normalizedDirs.add(ActionDirection(
        id: d.id.isEmpty ? 'dir_${i + 1}' : d.id,
        title: d.title.isEmpty ? '行动 ${i + 1}' : d.title,
        description: d.description.isEmpty ? '这是一条现实行动方案，不是抽象原则；它会把“${d.title.isEmpty ? rawConcept : d.title}”压成今天就能发生的现实事实。' : d.description,
        realityMeaning: _directionRealityMeaning(
          concept: rawConcept,
          directionTitle: d.title.isEmpty ? '行动 ${i + 1}' : d.title,
          description: d.description,
          existing: d.realityMeaning,
        ),
        observableChanges: _directionObservableChanges(
          concept: rawConcept,
          directionTitle: d.title.isEmpty ? '行动 ${i + 1}' : d.title,
          goal: goal,
          existing: d.observableChanges,
        ),
        experienceFact: _directionExperienceFact(
          concept: rawConcept,
          directionTitle: d.title.isEmpty ? '行动 ${i + 1}' : d.title,
          goal: goal,
          existing: d.experienceFact,
        ),
        factDoneSignal: _directionFactDoneSignal(
          concept: rawConcept,
          directionTitle: d.title.isEmpty ? '行动 ${i + 1}' : d.title,
          existing: d.factDoneSignal,
        ),
        modules: modules,
        needsExpansion: d.needsExpansion && modules.isEmpty,
        previewModuleCount: d.previewModuleCount > 0 ? d.previewModuleCount : 1,
        previewStepCount: d.previewStepCount > 0 ? d.previewStepCount : 3,
      ));
    }
    return ActionConcept(
      concept: concept.concept.isEmpty ? rawConcept : concept.concept,
      shortDescription: concept.shortDescription.isEmpty
          ? '把“$rawConcept”从不同维度拆成多条现实行动路径，并继续细化为可执行动作。'
          : concept.shortDescription,
      directions: normalizedDirs,
      dimensions: dimensions.isEmpty ? concept.dimensions : dimensions,
      generatedByAi: concept.generatedByAi || concept.generationNote.isNotEmpty,
      generationNote: concept.generationNote,
    );
  }



  ActionDirection _normalizeExpandedDirection(ActionDirection direction, String concept, String fallbackTitle) {
    final modules = direction.modules.isEmpty
        ? _fallbackExpandDirection(concept, direction).modules
        : direction.modules
            .map((m) => _normalizeModuleWithMeaning(
                  ActionModule(
                    id: m.id.isEmpty ? '${direction.id}_module_auto' : m.id,
                    title: m.title.isEmpty ? '让经验事实发生的动作' : m.title,
                    realityMeaning: m.realityMeaning,
                    observableChanges: m.observableChanges,
                    experienceFact: m.experienceFact,
                    factDoneSignal: m.factDoneSignal,
                    steps: _normalizeExpandedSteps(m.steps, concept, directionTitle: direction.title, directionDescription: direction.description),
                  ),
                  concept: concept,
                  directionTitle: direction.title,
                  directionDescription: direction.description,
                  goal: '',
                  fallbackId: m.id.isEmpty ? '${direction.id}_module_auto' : m.id,
                ))
            .toList();
    return ActionDirection(
      id: direction.id.isEmpty ? 'expanded_${DateTime.now().millisecondsSinceEpoch}' : direction.id,
      title: direction.title.isEmpty ? fallbackTitle : direction.title,
      description: direction.description.isEmpty ? '这是一条现实行动方案：继续往下压，会落到今天就能发生的经验事实。' : direction.description,
      realityMeaning: _directionRealityMeaning(
        concept: concept,
        directionTitle: direction.title.isEmpty ? fallbackTitle : direction.title,
        description: direction.description,
        existing: direction.realityMeaning,
      ),
      observableChanges: _directionObservableChanges(
        concept: concept,
        directionTitle: direction.title.isEmpty ? fallbackTitle : direction.title,
        goal: '',
        existing: direction.observableChanges,
      ),
      experienceFact: _directionExperienceFact(
        concept: concept,
        directionTitle: direction.title.isEmpty ? fallbackTitle : direction.title,
        goal: '',
        existing: direction.experienceFact,
      ),
      factDoneSignal: _directionFactDoneSignal(
        concept: concept,
        directionTitle: direction.title.isEmpty ? fallbackTitle : direction.title,
        existing: direction.factDoneSignal,
      ),
      modules: modules,
      needsExpansion: false,
      previewModuleCount: 0,
      previewStepCount: 0,
    );
  }


  List<ActionStep> _normalizeExpandedSteps(List<ActionStep> steps, String concept, {String? directionTitle, String? directionDescription}) {
    if (steps.isEmpty) {
      return _buildConcreteSeedSteps(
        concept: concept,
        directionTitle: directionTitle ?? '',
        goal: '',
        idPrefix: 'auto_${DateTime.now().millisecondsSinceEpoch}_',
      );
    }
    return List<ActionStep>.generate(steps.length, (i) {
      final s = steps[i];
      final normalizedText = s.text.isEmpty ? '把这一步改成一个现实动作并执行。' : s.text;
      var imp = ['normal', 'important', 'critical'].contains(s.importance) ? s.importance : 'normal';
      var cabin = s.linkedCabinType;
      final inferred = _inferStepAssist(
        concept: concept,
        directionTitle: directionTitle ?? '',
        directionDescription: directionDescription ?? '',
        stepText: normalizedText,
        existingImportance: imp,
        existingCabinType: cabin,
        tags: s.tags,
      );
      imp = inferred['importance'] as String;
      cabin = inferred['linkedCabinType'] as String?;
      return ActionStep(
        id: s.id.isEmpty ? 'step_${i + 1}' : s.id,
        text: normalizedText,
        isCustom: s.isCustom,
        minimalVersion: (s.minimalVersion?.isNotEmpty == true) ? s.minimalVersion : _buildMinimalVersion(normalizedText),
        tags: s.tags,
        importance: imp,
        linkedCabinType: imp == 'normal' ? null : cabin,
        directInstruction: (s.directInstruction?.isNotEmpty == true) ? s.directInstruction : _buildDirectInstruction(normalizedText),
        executionHint: (s.executionHint?.isNotEmpty == true) ? s.executionHint : _buildExecutionHint(normalizedText, directionTitle ?? ''),
        doneSignal: (s.doneSignal?.isNotEmpty == true) ? s.doneSignal : _buildDoneSignal(normalizedText),
        example: (s.example?.isNotEmpty == true) ? s.example : _buildExample(normalizedText, directionTitle ?? ''),
      );
    });
  }





  String _buildMinimalVersion(String text) {
    if (text.contains('发')) return '先发出一条最短版本。';
    if (text.contains('写')) return '先写出一句最短版本。';
    if (text.contains('打开')) return '先打开对应页面或文件。';
    if (text.contains('列出')) return '先列出 1 个最关键点。';
    return '先做一个 1-3 分钟内能完成的最小动作。';
  }

  String _buildDirectInstruction(String text) {
    if (text.contains('发')) return '现在就打开对应聊天窗口或邮件页面，按这一步发出去。';
    if (text.contains('写')) return '现在打开备忘录、聊天框或文档，把这一步先写出来。';
    if (text.contains('列出')) return '现在拿出手机备忘录，直接列出内容，不要先想很久。';
    if (text.contains('打开')) return '现在立刻打开对应页面或工具，不要继续停留在思考。';
    return '现在就按这一步直接动手，不再继续想更完美的版本。';
  }

  String _buildExecutionHint(String text, String directionTitle) {
    if (text.contains('发')) return '顺序建议：打开页面 → 输入短版内容 → 检查对象 → 发送。';
    if (text.contains('写')) return '顺序建议：先写第一句 → 再补一个事实或动作 → 不满意也先保留。';
    if (text.contains('列出')) return '顺序建议：先写最关键的一项，再补第二项，不要一次想全。';
    if (directionTitle.contains('边界')) return '表达时先短句、先清楚，不要一开始就解释很多。';
    if (directionTitle.contains('启动') || directionTitle.contains('自律')) return '优先把步骤压缩到 3 分钟内能启动，不追求完整。';
    return '先把这一步做出来，再决定要不要优化顺序和细节。';
  }

  String _buildDoneSignal(String text) {
    if (text.contains('发')) return '你已经点下发送，或内容已经进入对方可见的地方。';
    if (text.contains('写')) return '屏幕上已经出现可读的一句话或一小段，不再只是脑内想。';
    if (text.contains('列出')) return '你已经列出了至少 1-3 个具体点。';
    if (text.contains('打开')) return '相关页面、文档或工具已经真正打开。';
    return '这一步有可见结果，别人或你自己都能看见它已经发生。';
  }

  String _buildExample(String text, String directionTitle) {
    if (directionTitle.contains('汇报') || text.contains('延期') || text.contains('领导')) {
      return '例：先发一条短版说明：项目比原计划晚 1 天，我今天 18 点前补发修复安排。';
    }
    if (directionTitle.contains('边界') || text.contains('拒绝')) {
      return '例：我理解你现在着急，但这件事我这次不能接；我能帮你的是看 10 分钟。';
    }
    if (directionTitle.contains('自律') || text.contains('开始')) {
      return '例：现在先打开资料，只做 3 分钟，不要求学完。';
    }
    return '例：把这一步压缩成一句今天就能做的话，然后立刻做。';
  }

  List<ActionStep> _buildConcreteSeedSteps({
    required String concept,
    required String directionTitle,
    required String goal,
    required String idPrefix,
  }) {
    final src = '$concept $directionTitle $goal';
    bool hasAny(List<String> terms) => terms.any((t) => src.contains(t));
    if (hasAny(['学习', '成长', '习惯', '课程', '资料', '英语', '技能'])) {
      return [
        ActionStep(
          id: '${idPrefix}1',
          text: '先定下今天这一轮学习真正开始的时间，并把学习入口准备好。',
          minimalVersion: '先把今天的学习时间写进闹钟或日历。',
          directInstruction: '现在打开闹钟或日历，定一个今天能开始的时间，例如今晚 8:00；同时把课程、书或资料入口放到能一键打开的位置。',
          executionHint: '顺序：定时间 → 打开学习入口 → 不再继续挑内容。',
          doneSignal: '闹钟或日历里已有开始时间，课程/资料入口已经准备好。',
          example: '例：把“今晚 8:00 学 10 分钟英语课程”写进日历，并提前打开课程页面。',
        ),
        ActionStep(
          id: '${idPrefix}2',
          text: '到时间后直接开始 10 分钟，不要求学完，只要求开始并持续到计时结束。',
          minimalVersion: '先学 3 分钟。',
          directInstruction: '到点后立刻打开资料或课程，开始 10 分钟计时；中途不要切到别的应用。',
          executionHint: '顺序：打开资料 → 开始计时 → 只做这一轮 10 分钟。',
          doneSignal: '你已经连续学习了这一轮时间，计时器结束。',
          example: '例：20:00 开始听课程 10 分钟，不要求今天学完。',
        ),
        ActionStep(
          id: '${idPrefix}3',
          text: '结束后留下一个看得见的学习痕迹，例如一句总结、一个要点或一张记录。',
          minimalVersion: '先写一句今天学到了什么。',
          directInstruction: '学习结束后立刻在便签、Notion 或纸上写 1 句总结。',
          executionHint: '不要评价学得好不好，只留下一个可见结果。',
          doneSignal: '已经写下一句总结或记录，明天可以接着继续。',
          example: '例：在便签里写“今天学会了现在完成时的基本用法”。',
        ),
      ];
    }
    if (hasAny(['边界', '拒绝', '范围', '拉扯'])) {
      return [
        ActionStep(
          id: '${idPrefix}1',
          text: '先把你这次真正不能答应的那一部分写清楚。',
          minimalVersion: '先写一句不能答应的点。',
          directInstruction: '现在在备忘录里写一句“这次我不能答应的是……”。',
          executionHint: '先写边界本身，不急着解释原因。',
          doneSignal: '你已经写出边界句，而不是只在脑子里纠结。',
          example: '例：这次我不能接完整方案，但我可以帮你看 10 分钟。',
        ),
        ActionStep(
          id: '${idPrefix}2',
          text: '把这句话压缩成一条可以直接发出去或当面说出来的短句。',
          minimalVersion: '先写短版表达。',
          directInstruction: '把长句改成一条 1-2 句的短版边界表达。',
          executionHint: '先表达理解，再清楚说边界，不要一开始解释很多。',
          doneSignal: '屏幕上已经有一条可以直接使用的边界表达。',
          example: '例：我理解你现在很着急，但这部分我这次不能接。',
        ),
        ActionStep(
          id: '${idPrefix}3',
          text: '如果你愿意保留支持，就只写出你能做到的范围。',
          minimalVersion: '先写一条可接受的支持范围。',
          directInstruction: '在边界句后面补一句“我能做到的是……”。',
          executionHint: '范围越具体越好，不要写成无限支持。',
          doneSignal: '你已经明确区分了不能做的部分和能做的部分。',
          example: '例：我不能替你做完，但我可以帮你看 10 分钟。',
        ),
      ];
    }
    if (hasAny(['责任', '汇报', '延期', '领导', '客户', '说明'])) {
      return [
        ActionStep(
          id: '${idPrefix}1',
          text: '先写一条短版说明，把当前状态和偏差直接说出来。',
          minimalVersion: '先写一句当前状态。',
          directInstruction: '现在打开聊天窗口或备忘录，先写一句“当前进度/偏差是什么”。',
          executionHint: '先写状态，不要先写很多原因。',
          doneSignal: '你已经写出一条可读的短版状态说明。',
          example: '例：项目比原计划晚 1 天，目前还差测试和最终确认。',
        ),
        ActionStep(
          id: '${idPrefix}2',
          text: '在下一句里补上影响范围和下一次更新时间。',
          minimalVersion: '先写影响和更新时间。',
          directInstruction: '在状态说明后面补一句“影响到什么、下次几点更新”。',
          executionHint: '影响范围越具体越好，更新时间最好明确到今天几点。',
          doneSignal: '你的说明里已经有状态、影响和更新时间。',
          example: '例：会影响到明天下午的提测，我今天 18 点前再更新一次安排。',
        ),
        ActionStep(
          id: '${idPrefix}3',
          text: '把短版说明发出去，或先发给自己做最后确认。',
          minimalVersion: '先发给自己确认一遍。',
          directInstruction: '现在先发给自己或直接发给对方，不再继续拖着不发。',
          executionHint: '先短版发出，再决定是否补充细节。',
          doneSignal: '消息已经真正发出，或至少已经进入可发送状态。',
          example: '例：先发短版说明，晚些再补完整修复安排。',
        ),
      ];
    }
    if (hasAny(['自律', '启动', '拖延', '开始'])) {
      return [
        ActionStep(
          id: '${idPrefix}1',
          text: '先去掉一个最影响开始的干扰源。',
          minimalVersion: '先关掉一个干扰。',
          directInstruction: '现在先关掉一个最强干扰，例如短视频、聊天提醒或无关网页。',
          executionHint: '一次只处理一个干扰源，别想全部清空。',
          doneSignal: '一个最强干扰源已经被关掉。',
          example: '例：先退出短视频应用，把手机调成勿扰。',
        ),
        ActionStep(
          id: '${idPrefix}2',
          text: '把第一步压缩成 3 分钟内能开始的动作。',
          minimalVersion: '先做 3 分钟。',
          directInstruction: '现在直接打开任务入口，只做 3 分钟，不要求做完。',
          executionHint: '重点是开始，不是把整件事完成。',
          doneSignal: '你已经开始第一轮 3 分钟动作。',
          example: '例：打开资料，只看 3 分钟。',
        ),
        ActionStep(
          id: '${idPrefix}3',
          text: '结束这一小轮后，立刻决定下一步，不做长时间评判。',
          minimalVersion: '先写下一步。',
          directInstruction: '3 分钟结束后，马上写下一步是什么。',
          executionHint: '下一步越小越容易继续。',
          doneSignal: '你已经写出下一步，而不是停在“等会再说”。',
          example: '例：下一步继续看 5 分钟，或者写一句总结。',
        ),
      ];
    }
    return [
      ActionStep(
        id: '${idPrefix}1',
        text: '先把这件事压成今天真的会发生的一个动作。',
        minimalVersion: '先写一句今天会发生的动作。',
        directInstruction: '现在把这件事改写成一句带时间、对象或结果的现实动作。',
        executionHint: '写成“什么时候、做什么、做到什么”的格式。',
        doneSignal: '已经出现一句现实动作，而不是抽象愿望。',
        example: '例：今天下班前打开文档，先写出标题和第一句。',
      ),
      ActionStep(
        id: '${idPrefix}2',
        text: '把这个动作再拆成 2-3 个你看得见的小动作。',
        minimalVersion: '先拆出第一小步。',
        directInstruction: '把动作拆成打开什么、写什么、发给谁、做几分钟。',
        executionHint: '优先拆出能立刻开始的第一小步。',
        doneSignal: '你已经拆出至少一个可立即开始的小动作。',
        example: '例：先打开文件 → 写标题 → 写第一句。',
      ),
      ActionStep(
        id: '${idPrefix}3',
        text: '完成后留下一条看得见的结果，证明这件事已经发生。',
        minimalVersion: '先留下一个结果痕迹。',
        directInstruction: '执行完后立刻留下一句记录、一个已发送动作或一个完成痕迹。',
        executionHint: '结果要能被你自己或别人看见。',
        doneSignal: '已经留下可见结果。',
        example: '例：发出消息、写下一句记录，或保存一条完成痕迹。',
      ),
    ];
  }

  Map<String, dynamic> _inferStepAssist({
    required String concept,
    required String directionTitle,
    required String directionDescription,
    required String stepText,
    required String existingImportance,
    required String? existingCabinType,
    required List<String> tags,
  }) {
    var importance = existingImportance;
    var cabin = existingCabinType;
    final src = '$concept $directionTitle $directionDescription $stepText ${tags.join(' ')}';

    bool containsAny(List<String> terms) => terms.any((t) => src.contains(t));

    if (cabin == null || cabin.isEmpty) {
      if (containsAny(['边界', '拒绝', '说不能', '不答应', '范围', '结束拉扯', '重申边界'])) {
        cabin = 'boundaryExpression';
      } else if (containsAny(['自律', '启动', '拖延', '开始', '第一步', '执行', '分心', '干扰', '立刻开始'])) {
        cabin = 'selfDisciplineStart';
      } else if (containsAny(['汇报', '延期', '承担', '说明', '沟通', '更新', '领导', '客户', '发出说明'])) {
        cabin = 'delayReport';
      }
    }

    if (importance == 'normal' &&
        containsAny(['承担', '说明', '汇报', '拒绝', '边界', '开始', '第一步', '承诺', '更新时间', '向领导', '向客户', '发出消息', '表达'])) {
      importance = 'important';
    }
    if (importance != 'critical' &&
        cabin != null &&
        containsAny(['向领导', '向客户', '承担责任', '明确拒绝', '重申边界', '开始第一步', '立即开始', '发出说明', '做出承诺'])) {
      importance = 'critical';
    }
    return {
      'importance': importance,
      'linkedCabinType': cabin,
    };
  }

  ActionDirection _mergeDirectionPaths(ActionDirection base, ActionDirection extra, String concept) {
    final seenModuleIds = <String>{...base.modules.map((e) => e.id)};
    final mergedModules = <ActionModule>[...base.modules];
    var moduleCounter = mergedModules.length + 1;
    for (final module in extra.modules) {
      final steps = _normalizeExpandedSteps(
        module.steps,
        concept,
        directionTitle: extra.title,
        directionDescription: extra.description,
      );
      if (steps.isEmpty) continue;
      final id = seenModuleIds.add(module.id) ? module.id : '${extra.id}_alt_${moduleCounter++}';
      mergedModules.add(ActionModule(
        id: id,
        title: module.title.isEmpty ? '替代路径 ${moduleCounter - 1}' : module.title,
        steps: steps,
      ));
    }
    return ActionDirection(
      id: base.id,
      title: base.title,
      description: base.description,
      modules: mergedModules,
      needsExpansion: false,
      previewModuleCount: 0,
      previewStepCount: 0,
    );
  }

  ActionDirection _fallbackMorePaths(String concept, ActionDirection direction) {
    final cabinType = _inferCabinType(concept, direction.title, direction.description);
    return ActionDirection(
      id: direction.id,
      title: direction.title,
      description: direction.description,
      modules: [
        ActionModule(
          id: '${direction.id}_alt_path_1',
          title: '替代路径 A：先缩小再执行',
          steps: [
            ActionStep(
              id: '${direction.id}_alt_s1',
              text: '先把“${direction.title}”缩小成一句今天一定能完成的动作。',
              minimalVersion: '先缩小成一句动作。',
              importance: 'normal',
            ),
            ActionStep(
              id: '${direction.id}_alt_s2',
              text: '先执行最小版本，再根据结果补后续动作。',
              minimalVersion: '先做最小版本。',
              importance: 'important',
            ),
            ActionStep(
              id: '${direction.id}_alt_s3',
              text: '如果这是关键表达，先用一句短版表达，再补充说明。',
              minimalVersion: '先发一句短版。',
              importance: cabinType == null ? 'important' : 'critical',
              linkedCabinType: cabinType,
            ),
          ],
        ),
        ActionModule(
          id: '${direction.id}_alt_path_2',
          title: '替代路径 B：先准备再落地',
          steps: [
            ActionStep(
              id: '${direction.id}_alt_s4',
              text: '先确认完成这件事必须具备的一个前提条件。',
              minimalVersion: '先确认一个前提。',
            ),
            ActionStep(
              id: '${direction.id}_alt_s5',
              text: '把行动顺序写成 1、2、3 三步，再立刻做第 1 步。',
              minimalVersion: '先做第 1 步。',
              importance: 'important',
            ),
            ActionStep(
              id: '${direction.id}_alt_s6',
              text: '完成后立即更新结果，避免动作悬空。',
              minimalVersion: '先更新一句结果。',
            ),
          ],
        ),
      ],
      needsExpansion: false,
    );
  }

  ActionDirection _fallbackExpandDirection(String concept, ActionDirection direction) {
    final cabinType = _inferCabinType(concept, direction.title, direction.description);
    return ActionDirection(
      id: direction.id,
      title: direction.title,
      description: direction.description,
      modules: [
        ActionModule(
          id: '${direction.id}_m1',
          title: '先准备',
          steps: [
            ActionStep(id: '${direction.id}_s1', text: '先写下这条行动方向最想达成的现实结果。', minimalVersion: '先写一句目标。'),
            ActionStep(id: '${direction.id}_s2', text: '列出开始前必须确认的一个事实。', minimalVersion: '先确认一个事实。'),
            ActionStep(id: '${direction.id}_s3', text: '把第一步改写成一句今天就能做的话。', minimalVersion: '先写第一步。'),
          ],
        ),
        ActionModule(
          id: '${direction.id}_m2',
          title: '开始执行',
          steps: [
            ActionStep(id: '${direction.id}_s4', text: '先完成第一步，不要求完美。', minimalVersion: '先做第一步。', importance: 'important'),
            ActionStep(id: '${direction.id}_s5', text: '完成后立即决定下一步。', minimalVersion: '先决定下一步。', importance: 'normal'),
            ActionStep(id: '${direction.id}_s6', text: '如果这是关键沟通，先预演再执行。', minimalVersion: '先预演一句开场。', importance: cabinType == null ? 'important' : 'critical', linkedCabinType: cabinType),
          ],
        ),
      ],
      needsExpansion: false,
    );
  }

  String? _inferCabinType(String concept, String title, String description) {
    final src = '$concept $title $description';
    if (src.contains('边界') || src.contains('拒绝')) return 'boundaryExpression';
    if (src.contains('自律') || src.contains('启动') || src.contains('拖延')) return 'selfDisciplineStart';
    if (src.contains('汇报') || src.contains('延期') || src.contains('责任') || src.contains('沟通')) return 'delayReport';
    return null;
  }

  ActionConcept _buildFallbackConcept({
    required String concept,
    required String goal,
    required String domain,
    required List<String> dimensions,
  }) {
    return ActionConcept(
      concept: concept,
      shortDescription: 'AI 暂时不可用，已根据“$concept”生成一份可直接执行的基础行动树。',
      dimensions: dimensions,
      generatedByAi: false,
      generationNote: '当前使用本地 fallback 行动树。',
      directions: _fallbackDirections(concept, goal, domain, dimensions),
    );
  }

  List<ActionDirection> _fallbackDirections(String concept, String goal, String domain, List<String> dimensions) {
    final dims = dimensions.isEmpty
        ? ['启动', '准备', '沟通', '拆分', '执行', '推进', '确认', '复盘', '协作', '节奏']
        : dimensions;
    final List<ActionDirection> result = [];
    for (var i = 0; i < dims.length; i++) {
      final dim = dims[i];
      result.add(ActionDirection(
        id: 'fallback_${i + 1}',
        title: '$dim行动',
        description: '从“$dim”这个维度，把“$concept”变成现实动作。',
        modules: [
          ActionModule(
            id: 'fallback_${i + 1}_m1',
            title: '$dim · 具体做法',
            steps: _buildConcreteSeedSteps(
              concept: concept,
              directionTitle: '$dim行动',
              goal: goal,
              idPrefix: 'fallback_${i + 1}_',
            ),
          ),
        ],
      ));
    }
    while (result.length < 10) {
      final n = result.length + 1;
      result.add(ActionDirection(
        id: 'fallback_extra_$n',
        title: '实现路径 $n',
        description: '条条大路通罗马，为“$concept”补充另一种可执行路径。',
        modules: [
          ActionModule(
            id: 'fallback_extra_${n}_m1',
            title: '可执行动作',
            steps: _buildConcreteSeedSteps(
              concept: concept,
              directionTitle: '实现路径 $n',
              goal: goal,
              idPrefix: 'fallback_extra_${n}_',
            ),
          ),
        ],
      ));
    }
    return result.take(10).toList();
  }

  List<String> suggestFallbackSteps(FrictionType type, ActionStep currentStep) {
    switch (type) {
      case FrictionType.notStarting:
        return [
          currentStep.minimalVersion ?? '先做这一步的最小版本',
          '先用 30 秒打开入口，不要求一次做好',
          '先把这一步变成一句最短的话或一个最小动作',
        ];
      case FrictionType.fearExpression:
        return [
          '先写一句短版表达，不求完整',
          '先用“我想先把当前情况说清楚”开头',
          currentStep.minimalVersion ?? '先说最核心的一句',
        ];
      case FrictionType.stepTooLarge:
        return [
          currentStep.minimalVersion ?? '把这一步拆成更小的动作',
          '只完成第一小部分',
          '先写出标题或第一句',
        ];
      case FrictionType.delayLoop:
        return [
          '先去掉一个干扰源，再继续',
          '给自己 3 分钟开始，不评判质量',
          currentStep.minimalVersion ?? '只做最小动作',
        ];
      case FrictionType.unclearNext:
        return [
          '先明确你做完这一步后要交付什么',
          '把这一步改成“写一句话/做一个动作”',
          currentStep.minimalVersion ?? '先完成最小版本',
        ];
    }
  }
}

const List<String> _builtinConcepts = [
  r'''{
  "concept": "责任感",
  "short_description": "把该面对的事情真正面对，把该推进的事情真正推进，并把结果收尾。",
  "dimensions": ["沟通", "承担", "补救", "闭环"],
  "directions": [
    {
      "id": "responsibility_communicate",
      "title": "主动沟通",
      "description": "在问题扩大前，主动说明现状、偏差和下一步。",
      "modules": [
        {
          "id": "status",
          "title": "说明现状",
          "steps": [
            {"id": "s1", "text": "写出当前真实状态", "minimal_version": "先写一句当前状态"},
            {"id": "s2", "text": "明确指出偏差点", "minimal_version": "先写出偏差点"},
            {"id": "s3", "text": "不回避关键问题", "minimal_version": "先说最关键的问题"}
          ]
        },
        {
          "id": "impact",
          "title": "说明影响",
          "steps": [
            {"id": "s4", "text": "列出影响范围", "minimal_version": "先列 1 个影响点"},
            {"id": "s5", "text": "指出最关键后果", "minimal_version": "先写最重要后果"}
          ]
        },
        {
          "id": "plan",
          "title": "给出下一步",
          "steps": [
            {"id": "s6", "text": "写出一个补救动作", "minimal_version": "先写一个补救动作"},
            {"id": "s7", "text": "给出下一次更新时间", "minimal_version": "先定一个更新时间", "importance": "important", "linked_cabin_type": "delayReport"},
            {"id": "s8", "text": "确认谁来负责推进", "minimal_version": "先明确责任人"}
          ]
        }
      ]
    },
    {
      "id": "responsibility_accountability",
      "title": "承担问题",
      "description": "先说自己的责任部分，不先推责。",
      "modules": [
        {
          "id": "own_part",
          "title": "承担自己的部分",
          "steps": [
            {"id": "s9", "text": "先写出你负责的部分", "minimal_version": "先写你负责的一句"},
            {"id": "s10", "text": "去掉模糊责任的话", "minimal_version": "删掉一句模糊责任的话"},
            {"id": "s11", "text": "用一句话承担结果", "minimal_version": "写一句承担结果的话", "importance": "critical", "linked_cabin_type": "delayReport"}
          ]
        }
      ]
    },
    {
      "id": "responsibility_closure",
      "title": "闭环收尾",
      "description": "让事情不是停在解释，而是走到确认完成。",
      "modules": [
        {
          "id": "closure",
          "title": "结果确认",
          "steps": [
            {"id": "s12", "text": "确认当前动作是否完成", "minimal_version": "先勾选当前动作"},
            {"id": "s13", "text": "发出一次结果确认", "minimal_version": "先发一条确认"},
            {"id": "s14", "text": "留下后续跟进时间点", "minimal_version": "先写跟进时间点"}
          ]
        }
      ]
    }
  ]
}''',
  r'''{
  "concept": "边界感",
  "short_description": "清楚知道自己能做什么、不能做什么，并稳定表达出来。",
  "dimensions": ["理解", "拒绝", "范围", "结束拉扯"],
  "directions": [
    {
      "id": "boundary_refuse",
      "title": "明确拒绝",
      "description": "不回避地表达不能接受的部分。",
      "modules": [
        {
          "id": "acknowledge",
          "title": "表达理解",
          "steps": [
            {"id": "b1", "text": "先表达你理解对方的处境", "minimal_version": "先说我理解你的处境"},
            {"id": "b2", "text": "不要一上来否定对方", "minimal_version": "先不用攻击式回应"}
          ]
        },
        {
          "id": "clear_no",
          "title": "明确边界",
          "steps": [
            {"id": "b3", "text": "直接说出你不能接受", "minimal_version": "先说不能", "importance": "critical", "linked_cabin_type": "boundaryExpression"},
            {"id": "b4", "text": "不用绕着拒绝", "minimal_version": "少解释一句"},
            {"id": "b5", "text": "不用过度解释", "minimal_version": "删掉多余解释"}
          ]
        }
      ]
    },
    {
      "id": "boundary_scope",
      "title": "缩小承诺范围",
      "description": "不是全答应或全拒绝，而是保留你能承担的部分。",
      "modules": [
        {
          "id": "scope",
          "title": "保留可接受部分",
          "steps": [
            {"id": "b6", "text": "删掉你不想答应的部分", "minimal_version": "先删一项不愿答应的内容"},
            {"id": "b7", "text": "留下你可以提供的支持", "minimal_version": "保留你能做的一小部分"},
            {"id": "b8", "text": "清楚说出这个范围", "minimal_version": "写出可支持的范围"}
          ]
        }
      ]
    },
    {
      "id": "boundary_end_loop",
      "title": "结束拉扯",
      "description": "当对方重复施压时，不再掉入无限解释。",
      "modules": [
        {
          "id": "repeat_boundary",
          "title": "重申边界",
          "steps": [
            {"id": "b9", "text": "识别重复施压", "minimal_version": "先看清对方在重复施压"},
            {"id": "b10", "text": "重复边界而不换说法", "minimal_version": "再说一次边界", "importance": "important", "linked_cabin_type": "boundaryExpression"},
            {"id": "b11", "text": "结束当前拉扯", "minimal_version": "结束当前对话"}
          ]
        }
      ]
    }
  ]
}''',
  r'''{
  "concept": "自律",
  "short_description": "不是逼自己完美，而是能开始、能继续、能完成一个现实动作。",
  "dimensions": ["开始", "中断拖延", "推进"],
  "directions": [
    {
      "id": "discipline_start",
      "title": "开始第一步",
      "description": "不再等待更好的状态，先做最小动作。",
      "modules": [
        {
          "id": "start_task",
          "title": "锁定起步动作",
          "steps": [
            {"id": "d1", "text": "只选今天这一件事", "minimal_version": "先写今天唯一任务"},
            {"id": "d2", "text": "去掉一个最强干扰源", "minimal_version": "先关掉一个干扰"},
            {"id": "d3", "text": "开始 3 分钟", "minimal_version": "先开始 1 分钟", "importance": "critical", "linked_cabin_type": "selfDisciplineStart"}
          ]
        }
      ]
    },
    {
      "id": "discipline_interrupt_delay",
      "title": "中断拖延",
      "description": "停止继续准备，立刻进入动作。",
      "modules": [
        {
          "id": "interrupt",
          "title": "切断拖延循环",
          "steps": [
            {"id": "d4", "text": "识别你正在用的借口", "minimal_version": "写出当前借口"},
            {"id": "d5", "text": "停止继续准备", "minimal_version": "停下继续准备"},
            {"id": "d6", "text": "立刻执行最小动作", "minimal_version": "现在就做最小动作", "importance": "important", "linked_cabin_type": "selfDisciplineStart"}
          ]
        }
      ]
    },
    {
      "id": "discipline_continue",
      "title": "保持推进",
      "description": "一小步完成后，继续衔接下一小步。",
      "modules": [
        {
          "id": "continue",
          "title": "维持连续性",
          "steps": [
            {"id": "d7", "text": "完成一小步后立刻确定下一步", "minimal_version": "先写下一小步"},
            {"id": "d8", "text": "先不评价质量", "minimal_version": "先暂停评价质量"},
            {"id": "d9", "text": "保持任务连续推进", "minimal_version": "继续做下一小段"}
          ]
        }
      ]
    }
  ]
}'''
];

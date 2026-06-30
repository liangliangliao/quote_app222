import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// Prompt center for the standalone Boundary Action Coach module.
///
/// All overrides are stored under `ai_prompt.boundary_action_coach.*`, so this
/// module remains independent from `boundary_practice` and other growth modules.
class BoundaryActionCoachPromptConfig {
  static const String moduleId = 'boundary_action_coach';
  static const String moduleName = '边界行动教练 Boundary Action Coach';

  static const String globalId = 'bac_global';
  static const String outputId = 'bac_output_standard';
  static const String commonSceneId = 'bac_scene_common';
  static const String familySceneId = 'bac_scene_family';
  static const String friendSceneId = 'bac_scene_friend';
  static const String intimacySceneId = 'bac_scene_intimacy';
  static const String parentingSceneId = 'bac_scene_parenting';
  static const String workSceneId = 'bac_scene_work';
  static const String selfSceneId = 'bac_scene_self';
  static const String valuesSceneId = 'bac_scene_values';
  static const String resistanceSceneId = 'bac_scene_resistance';
  static const String diagnosisId = 'bac_feature_diagnosis';
  static const String responsibilityMapId = 'bac_feature_responsibility_map';
  static const String scriptsId = 'bac_feature_scripts';
  static const String consequencesId = 'bac_feature_consequences';
  static const String roleplayId = 'bac_feature_roleplay';
  static const String supportId = 'bac_feature_support';
  static const String selfBoundaryId = 'bac_feature_self_boundary';
  static const String growthId = 'bac_feature_growth';
  static const String learningId = 'bac_feature_learning';
  static const String safetyId = 'bac_safety_professional_boundary';
  static const String jsonRepairId = 'bac_json_repair';

  static const List<String> allIds = <String>[
    globalId,
    outputId,
    commonSceneId,
    familySceneId,
    friendSceneId,
    intimacySceneId,
    parentingSceneId,
    workSceneId,
    selfSceneId,
    valuesSceneId,
    resistanceSceneId,
    diagnosisId,
    responsibilityMapId,
    scriptsId,
    consequencesId,
    roleplayId,
    supportId,
    selfBoundaryId,
    growthId,
    learningId,
    safetyId,
    jsonRepairId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    outputId: '输出格式层 Prompt',
    commonSceneId: '通用场景层 Prompt',
    familySceneId: '场景：原生家庭边界',
    friendSceneId: '场景：朋友边界',
    intimacySceneId: '场景：婚姻/亲密关系边界',
    parentingSceneId: '场景：育儿边界',
    workSceneId: '场景：职场边界',
    selfSceneId: '场景：自我边界',
    valuesSceneId: '场景：信仰/价值观边界',
    resistanceSceneId: '场景：阻力应对',
    diagnosisId: '功能：边界诊断中心',
    responsibilityMapId: '功能：责任归属地图',
    scriptsId: '功能：沟通话术工坊',
    consequencesId: '功能：后果设计器',
    roleplayId: '功能：AI 角色扮演',
    supportId: '功能：支持系统',
    selfBoundaryId: '功能：自我边界管理',
    growthId: '功能：成长路径追踪',
    learningId: '功能：学习与案例库',
    safetyId: '安全与专业边界',
    jsonRepairId: '异常恢复：JSON 修复',
  };

  static const Map<String, String> _defaults = <String, String>{
    globalId: '''你是一个“边界行动教练 AI”，你的价值框架来源于书籍/课程《Boundaries: When to Say Yes, How to Say No》。你的任务不是简单鼓励用户拒绝别人，而是帮助用户把该书的中心思想应用到现实行动中：在爱中连接，在真理中分离；在自由中说“是”，在真实中说“不”；对别人有爱的责任，但不替别人承担他们自己的生活责任。始终区分“我的责任 / 别人的责任 / 共同关系责任”，区分 burdens 与 loads，帮助用户设计清楚、有限、可执行、可复盘的边界。''',
    outputId: '''请严格输出：1 场景摘要；2 边界问题判断；3 责任归属表（属于我的/不属于我的/共同面对）；4 burdens/loads 判断；5 核心价值；6 建议边界；7 温柔版/简短版/高压重复版话术；8 对方可能反应与应对；9 24小时行动、7天行动、复盘问题；10 支持系统提醒；11 一句话价值提醒。''',
    commonSceneId: '当用户描述边界困境时，先复述困境，再判断场景、边界问题类型、责任归属、burdens/loads、核心价值、边界、话术、阻力、行动计划与安全风险。用户输入：{{user_input}}。场景：{{scene}}。档案：{{profile_json}}。',
    familySceneId: '关注成年生活被原生家庭控制、孝敬与无限顺从混淆、罪疚操控、三角关系、经济/探访/电话/婚姻介入边界。保留爱，同时拿回时间、金钱、婚姻、身体、情绪和选择权。',
    friendSceneId: '关注情绪倾倒、危机型操控、单方面维系、借钱、半夜电话、长期抱怨但不改变。设计有限帮助、频率限制、资源转介与关系降级。',
    intimacySceneId: '关注感受归属、亲密与分离、金钱/性/家务/育儿/手机/原生家庭边界，使用 I statement，并区分宽恕、信任重建与和解。',
    parentingSceneId: '关注年龄阶段、纪律与惩罚、自然后果、作业/起床/手机/零花钱规则、父母过度拯救与爆发式管教，帮助孩子内化责任。',
    workSceneId: '关注职责不清、替同事承担、下班后工作、优先级冲突、记录留痕、职场剥削、骚扰歧视与法律/HR渠道。',
    selfSceneId: '关注时间、金钱、饮食、睡眠、语言、情绪、性、手机、酒精药物、拖延和工作成瘾。设计小限制、外部支持、环境设计与复盘。',
    valuesSceneId: '当用户使用爱、顺服、牺牲、饶恕、服事、罪疚、神的旨意等语言时，区分爱与讨好、顺服与操控、饶恕与和解、真实责任与假罪疚。非宗教用户转为生命价值语言。',
    resistanceSceneId: '当用户设边界后面对生气、哭诉、自私指责、威胁、冷暴力时，区分外在阻力与内在罪疚，区分让人痛与伤害人，安全优先，并给不升级但不撤回的话术。',
    diagnosisId: '根据 10 个测评维度输出顺从、逃避、控制、不回应、自我边界、家庭纠缠、工作过载、亲密吞没风险，并生成关系雷达与怨气警报。',
    responsibilityMapId: '输出“我的院子/对方的院子/共同关系责任”，判断 burdens 与 loads，检测父母/配偶/同事/朋友/用户是否替他人承担后果。',
    scriptsId: '生成温柔拒绝、有限帮助、后果说明、关系保留四类话术，并检查解释过度、求饶、攻击、控制、威胁、罪疚操控、模糊边界和缺少执行方案。',
    consequencesId: '设计自然后果，区分后果与惩罚，评估愤怒、内疚、安全风险、支持者、提前话术和分阶段执行。',
    roleplayId: '模拟愤怒父母、哭诉母亲、控制老板、情绪倾倒朋友、逃避伴侣、叛逆孩子、借钱亲戚、冷暴力对象、罪疚操控组织成员和用户内疚声音。',
    supportId: '提醒 bonding first, boundaries second：支持者名单、行动前提醒、行动后复盘、问责伙伴、咨询师记录、支持小组、紧急联系人与孤立风险。',
    selfBoundaryId: '把边界用于自己：时间预算、金钱预算、身体照顾、语言边界、欲望与成瘾风险，强调结构、支持、真实和可执行限制。',
    growthId: '按 11 个成长阶段追踪：怨气觉察、安全支持、小的“不”、带罪疚设限、大不、罪疚下降、尊重别人边界、自由的是/不、价值使命生活。',
    learningId: '把书中思想行动化：边界是什么、什么属于我/不属于我、burdens/loads、四类问题、十条边界律、各关系场景、阻力与成熟路径、抽象案例卡。',
    safetyId: '不能包装成心理治疗师、法律顾问或医疗专业人士。涉及家暴、威胁、自伤他伤、虐待、跟踪、成瘾、严重精神危机、经济控制、非法职场压迫时，建议当地专业帮助、危机热线、法律援助或安全资源。',
    jsonRepairId: '如果上一次输出不是合法 JSON 或缺少字段，请只修复格式，不改变原意。原始内容：{{raw_text}}。',
  };

  final KeyValueDao _kv = KeyValueDao();

  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  List<String> allPromptIds() => allIds;
  String defaultFor(String id) => _defaults[id] ?? '';

  Future<String> getPrompt(String id, [String? fallback]) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    if (saved.isNotEmpty) return saved;
    return fallback ?? defaultFor(id);
  }

  Future<void> savePrompt(String id, String value) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), value.trim());
  }

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultFor(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty
          ? '当前使用边界行动教练内置 Prompt。'
          : '当前实际使用设置页保存的边界行动教练 Prompt，下一次本模块 AI 调用立即生效。',
    };
  }

  List<String> missingRequiredPlaceholders(String id, String template) {
    final required = <String, List<String>>{
      commonSceneId: <String>['{{user_input}}', '{{scene}}'],
      jsonRepairId: <String>['{{raw_text}}'],
    }[id];
    if (required == null) return const <String>[];
    return required.where((p) => !template.contains(p)).toList(growable: false);
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final rows = await _kv.keyValuesWithPrefix(_backupPrefix(id));
    return rows.map((e) {
      final key = e['key'] ?? '';
      final suffix = key.replaceFirst(_backupPrefix(id), '');
      final ms = int.tryParse(suffix) ?? 0;
      final dt = ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      final label = dt == null
          ? key
          : '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")} ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
      return CcPromptBackupRecord(key: key, promptId: id, versionLabel: label, value: e['value'] ?? '');
    }).toList(growable: false);
  }

  Future<void> restoreBackup(String id, String backupKey) async {
    final value = await _kv.getString(backupKey);
    if (value == null) return;
    await _kv.setString(_key(id), value);
  }

  Future<void> _backupCurrent(String id) async {
    final current = await _kv.getString(_key(id));
    if (current == null || current.trim().isEmpty) return;
    await _kv.setString('${_backupPrefix(id)}${DateTime.now().millisecondsSinceEpoch}', current);
  }
}

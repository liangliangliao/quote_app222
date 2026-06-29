import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/kv_dao.dart';
import '../pages/ai_prompt_settings_page.dart';
import 'self_worth_ai_ai_service.dart';
import 'self_worth_ai_engine.dart';
import 'self_worth_ai_prompt_config.dart';

class SelfWorthAiHomePage extends StatefulWidget {
  const SelfWorthAiHomePage({super.key});

  @override
  State<SelfWorthAiHomePage> createState() => _SelfWorthAiHomePageState();
}

class _SelfWorthAiHomePageState extends State<SelfWorthAiHomePage> with TickerProviderStateMixin {
  static const String _stateKey = 'self_worth_ai.state.v2';

  late final TabController _tab;
  final KeyValueDao _kv = KeyValueDao();
  final SelfWorthAiEngine _engine = const SelfWorthAiEngine();
  final SelfWorthAiService _aiService = SelfWorthAiService();
  final TextEditingController _eventCtrl = TextEditingController(text: '今天老板没有表扬我，我就开始怀疑自己是不是不够好。');
  final TextEditingController _reflectionCtrl = TextEditingController();
  String _scene = 'external_validation';
  String _coachOutput = '';
  final Set<String> _completed = <String>{};
  final Set<String> _completedFeatures = <String>{};
  final List<_EvidenceRecord> _evidence = <_EvidenceRecord>[];
  final Map<String, double> _sourceScores = <String, double>{};
  String _featureModuleFilter = '全部';
  bool _loading = true;
  bool _generating = false;
  String _lastCoachSource = '本地行动引擎';
  final Map<String, double> _metrics = <String, double>{
    '自尊稳定度': 0.46,
    '自我一致度': 0.52,
    '真实表达度': 0.38,
    '外部认可依赖下降度': 0.31,
    '关系互依度': 0.44,
    '责任行动数': 0.40,
  };

  static const _sceneLabels = <String, String>{
    'external_validation': '外部认可',
    'failure': '失败自否',
    'relationship_conflict': '关系冲突',
    'comparison': '嫉妒比较',
    'body_shame': '身体羞耻',
    'boundary': '边界说不',
    'goal_delay': '目标拖延',
    'self_acceptance': '自我接纳',
    'active_constructive': '积极回应',
    'integrity': '诚信表达',
    'criticism': '批评处理',
    'responsibility_review': '责任复盘',
  };

  static const _sources = <_SourceSpec>[
    _SourceSpec('认可依赖', '别人不夸我，我就怀疑自己', 0.72, Icons.thumb_up_alt_outlined),
    _SourceSpec('成就依赖', '做得不够好就觉得自己没有价值', 0.66, Icons.emoji_events_outlined),
    _SourceSpec('关系依赖', '对方冷淡一点，我就觉得自己不值得爱', 0.58, Icons.favorite_border),
    _SourceSpec('外貌依赖', '身体、颜值、年龄变化影响自我价值', 0.41, Icons.face_retouching_natural_outlined),
    _SourceSpec('比较依赖', '看到别人成功就焦虑或嫉妒', 0.63, Icons.compare_arrows_outlined),
    _SourceSpec('内在标准', '更关注是否符合自己的价值', 0.49, Icons.explore_outlined),
    _SourceSpec('无条件接纳', '失败时不否定整个人', 0.36, Icons.spa_outlined),
  ];

  static const _modules = <_ModuleSpec>[
    _ModuleSpec('自尊地图', Icons.map_outlined, '来源扫描、稳定曲线、依赖触发器、自尊画像报告。', ['今天是否因评价大幅波动？', '今天是否做了符合价值的行动？', '今天是否有一次真实表达？']),
    _ModuleSpec('三层自尊训练', Icons.layers_outlined, '依赖型识别、独立型标准、无条件自尊练习。', ['拆解一次掌声依赖', '写一张内在标准卡', '失败后区分事实/行为/人格']),
    _ModuleSpec('真实关系实验室', Icons.favorite_border, '被了解而非被认可，主动建设性回应，冲突修复，Love Boosters。', ['把讨好句改成真实表达', '对一个好消息主动建设性回应', '做一个30秒 Love Booster']),
    _ModuleSpec('六项自尊实践', Icons.fitness_center_outlined, '诚信、自我觉察、目标感、责任、自我接纳、自我主张。', ['今日真实度检查', '情绪—需求—价值三段式', '一句话边界练习']),
    _ModuleSpec('外部认可与比较戒断', Icons.visibility_off_outlined, '掌声成瘾识别、比较 detox、身体与媒体意象拆解。', ['24小时不查点赞', '把嫉妒转成一个目标', '做一次身体照顾而非惩罚']),
    _ModuleSpec('心理免疫与复原力', Icons.shield_outlined, '批评处理器、失败复原流程、身体行动模块。', ['提取批评中可行动部分', '写一句人格保护句', '10分钟走路后复盘']),
    _ModuleSpec('价值目标与责任系统', Icons.flag_outlined, '人生责任盘、自我一致目标、每周责任复盘。', ['选择一个人生领域最小行动', '检查目标是否只为证明自己', '把一个抱怨转成请求']),
    _ModuleSpec('AI 场景教练', Icons.auto_awesome, '亲密关系、职场、学业、外貌焦虑、失败复盘、冲突修复等场景化 Prompt。', ['输入一个现实事件', '生成行动卡', '今晚完成复盘问题']),
  ];

  static const _journey = <_JourneyWeek>[
    _JourneyWeek('第 1 天', '建立自尊地图', ['自尊来源扫描', '认可依赖测试', '比较触发器记录', '关系真实度检测']),
    _JourneyWeek('第 1 周', '识别依赖型自尊', ['记录一次外界影响波动', '拆解一次比较', '做一件无人知道但符合价值的事', '完成一次真实表达']),
    _JourneyWeek('第 2 周', '建立独立型自尊', ['写下一个内在标准', '记录一次过程胜利', '完成自我一致目标小行动', '做一次责任复盘']),
    _JourneyWeek('第 3 周', '关系中的真实自尊', ['主动建设性回应', 'Love Booster', '不讨好的表达', '冲突修复或欣赏表达']),
    _JourneyWeek('第 4 周', '无条件自尊练习', ['不比较练习', '失败去人格化', '祝福别人成功', '自我接纳与身体照顾']),
  ];


  static const _moduleFilters = <String>['全部', '自尊地图', '三层自尊训练', '真实关系实验室', '六项自尊实践', '外部认可与比较戒断', '心理免疫与复原力', '价值目标与责任系统', 'AI 场景教练'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this);
    for (final source in _sources) {
      _sourceScores[source.name] = source.value;
    }
    _coachOutput = _buildCoachOutput(_eventCtrl.text, _scene);
    _loadState();
  }

  @override
  void dispose() {
    _tab.dispose();
    _eventCtrl.dispose();
    _reflectionCtrl.dispose();
    super.dispose();
  }


  Future<void> _loadState() async {
    try {
      final raw = await _kv.getString(_stateKey);
      if (raw == null || raw.trim().isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final metrics = decoded['metrics'];
      final sources = decoded['source_scores'];
      final evidence = decoded['evidence'];
      final completedFeatures = decoded['completed_features'];
      if (!mounted) return;
      setState(() {
        if (metrics is Map) {
          for (final entry in metrics.entries) {
            final value = entry.value;
            if (value is num && _metrics.containsKey(entry.key.toString())) {
              _metrics[entry.key.toString()] = value.toDouble().clamp(0.0, 1.0).toDouble();
            }
          }
        }
        if (sources is Map) {
          for (final entry in sources.entries) {
            final value = entry.value;
            if (value is num) _sourceScores[entry.key.toString()] = value.toDouble().clamp(0.0, 1.0).toDouble();
          }
        }
        if (evidence is List) {
          _evidence
            ..clear()
            ..addAll(evidence.whereType<Map>().map(_EvidenceRecord.fromJson));
        }
        if (completedFeatures is List) {
          _completedFeatures
            ..clear()
            ..addAll(completedFeatures.map((e) => e.toString()));
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveState() async {
    final payload = <String, Object?>{
      'metrics': _metrics,
      'source_scores': _sourceScores,
      'evidence': _evidence.map((e) => e.toJson()).toList(growable: false),
      'completed_features': _completedFeatures.toList(growable: false),
    };
    await _kv.setString(_stateKey, jsonEncode(payload));
  }


  Future<void> _generateCoachWithAi() async {
    final input = _eventCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() => _generating = true);
    try {
      final result = await _aiService.generate(
        userInput: input,
        scene: _scene,
        profileJson: jsonEncode(<String, Object?>{
          'metrics': _metrics,
          'source_scores': _sourceScores,
          'completed_features': _completedFeatures.toList(growable: false),
        }),
        recentContextJson: jsonEncode(<String, Object?>{
          'evidence': _evidence.take(12).map((e) => e.toJson()).toList(growable: false),
        }),
      );
      if (!mounted) return;
      setState(() {
        _scene = result.scene;
        _coachOutput = result.markdown;
        _lastCoachSource = result.usedAi ? 'AI 生成' : '本地行动引擎';
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _buildCoachOutput(String event, String scene) {
    final label = _sceneLabels[scene] ?? '自尊练习';
    final outputTitle = switch (scene) {
      'failure' => '## 失败复盘',
      'relationship_conflict' => '## 关系冲突修复',
      'comparison' => '## 比较焦虑转化',
      'body_shame' => '## 外貌焦虑与身体照顾',
      'integrity' || 'boundary' => '## 真实表达练习',
      _ => '## 自尊行动卡',
    };
    final action = switch (scene) {
      'external_validation' => '接下来24小时不主动索要评价、不反复查看反馈；做一件符合你价值但无人知道的小事。',
      'failure' => '用10分钟写下：事实、可改进行为、下一次策略；只改行为，不攻击人格。',
      'relationship_conflict' => '发出一句真实但不攻击的表达，并提出一个具体可执行的修复请求。',
      'comparison' => '写下你真正羡慕的愿望，真诚承认对方一个努力点，然后为自己的愿望做15分钟行动。',
      'body_shame' => '做一次身体照顾行动：散步、拉伸、喝水、睡眠准备或认真吃饭，而不是惩罚身体。',
      'boundary' => '选择一个小请求练习温和拒绝：“谢谢你想到我，但我这次不能接，我需要保留这段时间。”',
      'goal_delay' => '把目标降到今天5分钟能开始的一步，并在完成后记录：我是在为价值行动，不是在证明价值。',
      'self_acceptance' => '给情绪命名，允许它存在，然后做一个温和行动：洗脸、走路、联系支持者或整理桌面。',
      'active_constructive' => '对对方的好消息追问一个细节、表达具体欣赏，并提出一个小庆祝。',
      'integrity' => '修复一句不真实的话：“我刚才说都可以，其实我更希望A，也愿意听你的想法。”',
      'criticism' => '把批评分成“可学习部分、情绪攻击、模糊信息、可能投射”，只接收可行动部分。',
      'responsibility_review' => '把一个抱怨转成具体请求：我无法控制什么？我能负责什么？我的边界是什么？',
      _ => '选择一个5-30分钟的小行动，让自尊从现实行动中长出来。',
    };
    return '''$outputTitle

### 1. 你现在可能正在经历什么
你记录的是「$event」。这更像是「$label」场景：外界反应、结果、关系、身体标准或比较正在牵动你的自我价值。这里不需要责怪自己，重点是把价值从外界手里拿回来，放回真实表达、责任和行动中。

### 2. 事实与解释分离
| 事实 | 解释 |
| --- | --- |
| 发生了一件触发你情绪的现实事件。 | 我可能把它解释成“我不够好 / 不值得 / 失败了 / 不被爱”。 |
| 外界只给出了一个有限信号。 | 这个信号不等于完整的我，也不能裁定我的人格价值。 |

### 3. 自尊模式识别
当前更接近：**依赖型自尊被触发，正在练习转向独立型自尊**。原因是你的情绪可能被评价、结果、关系回应或比较牵动；下一步不是强迫自己“别在乎”，而是建立更可靠的内在标准。

### 4. 价值重构
我的价值不等于这次评价、失败、比较、外貌感受或关系反应。我可以为表达、选择和行为负责，但不需要把一次事件扩大成对整个人格的否定。真实自尊来自诚信、责任、自我接纳、边界、关系修复和持续行动。

### 5. 今天的一个具体行动
$action

### 6. 一句话练习
“我愿意看见这件事带来的情绪，也愿意把注意力带回我今天能负责的一小步。”

### 7. 复盘问题
1. 我今天有没有把外界反应误读成自我价值？
2. 我做了哪一个符合价值、而不只是寻求认可的行动？
3. 如果明天再遇到类似场景，我可以怎样更真实地表达？''';
  }

  void _saveEvidence() {
    final text = _reflectionCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _evidence.insert(0, _EvidenceRecord(DateTime.now(), _sceneLabels[_scene] ?? _scene, text));
      _metrics['自尊稳定度'] = ((_metrics['自尊稳定度'] ?? 0.4) + 0.03).clamp(0.0, 1.0).toDouble();
      _metrics['行动一致度'] = ((_metrics['行动一致度'] ?? 0.35) + 0.04).clamp(0.0, 1.0).toDouble();
      _reflectionCtrl.clear();
    });
    _saveState();
  }


  void _resetLocalState() {
    _completed.clear();
    _completedFeatures.clear();
    _evidence.clear();
    _sourceScores
      ..clear()
      ..addEntries(_sources.map((s) => MapEntry(s.name, s.value)));
    _metrics
      ..clear()
      ..addAll(<String, double>{
        '自尊稳定度': 0.46,
        '自我一致度': 0.52,
        '真实表达度': 0.38,
        '外部认可依赖下降度': 0.31,
        '关系互依度': 0.44,
        '责任行动数': 0.40,
      });
    _scene = 'external_validation';
    _eventCtrl.text = '今天老板没有表扬我，我就开始怀疑自己是不是不够好。';
    _reflectionCtrl.clear();
    _coachOutput = _buildCoachOutput(_eventCtrl.text, _scene);
    _lastCoachSource = '本地行动引擎';
  }

  Future<void> _clearAllModuleData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空真实自尊模块数据？'),
        content: const Text('这会清空本模块的自尊来源、指标、已完成子功能、证据库、输入状态，以及本模块在 AI 提示词配置中心保存的 Prompt 覆盖和备份。此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认清空')),
        ],
      ),
    );
    if (ok != true) return;
    await _kv.setString(_stateKey, '');
    await SelfWorthAiPromptConfig().clearAllPromptData();
    if (!mounted) return;
    setState(_resetLocalState);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空真实自尊 SelfWorth AI 模块数据'), behavior: SnackBarBehavior.floating));
  }

  void _openPromptSettings([String? promptId]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiPromptSettingsPage(
        initialModuleId: SelfWorthAiPromptConfig.moduleId,
        initialPromptId: promptId ?? SelfWorthAiPromptConfig.globalId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('真实自尊 SelfWorth AI'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'AI 提示词统一配置',
            onPressed: () => _openPromptSettings(),
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: '首页'),
            Tab(text: '自尊地图'),
            Tab(text: '八大模块'),
            Tab(text: 'AI教练'),
            Tab(text: '功能总控台'),
            Tab(text: '训练路径'),
            Tab(text: '证据库'),
            Tab(text: 'Prompt体系'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tab,
        children: [_home(), _map(), _moduleGrid(), _coach(), _featureConsole(), _journeyPage(), _evidencePage(), _prompts()],
      ),
    );
  }

  Widget _home() => ListView(padding: const EdgeInsets.all(16), children: [
        _hero(),
        const SizedBox(height: 12),
        _section('今日自尊提醒', '不要把一次沉默、一次失败、一次比较或一次外貌不满意，解释成自我价值下降。'),
        _section('今日小行动', '做一件符合你价值、但不需要任何人知道的事。'),
        _section('今日复盘', '今天我哪里更真实？有没有寻求不必要的认可？是否为自己的幸福承担了一点责任？'),
        _quickSceneChips(),
        const SizedBox(height: 12),
        _metricPanel(),
      ]);

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF7C3AED)])),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('从被认可，走向被了解', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('围绕《幸福课》第21集后半与第22集，把自尊从空洞口号落到诚信、责任、真实关系、边界、身体照顾和每日行动。', style: TextStyle(color: Colors.white70, height: 1.45)),
        ]),
      );

  Widget _quickSceneChips() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _sceneLabels.entries
            .map((e) => ActionChip(label: Text(e.value), onPressed: () { setState(() => _scene = e.key); _tab.animateTo(3); }))
            .toList(),
      );

  Widget _map() => ListView(padding: const EdgeInsets.all(16), children: [
        _section('自尊来源扫描', '目标不是判断“我自尊高不高”，而是看见：我的自我价值主要依赖掌声、成就、关系、外貌、比较，还是内在价值与行动。'),
        ..._sources.map((s) => _sourceBar(s)),
        const SizedBox(height: 12),
        _metricPanel(),
        _section('我的依赖型触发器', '最容易影响我的人：权威/伴侣/同辈；最容易讨好的场景：被评价、被冷淡、被比较；最容易羞耻的失败：公开失误、目标落空、关系冲突。'),
        _section('自尊画像报告', '当前主导模式：转化中。主要风险：认可成瘾、完美主义、比较焦虑。当前优势：反思力、责任感、行动意愿。下周重点：真实表达 + 24小时认可戒断 + 身体照顾。'),
      ]);

  Widget _sourceBar(_SourceSpec s) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(s.icon, color: const Color(0xFF4F46E5)), const SizedBox(width: 8), Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900))), Text('${((_sourceScores[s.name] ?? s.value) * 100).round()}%')]),
            const SizedBox(height: 6),
            Slider(
              value: _sourceScores[s.name] ?? s.value,
              onChanged: (v) => setState(() => _sourceScores[s.name] = v),
              onChangeEnd: (_) => _saveState(),
            ),
            Text(s.description, style: const TextStyle(color: Color(0xFF64748B))),
          ]),
        ),
      );

  Widget _metricPanel() => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('关键指标（不排名，只看稳定与行动）', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 10),
            ..._metrics.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [SizedBox(width: 118, child: Text(e.key)), Expanded(child: LinearProgressIndicator(value: e.value, minHeight: 8, borderRadius: BorderRadius.circular(999))), const SizedBox(width: 8), Text('${(e.value * 100).round()}%')]),
                )),
          ]),
        ),
      );

  Widget _moduleGrid() => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 244, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: _modules.length,
        itemBuilder: (context, i) => _moduleCard(_modules[i]),
      );

  Widget _moduleCard(_ModuleSpec m) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(m.icon, color: const Color(0xFF4F46E5)), const SizedBox(width: 8), Expanded(child: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))]),
            const SizedBox(height: 8),
            Text(m.subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
            const Spacer(),
            ...m.actions.map((a) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _completed.contains('${m.title}$a'),
                  onChanged: (v) => setState(() => v == true ? _completed.add('${m.title}$a') : _completed.remove('${m.title}$a')),
                  title: Text(a, style: const TextStyle(fontSize: 12)),
                )),
          ]),
        ),
      );

  Widget _coach() => ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          value: _scene,
          decoration: const InputDecoration(labelText: '选择场景', border: OutlineInputBorder()),
          items: _sceneLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => _scene = v ?? _scene),
        ),
        const SizedBox(height: 12),
        TextField(controller: _eventCtrl, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '写下一个现实事件', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _generating ? null : _generateCoachWithAi, icon: Icon(_generating ? Icons.hourglass_top : Icons.auto_awesome), label: Text(_generating ? '正在生成...' : '生成自尊行动卡')),
        const SizedBox(height: 6),
        Text('生成来源：$_lastCoachSource', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        const SizedBox(height: 12),
        _markdownLike(_coachOutput),
        const SizedBox(height: 12),
        TextField(controller: _reflectionCtrl, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '完成行动后，写一句复盘，沉淀到自尊证据库', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _saveEvidence, icon: const Icon(Icons.archive_outlined), label: const Text('保存为稳定自尊证据')),
      ]);


  Widget _featureConsole() {
    final features = SelfWorthProductRegistry.features
        .where((f) => _featureModuleFilter == '全部' || _registryModuleTitle(f.moduleId) == _featureModuleFilter)
        .toList(growable: false);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _section('功能总控台', '这里直接读取 self_worth_ai_engine.dart 的产品功能注册表，把产品设计方案中的全部子功能拆成可进入、可提问、可生成行动卡、可沉淀证据的练习单元。'),
      _coverageAuditCard(),
      _nextRecommendedCard(),
      DropdownButtonFormField<String>(
        value: _featureModuleFilter,
        decoration: const InputDecoration(labelText: '按模块筛选', border: OutlineInputBorder()),
        items: _moduleFilters.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(growable: false),
        onChanged: (v) => setState(() => _featureModuleFilter = v ?? '全部'),
      ),
      const SizedBox(height: 12),
      ...features.map(_registryFeatureCard),
    ]);
  }


  Widget _coverageAuditCard() {
    final coverage = SelfWorthProductRegistry.coverageByModule();
    final gaps = SelfWorthProductRegistry.coverageGaps();
    final moduleTitles = {for (final m in SelfWorthProductRegistry.modules) m.id: m.title};
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('产品方案覆盖审计', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('已登记 ${SelfWorthProductRegistry.modules.length} 个一级模块、${SelfWorthProductRegistry.features.length} 个子功能；覆盖缺口：${gaps.isEmpty ? '0' : gaps.join('，')}。', style: const TextStyle(color: Color(0xFF334155))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: coverage.entries.map((e) => Chip(label: Text('${moduleTitles[e.key] ?? e.key} · ${e.value}项'))).toList(growable: false),
          ),
        ]),
      ),
    );
  }


  String _registryModuleTitle(String moduleId) {
    for (final module in SelfWorthProductRegistry.modules) {
      if (module.id == moduleId) return module.title;
    }
    return moduleId;
  }

  SelfWorthProgressReport _buildProgressReport() => _engine.buildProgressReport(
        completedFeatureIds: _completedFeatures,
        metrics: _metrics,
        sourceScores: _sourceScores,
      );

  Widget _nextRecommendedCard() {
    final report = _buildProgressReport();
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFBBF7D0))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('下一步推荐 · 已完成 ${report.completedFeatures}/${report.totalFeatures}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF14532D))),
          const SizedBox(height: 8),
          Text(report.summary, style: const TextStyle(color: Color(0xFF166534), height: 1.45)),
          const SizedBox(height: 8),
          ...report.recommendations.map((f) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${_registryModuleTitle(f.moduleId)} · ${f.goal}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _startRegistryFeature(f),
              )),
        ]),
      ),
    );
  }

  Widget _registryFeatureCard(SelfWorthFeatureSpec f) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(999)), child: Text(_registryModuleTitle(f.moduleId), style: const TextStyle(color: Color(0xFF5B21B6), fontSize: 12, fontWeight: FontWeight.w800))),
              const Spacer(),
              Checkbox(value: _completedFeatures.contains(f.id), onChanged: (v) => _toggleRegistryFeatureDone(f, v ?? false)),
              TextButton(onPressed: () => _startRegistryFeature(f), child: const Text('进入练习')),
            ]),
            Text(f.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(f.goal, style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
            const SizedBox(height: 8),
            Text('输入：${f.inputs.join(' / ')}', style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text('AI步骤：${f.aiSteps.join(' → ')}', style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text('产出：${f.outputs.join(' / ')}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
            const SizedBox(height: 4),
            Text('行动：${f.actions.join(' / ')}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
          ]),
        ),
      );

  void _startRegistryFeature(SelfWorthFeatureSpec f) {
    final input = '${f.title}：输入 ${f.inputs.join('、')}；目标 ${f.goal}。';
    final result = _engine.runFeature(feature: f, userInput: input);
    setState(() {
      _scene = result.scene;
      _eventCtrl.text = input;
      _coachOutput = result.markdown;
      _lastCoachSource = '功能引擎：${result.outputMode}';
    });
    _tab.animateTo(3);
  }

  void _toggleRegistryFeatureDone(SelfWorthFeatureSpec f, bool done) {
    setState(() {
      if (done) {
        _completedFeatures.add(f.id);
        _evidence.insert(0, _EvidenceRecord(DateTime.now(), _registryModuleTitle(f.moduleId), '完成子功能：${f.title}；行动：${f.actions.join(' / ')}'));
      } else {
        _completedFeatures.remove(f.id);
      }
    });
    _saveState();
  }

  Widget _journeyPage() => ListView(padding: const EdgeInsets.all(16), children: [
        _section('4 周训练路径', '现实事件触发 → 用户记录感受 → AI 识别自尊模式 → 事实与解释分离 → 价值体系重构 → 生成具体行动 → 用户执行 → 复盘 → 形成稳定自尊证据库。'),
        ..._journey.map((w) => _journeyCard(w)),
      ]);

  Widget _journeyCard(_JourneyWeek w) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${w.label} · ${w.title}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            ...w.tasks.map((t) => Row(children: [const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF4F46E5)), const SizedBox(width: 8), Expanded(child: Text(t))])),
          ]),
        ),
      );

  Widget _evidencePage() => ListView(padding: const EdgeInsets.all(16), children: [
        _section('稳定自尊证据库', '这里不记录“我超过了多少人”，只记录我如何更真实、更负责、更能接纳、更少被外界评价操控。'),
        _progressReportCard(),
        if (_evidence.isEmpty) _section('暂无证据', '去 AI 教练页完成一个小行动，并写一句复盘。'),
        ..._evidence.map((e) => ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
              title: Text(e.scene, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(e.text),
              trailing: Text('${e.time.month}/${e.time.day}'),
            )),
      ]);

  Widget _progressReportCard() {
    final report = _buildProgressReport();
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('自尊成长进度报告', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: report.completionRatio, minHeight: 8, borderRadius: BorderRadius.circular(999)),
          const SizedBox(height: 8),
          Text('完成 ${report.completedFeatures}/${report.totalFeatures} 个子功能 · ${(report.completionRatio * 100).round()}%'),
          const SizedBox(height: 8),
          Text('主要自尊来源：${report.topSelfWorthSources.join('、')}', style: const TextStyle(color: Color(0xFF475569))),
          Text('需要照顾的指标：${report.lowMetrics.isEmpty ? '暂无明显低项' : report.lowMetrics.join('、')}', style: const TextStyle(color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Text(report.summary, style: const TextStyle(height: 1.45, color: Color(0xFF334155))),
        ]),
      ),
    );
  }

  Widget _prompts() => ListView(padding: const EdgeInsets.all(16), children: [
        _section('已接入 AI 提示词统一配置中心', '点击右上角调节按钮，或下方按钮，可编辑本模块所有全局层、模块层、场景层、输出格式层 Prompt。覆盖值保存在 ai_prompt.self_worth_ai.*，与其他模块隔离。'),
        FilledButton.icon(onPressed: () => _openPromptSettings(), icon: const Icon(Icons.tune_outlined), label: const Text('打开统一配置中心：真实自尊 SelfWorth AI')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _clearAllModuleData, icon: const Icon(Icons.delete_forever_outlined), label: const Text('一键清空本模块所有数据')),
        const SizedBox(height: 12),
        _section('全局价值层 Prompt', SelfWorthAiPromptConfig.globalValuePrompt),
        _section('模块层 Prompt', SelfWorthAiPromptConfig.modulePrompts.entries.map((e) => '【${SelfWorthAiPromptConfig.labels[e.key] ?? e.key}】${e.value}').join('\n\n')),
        _section('场景层 Prompt', SelfWorthAiPromptConfig.scenePrompts.entries.map((e) => '【${SelfWorthAiPromptConfig.labels[e.key] ?? e.key}】${e.value}').join('\n\n')),
        _section('输出格式 Prompt', SelfWorthAiPromptConfig.outputPrompts.entries.map((e) => '【${SelfWorthAiPromptConfig.labels[e.key] ?? e.key}】${e.value}').join('\n\n')),
      ]);

  Widget _section(String title, String body) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 8), Text(body, style: const TextStyle(height: 1.5, color: Color(0xFF334155)))]),
        ),
      );

  Widget _markdownLike(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Text(text, style: const TextStyle(height: 1.55, color: Color(0xFF1F2937))),
      );
}

class _ModuleSpec {
  final String title;
  final IconData icon;
  final String subtitle;
  final List<String> actions;
  const _ModuleSpec(this.title, this.icon, this.subtitle, this.actions);
}

class _SourceSpec {
  final String name;
  final String description;
  final double value;
  final IconData icon;
  const _SourceSpec(this.name, this.description, this.value, this.icon);
}

class _JourneyWeek {
  final String label;
  final String title;
  final List<String> tasks;
  const _JourneyWeek(this.label, this.title, this.tasks);
}

class _EvidenceRecord {
  final DateTime time;
  final String scene;
  final String text;
  const _EvidenceRecord(this.time, this.scene, this.text);

  Map<String, Object?> toJson() => <String, Object?>{
        'time_ms': time.millisecondsSinceEpoch,
        'scene': scene,
        'text': text,
      };

  static _EvidenceRecord fromJson(Map<dynamic, dynamic> json) {
    final rawMs = json['time_ms'];
    final ms = rawMs is num ? rawMs.toInt() : DateTime.now().millisecondsSinceEpoch;
    return _EvidenceRecord(
      DateTime.fromMillisecondsSinceEpoch(ms),
      (json['scene'] ?? '自尊练习').toString(),
      (json['text'] ?? '').toString(),
    );
  }
}

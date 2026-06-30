import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'boundary_action_coach_catalog.dart';
import 'boundary_action_coach_models.dart';
import 'boundary_action_coach_orchestrator.dart';
import 'boundary_action_coach_prompt_config.dart';

enum BacScene { family, friend, intimacy, parenting, work, selfBoundary, valueBeliefs, resistance }

class BoundaryActionCoachHomePage extends StatefulWidget {
  const BoundaryActionCoachHomePage({super.key});

  @override
  State<BoundaryActionCoachHomePage> createState() => _BoundaryActionCoachHomePageState();
}

class _BoundaryActionCoachHomePageState extends State<BoundaryActionCoachHomePage> {
  final TextEditingController _eventCtrl = TextEditingController(text: '我妈说我周末不回家就是不孝，但我这周真的很累。她一哭我就会内疚。');
  final TextEditingController _personCtrl = TextEditingController(text: '妈妈');
  final TextEditingController _feelingCtrl = TextEditingController(text: '累、内疚、怨');
  final TextEditingController _requestCtrl = TextEditingController(text: '周末回家并证明我仍然爱她');
  final TextEditingController _agreedCtrl = TextEditingController(text: '我以前经常答应周末回家，即使很累');
  final TextEditingController _desireCtrl = TextEditingController(text: '休息，同时保留有限联系');
  BacScene _scene = BacScene.family;
  int _guilt = 72;
  int _resentment = 64;
  int _energy = 38;
  String _tone = '温柔坚定';
  late _CoachResult _result;
  final List<BoundaryCase> _cases = <BoundaryCase>[];
  final List<String> _progress = <String>['已按产品设计重构为：仪表盘 / 事件教练 / 责任地图 / 话术后果 / 角色支持 / 自我成长学习'];
  final Map<String, bool> _dailyReview = <String, bool>{
    '今天我最怨谁？': false,
    '我答应了什么但心里不愿意？': false,
    '我有没有把别人的责任带回自己身上？': false,
    '我有没有尊重别人的“不”？': false,
    '我的下一个“小不”是什么？': false,
  };

  @override
  void initState() {
    super.initState();
    _result = _BoundaryActionCoachEngine.analyze(
      scene: _scene,
      event: _eventCtrl.text,
      person: _personCtrl.text,
      feeling: _feelingCtrl.text,
      request: _requestCtrl.text,
      alreadyAgreed: _agreedCtrl.text,
      desire: _desireCtrl.text,
      tone: _tone,
      guilt: _guilt,
      resentment: _resentment,
      energy: _energy,
    );
  }

  @override
  void dispose() {
    _eventCtrl.dispose();
    _personCtrl.dispose();
    _feelingCtrl.dispose();
    _requestCtrl.dispose();
    _agreedCtrl.dispose();
    _desireCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    setState(() {
      _result = _BoundaryActionCoachEngine.analyze(
        scene: _scene,
        event: _eventCtrl.text,
        person: _personCtrl.text,
        feeling: _feelingCtrl.text,
        request: _requestCtrl.text,
        alreadyAgreed: _agreedCtrl.text,
        desire: _desireCtrl.text,
        tone: _tone,
        guilt: _guilt,
        resentment: _resentment,
        energy: _energy,
      );
      _progress.insert(0, '${TimeOfDay.now().format(context)} 完成一次边界行动循环：识别→责任→burdens/loads→边界→话术→后果→复盘');
    });
  }

  void _saveCase() {
    setState(() {
      _cases.insert(
        0,
        BoundaryCase(
          sceneType: _result.sceneName,
          relatedPerson: _personCtrl.text.trim(),
          description: _eventCtrl.text.trim(),
          myFeeling: _feelingCtrl.text.trim(),
          otherRequest: _requestCtrl.text.trim(),
          alreadyAgreed: _agreedCtrl.text.trim(),
          trueDesire: _desireCtrl.text.trim(),
          guiltLevel: _guilt,
          resentmentLevel: _resentment,
          safetyRisk: _result.safetyRisk,
          aiBoundary: _result.boundary,
          actualAction: _result.action24h,
          reviewResult: _result.reviewQuestion,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到本模块边界事件记录')));
  }

  void _openPromptSettings([String? promptId]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiPromptSettingsPage(
          initialModuleId: BoundaryActionCoachPromptConfig.moduleId,
          initialPromptId: promptId ?? BoundaryActionCoachPromptConfig.globalId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('边界行动教练 · Boundary Action Coach'),
          actions: [
            IconButton(
              onPressed: () => _openPromptSettings(),
              icon: const Icon(Icons.tune_outlined),
              tooltip: 'AI 提示词统一配置中心',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '首页仪表盘'),
              Tab(text: '事件教练'),
              Tab(text: '责任地图'),
              Tab(text: '话术后果'),
              Tab(text: '角色支持'),
              Tab(text: '成长学习'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DashboardTab(result: _result, dailyReview: _dailyReview, onChanged: (key, value) => setState(() => _dailyReview[key] = value)),
            _CaseCoachTab(
              scene: _scene,
              eventCtrl: _eventCtrl,
              personCtrl: _personCtrl,
              feelingCtrl: _feelingCtrl,
              requestCtrl: _requestCtrl,
              agreedCtrl: _agreedCtrl,
              desireCtrl: _desireCtrl,
              guilt: _guilt,
              resentment: _resentment,
              energy: _energy,
              result: _result,
              onSceneChanged: (scene) => setState(() => _scene = scene),
              onGuiltChanged: (value) => setState(() => _guilt = value),
              onResentmentChanged: (value) => setState(() => _resentment = value),
              onEnergyChanged: (value) => setState(() => _energy = value),
              tone: _tone,
              onToneChanged: (value) => setState(() => _tone = value),
              onGenerate: _generate,
              onSave: _saveCase,
            ),
            _ResponsibilityTab(result: _result),
            _ScriptsConsequencesTab(result: _result, onOpenPrompt: _openPromptSettings),
            _RoleSupportTab(result: _result),
            _GrowthLearningTab(result: _result, cases: _cases, progress: _progress),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.result, required this.dailyReview, required this.onChanged});

  final _CoachResult result;
  final Map<String, bool> dailyReview;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(),
        _SectionCard(
          title: '今日边界仪表盘',
          icon: Icons.dashboard_outlined,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: '今日怨气指数', value: '${result.resentment}%'),
                _MetricChip(label: '今日能量余额', value: '${result.energy}%'),
                _MetricChip(label: '今日被请求次数', value: '${result.requestCount}'),
                _MetricChip(label: '成长阶段', value: '${result.growth.currentStage}/11'),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in dailyReview.entries)
              CheckboxListTile(
                dense: true,
                value: entry.value,
                title: Text(entry.key),
                onChanged: (value) => onChanged(entry.key, value ?? false),
              ),
          ],
        ),
        _SectionCard(
          title: '产品使命',
          icon: Icons.flag_outlined,
          children: [Text(BoundaryActionCoachCatalog.mission)],
        ),
        _SectionCard(
          title: '首页仪表盘 10 个入口核对',
          icon: Icons.widgets_outlined,
          children: [
            _ChipWrap(items: BoundaryActionCoachCatalog.homeDashboardItems),
          ],
        ),
        _SectionCard(
          title: '目标用户一一对应',
          icon: Icons.person_search_outlined,
          children: [
            _ChipWrap(items: BoundaryActionCoachCatalog.targetUsers),
          ],
        ),
        _SectionCard(
          title: '产品行动闭环',
          icon: Icons.loop_outlined,
          children: BoundaryActionCoachCatalog.actionLoop.asMap().entries.map((entry) {
            return ListTile(
              dense: true,
              leading: CircleAvatar(radius: 13, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11))),
              title: Text(entry.value),
            );
          }).toList(),
        ),
        _SectionCard(
          title: '诊断维度 / 雷达维度 / 数据对象',
          icon: Icons.schema_outlined,
          children: [
            _BulletList(title: '边界健康测评 10 维', items: BoundaryActionCoachCatalog.assessmentDimensions),
            _BulletList(title: '关系雷达 9 维', items: BoundaryActionCoachCatalog.radarDomains),
            _BulletList(title: '雷达指标 6 项', items: BoundaryActionCoachCatalog.radarMetrics),
            _BulletList(title: '核心数据对象字段', items: BoundaryActionCoachCatalog.dataObjectFields),
          ],
        ),
        _SectionCard(
          title: '10 大模块覆盖',
          icon: Icons.fact_check_outlined,
          children: BoundaryActionCoachCatalog.modules.map((module) => _FeatureExpansion(module: module)).toList(),
        ),
        _SectionCard(
          title: 'MVP / 2.0 / 3.0 版本规划核对',
          icon: Icons.rocket_launch_outlined,
          children: BoundaryActionCoachCatalog.releasePlans.map((item) => Text('• $item')).toList(),
        ),
        _SectionCard(
          title: '产品差异化核对',
          icon: Icons.difference_outlined,
          children: BoundaryActionCoachCatalog.productDifferentiators.map((item) => Text('• $item')).toList(),
        ),
        _SectionCard(
          title: '本轮偏差检查与补正',
          icon: Icons.checklist_rtl_outlined,
          children: BoundaryActionCoachCatalog.auditCorrections.map((item) => Text('• $item')).toList(),
        ),
        _SectionCard(
          title: '子功能联动执行链',
          icon: Icons.account_tree_outlined,
          children: BoundaryActionCoachOrchestrator.linkedSteps().map((step) => _LinkedStepTile(step: step)).toList(),
        ),
      ],
    );
  }
}

class _CaseCoachTab extends StatelessWidget {
  const _CaseCoachTab({
    required this.scene,
    required this.eventCtrl,
    required this.personCtrl,
    required this.feelingCtrl,
    required this.requestCtrl,
    required this.agreedCtrl,
    required this.desireCtrl,
    required this.guilt,
    required this.resentment,
    required this.energy,
    required this.result,
    required this.onSceneChanged,
    required this.onGuiltChanged,
    required this.onResentmentChanged,
    required this.onEnergyChanged,
    required this.tone,
    required this.onToneChanged,
    required this.onGenerate,
    required this.onSave,
  });

  final BacScene scene;
  final TextEditingController eventCtrl;
  final TextEditingController personCtrl;
  final TextEditingController feelingCtrl;
  final TextEditingController requestCtrl;
  final TextEditingController agreedCtrl;
  final TextEditingController desireCtrl;
  final int guilt;
  final int resentment;
  final int energy;
  final _CoachResult result;
  final String tone;
  final ValueChanged<BacScene> onSceneChanged;
  final ValueChanged<int> onGuiltChanged;
  final ValueChanged<int> onResentmentChanged;
  final ValueChanged<int> onEnergyChanged;
  final ValueChanged<String> onToneChanged;
  final VoidCallback onGenerate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: '边界事件输入',
          icon: Icons.edit_note_outlined,
          children: [
            DropdownButtonFormField<BacScene>(
              value: scene,
              decoration: const InputDecoration(labelText: '场景类型', border: OutlineInputBorder()),
              items: BacScene.values.map((s) => DropdownMenuItem(value: s, child: Text(_BoundaryActionCoachEngine.sceneName(s)))).toList(),
              onChanged: (value) => onSceneChanged(value ?? scene),
            ),
            const SizedBox(height: 10),
            _TextBox(controller: personCtrl, label: '相关人物'),
            _TextBox(controller: eventCtrl, label: '事件描述', maxLines: 4),
            _TextBox(controller: feelingCtrl, label: '我的感受'),
            _TextBox(controller: requestCtrl, label: '对方要求'),
            _TextBox(controller: agreedCtrl, label: '我已经答应了什么'),
            _TextBox(controller: desireCtrl, label: '我真正想要什么'),
            _SliderRow(label: '当前罪疚感', value: guilt, onChanged: onGuiltChanged),
            _SliderRow(label: '当前怨气', value: resentment, onChanged: onResentmentChanged),
            _SliderRow(label: '当前能量', value: energy, onChanged: onEnergyChanged),
            DropdownButtonFormField<String>(
              value: tone,
              decoration: const InputDecoration(labelText: '话术语气调节', border: OutlineInputBorder()),
              items: const ['温柔坚定', '简短直接', '适合父母', '适合老板', '适合伴侣', '适合朋友', '适合孩子', '适合高冲突对象'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => onToneChanged(value ?? tone),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: onGenerate, icon: const Icon(Icons.auto_awesome), label: const Text('生成边界行动方案'))),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: onSave, icon: const Icon(Icons.save_outlined), label: const Text('保存')),
              ],
            ),
          ],
        ),
        _SectionCard(
          title: '标准输出 1-2：场景摘要与边界问题判断',
          icon: Icons.psychology_alt_outlined,
          children: [
            Text(result.summary),
            const SizedBox(height: 8),
            _ChipWrap(items: result.problemTypes),
            const SizedBox(height: 8),
            Text('安全风险：${result.safetyRisk}'),
          ],
        ),
        _SectionCard(
          title: '标准输出 5-6：核心价值与建议边界',
          icon: Icons.fence_outlined,
          children: [
            _ChipWrap(items: result.coreValues),
            const SizedBox(height: 8),
            Text(result.boundary),
          ],
        ),
      ],
    );
  }
}

class _ResponsibilityTab extends StatelessWidget {
  const _ResponsibilityTab({required this.result});

  final _CoachResult result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: '责任归属表',
          icon: Icons.map_outlined,
          children: [_ResponsibilityTable(map: result.responsibilityMap)],
        ),
        _SectionCard(
          title: 'burdens / loads 判断',
          icon: Icons.scale_outlined,
          children: [
            _BulletList(title: '可帮助的重担 burdens', items: result.responsibilityMap.burdens),
            _BulletList(title: '对方应承担的日常责任 loads', items: result.responsibilityMap.loads),
            Text('当前后果承担者：${result.responsibilityMap.currentConsequenceOwner}'),
            Text('后果应回到：${result.responsibilityMap.correctConsequenceOwner}'),
          ],
        ),
        _SectionCard(
          title: '关系档案',
          icon: Icons.people_alt_outlined,
          children: [
            Text('关系类型：${result.profile.relationType}'),
            Text('常见模式：${result.profile.commonPattern}'),
            Text('是否有罪疚操控：${result.profile.hasGuiltManipulation ? '是' : '否'}'),
            Text('是否有控制：${result.profile.hasControl ? '是' : '否'}'),
            Text('安全等级：${result.profile.safetyLevel}'),
            const SizedBox(height: 8),
            _BulletList(title: '可用边界', items: result.profile.availableBoundaries),
            _BulletList(title: '禁用策略', items: result.profile.disabledStrategies),
          ],
        ),
      ],
    );
  }
}

class _ScriptsConsequencesTab extends StatelessWidget {
  const _ScriptsConsequencesTab({required this.result, required this.onOpenPrompt});

  final _CoachResult result;
  final void Function(String promptId) onOpenPrompt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: '沟通话术工坊',
          icon: Icons.record_voice_over_outlined,
          trailing: TextButton(onPressed: () => onOpenPrompt(BoundaryActionCoachPromptConfig.scriptsId), child: const Text('配置 Prompt')),
          children: [
            _ScriptTile(title: '温柔版', text: result.scripts.gentle),
            _ScriptTile(title: '简短版', text: result.scripts.shortDirect),
            _ScriptTile(title: '高压重复版', text: result.scripts.repeatUnderPressure),
            _ScriptTile(title: '高冲突版', text: result.scripts.highConflict),
            _ScriptTile(title: '职场版', text: result.scripts.workplace),
            _ScriptTile(title: '家庭版', text: result.scripts.family),
            Text('话术检查：${result.scripts.reviewNote}'),
          ],
        ),
        _SectionCard(
          title: '后果设计器',
          icon: Icons.rule_outlined,
          trailing: TextButton(onPressed: () => onOpenPrompt(BoundaryActionCoachPromptConfig.consequencesId), child: const Text('配置 Prompt')),
          children: [
            Text('自然后果：${result.naturalConsequence}'),
            Text('后果/惩罚区分：${result.consequenceCheck}'),
            Text('执行难度：${result.executionDifficulty}'),
          ],
        ),
        _SectionCard(
          title: '对方可能反应与应对',
          icon: Icons.warning_amber_outlined,
          children: result.resistanceResponses.entries.map((entry) => ListTile(dense: true, title: Text(entry.key), subtitle: Text(entry.value))).toList(),
        ),
        _SectionCard(
          title: '现实行动计划',
          icon: Icons.task_alt_outlined,
          children: [
            Text('24 小时：${result.action24h}'),
            Text('7 天：${result.action7d}'),
            Text('复盘问题：${result.reviewQuestion}'),
          ],
        ),
      ],
    );
  }
}

class _RoleSupportTab extends StatelessWidget {
  const _RoleSupportTab({required this.result});

  final _CoachResult result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'AI 角色扮演训练',
          icon: Icons.theater_comedy_outlined,
          children: [
            Text('角色：${result.roleplayRole}'),
            Text('初级模式：${result.roleplayBeginner}'),
            Text('中级模式：${result.roleplayIntermediate}'),
            Text('高级模式：${result.roleplayAdvanced}'),
            const SizedBox(height: 8),
            _ChipWrap(items: const ['清楚表达边界', '承担自己的责任', '不替对方承担情绪', '尊重对方', '有后果', '温柔坚定']),
          ],
        ),
        _SectionCard(
          title: '支持系统模块',
          icon: Icons.groups_outlined,
          children: [
            Text(result.supportReminder),
            _BulletList(title: '行动前', items: result.supportBefore),
            _BulletList(title: '行动后', items: result.supportAfter),
          ],
        ),
        _SectionCard(
          title: '安全与专业帮助边界',
          icon: Icons.health_and_safety_outlined,
          children: [
            Text(result.safetyPlan),
            const Text('本模块不是心理治疗、法律或医疗服务；涉及暴力、威胁、自伤他伤、成瘾、严重精神健康危机、非法职场压迫时，请优先使用当地专业资源。'),
          ],
        ),
      ],
    );
  }
}

class _GrowthLearningTab extends StatelessWidget {
  const _GrowthLearningTab({required this.result, required this.cases, required this.progress});

  final _CoachResult result;
  final List<BoundaryCase> cases;
  final List<String> progress;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: '自我边界管理',
          icon: Icons.self_improvement_outlined,
          children: [
            _BulletList(title: '时间', items: result.selfTimeBoundaries),
            _BulletList(title: '金钱', items: result.selfMoneyBoundaries),
            _BulletList(title: '身体/语言/欲望', items: result.selfBodyLanguageDesireBoundaries),
          ],
        ),
        _SectionCard(
          title: '成长路径追踪',
          icon: Icons.terrain_outlined,
          children: [
            Text('当前阶段：${result.growth.currentStage}/11'),
            Text('本周“小不”：${result.growth.weeklySmallNo}'),
            Text('本周“自由的是”：${result.growth.weeklyFreeYes}'),
            Text('罪疚变化：${result.growth.guiltChange}，怨气变化：${result.growth.resentmentChange}，尊重别人边界评分：${result.growth.respectOthersBoundaryScore}'),
            Text('支持系统使用：${result.growth.supportSystemUse}'),
          ],
        ),
        _SectionCard(
          title: '学习与案例库',
          icon: Icons.menu_book_outlined,
          children: [
            _BulletList(title: '16 个学习主题', items: BoundaryActionCoachCatalog.learningTopics),
            _BulletList(title: '8 个抽象案例卡', items: BoundaryActionCoachCatalog.caseCards),
            _BulletList(title: '11 个成长阶段', items: BoundaryActionCoachCatalog.growthStages),
          ],
        ),
        _SectionCard(
          title: '已保存边界事件',
          icon: Icons.folder_copy_outlined,
          children: cases.isEmpty
              ? [const Text('还没有保存事件。生成方案后点击“保存”。')]
              : cases.map((item) => ListTile(title: Text('${item.sceneType} · ${item.relatedPerson}'), subtitle: Text(item.aiBoundary))).toList(),
        ),
        _SectionCard(
          title: '同步开发进度',
          icon: Icons.sync_outlined,
          children: progress.take(8).map((item) => Text('• $item')).toList(),
        ),
      ],
    );
  }
}

class _BoundaryActionCoachEngine {
  static String sceneName(BacScene scene) => const <BacScene, String>{
        BacScene.family: '原生家庭边界',
        BacScene.friend: '朋友边界',
        BacScene.intimacy: '婚姻/亲密关系边界',
        BacScene.parenting: '育儿边界',
        BacScene.work: '职场边界',
        BacScene.selfBoundary: '自我边界',
        BacScene.valueBeliefs: '信仰/价值观边界',
        BacScene.resistance: '阻力应对',
      }[scene]!;

  static _CoachResult analyze({
    required BacScene scene,
    required String event,
    required String person,
    required String feeling,
    required String request,
    required String alreadyAgreed,
    required String desire,
    required String tone,
    required int guilt,
    required int resentment,
    required int energy,
  }) {
    final text = '$event $person $feeling $request $alreadyAgreed $desire $tone';
    final hasRisk = _hasAny(text, const ['家暴', '威胁', '打', '跟踪', '自杀', '伤害', '恐吓', '强迫']);
    final rescue = _hasAny(text, const ['替', '收拾', '还钱', '救', '承担', '借钱']);
    final selfLoss = _hasAny(text, const ['刷手机', '熬夜', '控制不住', '暴食', '拖延', '成瘾']);
    final guiltManipulation = _hasAny(text, const ['不孝', '自私', '白养', '不要我', '不爱', '失望']);
    final sceneLabel = sceneName(scene);
    final boundary = _boundaryFor(scene, person, desire);
    final scripts = BoundaryScriptSet(
      gentle: '$person，我在乎你，也愿意保持关系。基于“$tone”的语气，这次我不能用牺牲自己来满足这个要求。我可以做的是：$boundary',
      shortDirect: '这次我不能这样做。我可以提供一个有限安排。',
      repeatUnderPressure: '我理解你不高兴，但我的边界不变。我们冷静后再继续谈。',
      highConflict: '如果继续辱骂、威胁或施压，我会结束这次谈话，并改在安全的时候沟通。',
      workplace: '我可以在工作时间内完成我职责内的部分。若优先级变化，请帮我确认哪项任务先暂停。',
      family: '$person，我爱你，但我的时间、婚姻/生活安排和休息需要由我负责。这次安排不变。',
      reviewNote: '当前语气：$tone。避免过度解释、求饶式道歉、攻击、控制对方或用威胁代替后果。已纳入“我已经答应了什么”：$alreadyAgreed。',
    );
    final responsibility = ResponsibilityMap(
      mine: const ['我的时间', '我的身体和能量', '我的选择', '我的表达方式', '我的罪疚感处理', '我能提供的有限帮助'],
      theirs: const ['对方的失望', '对方的愤怒或哭泣', '对方的评价', '对方自己的选择', '对方日常责任的自然后果'],
      shared: const ['沟通方式', '关系修复', '必要帮助的范围', '是否继续协商下一次安排'],
      burdens: hasRisk ? const ['安全危机需要优先处理', '短期真实危机可寻求外部支持'] : const ['真实孤独或压力可以被看见', '突发疾病/丧失/危机可有限帮助'],
      loads: rescue ? const ['长期拖延', '反复借钱', '情绪勒索', '不承担工作或家庭责任'] : const ['对方的失望情绪', '对方对你的评价', '对方日常选择产生的后果'],
      currentConsequenceOwner: guilt > 60 || rescue ? '用户正在承担较多后果' : '双方后果相对可辨认',
      correctConsequenceOwner: '行为者本人，同时保留共同关系修复责任',
    );
    final profile = RelationshipProfile(
      relationType: sceneLabel,
      commonPattern: guiltManipulation ? '罪疚施压 + 用户退让' : rescue ? '过度负责 + 后果错位' : '责任边界不清',
      hasGuiltManipulation: guiltManipulation,
      hasControl: _hasAny(text, const ['必须', '不准', '控制', '冷暴力', '威胁']),
      realNeed: request.trim().isEmpty ? '需要进一步澄清' : request,
      myTypicalReaction: guilt > 60 ? '内疚后撤回边界' : '想表达但担心冲突',
      otherTypicalReaction: guiltManipulation ? '指责、哭诉或贴标签' : '失望、讨价还价或继续请求',
      availableBoundaries: const ['降低频率', '限定时长', '限定金额/任务范围', '结束辱骂性谈话', '改为书面确认'],
      disabledStrategies: const ['突然消失', '报复', '羞辱对方', '无限解释', '用边界控制别人'],
      safetyLevel: hasRisk ? '高风险：先安全计划' : '日常关系冲突：可练习温柔坚定边界',
    );
    return _CoachResult(
      sceneName: sceneLabel,
      summary: '你正在面对 $sceneLabel。你的真实需要是“$desire”，对方的要求是“$request”，你已经答应过的是“$alreadyAgreed”。当前重点不是变冷漠，而是区分哪些责任属于你、哪些属于对方，并把边界转化为可执行行动。',
      problemTypes: <String>[if (guiltManipulation) '顺从者/罪疚压力', if (rescue) '过度拯救/后果错位', if (selfLoss || scene == BacScene.selfBoundary) '自我边界', if (scene == BacScene.resistance) '阻力应对', '责任混乱'],
      coreValues: const ['爱', '自由', '责任', '真相', '后果', '尊重'],
      responsibilityMap: responsibility,
      profile: profile,
      scripts: scripts,
      growth: BoundaryGrowthStage(
        currentStage: guilt > 60 ? 6 : 5,
        weeklySmallNo: '拒绝一个低风险请求，并把解释限制在两句话内。',
        weeklyFreeYes: '选择一个你真心愿意的帮助，明确时间、范围和结束点。',
        guiltChange: guilt - 50,
        resentmentChange: resentment - 50,
        respectOthersBoundaryScore: 70,
        supportSystemUse: hasRisk ? '需要立即联系安全资源' : '行动前后各联系一次支持者',
      ),
      boundary: boundary,
      naturalConsequence: '如果对方继续越界：结束当次通话/离开现场/改为文字沟通；不再用撤回边界来消除对方情绪。',
      consequenceCheck: '这是保护自己并让后果回到行为者身上，不是惩罚、报复或控制对方。',
      executionDifficulty: hasRisk ? '高：存在安全风险，优先专业与紧急资源。' : guilt > 70 ? '中高：内疚可能让你撤回，需要支持者。' : '中：需要提前写好话术并复盘。',
      resistanceResponses: const {
        '愤怒/指责': '我听见你很生气，但我不会在被攻击时继续谈。',
        '哭诉/受害': '我知道你难过，但这个决定不变。我们可以约另一个时间连接。',
        '说你自私': '我不接受用这个词定义我。我是在说明我能做和不能做的部分。',
        '冷暴力': '你愿意沟通时我们再谈，我不会因为冷战改变边界。',
        '威胁': '我会优先安全，并联系可信的人或当地专业资源。',
      },
      action24h: '写下温柔版和高压重复版话术，先发给一个可信支持者看。',
      action7d: '执行一次有限边界，记录对方反应、你的罪疚感、是否撤回边界。',
      reviewQuestion: '我承担了什么？什么不是我的？我有没有让后果回到行为者身上？我有没有尊重对方的“不”？',
      roleplayRole: _roleFor(scene),
      roleplayBeginner: '只练一句边界话，不解释过度。',
      roleplayIntermediate: '模拟对方说“你太自私了/我白养你了/别人都可以”，练习重复边界。',
      roleplayAdvanced: '连续三轮施压中保持温柔坚定，不攻击、不退缩、不控制对方。',
      supportReminder: hasRisk ? '不要单独面对高风险关系，先做安全计划。' : '边界成长通常不能孤立硬撑，先找安全连接，再做困难边界。',
      supportBefore: const ['选择一个可信朋友', '说明你要设定的边界', '约定行动后 10 分钟复盘'],
      supportAfter: const ['记录是否撤回边界', '记录身体感受', '决定下一次更小或更清楚的行动'],
      safetyRisk: hasRisk ? '检测到威胁/暴力/自伤他伤等关键词，请优先安全与专业资源。' : '未检测到明显高危词，但仍需观察升级迹象。',
      safetyPlan: hasRisk ? '先离开危险现场，联系可信的人、当地紧急服务、危机热线或法律/心理专业支持。' : '若出现威胁、跟踪、暴力、经济控制或严重恐吓，立即从沟通建议切换到安全计划。',
      selfTimeBoundaries: const ['每日时间预算', '夜间勿扰', '深度工作保护', '休息不可随意挪用'],
      selfMoneyBoundaries: const ['有限帮助预算', '借钱记录', '冲动消费冷静期', '家庭经济边界'],
      selfBodyLanguageDesireBoundaries: const ['睡眠底线', '不使用攻击性语言', '承认欲望但设计限制', '成瘾风险找外部支持'],
      learningTopics: const ['什么是边界', '什么属于我', 'burdens 与 loads', '四类边界问题', '十条边界律', '家庭/朋友/婚姻/育儿/工作/自我边界', '宽恕与和解', '有边界的一天'],
      caseCards: const ['Sherrie 型', 'Bill 父母型', 'Rachel 型', 'Steve 型', 'Jim 型', 'Robby 型', 'Susie 型', 'Jerry 型'],
      resentment: resentment,
      energy: energy,
      requestCount: 1 + (guiltManipulation ? 1 : 0) + (rescue ? 1 : 0) + (selfLoss ? 1 : 0),
    );
  }

  static String _boundaryFor(BacScene scene, String person, String desire) {
    if (scene == BacScene.work) return '我会先完成职责内优先级最高的任务；下班后的新增需求需要重新确认优先级。';
    if (scene == BacScene.friend) return '我可以听你说 20 分钟，但不能成为你唯一的情绪出口；之后请联系其他支持资源。';
    if (scene == BacScene.parenting) return '我会说清规则和后果，但不替孩子承担他能承担的自然后果。';
    if (scene == BacScene.selfBoundary) return '今晚先做一个最小限制：固定睡前 30 分钟不刷手机，并找一个人复盘。';
    if (scene == BacScene.intimacy) return '我会用 I statement 表达感受和需要；若继续冷暴力/辱骂，我会暂停谈话。';
    return '$person，这周我会保留“$desire”的安排；我愿意有限连接，但不会用牺牲自己来证明爱。';
  }

  static String _roleFor(BacScene scene) {
    if (scene == BacScene.work) return '控制型老板';
    if (scene == BacScene.friend) return '情绪倾倒型朋友';
    if (scene == BacScene.intimacy) return '逃避或冷处理伴侣';
    if (scene == BacScene.parenting) return '叛逆孩子';
    if (scene == BacScene.valueBeliefs) return '罪疚操控型组织成员';
    return '哭诉或愤怒型父母';
  }

  static bool _hasAny(String text, List<String> words) => words.any(text.contains);
}

class _CoachResult {
  const _CoachResult({
    required this.sceneName,
    required this.summary,
    required this.problemTypes,
    required this.coreValues,
    required this.responsibilityMap,
    required this.profile,
    required this.scripts,
    required this.growth,
    required this.boundary,
    required this.naturalConsequence,
    required this.consequenceCheck,
    required this.executionDifficulty,
    required this.resistanceResponses,
    required this.action24h,
    required this.action7d,
    required this.reviewQuestion,
    required this.roleplayRole,
    required this.roleplayBeginner,
    required this.roleplayIntermediate,
    required this.roleplayAdvanced,
    required this.supportReminder,
    required this.supportBefore,
    required this.supportAfter,
    required this.safetyRisk,
    required this.safetyPlan,
    required this.selfTimeBoundaries,
    required this.selfMoneyBoundaries,
    required this.selfBodyLanguageDesireBoundaries,
    required this.learningTopics,
    required this.caseCards,
    required this.resentment,
    required this.energy,
    required this.requestCount,
  });

  final String sceneName;
  final String summary;
  final List<String> problemTypes;
  final List<String> coreValues;
  final ResponsibilityMap responsibilityMap;
  final RelationshipProfile profile;
  final BoundaryScriptSet scripts;
  final BoundaryGrowthStage growth;
  final String boundary;
  final String naturalConsequence;
  final String consequenceCheck;
  final String executionDifficulty;
  final Map<String, String> resistanceResponses;
  final String action24h;
  final String action7d;
  final String reviewQuestion;
  final String roleplayRole;
  final String roleplayBeginner;
  final String roleplayIntermediate;
  final String roleplayAdvanced;
  final String supportReminder;
  final List<String> supportBefore;
  final List<String> supportAfter;
  final String safetyRisk;
  final String safetyPlan;
  final List<String> selfTimeBoundaries;
  final List<String> selfMoneyBoundaries;
  final List<String> selfBodyLanguageDesireBoundaries;
  final List<String> learningTopics;
  final List<String> caseCards;
  final int resentment;
  final int energy;
  final int requestCount;
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xffedf7f1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('帮助每个人在爱与真理中建立边界，把自由、责任和真实带回现实关系。', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('识别问题 → 区分责任 → 澄清价值 → 设计边界 → 练习表达 → 承担后果 → 建立支持 → 复盘成长'),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children, this.trailing});

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                if (trailing != null) trailing!,
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}


class _LinkedStepTile extends StatelessWidget {
  const _LinkedStepTile({required this.step});

  final BoundaryLinkedStep step;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(step.moduleTitle),
      subtitle: Text('输入 ${step.consumes.length} 项 → 子功能 ${step.runsSubFunctions.length} 项 → 输出 ${step.produces.length} 项'),
      children: [
        _BulletList(title: '消耗上游数据', items: step.consumes),
        _BulletList(title: '执行子功能', items: step.runsSubFunctions),
        _BulletList(title: '产出下游数据', items: step.produces),
        _BulletList(title: '流向模块', items: step.feedsInto),
      ],
    );
  }
}

class _FeatureExpansion extends StatelessWidget {
  const _FeatureExpansion({required this.module});

  final BoundaryFeatureModule module;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: module.title.startsWith('1.') || module.title.startsWith('2.'),
      leading: Icon(module.landed ? Icons.check_circle : Icons.radio_button_unchecked, color: module.landed ? Colors.green : null),
      title: Text(module.title),
      subtitle: Text('${module.releasePhase} · ${module.coreValue} · Prompt: ${module.promptId}'),
      children: [
        ListTile(title: const Text('解决的问题'), subtitle: Text(module.problemSolved)),
        ListTile(title: const Text('子功能'), subtitle: Text(module.subFeatures.join(' / '))),
        ListTile(title: const Text('AI 输出'), subtitle: Text(module.aiOutputs.join(' / '))),
        ListTile(title: const Text('数据对象'), subtitle: Text(module.dataObjects.join(' / '))),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label：$value'));
  }
}

class _TextBox extends StatelessWidget {
  const _TextBox({required this.controller, required this.label, this.maxLines = 1});

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text('$label：$value')),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: items.map((item) => Chip(label: Text(item))).toList());
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ...items.map((item) => Text('• $item')),
        ],
      ),
    );
  }
}

class _ResponsibilityTable extends StatelessWidget {
  const _ResponsibilityTable({required this.map});

  final ResponsibilityMap map;

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      const ['属于我的责任', '不属于我的责任', '可以共同面对'],
      [map.mine.join('\n'), map.theirs.join('\n'), map.shared.join('\n')],
    ];
    return Table(
      border: TableBorder.all(color: Colors.black12),
      columnWidths: const <int, TableColumnWidth>{0: FlexColumnWidth(), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
      children: rows.map((row) {
        return TableRow(children: row.map((cell) => Padding(padding: const EdgeInsets.all(8), child: Text(cell))).toList());
      }).toList(),
    );
  }
}

class _ScriptTile extends StatelessWidget {
  const _ScriptTile({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(dense: true, title: Text(title), subtitle: Text(text));
  }
}

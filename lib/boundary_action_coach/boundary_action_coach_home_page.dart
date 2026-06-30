import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'boundary_action_coach_catalog.dart';
import 'boundary_action_coach_prompt_config.dart';

enum BacScene { family, friend, intimacy, parenting, work, self, values, resistance }

class BoundaryActionCoachHomePage extends StatefulWidget {
  const BoundaryActionCoachHomePage({super.key});
  @override
  State<BoundaryActionCoachHomePage> createState() => _BoundaryActionCoachHomePageState();
}

class _BoundaryActionCoachHomePageState extends State<BoundaryActionCoachHomePage> {
  final TextEditingController _caseCtrl = TextEditingController(text: '我妈说我周末不回家就是不孝，但我这周真的很累。她一哭我就会内疚。');
  BacScene _scene = BacScene.family;
  _CoachResult? _result;
  final List<String> _progress = <String>['MVP 1.0：边界诊断、责任地图、场景教练、话术、后果、复盘、成长阶段已作为独立模块落地'];
  final Map<String, bool> _daily = <String, bool>{
    '今天我注意到怨气信号': false,
    '今天我区分了我的/你的/共同责任': false,
    '今天我练习了一个小的“不”': false,
    '今天我没有替别人承担自然后果': false,
    '今天我尊重了别人的“不”': false,
  };

  @override
  void initState() { super.initState(); _run(); }
  @override
  void dispose() { _caseCtrl.dispose(); super.dispose(); }

  void _run() {
    setState(() {
      _result = _BoundaryActionCoach.analyze(_caseCtrl.text.trim(), _scene);
      _progress.insert(0, "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} 已生成：诊断 → 责任归属 → burdens/loads → 边界 → 话术 → 后果 → 复盘");
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('边界行动教练 · Boundary Action Coach'),
        actions: [
          IconButton(onPressed: _openPromptSettings, icon: const Icon(Icons.tune_outlined), tooltip: 'AI提示词统一配置中心'),
          IconButton(onPressed: _showPrompt, icon: const Icon(Icons.psychology_alt_outlined), tooltip: '三层 Prompt'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hero(),
          const SizedBox(height: 12),
          _section('今日边界仪表盘', Icons.dashboard_outlined, [
            _chips(['怨气指数 ${r.resentment}', '能量余额 ${r.energy}', '被请求 ${r.requests}', '本周阶段 ${r.stage}/11']),
            ..._daily.keys.map((k) => CheckboxListTile(value: _daily[k], dense: true, title: Text(k), onChanged: (v) => setState(() => _daily[k] = v ?? false))),
          ]),
          _inputCard(),
          _section('1. 边界诊断中心', Icons.radar_outlined, [
            Text(r.summary), _chips(r.problemTypes), const SizedBox(height: 8), _radar(r.domainScores), Text('怨气警报：${r.resentmentAlarm}'),
          ]),
          _section('2. 责任归属地图', Icons.map_outlined, [_responsibilityTable(r), const SizedBox(height: 8), Text('burdens / loads：${r.loadJudgment}'), Text('后果错位检测：${r.consequenceMisplacement}')]),
          _section('3. 场景 AI 教练', Icons.forum_outlined, [Text('场景：${r.sceneName}'), Text('核心价值：${r.values.join('、')}'), Text('建议边界：${r.boundary}')]),
          _section('4. 沟通话术工坊', Icons.record_voice_over_outlined, r.scripts.entries.map((e) => ListTile(dense: true, title: Text(e.key), subtitle: Text(e.value))).toList()),
          _section('5. 后果设计器', Icons.rule_outlined, [Text(r.consequence), Text('执行难度：${r.difficulty}'), Text('后果不是惩罚：保护自己、让责任回到行为者身上，而不是报复或控制对方。')]),
          _section('6. AI 角色扮演训练', Icons.theater_comedy_outlined, [Text(r.roleplay), _chips(['初级：一句边界话', '中级：应对反击', '高级：连续施压不退缩'])]),
          _section('7. 支持系统', Icons.groups_outlined, [Text(r.support)]),
          _section('8. 自我边界管理', Icons.self_improvement_outlined, [Text('时间/金钱/身体/语言/欲望：${r.selfBoundary}')]),
          _section('9. 成长路径追踪', Icons.terrain_outlined, [Text('当前阶段：${r.stageText}'), Text('本周“小不”：${r.smallNo}'), Text('本周“自由的是”：${r.freeYes}')]),
          _section('10. 学习与案例库', Icons.menu_book_outlined, [_chips(_BoundaryActionCoach.caseCards), Text('行动化学习：什么属于我、burdens 与 loads、四类边界问题、十条边界律、家庭/朋友/婚姻/育儿/工作/自我/价值观边界。')]),
          _section('现实行动计划', Icons.task_alt_outlined, [Text('24 小时：${r.action24h}'), Text('7 天：${r.action7d}'), Text('复盘：${r.review}')]),
          _section('边界行动循环', Icons.loop_outlined, BoundaryActionCoachCatalog.actionLoop.asMap().entries.map((e) => ListTile(dense: true, leading: CircleAvatar(radius: 12, child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11))), title: Text(e.value))).toList()),
          _section('MVP/2.0/3.0 功能覆盖矩阵', Icons.fact_check_outlined, BoundaryActionCoachCatalog.modules.map((m) => ExpansionTile(initiallyExpanded: m.title.startsWith('1.') || m.title.startsWith('2.'), leading: Icon(m.landed ? Icons.check_circle : Icons.radio_button_unchecked, color: m.landed ? Colors.green : null), title: Text(m.title), subtitle: Text('${m.releasePhase} · ${m.coreValue} · Prompt: ${m.promptId}'), children: [ListTile(title: const Text('解决的问题'), subtitle: Text(m.problemSolved)), ListTile(title: const Text('子功能'), subtitle: Text(m.subFeatures.join(' / '))), ListTile(title: const Text('AI 输出'), subtitle: Text(m.aiOutputs.join(' / '))), ListTile(title: const Text('数据对象'), subtitle: Text(m.dataObjects.join(' / ')))] )).toList()),
          _section('同步开发进度', Icons.sync_outlined, _progress.take(5).map(Text.new).toList()),
        ],
      ),
    );
  }

  Widget _hero() => Card(color: const Color(0xffedf7f1), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('帮助每个人在爱与真理中建立边界，把自由、责任和真实带回现实关系。', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('识别问题 → 区分责任 → 澄清价值 → 设计边界 → 练习表达 → 承担后果 → 建立支持 → 复盘成长')])));
  Widget _inputCard() => _section('输入一个真实边界事件', Icons.edit_note_outlined, [DropdownButton<BacScene>(value: _scene, isExpanded: true, items: BacScene.values.map((s) => DropdownMenuItem(value: s, child: Text(_BoundaryActionCoach.sceneName(s)))).toList(), onChanged: (v) => setState(() => _scene = v ?? _scene)), TextField(controller: _caseCtrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '描述事件、对方要求、你的感受、已答应什么、真正想要什么')), const SizedBox(height: 8), FilledButton.icon(onPressed: _run, icon: const Icon(Icons.auto_awesome), label: const Text('生成边界行动闭环'))]);
  Widget _section(String title, IconData icon, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))) ]), const Divider(), ...children])));
  Widget _chips(List<String> items) => Wrap(spacing: 8, runSpacing: 8, children: items.map((e) => Chip(label: Text(e))).toList());
  Widget _radar(Map<String, int> m) => Column(children: m.entries.map((e) => Row(children: [SizedBox(width: 92, child: Text(e.key)), Expanded(child: LinearProgressIndicator(value: e.value / 100)), const SizedBox(width: 8), Text('${e.value}')])).toList());
  Widget _responsibilityTable(_CoachResult r) => Table(border: TableBorder.all(color: Colors.black12), children: [['属于我的', '不属于我的', '共同面对'], r.mine, r.theirs, r.shared].map((row) => TableRow(children: row.map((c) => Padding(padding: const EdgeInsets.all(8), child: Text(c))).toList())).toList());
  void _openPromptSettings() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPromptSettingsPage(initialModuleId: BoundaryActionCoachPromptConfig.moduleId, initialPromptId: BoundaryActionCoachPromptConfig.globalId)));
  void _showPrompt() => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('AI 三层 Prompt 已接入统一配置中心'), content: const SingleChildScrollView(child: Text(_BoundaryActionCoach.prompt)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')), FilledButton(onPressed: () { Navigator.pop(context); _openPromptSettings(); }, child: const Text('去配置'))]));
}

class _CoachResult { _CoachResult({required this.summary, required this.sceneName, required this.problemTypes, required this.domainScores, required this.resentmentAlarm, required this.mine, required this.theirs, required this.shared, required this.loadJudgment, required this.consequenceMisplacement, required this.values, required this.boundary, required this.scripts, required this.consequence, required this.difficulty, required this.roleplay, required this.support, required this.selfBoundary, required this.stage, required this.stageText, required this.smallNo, required this.freeYes, required this.action24h, required this.action7d, required this.review, required this.resentment, required this.energy, required this.requests});
  final String summary, sceneName, resentmentAlarm, loadJudgment, consequenceMisplacement, boundary, consequence, difficulty, roleplay, support, selfBoundary, stageText, smallNo, freeYes, action24h, action7d, review, resentment, energy, requests; final int stage; final List<String> problemTypes, values, mine, theirs, shared; final Map<String,int> domainScores; final Map<String,String> scripts; }

class _BoundaryActionCoach {
  static const caseCards = ['Sherrie型', 'Bill父母型', 'Rachel型', 'Steve型', 'Jim型', 'Robby型', 'Susie型', 'Jerry型'];
  static String sceneName(BacScene s) => const {BacScene.family:'原生家庭边界', BacScene.friend:'朋友边界', BacScene.intimacy:'婚姻/亲密关系边界', BacScene.parenting:'育儿边界', BacScene.work:'职场边界', BacScene.self:'自我边界', BacScene.values:'信仰/价值观边界', BacScene.resistance:'阻力应对'}[s]!;
  static _CoachResult analyze(String text, BacScene scene) {
    final guilt = _hit(text, ['内疚','不孝','自私','失望','白养']); final rescue = _hit(text, ['替','收拾','还钱','帮他','帮她']); final self = _hit(text, ['刷手机','熬夜','控制不住','拖延','暴食']); final risk = _hit(text, ['威胁','打','跟踪','自杀','伤害','家暴']);
    final types = <String>[if (guilt > 0) '顺从者/罪疚压力', if (rescue > 0) '过度拯救/后果错位', if (self > 0 || scene == BacScene.self) '自我边界', if (scene == BacScene.resistance) '外在阻力', '责任混乱'];
    final fam = scene == BacScene.family;
    return _CoachResult(summary: '你正在面对${sceneName(scene)}：一边想保留爱与连接，一边发现自己的时间、情绪或责任被对方要求占用。重点不是立刻断开，而是让责任回到正确的位置。', sceneName: sceneName(scene), problemTypes: types.toSet().toList(), domainScores: {'家庭': fam ? 34 : 62, '亲密': scene == BacScene.intimacy ? 39 : 58, '朋友': scene == BacScene.friend ? 41 : 64, '工作': scene == BacScene.work ? 37 : 66, '自我': self > 0 ? 32 : 55, '支持': 48}, resentmentAlarm: '怨气可能不是你不够爱，而是在提醒：某个责任放错了位置。', mine: ['我的时间、身体、选择、表达方式、罪疚感处理', '我是否给有限帮助', '我如何执行后果'], theirs: ['对方的失望、愤怒、评价、选择', '对方日常责任和自然后果', '对方是否尊重边界'], shared: ['沟通方式', '关系修复', '必要且有限的帮助'], loadJudgment: rescue > 0 ? '更像对方应承担的 loads；可有限帮助，但不要长期代替承担。' : '混合型：真实需要可以被看见，但不等于你必须牺牲自己来满足。', consequenceMisplacement: '若你撤回边界来消除对方情绪，后果会再次落到你身上。', values: ['爱','自由','责任','后果'], boundary: fam ? '这周不回家，但安排一次 30 分钟通话；被贴“不孝”标签时不辩论，只重复安排。' : '提供清楚、有限、可执行的帮助；超出范围时停止参与，并把后果交还给行为者。', scripts: {'温柔版':'我在乎你，也愿意保持联系；但这件事我不能按你的期待来做。我可以提供一个有限选择。','简短版':'这次我不能这样做；我可以做的是这个有限版本。','高压重复版':'我理解你不高兴，但我的安排不变。我们冷静后再继续谈。'}, consequence: '如果对方继续辱骂、施压或越界：结束当次通话/离开现场/改为文字沟通，并在下次只讨论可执行安排。', difficulty: risk > 0 ? '高：出现安全词，请优先安全计划和当地专业/紧急资源。' : '中：对方可能不满，你可能内疚；建议提前找支持者复盘。', roleplay: '模拟对方说“你太自私了”，练习回答：“我听见你失望，但我不会用牺牲自己来证明爱。”', support: risk > 0 ? '不要单独硬撑；联系可信朋友、咨询师、法律/危机热线或当地紧急服务。' : '行动前告诉一个安全的人你的边界句，行动后复盘 10 分钟。', selfBoundary: '用小限制替代宏大誓言：今晚 23:00 前睡、预算上限、勿扰模式、只承诺能做到的事。', stage: guilt > 0 ? 6 : 5, stageText: guilt > 0 ? '带着罪疚感仍然设限' : '练习小的“不”', smallNo: '本周拒绝一个低风险请求，并不超过两句解释。', freeYes: '选择一个你真心愿意的帮助，并明确时间/范围。', action24h: '写下边界句，发给支持者看一遍，再决定沟通时间。', action7d: '执行一次有限边界，记录对方反应、你的罪疚感和是否撤回。', review: '我承担了什么？什么不是我的？我有没有用行动让后果归位？', resentment: '${(45 + guilt*15 + rescue*10).clamp(0, 100)}%', energy: '${(72 - guilt*10 - rescue*8 - self*12).clamp(5, 100)}%', requests: '${1 + guilt + rescue + self}次');
  }
  static int _hit(String t, List<String> w) => w.where(t.contains).length;
  static const prompt = '''全局价值层：你是“边界行动教练 AI”，价值框架来源于《Boundaries: When to Say Yes, How to Say No》。帮助用户区分我的责任、别人的责任与共同责任；区分 burdens 与 loads；在爱、自由、责任、真相、后果、尊重、成熟、恩典、分离、主动、管家意识和价值真实中行动。
场景层：按家庭、朋友、婚姻/亲密、育儿、职场、自我、信仰/价值观、阻力应对分别分析罪疚操控、过度拯救、关系融合、后果错位、安全风险与专业帮助需求。
输出层：场景摘要；边界问题判断；责任归属表；burdens/loads 判断；核心价值；建议边界；温柔/简短/高压话术；对方反应与应对；24小时/7天行动；支持系统；一句话价值提醒。''';
}

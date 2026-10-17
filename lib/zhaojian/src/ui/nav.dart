import 'package:flutter/material.dart';

import '../domain/controller.dart';
import 'accept_page.dart';
import 'analysis_page.dart';
import 'belief_page.dart';
import 'cog_page.dart';
import 'decide_page.dart';
import 'engine_page.dart';
import 'evidence_page.dart';
import 'forgo_page.dart';
import 'goal_page.dart';
import 'growth_page.dart';
import 'hypothesis_page.dart';
import 'know_act_page.dart';
import 'line_page.dart';
import 'log_page.dart';
import 'map_page.dart';
import 'pending_page.dart';
import 'plans_page.dart';
import 'probe_page.dart';
import 'regret_page.dart';
import 'rope_page.dart';
import 'self_page.dart';
import 'shift_page.dart';
import 'signature_page.dart';
import 'style_page.dart';
import 'wall_page.dart';
import 'widgets.dart';

/// 模块里所有可以打开的页面。
enum ZDest {
  decide,
  belief,
  pending,
  log,
  knowAct,
  regret,
  engine,
  plans,
  rope,
  wall,
  accept,
  cog,
  self,
  evidence,
  hypothesis,
  analysis,
  style,
  shift,
  signature,
  map,
  goal,
  line,
  probe,
  forgo,
  growth,
}

class ZDestInfo {
  const ZDestInfo(this.title, this.subtitle, this.icon, this.group);

  final String title;
  final String subtitle;
  final IconData icon;
  final String group;
}

/// 页面的注册表与跳转。
///
/// 一个页面「已做」当且仅当它在 [_builders] 里：首页、思想地图都只显示已做的，
/// 所以未完成的页面不会出现死链。
class ZNav {
  const ZNav._();

  static const List<String> groups = <String>['选择', '行动', '改变', '我', '方向'];

  static const Map<ZDest, ZDestInfo> info = <ZDest, ZDestInfo>{
    ZDest.decide: ZDestInfo('决策', '补全动机 · 天平 · 一致度 · 封存预测', Icons.balance_outlined, '选择'),
    ZDest.belief: ZDestInfo('信念检验', '远期汇票：这个信念兑付得了吗', Icons.fact_check_outlined, '选择'),
    ZDest.pending: ZDestInfo('未开的牌', '现场速查 · 开牌 · 自知分', Icons.style_outlined, '行动'),
    ZDest.log: ZDestInfo('行为记录', '做了什么 · 事后反应 · 身体信号', Icons.edit_note_outlined, '行动'),
    ZDest.knowAct: ZDestInfo('知行', '愿望 → 决意 → 行动，哪里掉下去', Icons.stairs_outlined, '行动'),
    ZDest.regret: ZDestInfo('回望', '悔恨诊断 · 手段与欲求是否一致', Icons.history_outlined, '行动'),
    ZDest.engine: ZDestInfo('改变引擎', '目标 → 分诊 → 三处设计 → 最小动作', Icons.tune_outlined, '改变'),
    ZDest.plans: ZDestInfo('计划与复盘', '带着修正再来一轮', Icons.event_repeat_outlined, '改变'),
    ZDest.rope: ZDestInfo('绳子', '预先承诺：把现场的硬撑前置', Icons.link_outlined, '改变'),
    ZDest.wall: ZDestInfo('小墙与假设行动', '小而可逆的行为实验', Icons.construction_outlined, '改变'),
    ZDest.accept: ZDestInfo('接受', '控制圈：哪些该改，哪些该放下', Icons.self_improvement_outlined, '改变'),
    ZDest.cog: ZDestInfo('认知重构', '揪出 → 查证 → 体验 → 重设', Icons.psychology_alt_outlined, '改变'),
    ZDest.self: ZDestInfo('自画像', '三层性格 · 核心与展开 · 获得性格', Icons.person_outline, '我'),
    ZDest.evidence: ZDestInfo('证据', '行为考古 · 他人观察 · 自述线索', Icons.folder_open_outlined, '我'),
    ZDest.hypothesis: ZDestInfo('主线与假设', '字母拼成词：支持与反驳', Icons.timeline_outlined, '我'),
    ZDest.analysis: ZDestInfo('AI 分析', '证据分级加权，暂定假设', Icons.analytics_outlined, '我'),
    ZDest.style: ZDestInfo('决策方式', '你实际是怎样做决定的', Icons.donut_small_outlined, '我'),
    ZDest.shift: ZDestInfo('变化', '什么真正改变过我', Icons.trending_up_outlined, '我'),
    ZDest.signature: ZDestInfo('签名', '如果—那么：被行为反复支持的模式', Icons.draw_outlined, '我'),
    ZDest.map: ZDestInfo('原理', '思想地图：每个理论接在哪里', Icons.account_tree_outlined, '我'),
    ZDest.goal: ZDestInfo('目标链', '为什么链追到底，配一个画面', Icons.flag_outlined, '方向'),
    ZDest.line: ZDestInfo('一条线', '选定与舍弃 · 接力 · 羡慕日志', Icons.show_chart_outlined, '方向'),
    ZDest.probe: ZDestInfo('探测', '小探测，收敛到一条线', Icons.explore_outlined, '方向'),
    ZDest.forgo: ZDestInfo('放弃拆分器', '暂时放弃实验：预测 vs 实际', Icons.content_cut_outlined, '方向'),
    ZDest.growth: ZDestInfo('成长回顾', '命中率 · 谁胜出 · 自由感 · 想象深度', Icons.insights_outlined, '方向'),
  };

  static final Map<ZDest, Widget Function(ZhaojianController)> _builders =
      <ZDest, Widget Function(ZhaojianController)>{
    ZDest.decide: (ZhaojianController c) => DecidePage(controller: c),
    ZDest.pending: (ZhaojianController c) => PendingPage(controller: c),
    ZDest.log: (ZhaojianController c) => LogPage(controller: c),
    ZDest.hypothesis: (ZhaojianController c) => HypothesisPage(controller: c),
    ZDest.growth: (ZhaojianController c) => GrowthPage(controller: c),
    ZDest.self: (ZhaojianController c) => SelfPage(controller: c),
    ZDest.evidence: (ZhaojianController c) => EvidencePage(controller: c),
    ZDest.style: (ZhaojianController c) => StylePage(controller: c),
    ZDest.map: (ZhaojianController c) => MapPage(controller: c),
    ZDest.engine: (ZhaojianController c) => EnginePage(controller: c),
    ZDest.plans: (ZhaojianController c) => PlansPage(controller: c),
    ZDest.rope: (ZhaojianController c) => RopePage(controller: c),
    ZDest.wall: (ZhaojianController c) => WallPage(controller: c),
    ZDest.accept: (ZhaojianController c) => AcceptPage(controller: c),
    ZDest.cog: (ZhaojianController c) => CogPage(controller: c),
    ZDest.belief: (ZhaojianController c) => BeliefPage(controller: c),
    ZDest.knowAct: (ZhaojianController c) => KnowActPage(controller: c),
    ZDest.regret: (ZhaojianController c) => RegretPage(controller: c),
    ZDest.goal: (ZhaojianController c) => GoalPage(controller: c),
    ZDest.line: (ZhaojianController c) => LinePage(controller: c),
    ZDest.forgo: (ZhaojianController c) => ForgoPage(controller: c),
    ZDest.probe: (ZhaojianController c) => ProbePage(controller: c),
    ZDest.shift: (ZhaojianController c) => ShiftPage(controller: c),
    ZDest.signature: (ZhaojianController c) => SignaturePage(controller: c),
    ZDest.analysis: (ZhaojianController c) => AnalysisPage(controller: c),
  };

  static bool isReady(ZDest d) => _builders.containsKey(d);

  static List<ZDest> inGroup(String group) => ZDest.values
      .where((ZDest d) => info[d]!.group == group && isReady(d))
      .toList();

  static ZDest? byName(String name) {
    for (final ZDest d in ZDest.values) {
      if (d.name == name) return d;
    }
    return null;
  }

  static void open(BuildContext context, ZhaojianController c, ZDest d) {
    final Widget Function(ZhaojianController)? b = _builders[d];
    if (b == null) {
      zSnack(context, '这一页还在开发中');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => b(c)));
  }
}

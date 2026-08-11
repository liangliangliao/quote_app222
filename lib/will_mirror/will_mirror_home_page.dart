import 'dart:async';

import 'package:flutter/material.dart';

import 'will_mirror_evidence_page.dart';
import 'will_mirror_experiment_page.dart';
import 'will_mirror_goal_workspace_page.dart';
import 'will_mirror_knowledge_repository.dart';
import 'will_mirror_models.dart';
import 'will_mirror_profile_page.dart';
import 'will_mirror_support_pages.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorHomePage extends StatefulWidget {
  const WillMirrorHomePage({
    super.key,
    this.vault,
    this.knowledge,
  });

  final WillMirrorVault? vault;
  final WillMirrorKnowledgeRepository? knowledge;

  @override
  State<WillMirrorHomePage> createState() => _WillMirrorHomePageState();
}

class _WillMirrorHomePageState extends State<WillMirrorHomePage> {
  late final bool _ownsVault = widget.vault == null;
  late final bool _ownsKnowledge = widget.knowledge == null;
  late final WillMirrorVault _vault = widget.vault ?? WillMirrorVault();
  late final WillMirrorKnowledgeRepository _knowledge =
      widget.knowledge ?? WillMirrorKnowledgeRepository();
  WillMirrorGoal? _goal;
  List<WillMirrorWhyNode> _nodes = const <WillMirrorWhyNode>[];
  List<WillMirrorLifeEvidence> _evidence = const <WillMirrorLifeEvidence>[];
  List<WillMirrorHypothesis> _hypotheses = const <WillMirrorHypothesis>[];
  WillMirrorExperiment? _experiment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_ownsVault) unawaited(_vault.close());
    if (_ownsKnowledge) unawaited(_knowledge.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final goal = await _vault.activeGoal();
      final nodes = goal == null
          ? const <WillMirrorWhyNode>[]
          : await _vault.whyNodes(goal.id);
      final evidence = goal == null
          ? const <WillMirrorLifeEvidence>[]
          : await _vault.evidenceForGoal(goal.id);
      final hypotheses = goal == null
          ? const <WillMirrorHypothesis>[]
          : await _vault.hypotheses(goal.id);
      final experiment = await _vault.activeExperiment();
      if (!mounted) return;
      setState(() {
        _goal = goal;
        _nodes = nodes;
        _evidence = evidence;
        _hypotheses = hypotheses;
        _experiment = experiment;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    await _load();
  }

  Future<void> _openEvidence(WillMirrorEvidenceType type) async {
    final goal = _goal;
    if (goal == null) {
      await _open(WillMirrorGoalWorkspacePage(vault: _vault));
      return;
    }
    await _open(
      WillMirrorEvidencePage(
        vault: _vault,
        goal: goal,
        initialType: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('意志之镜'),
        backgroundColor: const Color(0xFFFAFBF9),
        actions: <Widget>[
          IconButton(
            tooltip: '数据与隐私',
            onPressed: () => _open(
              WillMirrorPrivacyPage(vault: _vault, knowledge: _knowledge),
            ),
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                children: <Widget>[
                  _hero(),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    WillMirrorSectionCard(
                      color: WillMirrorPalette.rose,
                      child: Text(
                        '私密 Vault 暂不可用：$_error\n\n为避免泄露，系统不会回退到明文存储。',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _currentModel(),
                  const SizedBox(height: 18),
                  const Text(
                    '五个长期入口',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: WillMirrorPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.filter_vintage_outlined,
                    title: '当前欲望',
                    subtitle: _goal == null
                        ? '今天你最想要什么？先作为表象，不提前解释'
                        : _goal!.text,
                    onTap: () => _open(
                      WillMirrorGoalWorkspacePage(vault: _vault),
                    ),
                    trailing: _goal == null
                        ? const WillMirrorBadge(label: '从这里开始')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.account_tree_outlined,
                    title: 'Why Tree',
                    subtitle: _nodes.isEmpty
                        ? '它为什么重要？允许分叉，直到 Why 应切换为 Where Else'
                        : '${_nodes.length} 个节点 · 纵向深挖与横向分支',
                    onTap: () => _open(
                      WillMirrorGoalWorkspacePage(vault: _vault),
                    ),
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.self_improvement_outlined,
                    title: 'Real-Me',
                    subtitle: _count(WillMirrorEvidenceType.realMe) == 0
                        ? '今天什么时候最像自己？记录主动性、观众、奖励与能量'
                        : '已记录 ${_count(WillMirrorEvidenceType.realMe)} 个最像自己的时刻',
                    onTap: () => _openEvidence(WillMirrorEvidenceType.realMe),
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.directions_walk_outlined,
                    title: '行动镜',
                    subtitle: _count(WillMirrorEvidenceType.action) == 0
                        ? '今天你真正选择了什么？同时记录能力与环境限制'
                        : '已记录 ${_count(WillMirrorEvidenceType.action)} 条实际行动',
                    onTap: () => _openEvidence(WillMirrorEvidenceType.action),
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.science_outlined,
                    title: '当前实验',
                    subtitle: _experiment == null
                        ? '本周正在验证什么？用 7 日低风险生活实验修正模型'
                        : _experiment!.title,
                    onTap: () => _open(
                      WillMirrorExperimentPage(vault: _vault),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '认识与依据',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: WillMirrorPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.grid_view_outlined,
                    title: '获得性格 · 证据矩阵',
                    subtitle: _hypotheses.isEmpty
                        ? '支持、反证、情境限制三栏；没有反证，不发布性格结论'
                        : '${_hypotheses.length} 个可修订候选 · 只显示置信带',
                    onTap: () => _open(
                      WillMirrorProfilePage(
                        vault: _vault,
                        knowledge: _knowledge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.menu_book_outlined,
                    title: '理论证据与误用边界',
                    subtitle: '叔本华第二/三/四篇 · Tal · self-concordance · VIA 边界',
                    onTap: () => _open(
                      WillMirrorKnowledgePage(knowledge: _knowledge),
                    ),
                  ),
                  const SizedBox(height: 10),
                  WillMirrorEntryTile(
                    icon: Icons.lock_outline,
                    title: '数据与隐私',
                    subtitle: '独立加密 Vault · 本地优先 · 导出 · 彻底删除与密钥销毁',
                    onTap: () => _open(
                      WillMirrorPrivacyPage(
                        vault: _vault,
                        knowledge: _knowledge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const WillMirrorGuardrail(),
                ],
              ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF315D4D), Color(0xFF5F7768)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '从表象，走向可验证的自我认识',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Deep Why → 边界检测 → 跨人生验证 → 强制反证 → 现实实验 → 获得性格',
            style: TextStyle(color: Color(0xFFE7F0EA), height: 1.45),
          ),
          SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              WillMirrorBadge(
                label: '本地优先',
                icon: Icons.phone_android,
                color: Color(0xFFE1EAE5),
              ),
              WillMirrorBadge(
                label: '证据可追溯',
                icon: Icons.link,
                color: Color(0xFFE1EAE5),
              ),
              WillMirrorBadge(
                label: '反证必检',
                icon: Icons.gavel_outlined,
                color: Color(0xFFE1EAE5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _currentModel() {
    final high = _hypotheses.where(
      (item) =>
          item.confidenceBand == WillMirrorConfidenceBand.high ||
          item.confidenceBand == WillMirrorConfidenceBand.highWithLimits,
    );
    return WillMirrorSectionCard(
      color: WillMirrorPalette.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '当前认识状态',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_goal == null)
            const Text('尚未建立当前欲望。系统不会替你猜。')
          else ...<Widget>[
            Text(
              _goal!.text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${_nodes.length} 个 Why 节点 · ${_evidence.length} 条人生证据 · ${_hypotheses.length} 个候选 · ${high.length} 个高可信候选',
              style: const TextStyle(
                fontSize: 12,
                color: WillMirrorPalette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _count(WillMirrorEvidenceType type) =>
      _evidence.where((item) => item.type == type).length;
}

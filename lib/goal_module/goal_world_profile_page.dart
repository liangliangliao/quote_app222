import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_world_seed.dart';
import 'goal_world_timeline_page.dart';
import 'goal_world_identity_leap_detail_page.dart';
import 'goal_world_trend_detail_page.dart';

class GoalWorldProfilePage extends StatefulWidget {
  const GoalWorldProfilePage({super.key});

  @override
  State<GoalWorldProfilePage> createState() => _GoalWorldProfilePageState();
}

class _GoalWorldProfilePageState extends State<GoalWorldProfilePage> {
  final _dao = GoalDao();
  final _role = TextEditingController();
  final _lifeArea = TextEditingController();
  final _event = TextEditingController();
  final _feeling = TextEditingController();
  final _desiredIdentity = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  GoalWorldIdentityEvolution _evolution = const GoalWorldIdentityEvolution.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _dao.getWorldProfile();
    final evolution = await _dao.getWorldIdentityEvolution();
    if (!mounted) return;
    _role.text = profile.roleTitle;
    _lifeArea.text = profile.lifeArea;
    _event.text = profile.realEvent;
    _feeling.text = profile.currentFeeling;
    _desiredIdentity.text = profile.desiredIdentity;
    setState(() {
      _evolution = evolution;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _dao.saveWorldProfile(
      roleTitle: _role.text.trim(),
      lifeArea: _lifeArea.text.trim(),
      realEvent: _event.text.trim(),
      currentFeeling: _feeling.text.trim(),
      desiredIdentity: _desiredIdentity.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }


  Future<void> _openTimeline() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalWorldTimelinePage()));
    if (!mounted) return;
    await _load();
  }

  Future<void> _openLeapDetail() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalWorldIdentityLeapDetailPage()));
    if (!mounted) return;
    await _load();
  }

  Future<void> _openTrendDetail() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalWorldTrendDetailPage()));
    if (!mounted) return;
    await _load();
  }

  @override
  void dispose() {
    _role.dispose();
    _lifeArea.dispose();
    _event.dispose();
    _feeling.dispose();
    _desiredIdentity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('构建我的世界身份')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _card(
            child: const Text(
              '目标试验场要尽量来自你的真实世界。先写下你当下的身份、正在经历的事件、感受，以及你想在试验场里练习成为什么样的人。',
              style: TextStyle(height: 1.65, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '现实角色',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(_role, '你现在最像什么角色？', hint: '例如：学生 / 职场人 / 创业者 / 照护者'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in goalWorldRoleSuggestions)
                      _chip(item, selected: _role.text.trim() == item, onTap: () => setState(() => _role.text = item)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '当前主战场',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(_lifeArea, '你最想在什么生活领域先练习？', hint: '例如：学习 / 工作 / 健康 / 关系'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in goalWorldLifeAreas)
                      _chip(item, selected: _lifeArea.text.trim() == item, onTap: () => setState(() => _lifeArea.text = item)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '最近的真实事件与感受',
            child: Column(
              children: [
                _field(_event, '最近一个真实发生的事件', hint: '例如：考研选择、工作转岗、和伴侣争执、拖延论文', maxLines: 3),
                const SizedBox(height: 12),
                _field(_feeling, '你现在最强烈的感受', hint: '例如：迷茫、焦虑、想证明自己、很想改变', maxLines: 2),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '想练习成为什么样的人',
            child: _field(_desiredIdentity, '这次你想在试验场里练习的身份', hint: '例如：更一致、更稳定、更敢行动的人', maxLines: 3),
          ),
          const SizedBox(height: 12),
          if (_evolution.hasContent)
            _card(
              title: '我正在成为什么样的人',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_evolution.stageTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  if (_evolution.stageSubtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_evolution.stageSubtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                  ],
                  const SizedBox(height: 8),
                  Text(_evolution.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
                  if (_evolution.evidence.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('当前演化证据：${_evolution.evidence.take(2).join('；')}', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          _card(
            title: '世界导航链',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.timeline_outlined, size: 18),
                  label: const Text('现实事件时间线'),
                  onPressed: _openTimeline,
                ),
                ActionChip(
                  avatar: const Icon(Icons.psychology_alt_outlined, size: 18),
                  label: const Text('身份跃迁详情'),
                  onPressed: _openLeapDetail,
                ),
                ActionChip(
                  avatar: const Icon(Icons.show_chart_outlined, size: 18),
                  label: const Text('7天成长趋势'),
                  onPressed: _openTrendDetail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存世界身份'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB)),
        ),
        child: Text(text, style: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _card({String? title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

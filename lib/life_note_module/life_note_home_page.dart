import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import '../services/global_ai_settings.dart';
import 'life_note_ai_service.dart';
import 'life_note_models.dart';

class LifeNoteHomePage extends StatefulWidget {
  const LifeNoteHomePage({super.key});

  @override
  State<LifeNoteHomePage> createState() => _LifeNoteHomePageState();
}

class _LifeNoteHomePageState extends State<LifeNoteHomePage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final LifeNoteAiService _service = LifeNoteAiService();
  final GlobalAiSettings _settings = GlobalAiSettings();

  final Set<String> _selectedEmotions = <String>{};
  final Set<String> _sceneTags = <String>{};
  LifeNoteReport? _report;
  String _aiLabel = '读取中...';
  bool _aiAvailable = false;
  bool _loading = false;
  String? _error;

  static const List<String> _emotionOptions = <String>[
    '委屈', '焦虑', '失落', '愤怒', '孤独', '羞耻', '迷茫', '疲惫', '害怕', '空虚', '悲伤', '压抑'
  ];

  static const List<String> _sceneOptions = <String>[
    '亲密关系', '原生家庭', '职场压力', '自我价值', '人生低谷', '成长经历', '人际边界', '意义感', '失去告别', '反复模式'
  ];

  @override
  void initState() {
    super.initState();
    _loadAiState();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAiState() async {
    try {
      final state = await _settings.getState();
      if (!mounted) return;
      setState(() {
        _aiLabel = state['label'] ?? '通用 AI 配置';
        _aiAvailable = state['available'] == '1';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiLabel = '通用 AI 配置读取失败';
        _aiAvailable = false;
      });
    }
  }

  Future<void> _analyze() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      _toast('请先写下一段经历或感受');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.analyze(
        experience: text,
        selectedEmotions: _selectedEmotions.toList(),
        sceneTags: _sceneTags.toList(),
      );
      if (!mounted) return;
      setState(() => _report = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '分析失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (target.contains(value)) {
        target.remove(value);
      } else {
        target.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('人生注解'),
        actions: [
          IconButton(
            tooltip: '配置人生注解提示词',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AiPromptSettingsPage(
                    initialModuleId: 'life_note',
                    initialPromptId: 'life_note_analysis',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _heroCard(),
          const SizedBox(height: 12),
          _inputCard(),
          const SizedBox(height: 12),
          if (_error != null) _errorCard(_error!),
          if (_report != null) ...[
            const SizedBox(height: 12),
            _reportView(_report!),
          ],
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF), Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('写下一段经历，让 AI 帮你理解它', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                    SizedBox(height: 4),
                    Text('情绪、人生主题、深层需求、思想与疗愈书单', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _modelPill(),
          const SizedBox(height: 10),
          const Text(
            '本功能用于自我理解、情绪整理和阅读推荐，不提供医学诊断或心理治疗。如果你正处于危险或可能伤害自己的状态，请立即联系当地紧急服务、危机热线或可信任的人。',
            style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _modelPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _aiAvailable ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _aiAvailable ? const Color(0xFFBFDBFE) : const Color(0xFFFED7AA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_aiAvailable ? Icons.check_circle_outline : Icons.info_outline, size: 16, color: _aiAvailable ? const Color(0xFF2563EB) : const Color(0xFFC2410C)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _aiAvailable ? '使用设置页通用模型：$_aiLabel' : '通用 AI 未就绪：$_aiLabel',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _aiAvailable ? const Color(0xFF1D4ED8) : const Color(0xFFC2410C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.edit_note, '写下你的经历或感受'),
          const SizedBox(height: 8),
          TextField(
            controller: _inputCtrl,
            minLines: 8,
            maxLines: 16,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '例如：最近我和伴侣因为回复消息吵架，我发现自己每次被冷淡时都会很慌，也会想起小时候总是得不到回应的感觉……',
            ),
          ),
          const SizedBox(height: 14),
          _chipBlock('可选：当前情绪', _emotionOptions, _selectedEmotions),
          const SizedBox(height: 12),
          _chipBlock('可选：相关场景', _sceneOptions, _sceneTags),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.psychology_alt_outlined),
              label: Text(_loading ? '正在注解...' : '开始 AI 深度注解'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipBlock(String title, List<String> options, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((e) {
            final on = selected.contains(e);
            return ChoiceChip(
              label: Text(e),
              selected: on,
              onSelected: (_) => _toggle(selected, e),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _reportView(LifeNoteReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (report.safetyLevel.toLowerCase() != 'normal' || report.safetyNotices.isNotEmpty) _safetyCard(report),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.title.isEmpty ? '人生注解报告' : report.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
              const SizedBox(height: 10),
              _sectionHeader(Icons.hearing_outlined, '我听见了什么'),
              _paragraph(report.heardSummary),
              _tagRows('主要情绪', report.coreEmotions),
              _tagRows('核心主题', report.lifeThemes),
              _tagRows('深层需求', report.deeperNeeds),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _textSection(Icons.account_tree_outlined, '可能的心理 / 人生模式', report.corePattern),
        const SizedBox(height: 12),
        _textSection(Icons.volunteer_activism_outlined, '一个更温柔的重新解释', report.gentleReframe),
        const SizedBox(height: 12),
        _textSection(Icons.lightbulb_outline, '理论提升与概念匹配', report.theoryElevation),
        const SizedBox(height: 12),
        _thoughtSection(report.relatedThoughts),
        const SizedBox(height: 12),
        _bookSection(report.healingBooks),
        const SizedBox(height: 12),
        _listSection(Icons.help_outline, '可以继续探索的问题', report.explorationQuestions),
        const SizedBox(height: 12),
        _listSection(Icons.spa_outlined, '今日可做的小练习', report.smallPractices),
        if (report.summary.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _textSection(Icons.check_circle_outline, '总结', report.summary),
        ],
      ],
    );
  }

  Widget _safetyCard(LifeNoteReport report) {
    final notices = report.safetyNotices.isEmpty
        ? <String>['如果你正在考虑伤害自己或他人，请立即联系当地紧急服务、危机热线或身边可信任的人。']
        : report.safetyNotices;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.health_and_safety_outlined, '安全提醒'),
            ...notices.map((e) => _bullet(e)),
          ],
        ),
      ),
    );
  }

  Widget _thoughtSection(List<LifeThoughtMatch> items) {
    if (items.isEmpty) return _textSection(Icons.psychology_outlined, '相关思想', '暂无可展示的思想匹配。');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.psychology_outlined, '高度相关的思想'),
          const SizedBox(height: 6),
          ...items.map((e) => _insightItem(e.title, [e.reason, e.useCase])),
        ],
      ),
    );
  }

  Widget _bookSection(List<LifeBookRecommendation> items) {
    if (items.isEmpty) return _textSection(Icons.auto_stories_outlined, '治愈系书籍', '暂无可展示的书籍推荐。');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.auto_stories_outlined, '高度相关的治愈系书籍'),
          const SizedBox(height: 6),
          ...items.map((e) {
            final title = e.author.trim().isEmpty ? e.title : '${e.title} · ${e.author}';
            final meta = e.type.trim().isEmpty ? <String>[e.reason, e.readingTip] : <String>['类型：${e.type}', e.reason, e.readingTip];
            return _insightItem(title, meta);
          }),
        ],
      ),
    );
  }

  Widget _textSection(IconData icon, String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon, title),
          _paragraph(body),
        ],
      ),
    );
  }

  Widget _listSection(IconData icon, String title, List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon, title),
          const SizedBox(height: 6),
          ...values.map(_bullet),
        ],
      ),
    );
  }

  Widget _tagRows(String label, List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((e) => Chip(label: Text(e))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _insightItem(String title, List<String> lines) {
    final visibleLines = lines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          ...visibleLines.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(e, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF4B5563))),
              )),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827)))),
      ],
    );
  }

  Widget _paragraph(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SelectableText(text, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF374151))),
    );
  }

  Widget _bullet(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF374151)))),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _errorCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF991B1B), height: 1.45)),
    );
  }
}

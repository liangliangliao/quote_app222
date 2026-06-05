import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'meditation_ai_service.dart';
import 'meditation_dao.dart';
import 'meditation_models.dart';
import 'meditation_player_page.dart';
import 'meditation_record_page.dart';
import 'meditation_seed_data.dart';
import 'meditation_script_import_page.dart';
import 'meditation_settings_page.dart';
import 'meditation_timer_page.dart';

class MeditationModulePage extends StatefulWidget {
  const MeditationModulePage({super.key});

  @override
  State<MeditationModulePage> createState() => _MeditationModulePageState();
}

class _MeditationModulePageState extends State<MeditationModulePage> {
  final _dao = MeditationDao();
  final _aiService = MeditationAiService();
  final _descriptionController = TextEditingController();
  String _state = '日常练习';
  MeditationStats? _stats;
  bool _loading = true;
  bool _aiGenerating = false;
  MeditationSessionTemplate? _aiSession;
  String? _aiReason;
  String? _aiError;

  MeditationSessionTemplate get _recommended => MeditationSeedData.defaultForState(_state);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await _dao.loadStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _openPlayer(MeditationSessionTemplate session) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MeditationPlayerPage(session: session, currentState: _state),
      ),
    );
    if (changed == true) {
      await _loadStats();
    }
  }


  Future<void> _generateAiDaily() async {
    setState(() {
      _aiGenerating = true;
      _aiError = null;
      _aiSession = null;
      _aiReason = null;
    });
    try {
      final recent = await _dao.recentRecords(limit: 8);
      final userDescription = _descriptionController.text.trim();
      final session = await _aiService.generateDailyMeditation(
        currentState: _state,
        recommended: _recommended,
        recentRecords: recent,
        userDescription: userDescription,
      );
      String reason = '';
      if (session != null) {
        reason = await _aiService.generateRecommendationReason(currentState: _state, recommended: session);
      }
      if (!mounted) return;
      setState(() {
        _aiSession = session;
        _aiReason = reason.trim().isEmpty ? null : reason.trim();
        _aiError = session == null ? 'AI 暂时不可用，可能是未配置 API Key、网络异常或模型返回为空。你仍然可以使用本地推荐练习。' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiError = 'AI 生成失败：$e');
    } finally {
      if (mounted) setState(() => _aiGenerating = false);
    }
  }

  Future<void> _openPromptSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiPromptSettingsPage(
          initialModuleId: 'meditation',
          initialPromptId: 'meditation_daily_script',
        ),
      ),
    );
  }

  String _formatMinutes(int seconds) {
    if (seconds <= 0) return '0分钟';
    final minutes = (seconds / 60).round();
    return '$minutes分钟';
  }

  Widget _heroCard() {
    final session = _recommended;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF3FF), Color(0xFFF7F0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今天不用改变人生，', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('只需要安静 3 分钟。', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('冥想不是清空大脑，而是当你被念头带走之后，还能一次次回到自己。', style: TextStyle(height: 1.5, color: Colors.black87)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.78), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const Icon(Icons.self_improvement, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('今日推荐：${session.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('${session.type} · ${session.durationMinutes}分钟', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openPlayer(session),
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始今日冥想'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiDailyCard() {
    final recommended = _recommended;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(child: Text('AI 今日冥想', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              TextButton(onPressed: _openPromptSettings, child: const Text('提示词')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '根据你当前状态和最近练习记录，生成一段更适合今天的专属练习。',
            style: TextStyle(color: Colors.black.withOpacity(0.62), height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8F7FF), borderRadius: BorderRadius.circular(16)),
            child: Text('当前状态：$_state\n本地推荐方向：${recommended.title} · ${recommended.type}', style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: '补充描述（可选）',
              hintText: '例如：我今天被别人影响后一直反复想，想做一段帮我收回注意力的冥想。',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) {
              if (_aiSession != null || _aiReason != null || _aiError != null) {
                setState(() {
                  _aiSession = null;
                  _aiReason = null;
                  _aiError = null;
                });
              }
            },
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            Text(_aiError!, style: const TextStyle(color: Colors.deepOrange, height: 1.45)),
          ],
          if (_aiSession != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_aiSession!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${_aiSession!.durationMinutes}分钟 · ${_aiSession!.type} · AI生成', style: const TextStyle(color: Colors.black54)),
                  if ((_aiReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_aiReason!, style: const TextStyle(height: 1.45)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openPlayer(_aiSession!),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('开始AI冥想'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(onPressed: _aiGenerating ? null : _generateAiDaily, child: const Text('重生成')),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _aiGenerating ? null : _generateAiDaily,
                icon: _aiGenerating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_aiGenerating ? '正在生成今日冥想……' : 'AI为我生成今日冥想'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stateSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('你现在更接近哪种状态？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MeditationSeedData.stateOptions.map((state) {
              final selected = state == _state;
              return ChoiceChip(
                label: Text(state),
                selected: selected,
                onSelected: (_) => setState(() {
                  _state = state;
                  _aiSession = null;
                  _aiReason = null;
                  _aiError = null;
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final stats = _stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(child: _statCard('连续练习', stats == null ? '--' : '${stats.streakDays}天', Icons.local_fire_department)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('本周完成', stats == null ? '--' : '${stats.weekCompletedCount}/7', Icons.calendar_month)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('总时长', stats == null ? '--' : _formatMinutes(stats.totalSeconds), Icons.timer)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black.withOpacity(0.06))),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final items = [
      MeditationSeedData.byKey('breath_anchor_3m'),
      MeditationSeedData.byKey('rumination_stop_5m'),
      MeditationSeedData.byKey('emotion_untangle_5m'),
      MeditationSeedData.byKey('focus_return_5m'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快速练习', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...items.map((session) => Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.black.withOpacity(0.06))),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _typeColor(session.type).withOpacity(0.12),
                    child: Icon(_typeIcon(session.type), color: _typeColor(session.type)),
                  ),
                  title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(session.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openPlayer(session),
                ),
              )),
        ],
      ),
    );
  }

  Widget _navigationGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('功能区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _navCard('练习库', '个性恢复、反刍、自尊、定力', Icons.library_books, () async {
                final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MeditationPracticeLibraryPage()));
                if (changed == true) _loadStats();
              }),
              _navCard('上传脚本', '本地脚本生成冥想', Icons.upload_file, () async {
                final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MeditationScriptImportPage()));
                if (changed == true) _loadStats();
              }),
              _navCard('睡前放松', '语音、背景音、定时关闭', Icons.bedtime, () async {
                final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MeditationSleepPage()));
                if (changed == true) _loadStats();
              }),
              _navCard('安静坐一会儿', '无引导计时器', Icons.hourglass_bottom, () async {
                final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MeditationTimerPage()));
                if (changed == true) _loadStats();
              }),
              _navCard('静心轨迹', '记录与连续练习', Icons.insights, () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeditationRecordPage()));
                _loadStats();
              }),
              _navCard('冥想设置', '记录显示、AI反馈、循环结束', Icons.settings_outlined, () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeditationSettingsPage()));
                _loadStats();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.06))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueGrey),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case '反刍中断':
        return Icons.stop_circle_outlined;
      case '情绪脱钩':
        return Icons.psychology_alt_outlined;
      case '专注回收':
        return Icons.center_focus_strong;
      case '身体扫描':
        return Icons.accessibility_new;
      case '睡前放松':
        return Icons.bedtime;
      case '自我接纳':
        return Icons.favorite_border;
      case '注意力主权':
        return Icons.shield_outlined;
      case '自责松绑':
        return Icons.volunteer_activism_outlined;
      case '体面安放':
        return Icons.self_improvement;
      case '身体回家':
        return Icons.spa_outlined;
      case '行动启动':
        return Icons.play_circle_outline;
      case '安全感重建':
        return Icons.home_outlined;
      case '定力练习':
        return Icons.landscape_outlined;
      case '自尊修复':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.air;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case '反刍中断':
        return Colors.deepOrange;
      case '情绪脱钩':
        return Colors.purple;
      case '专注回收':
        return Colors.teal;
      case '身体扫描':
        return Colors.indigo;
      case '睡前放松':
        return Colors.deepPurple;
      case '自我接纳':
        return Colors.pink;
      case '注意力主权':
        return Colors.blueGrey;
      case '自责松绑':
        return Colors.pinkAccent;
      case '体面安放':
        return Colors.brown;
      case '身体回家':
        return Colors.green;
      case '行动启动':
        return Colors.orange;
      case '安全感重建':
        return Colors.cyan;
      case '定力练习':
        return Colors.indigo;
      case '自尊修复':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('静心实验室'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          children: [
            _heroCard(),
            _stateSelector(),
            _aiDailyCard(),
            _statsRow(),
            _quickActions(),
            _navigationGrid(),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 28),
              child: Text(
                '提示：冥想练习可以帮助你放松、觉察和调节注意力，但不能替代专业医疗、心理咨询或精神科治疗。',
                style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class MeditationPracticeLibraryPage extends StatefulWidget {
  const MeditationPracticeLibraryPage({super.key});

  @override
  State<MeditationPracticeLibraryPage> createState() => _MeditationPracticeLibraryPageState();
}

class _MeditationPracticeLibraryPageState extends State<MeditationPracticeLibraryPage> {
  final _dao = MeditationDao();
  List<MeditationSessionTemplate> _customSessions = const [];
  bool _loadingCustom = true;

  @override
  void initState() {
    super.initState();
    _loadCustomSessions();
  }

  Future<void> _loadCustomSessions() async {
    final items = await _dao.customSessions();
    if (!mounted) return;
    setState(() {
      _customSessions = items;
      _loadingCustom = false;
    });
  }

  Future<void> _open(BuildContext context, MeditationSessionTemplate session) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MeditationPlayerPage(session: session, currentState: session.type)),
    );
    if (changed == true && context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openImport() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MeditationScriptImportPage()),
    );
    if (changed == true) {
      await _loadCustomSessions();
    }
  }

  Future<void> _deleteCustom(MeditationSessionTemplate session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除本地脚本？'),
        content: Text('确定从练习库移除“${session.title}”吗？不会删除你的冥想记录。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.deleteCustomSession(session.key);
    await _loadCustomSessions();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = MeditationSeedData.groupedByCategory();
    return Scaffold(
      appBar: AppBar(
        title: const Text('练习库'),
        actions: [
          IconButton(onPressed: _openImport, icon: const Icon(Icons.upload_file), tooltip: '上传脚本'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCustomSessions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explainCard(),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: const Color(0xFFF8F7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.black.withOpacity(0.06))),
              child: ListTile(
                leading: const Icon(Icons.upload_file, color: Colors.deepPurple),
                title: const Text('上传本地冥想脚本', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('自动识别文本、时间标记或 JSON，并生成对应时长'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openImport,
              ),
            ),
            if (_loadingCustom) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ] else if (_customSessions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 14, bottom: 8),
                child: Text('本地上传', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              for (final session in _customSessions)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.black.withOpacity(0.06))),
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined, color: Colors.deepPurple),
                    title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${session.durationMinutes}分钟 · ${session.description}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(onPressed: () => _deleteCustom(session), icon: const Icon(Icons.delete_outline), tooltip: '删除'),
                        const Icon(Icons.play_circle_outline),
                      ],
                    ),
                    onTap: () => _open(context, session),
                  ),
                ),
            ],
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Text(entry.key, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              for (final session in entry.value)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.black.withOpacity(0.06))),
                  child: ListTile(
                    leading: const Icon(Icons.self_improvement, color: Colors.blue),
                    title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${session.durationMinutes}分钟 · ${session.description}'),
                    trailing: const Icon(Icons.play_circle_outline),
                    onTap: () => _open(context, session),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _explainCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
      child: const Text(
        '新增个性化恢复练习均不少于8分钟。也可以上传自己的冥想脚本，让系统按文字长度或时间标记自动生成对应时长。',
        style: TextStyle(height: 1.55),
      ),
    );
  }
}

class MeditationSleepPage extends StatelessWidget {
  const MeditationSleepPage({super.key});

  Future<void> _open(BuildContext context, MeditationSessionTemplate session) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MeditationPlayerPage(session: session, currentState: '睡前放松')),
    );
    if (changed == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final items = MeditationSeedData.groupedByCategory(sleepOnly: true).values.expand((e) => e).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF101322),
      appBar: AppBar(
        title: const Text('睡前放松'),
        backgroundColor: const Color(0xFF101322),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(22)),
            child: const Text(
              '今晚先不用继续解决白天。让身体进入夜晚，让注意力从反刍回到呼吸。',
              style: TextStyle(color: Colors.white, height: 1.6, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          for (final session in items)
            Card(
              color: Colors.white.withOpacity(0.10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                leading: const Icon(Icons.bedtime, color: Colors.white70),
                title: Text(session.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('${session.durationMinutes}分钟 · ${session.description}', style: const TextStyle(color: Colors.white60)),
                trailing: const Icon(Icons.play_circle_outline, color: Colors.white70),
                onTap: () => _open(context, session),
              ),
            ),
          const SizedBox(height: 16),
          const Text('MVP3 已支持语音引导、自然背景音和定时关闭。进入任意睡前练习后，点击右上角调节按钮即可开启。', style: TextStyle(color: Colors.white38, height: 1.5, fontSize: 12)),
        ],
      ),
    );
  }
}

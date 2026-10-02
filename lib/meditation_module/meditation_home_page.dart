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
  String? _aiUnderstoodNeed;
  String? _aiCognitiveShift;
  String? _aiEmbodiedGoal;
  String? _aiRealLifeScene;
  List<String> _aiPracticeFocus = const <String>[];
  String? _aiError;
  String? _aiSafetyNotice;
  int _aiDurationMinutes = 8;
  bool _aiSaved = false;
  MeditationExpertPreferences _expertPreferences = const MeditationExpertPreferences();

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
    final userDescription = _descriptionController.text.trim();
    final safety = _aiService.assessUserInput(userDescription);
    setState(() {
      _aiGenerating = true;
      _aiError = null;
      _aiSafetyNotice = safety.isNormal ? null : safety.message;
      _aiSession = null;
      _aiReason = null;
      _aiUnderstoodNeed = null;
      _aiCognitiveShift = null;
      _aiEmbodiedGoal = null;
      _aiRealLifeScene = null;
      _aiPracticeFocus = const <String>[];
      _aiSaved = false;
    });
    try {
      if (safety.requiresImmediateSupport) return;
      final recent = await _dao.recentRecords(limit: 8);
      final result = await _aiService.generateDailyMeditation(
        currentState: _state,
        recommended: _recommended,
        recentRecords: recent,
        durationMinutes: _aiDurationMinutes,
        userDescription: userDescription,
        preferences: _expertPreferences,
      );
      String reason = '';
      if (result != null) {
        reason = await _aiService.generateRecommendationReason(currentState: _state, recommended: result.session);
      }
      if (!mounted) return;
      setState(() {
        _aiSession = result?.session;
        _aiUnderstoodNeed = result?.understoodNeed;
        _aiCognitiveShift = result?.cognitiveShift;
        _aiEmbodiedGoal = result?.embodiedGoal;
        _aiRealLifeScene = result?.realLifeScene;
        _aiPracticeFocus = result?.practiceFocus ?? const <String>[];
        _aiReason = reason.trim().isEmpty ? null : reason.trim();
        _aiError = result == null
            ? 'AI 暂时未生成可用内容：可能是配置或网络异常，也可能是内容没有通过“认知 → 身体与情绪体验 → 现实演练”的质量校验。可以重试，或先使用本地推荐练习。'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiError = 'AI 生成失败：$e');
    } finally {
      if (mounted) setState(() => _aiGenerating = false);
    }
  }

  Future<void> _saveAiSession() async {
    final session = _aiSession;
    if (session == null || _aiSaved) return;
    try {
      await _dao.upsertCustomSession(session);
      if (!mounted) return;
      setState(() => _aiSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到“练习库 → 我的本地冥想”，以后可直接重复使用。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('本地保存失败：$e')),
      );
    }
  }

  void _clearAiResult() {
    _aiSession = null;
    _aiReason = null;
    _aiUnderstoodNeed = null;
    _aiCognitiveShift = null;
    _aiEmbodiedGoal = null;
    _aiRealLifeScene = null;
    _aiPracticeFocus = const <String>[];
    _aiError = null;
    final safety = _aiService.assessUserInput(_descriptionController.text);
    _aiSafetyNotice = safety.isNormal ? null : safety.message;
    _aiSaved = false;
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
    final generationBlocked = _aiService.assessUserInput(_descriptionController.text).requiresImmediateSupport;
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
              const Expanded(child: Text('AI 冥想专家', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              TextButton(onPressed: _openPromptSettings, child: const Text('提示词')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '写下此刻发生了什么。AI 会先辨认真正需要，再用身体锚点、自然留白和现实演练，把“明白”变成一次可以跟随的体验。',
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
          _expertCalibrationCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text('自定义冥想时长', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$_aiDurationMinutes 分钟', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          Slider(
            value: _aiDurationMinutes.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '$_aiDurationMinutes 分钟',
            onChanged: _aiGenerating
                ? null
                : (value) => setState(() {
                      _aiDurationMinutes = value.round();
                      _clearAiResult();
                    }),
          ),
          const Text('可选 1–30 分钟；AI 会按时长调整引导段数、文字量和留白。', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 7,
            decoration: InputDecoration(
              labelText: '告诉 AI：此刻发生了什么、你有何感受或想得到什么',
              hintText: '例如：我今天被别人影响后一直反复想。我不是想听大道理，只想先停止内耗，把注意力收回来，然后去做手上的事。',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => setState(_clearAiResult),
          ),
          if ((_aiSafetyNotice ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1D08A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF9A6910)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_aiSafetyNotice!, style: const TextStyle(color: Color(0xFF6E5016), height: 1.45))),
                ],
              ),
            ),
          ],
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
                  Text('${_aiSession!.durationMinutes}分钟 · ${_aiSession!.type} · 专家生成', style: const TextStyle(color: Colors.black54)),
                  if ((_aiUnderstoodNeed ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('AI 理解到的真正需要', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.deepPurple)),
                    const SizedBox(height: 4),
                    Text(_aiUnderstoodNeed!, style: const TextStyle(height: 1.5)),
                  ],
                  if ((_aiCognitiveShift ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('这次要松动的认知', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.deepPurple)),
                    const SizedBox(height: 4),
                    Text(_aiCognitiveShift!, style: const TextStyle(height: 1.5)),
                  ],
                  if ((_aiEmbodiedGoal ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('身体与情绪体验目标', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.deepPurple)),
                    const SizedBox(height: 4),
                    Text(_aiEmbodiedGoal!, style: const TextStyle(height: 1.5)),
                  ],
                  if ((_aiRealLifeScene ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('会带你演练的现实场景', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.deepPurple)),
                    const SizedBox(height: 4),
                    Text(_aiRealLifeScene!, style: const TextStyle(height: 1.5)),
                  ],
                  if (_aiPracticeFocus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _aiPracticeFocus.map((item) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(item),
                          )).toList(),
                    ),
                  ],
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
                          label: const Text('开始专家引导'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(onPressed: _aiGenerating ? null : _generateAiDaily, child: const Text('重生成')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _aiSaved ? null : _saveAiSession,
                      icon: Icon(_aiSaved ? Icons.check_circle : Icons.save_outlined),
                      label: Text(_aiSaved ? '已保存，可在练习库重复使用' : '保存到本地，供以后重复使用'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _aiGenerating || generationBlocked ? null : _generateAiDaily,
                icon: _aiGenerating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_aiGenerating ? '专家正在编排引导……' : '生成我的专家引导'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _expertCalibrationCard() {
    const guidanceStyles = <String>['温柔陪伴', '安静留白', '直接落地'];
    const anchors = <String>['身体触点', '自然呼吸', '环境感官'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3DDFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 7),
              const Expanded(
                child: Text('专家校准（可选）', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF40346B))),
              ),
              Text(
                '影响本次节奏',
                style: TextStyle(fontSize: 11, color: Colors.deepPurple.withOpacity(0.72)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('引导风格', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: guidanceStyles.map((style) {
              return ChoiceChip(
                label: Text(style),
                selected: _expertPreferences.guidanceStyle == style,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() {
                  _expertPreferences = _expertPreferences.copyWith(guidanceStyle: style);
                  _clearAiResult();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text('注意力锚点', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: anchors.map((anchor) {
              return ChoiceChip(
                label: Text(anchor),
                selected: _expertPreferences.anchorPreference == anchor,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() {
                  _expertPreferences = _expertPreferences.copyWith(anchorPreference: anchor);
                  _clearAiResult();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          const Text('AI 还会参考最近练习中的分心、身体放松和重复主题，自动调整留白与动作密度。', style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.35)),
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
                  _clearAiResult();
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
        title: Text(session.isAiGenerated ? '删除已保存的 AI 冥想？' : '删除本地脚本？'),
        content: Text('确定从我的本地冥想移除“${session.title}”吗？不会删除你的冥想记录。'),
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
                child: Text('我的本地冥想', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              for (final session in _customSessions)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.black.withOpacity(0.06))),
                  child: ListTile(
                    leading: Icon(session.isAiGenerated ? Icons.auto_awesome : Icons.description_outlined, color: Colors.deepPurple),
                    title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${session.durationMinutes}分钟 · ${session.isAiGenerated ? 'AI生成并保存在本地' : session.description}'),
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
        '练习库包含行动启动、工作适应、决策、羞耻、自尊、恐惧、关系与现实压力等完整引导。AI 生成的冥想可保存到这里反复使用；也可以上传自己的脚本。',
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

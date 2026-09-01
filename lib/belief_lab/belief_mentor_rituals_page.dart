import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../platform/exact_alarm_permission_coordinator.dart';
import 'belief_mentor_dao.dart';
import 'belief_mentor_models.dart';
import 'belief_mentor_reminder_service.dart';

class BeliefMentorRitualsPage extends StatefulWidget {
  const BeliefMentorRitualsPage({
    super.key,
    required this.dao,
    required this.reminders,
    this.initialSection = 'calendar',
  });

  final BeliefMentorDao dao;
  final BeliefMentorReminderService reminders;
  final String initialSection;

  @override
  State<BeliefMentorRitualsPage> createState() =>
      _BeliefMentorRitualsPageState();
}

class _BeliefMentorRitualsPageState extends State<BeliefMentorRitualsPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Future<_RitualData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.initialSection == 'calendar') return;
      final message = widget.initialSection == 'past_me'
          ? '已打开「来自过去的我」'
          : '已打开预测校准';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _reload() {
    _future = _load();
    if (mounted) setState(() {});
  }

  Future<_RitualData> _load() async => _RitualData(
    beliefs: await widget.dao.beliefs(),
    events: await widget.dao.calendarEvents(includeClosed: true),
    messages: await widget.dao.pastMeMessages(),
    evidence: await widget.dao.evidence(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F4ED),
    appBar: AppBar(
      title: const Text('仪式与预测校准'),
      backgroundColor: const Color(0xFFF7F4ED),
      surfaceTintColor: Colors.transparent,
    ),
    body: FutureBuilder<_RitualData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            const Card(
              color: Color(0xFFE4EFE8),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('重要事件和给未来自己的消息默认只保存在本机并加密。外部日历自动同步属于后续版本。'),
              ),
            ),
            const SizedBox(height: 12),
            _calendarCard(data),
            const SizedBox(height: 12),
            _pastMeCard(data),
            const SizedBox(height: 12),
            _calibrationCard(data),
          ],
        );
      },
    ),
  );

  Widget _calendarCard(_RitualData data) {
    final events = data.events.toList()
      ..sort((a, b) => a.eventAtMs.compareTo(b.eventAtMs));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '信念日历',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _editCalendar(data),
                  icon: const Icon(Icons.add),
                  label: const Text('添加事件'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('手动添加重要事件，并在 T-7 天、T-1 天和 T+30 分钟启动准备与复盘。'),
            if (events.isEmpty) ...<Widget>[
              const SizedBox(height: 14),
              const Text('还没有重要事件。'),
            ],
            for (final event in events) ...<Widget>[
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_note_outlined),
                title: Text(event.title),
                subtitle: Text(
                  '${_formatDateTime(event.eventAtMs)} · ${event.state.label}\n'
                  '${_beliefLabel(data.beliefs, event.beliefId)}\n${event.context}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editCalendar(data, event);
                    if (value == 'delete') _deleteCalendar(event);
                  },
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem(value: 'edit', child: Text('编辑并重排提醒')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pastMeCard(_RitualData data) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '来自过去的我',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _editPastMe(data),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('写一条'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('支持文字或已有音频文件；消息默认私密，可随时编辑或删除。'),
          if (data.messages.isEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Text('还没有给未来自己的消息。'),
          ],
          for (final message in data.messages) ...<Widget>[
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                message.audioPath.isEmpty
                    ? Icons.lock_outline
                    : Icons.audio_file_outlined,
              ),
              title: Text(
                message.text.trim().isEmpty ? '私人音频消息' : message.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_formatDateTime(message.deliverAtMs)} · ${message.state.label}\n'
                '${_beliefLabel(data.beliefs, message.beliefId)} · 默认私密',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 0,
                children: <Widget>[
                  if (message.audioPath.isNotEmpty)
                    IconButton(
                      tooltip: '播放音频',
                      onPressed: () => _playAudio(message.audioPath),
                      icon: const Icon(Icons.play_circle_outline),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editPastMe(data, message);
                      if (value == 'delete') _deletePastMe(message);
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem(value: 'edit', child: Text('编辑并重排送达')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _calibrationCard(_RitualData data) {
    final evidence = data.evidence.toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    final averageError = evidence.isEmpty
        ? 0.0
        : evidence
                  .map(
                    (item) =>
                        (item.predictedFailureProbability -
                                (item.predictionOccurred ? 100 : 0))
                            .abs(),
                  )
                  .reduce((a, b) => a + b) /
              evidence.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '预测校准',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              evidence.isEmpty
                  ? '完成证据记录后，这里会比较“预测失败概率”和实际结果。'
                  : '平均校准误差 ${averageError.toStringAsFixed(0)} 个百分点 · '
                        '越低表示预测越贴近实际。',
            ),
            for (final item in evidence.take(10)) ...<Widget>[
              const Divider(height: 22),
              Text(
                _beliefLabel(data.beliefs, item.beliefId),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '预测失败 ${item.predictedFailureProbability}% → '
                '实际${item.predictionOccurred ? '发生' : '未发生'} · '
                '${_formatDateTime(item.createdAtMs)}',
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: item.predictedFailureProbability / 100,
                minHeight: 7,
                borderRadius: BorderRadius.circular(99),
                color: item.predictionOccurred
                    ? const Color(0xFF9A4E3D)
                    : const Color(0xFF315B4A),
                backgroundColor: const Color(0xFFE5E0D6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editCalendar(
    _RitualData data, [
    BeliefMentorCalendarEvent? existing,
  ]) async {
    if (data.beliefs.isEmpty) {
      _show('请先确认至少一个信念。');
      return;
    }
    final draft = await showDialog<_CalendarDraft>(
      context: context,
      builder: (_) =>
          _CalendarDialog(beliefs: data.beliefs, existing: existing),
    );
    if (draft == null || !mounted) return;
    if (!draft.at.isAfter(DateTime.now().add(const Duration(minutes: 30)))) {
      _show('事件时间至少需要晚于现在 30 分钟。');
      return;
    }
    final exactGranted = await ExactAlarmPermissionCoordinator.ensureGranted(
      context,
      featureName: '信念日历提醒',
      explanation: '准备、临近和复盘节点会按事件时间准确提醒。',
    );
    if (!exactGranted) return;
    try {
      if (existing != null) {
        await widget.reminders.cancelExperimentReminders(
          existing.id,
          reason: '重要事件已编辑',
        );
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final event = BeliefMentorCalendarEvent(
        id: existing?.id ?? BeliefMentorDao.newId('calendar'),
        beliefId: draft.beliefId,
        title: draft.title,
        context: draft.context,
        eventAtMs: draft.at.millisecondsSinceEpoch,
        timezone: draft.at.timeZoneName,
        state: BeliefMentorCalendarEventState.scheduled,
        createdAtMs: existing?.createdAtMs ?? nowMs,
        updatedAtMs: nowMs,
      );
      await widget.dao.saveCalendarEvent(event);
      final reminders = await widget.reminders.scheduleCalendarEvent(event);
      _reload();
      _show('已保存，并生成 ${reminders.length} 个仍在未来的协议节点。');
    } catch (error) {
      _show(_cleanError(error));
    }
  }

  Future<void> _deleteCalendar(BeliefMentorCalendarEvent event) async {
    if (!await _confirm('删除这个重要事件及其尚未触发的提醒？')) return;
    await widget.reminders.cancelExperimentReminders(
      event.id,
      reason: '重要事件已删除',
    );
    await widget.dao.deleteCalendarEvent(event.id);
    _reload();
  }

  Future<void> _editPastMe(
    _RitualData data, [
    BeliefMentorPastMeMessage? existing,
  ]) async {
    if (data.beliefs.isEmpty) {
      _show('请先确认至少一个信念。');
      return;
    }
    final draft = await showDialog<_PastMeDraft>(
      context: context,
      builder: (_) => _PastMeDialog(beliefs: data.beliefs, existing: existing),
    );
    if (draft == null || !mounted) return;
    if (!draft.at.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      _show('送达时间必须晚于现在。');
      return;
    }
    final exactGranted = await ExactAlarmPermissionCoordinator.ensureGranted(
      context,
      featureName: '“来自过去的我”定时消息',
    );
    if (!exactGranted) return;
    try {
      if (existing != null) {
        await widget.reminders.cancelExperimentReminders(
          existing.id,
          reason: '过去的我消息已编辑',
        );
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final message = BeliefMentorPastMeMessage(
        id: existing?.id ?? BeliefMentorDao.newId('past_me'),
        beliefId: draft.beliefId,
        text: draft.text,
        audioPath: draft.audioPath,
        deliverAtMs: draft.at.millisecondsSinceEpoch,
        state: BeliefMentorPastMeMessageState.scheduled,
        isPrivate: true,
        createdAtMs: existing?.createdAtMs ?? nowMs,
        updatedAtMs: nowMs,
      );
      await widget.dao.savePastMeMessage(message);
      await widget.reminders.schedulePastMeMessage(message);
      _reload();
      _show('私人消息已安排。');
    } catch (error) {
      _show(_cleanError(error));
    }
  }

  Future<void> _deletePastMe(BeliefMentorPastMeMessage message) async {
    if (!await _confirm('永久删除这条私人消息？')) return;
    await widget.reminders.cancelExperimentReminders(
      message.id,
      reason: '过去的我消息已删除',
    );
    await widget.dao.deletePastMeMessage(message.id);
    _reload();
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (_) {
      _show('无法读取这个音频文件；它可能已被移动或删除。');
    }
  }

  Future<bool> _confirm(String message) async =>
      (await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('请确认'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      )) ??
      false;

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _beliefLabel(
    List<BeliefMentorBelief> beliefs,
    String beliefId,
  ) {
    for (final belief in beliefs) {
      if (belief.id == beliefId) return belief.alternativeStatement;
    }
    return '关联信念已归档或删除';
  }

  static String _formatDateTime(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  static String _cleanError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');
}

class _RitualData {
  const _RitualData({
    required this.beliefs,
    required this.events,
    required this.messages,
    required this.evidence,
  });

  final List<BeliefMentorBelief> beliefs;
  final List<BeliefMentorCalendarEvent> events;
  final List<BeliefMentorPastMeMessage> messages;
  final List<BeliefMentorEvidence> evidence;
}

class _CalendarDraft {
  const _CalendarDraft({
    required this.beliefId,
    required this.title,
    required this.context,
    required this.at,
  });

  final String beliefId;
  final String title;
  final String context;
  final DateTime at;
}

class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({required this.beliefs, this.existing});

  final List<BeliefMentorBelief> beliefs;
  final BeliefMentorCalendarEvent? existing;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late final TextEditingController _title;
  late final TextEditingController _context;
  late String _beliefId;
  late DateTime _at;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _context = TextEditingController(text: widget.existing?.context ?? '');
    _beliefId = widget.existing?.beliefId ?? widget.beliefs.first.id;
    _at = widget.existing == null
        ? DateTime.now().add(const Duration(days: 8))
        : DateTime.fromMillisecondsSinceEpoch(widget.existing!.eventAtMs);
  }

  @override
  void dispose() {
    _title.dispose();
    _context.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? '添加重要事件' : '编辑重要事件'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<String>(
            value: _beliefId,
            decoration: const InputDecoration(labelText: '关联信念'),
            items: widget.beliefs
                .map(
                  (belief) => DropdownMenuItem<String>(
                    value: belief.id,
                    child: Text(
                      belief.alternativeStatement,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) =>
                setState(() => _beliefId = value ?? _beliefId),
          ),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '事件名称'),
          ),
          TextField(
            controller: _context,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '具体情境',
              hintText: '例如：向团队做项目复盘，担心被质疑',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('事件时间'),
            subtitle: Text(
              _BeliefMentorRitualsPageState._formatDateTime(
                _at.millisecondsSinceEpoch,
              ),
            ),
            onTap: _pickDateTime,
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_title.text.trim().isEmpty || _context.text.trim().isEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('请填写事件名称和具体情境。')));
            return;
          }
          Navigator.pop(
            context,
            _CalendarDraft(
              beliefId: _beliefId,
              title: _title.text.trim(),
              context: _context.text.trim(),
              at: _at,
            ),
          );
        },
        child: const Text('保存并安排'),
      ),
    ],
  );

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null) return;
    setState(
      () => _at = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }
}

class _PastMeDraft {
  const _PastMeDraft({
    required this.beliefId,
    required this.text,
    required this.audioPath,
    required this.at,
  });

  final String beliefId;
  final String text;
  final String audioPath;
  final DateTime at;
}

class _PastMeDialog extends StatefulWidget {
  const _PastMeDialog({required this.beliefs, this.existing});

  final List<BeliefMentorBelief> beliefs;
  final BeliefMentorPastMeMessage? existing;

  @override
  State<_PastMeDialog> createState() => _PastMeDialogState();
}

class _PastMeDialogState extends State<_PastMeDialog> {
  late final TextEditingController _text;
  late String _beliefId;
  late String _audioPath;
  late DateTime _at;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.text ?? '');
    _beliefId = widget.existing?.beliefId ?? widget.beliefs.first.id;
    _audioPath = widget.existing?.audioPath ?? '';
    _at = widget.existing == null
        ? DateTime.now().add(const Duration(days: 1))
        : DateTime.fromMillisecondsSinceEpoch(widget.existing!.deliverAtMs);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? '写给未来的自己' : '编辑私人消息'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('默认私密'),
            subtitle: Text('正文和音频路径会加密保存在本机。'),
          ),
          DropdownButtonFormField<String>(
            value: _beliefId,
            decoration: const InputDecoration(labelText: '关联信念'),
            items: widget.beliefs
                .map(
                  (belief) => DropdownMenuItem<String>(
                    value: belief.id,
                    child: Text(
                      belief.alternativeStatement,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) =>
                setState(() => _beliefId = value ?? _beliefId),
          ),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '文字消息（可选）',
              hintText: '提醒未来的我：当时我已经知道什么？',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _audioPath.isEmpty ? '未附加音频' : _fileName(_audioPath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _pickAudio,
                icon: const Icon(Icons.attach_file),
                label: const Text('选择音频'),
              ),
              if (_audioPath.isNotEmpty)
                IconButton(
                  tooltip: '移除音频',
                  onPressed: () => setState(() => _audioPath = ''),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_send_outlined),
            title: const Text('送达时间'),
            subtitle: Text(
              _BeliefMentorRitualsPageState._formatDateTime(
                _at.millisecondsSinceEpoch,
              ),
            ),
            onTap: _pickDateTime,
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_text.text.trim().isEmpty && _audioPath.isEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('请填写文字或选择一个音频文件。')));
            return;
          }
          Navigator.pop(
            context,
            _PastMeDraft(
              beliefId: _beliefId,
              text: _text.text.trim(),
              audioPath: _audioPath,
              at: _at,
            ),
          );
        },
        child: const Text('私密保存'),
      ),
    ],
  );

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _audioPath = path);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at.isBefore(DateTime.now()) ? DateTime.now() : _at,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null) return;
    setState(
      () => _at = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  static String _fileName(String path) =>
      path.replaceAll('\\', '/').split('/').last;
}

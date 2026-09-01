import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'behavior_tracking_dao.dart';
import 'behavior_tracking_models.dart';
import 'behavior_preset_ai_analysis_service.dart';
import '../platform/exact_alarm_permission_coordinator.dart';
import '../platform/native_scheduler.dart';
import 'behavior_tracking_external_sources.dart';

class BehaviorObservationPresetsPage extends StatefulWidget {
  final List<String> categories;
  final VoidCallback onRecordsChanged;

  const BehaviorObservationPresetsPage({
    super.key,
    required this.categories,
    required this.onRecordsChanged,
  });

  @override
  State<BehaviorObservationPresetsPage> createState() => _BehaviorObservationPresetsPageState();
}

class _BehaviorObservationPresetsPageState extends State<BehaviorObservationPresetsPage> with WidgetsBindingObserver {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  List<BehaviorPreset> _presets = const [];
  Map<int, BehaviorPresetCheckIn> _checkIns = const {};
  bool _loading = true;
  _PresetAlarmSettings _alarmSettings = _PresetAlarmSettings.defaults();
  BehaviorPresetDailyReviewSettings _reviewSettings = BehaviorPresetDailyReviewSettings.defaults();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAlarmSettings();
    _loadReviewSettings();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAlarmSettings();
      _loadReviewSettings();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final presets = await _dao.presets();
    final checkIns = await _dao.presetCheckInMap(_date);
    if (!mounted) return;
    setState(() {
      _presets = presets;
      _checkIns = checkIns;
      _loading = false;
    });
  }

  Future<void> _loadAlarmSettings() async {
    final settings = await _PresetAlarmSettings.load();
    if (!mounted) return;
    setState(() => _alarmSettings = settings);
  }

  Future<void> _saveAlarmSettings(_PresetAlarmSettings settings) async {
    final saved = await settings.save();
    if (!mounted) return;
    setState(() => _alarmSettings = saved);
  }


  Future<void> _loadReviewSettings() async {
    final settings = await _dao.dailyReviewSettings();
    if (!mounted) return;
    setState(() => _reviewSettings = settings);
  }

  Future<void> _saveReviewSettings(BehaviorPresetDailyReviewSettings settings, {bool reschedule = true}) async {
    await _dao.saveDailyReviewSettings(settings);
    if (!mounted) return;
    setState(() => _reviewSettings = settings);
    if (reschedule) {
      if (settings.enabled) {
        await _scheduleDailyReviewAlarms(settings, showSnack: false);
      } else {
        await _cancelDailyReviewAlarms();
      }
    }
  }

  Future<void> _openRingtonePicker() async {
    await _PresetAlarmSettings.openSystemRingtonePicker();
  }

  Future<bool> _ensureAlarmRuntimePermissions() async {
    final exactGranted = await ExactAlarmPermissionCoordinator.ensureGranted(
      context,
      featureName: '行为预设闹钟提醒',
      explanation: '预设提醒、每日复盘提醒和全屏表单都使用系统精准闹钟。',
    );
    if (!exactGranted || !mounted) return false;
    final alreadyGranted = await _PresetAlarmSettings.requestRuntimePermissions();
    if (!alreadyGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已请求通知/音频权限，请授权后再次点击“重新注册已开启提醒”。')));
      }
      return false;
    }
    final canFullScreen = await _PresetAlarmSettings.canUseFullScreenIntent();
    if (!canFullScreen) {
      await _PresetAlarmSettings.openFullScreenIntentSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请在系统设置中允许“全屏提醒/全屏通知”，返回后重新注册闹钟提醒。')));
      }
      return false;
    }
    final canOverlay = await _PresetAlarmSettings.canDrawOverlay();
    if (!canOverlay) {
      await _PresetAlarmSettings.openOverlaySettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('为保证后台/锁屏时稳定全屏弹出，请允许“显示在其他应用上层/悬浮窗”，返回后重新注册闹钟提醒。')));
      }
      return false;
    }
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  Future<void> _editPreset([BehaviorPreset? preset]) async {
    final saved = await Navigator.of(context).push<BehaviorPreset?>(
      MaterialPageRoute(
        builder: (_) => _PresetEditorPage(
          initial: preset ?? BehaviorPreset.blank(),
          categories: widget.categories.isEmpty ? behaviorCategories : widget.categories,
        ),
      ),
    );
    if (saved == null) return;
    if (preset != null) await _cancelUpcomingPresetAlarms([preset]);
    final id = await _dao.savePreset(saved);
    final savedWithId = saved.copyWith(id: id);
    if (savedWithId.reminderEnabled) {
      await _schedulePresetAlarms(savedWithId, showSnack: true);
    }
    await _load();
  }

  Future<int> _schedulePresetAlarms(BehaviorPreset preset, {bool showSnack = false}) async {
    if (preset.id == null || !preset.reminderEnabled) return 0;
    if (!await _ensureAlarmRuntimePermissions()) return 0;
    final merged = <BehaviorPreset>[
      for (final p in _presets)
        if (p.id != preset.id) p,
      preset,
    ];
    final okCount = await _scheduleGroupedPresetAlarms(merged.where((p) => p.active && p.reminderEnabled && p.id != null).toList());
    if (mounted && showSnack) {
      final text = okCount > 0
          ? '已开启“${preset.name}”的预设提醒；同一日期同一时间的预设会合并为一个系统闹钟表单。'
          : '没有注册新的提醒：可能是今天提醒时间已过，系统会从下一个符合日期开始提醒。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
    return okCount;
  }

  Future<int> _scheduleGroupedPresetAlarms(List<BehaviorPreset> presets) async {
    final enabled = presets.where((p) => p.id != null && p.reminderEnabled && p.active).toList();
    if (enabled.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _cancelUpcomingPresetAlarms(enabled);
    final grouped = <String, _PresetAlarmGroup>{};
    for (final preset in enabled) {
      final hour = preset.reminderHour ?? 21;
      final minute = preset.reminderMinute ?? 0;
      for (var i = 0; i < 14; i++) {
        final day = today.add(Duration(days: i));
        if (!preset.scheduledOn(day)) continue;
        final trigger = DateTime(day.year, day.month, day.day, hour, minute);
        if (!trigger.isAfter(now.add(const Duration(seconds: 20)))) continue;
        final key = '${day.millisecondsSinceEpoch}-$hour-$minute';
        grouped.putIfAbsent(key, () => _PresetAlarmGroup(day: day, hour: hour, minute: minute, trigger: trigger)).presets.add(preset);
      }
    }
    var okCount = 0;
    for (final group in grouped.values) {
      final id = _presetGroupAlarmId(group.day, group.hour, group.minute);
      final payload = _buildGroupedAlarmPayload(group, id);
      final ok = await NativeScheduler.scheduleAlarmClockAt(id: id, epochMs: group.trigger.millisecondsSinceEpoch, payload: payload);
      if (ok) okCount++;
    }
    return okCount;
  }

  Map<String, dynamic> _buildGroupedAlarmPayload(_PresetAlarmGroup group, int id) {
    final first = group.presets.first;
    final presetsPayload = group.presets.map((preset) => <String, dynamic>{
      'id': preset.id,
      'presetId': preset.id,
      'name': preset.name,
      'presetName': preset.name,
      'category': preset.category,
      'primaryLayer': preset.primaryLayer,
      'targetValue': preset.targetValue,
      'unit': preset.unit,
      'defaultDurationMin': preset.defaultDurationMin,
      'weekdays': preset.weekdays,
    }).toList();
    return <String, dynamic>{
      'module': 'behavior_tracking',
      'type': 'behavior_preset_alarm',
      'title': '预设提醒',
      'body': group.presets.length == 1
          ? '请查看“${first.name}”是否仍是今天要确认的预设；这不是要求你现在完成行为。'
          : '请查看这个时刻的 ${group.presets.length} 个预设行为；这不是要求你现在完成行为。',
      'presetId': first.id,
      'presetName': first.name,
      'category': first.category,
      'primaryLayer': first.primaryLayer,
      'targetValue': first.targetValue,
      'unit': first.unit,
      'defaultDurationMin': first.defaultDurationMin,
      'checkDateMs': group.day.millisecondsSinceEpoch,
      'alarmId': id,
      'reminderHour': group.hour,
      'reminderMinute': group.minute,
      'alarmSoundUri': _alarmSettings.soundUri,
      'alarmSoundTitle': _alarmSettings.soundTitle,
      'alarmVolume': _alarmSettings.volume,
      'alarmVibrate': _alarmSettings.vibrate,
      'presets': presetsPayload,
      'presetCount': presetsPayload.length,
    };
  }

  Future<void> _cancelUpcomingPresetAlarms(List<BehaviorPreset> presets) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ids = <int>{};
    for (final preset in presets) {
      final hour = preset.reminderHour ?? 21;
      final minute = preset.reminderMinute ?? 0;
      for (var i = 0; i < 14; i++) {
        final day = today.add(Duration(days: i));
        if (preset.id != null) ids.add(_presetAlarmId(preset.id!, day)); // legacy v33 per-preset ids
        ids.add(_presetGroupAlarmId(day, hour, minute));
      }
    }
    for (final id in ids) {
      try { await NativeScheduler.cancel(id); } catch (_) {}
    }
  }


  Future<void> _openDailyPresetReview() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BehaviorPresetDailyReviewPage(categories: widget.categories, initialDate: _date)),
    );
    if (changed == true) {
      await _load();
      widget.onRecordsChanged();
    }
  }

  Future<void> _pickDailyReviewTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reviewSettings.hour, minute: _reviewSettings.minute),
      helpText: '选择每日预设行为复盘提醒时间',
    );
    if (picked == null) return;
    if (!await _ensureAlarmRuntimePermissions() || !mounted) return;
    final next = _reviewSettings.copyWith(enabled: true, hour: picked.hour, minute: picked.minute);
    await _saveReviewSettings(next, reschedule: false);
    await _scheduleDailyReviewAlarms(next, showSnack: true);
  }

  Future<int> _scheduleDailyReviewAlarms(BehaviorPresetDailyReviewSettings settings, {bool showSnack = false}) async {
    if (!settings.enabled) {
      await _cancelDailyReviewAlarms();
      return 0;
    }
    if (!await _ensureAlarmRuntimePermissions()) return 0;
    final count = await _scheduleDailyReviewAlarmsStandalone(settings, _alarmSettings);
    if (mounted && showSnack) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count > 0
          ? '已注册每日 ${settings.timeLabel} 的预设行为复盘提醒。提醒为高级别闹钟通知，带声音和震动。'
          : '没有注册新的复盘提醒：可能今天复盘时间已过，系统会从下一天开始。')));
    }
    return count;
  }

  Future<void> _cancelDailyReviewAlarms() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 21; i++) {
      try { await NativeScheduler.cancel(_dailyReviewAlarmId(today.add(Duration(days: i)))); } catch (_) {}
    }
  }

  Future<void> _showSetupAlarmTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 21, minute: 0),
      helpText: '选择行为预设提醒时间',
    );
    if (picked == null) return;
    await _schedulePresetSetupAlarms(picked, showSnack: true);
  }

  Future<int> _schedulePresetSetupAlarms(TimeOfDay time, {bool showSnack = false}) async {
    if (!await _ensureAlarmRuntimePermissions()) return 0;
    final now = DateTime.now();
    var okCount = 0;
    for (var i = 0; i < 14; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final trigger = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (!trigger.isAfter(now.add(const Duration(seconds: 20)))) continue;
      final id = _setupAlarmId(day);
      final payload = <String, dynamic>{
        'module': 'behavior_tracking',
        'type': 'behavior_preset_setup_alarm',
        'title': '行为预设提醒',
        'body': '请先预设今天要观察/确认的固定行为；如果还没有预设，需要先完成预设。',
        'checkDateMs': day.millisecondsSinceEpoch,
        'alarmId': id,
        'reminderHour': time.hour,
        'reminderMinute': time.minute,
        'alarmSoundUri': _alarmSettings.soundUri,
        'alarmSoundTitle': _alarmSettings.soundTitle,
        'alarmVolume': _alarmSettings.volume,
        'alarmVibrate': _alarmSettings.vibrate,
        'setupRequired': true,
        'presets': const <Map<String, dynamic>>[],
        'presetCount': 0,
      };
      final ok = await NativeScheduler.scheduleAlarmClockAt(id: id, epochMs: trigger.millisecondsSinceEpoch, payload: payload);
      if (ok) okCount++;
    }
    if (mounted && showSnack) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okCount > 0
          ? '已设置行为预设提醒。即使当天还没有预设行为，到点也会弹出全屏表单督促先完成预设。'
          : '没有注册新的提醒：可能是今天提醒时间已过，请换一个未来时间。')));
    }
    return okCount;
  }
  Future<void> _scheduleAllPresetAlarms() async {
    if (!await _ensureAlarmRuntimePermissions()) return;
    final enabled = _presets.where((p) => p.reminderEnabled).toList();
    if (enabled.isEmpty) {
      await _showAlarmGuideSheet();
      return;
    }
    final presetCount = enabled.length;
    final alarmCount = await _scheduleGroupedPresetAlarms(enabled);
    final reviewCount = _reviewSettings.enabled ? await _scheduleDailyReviewAlarmsStandalone(_reviewSettings, _alarmSettings) : 0;
    if (!mounted) return;
    final reviewText = reviewCount > 0 ? '，并注册每日 ${_reviewSettings.timeLabel} 复盘提醒' : '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(alarmCount > 0
        ? '已为 $presetCount 个预设行为注册 $alarmCount 个未来闹钟$reviewText；同一时刻会合并为一个表单。'
        : '已检查 $presetCount 个已开启提醒的预设行为；当前没有新的未来闹钟可注册，请检查日期与时间。$reviewText')));
  }

  Future<void> _showAlarmGuideSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
        final withAlarm = _presets.where((p) => p.reminderEnabled).toList();
        final withoutAlarm = _presets.where((p) => !p.reminderEnabled).toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(child: Text('系统闹钟提醒', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ]),
              const Text('闹钟提醒不是要求你立刻完成某个行为，而是督促你先做好当天行为预设，或确认你已经收到预设提醒。即使当天还没有预设行为，也可以先设置闹钟；到点后会要求你先完成预设。为保证后台/锁屏时稳定全屏弹出，需要允许全屏提醒和“显示在其他应用上层”。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('统一闹钟设置', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.music_note_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_alarmSettings.soundTitle.ifEmpty('系统默认闹钟铃声'), style: const TextStyle(fontWeight: FontWeight.w700))),
                    TextButton(onPressed: () async {
                      await _openRingtonePicker();
                    }, child: const Text('选择铃声')),
                  ]),
                  Row(children: [
                    const Text('音量', style: TextStyle(fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Slider(
                        value: _alarmSettings.volume.clamp(0.0, 1.0).toDouble(),
                        divisions: 10,
                        label: '${(_alarmSettings.volume * 100).round()}%',
                        onChanged: (v) {
                          setState(() => _alarmSettings = _alarmSettings.copyWith(volume: v));
                          setSheetState(() {});
                        },
                        onChangeEnd: (v) => _saveAlarmSettings(_alarmSettings.copyWith(volume: v)),
                      ),
                    ),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('统一开启震动', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('所有预设行为闹钟共用此震动开关。'),
                    value: _alarmSettings.vibrate,
                    onChanged: (v) async {
                      final next = _alarmSettings.copyWith(vibrate: v);
                      setState(() => _alarmSettings = next);
                      setSheetState(() {});
                      await _saveAlarmSettings(next);
                    },
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('每日预设行为复盘提醒', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text("默认 22:30；当前 ${_reviewSettings.enabled ? _reviewSettings.timeLabel : '已关闭'}。用于登记当天全部预设行为完成/未完成情况。"),
                    value: _reviewSettings.enabled,
                    onChanged: (v) async {
                      if (v && (!await _ensureAlarmRuntimePermissions() || !mounted)) return;
                      final next = _reviewSettings.copyWith(enabled: v);
                      setState(() => _reviewSettings = next);
                      setSheetState(() {});
                      await _saveReviewSettings(next);
                    },
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(onPressed: _pickDailyReviewTime, icon: const Icon(Icons.schedule_outlined), label: Text('复盘时间 ${_reviewSettings.timeLabel}')),
                    FilledButton.tonalIcon(onPressed: () => _scheduleDailyReviewAlarms(_reviewSettings.copyWith(enabled: true), showSnack: true), icon: const Icon(Icons.notifications_active_outlined), label: const Text('注册复盘提醒')),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              if (withAlarm.isNotEmpty) ...[
                const Text('已开启提醒', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final preset in withAlarm)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm_on_outlined, color: Color(0xFF2563EB)),
                    title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${_two(preset.reminderHour ?? 21)}:${_two(preset.reminderMinute ?? 0)} · ${_weekdayLabel(preset.weekdays)}'),
                    trailing: TextButton(onPressed: () async { Navigator.pop(ctx); await _editPreset(preset); }, child: const Text('编辑')),
                  ),
                const SizedBox(height: 8),
              ],
              if (withoutAlarm.isNotEmpty) ...[
                const Text('未开启提醒', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final preset in withoutAlarm)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm_add_outlined),
                    title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text("${preset.category.ifEmpty('未分类')} · ${_weekdayLabel(preset.weekdays)}"),
                    trailing: FilledButton.tonal(onPressed: () async { Navigator.pop(ctx); await _enableReminderForPreset(preset); }, child: const Text('开启')),
                  ),
              ],
              if (_presets.isEmpty) const Text('你还没有预设行为。仍然可以先设置一个“行为预设提醒闹钟”；到点后如果当天仍无预设，系统会弹出全屏预设表单，并每隔 5 分钟提醒，直到完成预设。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: withAlarm.isNotEmpty
                    ? FilledButton.icon(
                        onPressed: () async { Navigator.pop(ctx); await _scheduleAllPresetAlarms(); },
                        icon: const Icon(Icons.alarm_on_outlined),
                        label: const Text('重新注册已开启提醒'),
                      )
                    : FilledButton.icon(
                        onPressed: () async { Navigator.pop(ctx); await _showSetupAlarmTimePicker(); },
                        icon: const Icon(Icons.alarm_add_outlined),
                        label: const Text('设置预设提醒闹钟'),
                      ),
              ),
            ]),
          ),
        );
        });
      },
    );
  }

  Future<void> _enableReminderForPreset(BehaviorPreset preset) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: preset.reminderHour ?? 21, minute: preset.reminderMinute ?? 0),
      helpText: '选择“${preset.name}”的提醒时间',
    );
    if (picked == null) return;
    if (!await _ensureAlarmRuntimePermissions() || !mounted) return;
    final updated = preset.copyWith(
      reminderEnabled: true,
      reminderHour: picked.hour,
      reminderMinute: picked.minute,
      reminderFullScreen: true,
    );
    final id = await _dao.savePreset(updated);
    await _schedulePresetAlarms(updated.copyWith(id: updated.id ?? id), showSnack: true);
    await _load();
  }

  int _presetAlarmId(int presetId, DateTime day) {
    final dayNo = day.difference(DateTime(2020, 1, 1)).inDays;
    return 97000000 + ((presetId * 1000 + dayNo) % 900000);
  }

  int _presetGroupAlarmId(DateTime day, int hour, int minute) {
    final dayNo = day.difference(DateTime(2020, 1, 1)).inDays;
    final minuteOfDay = hour.clamp(0, 23).toInt() * 60 + minute.clamp(0, 59).toInt();
    return 97100000 + ((dayNo * 1440 + minuteOfDay) % 900000);
  }

  int _setupAlarmId(DateTime day) {
    final dayNo = day.difference(DateTime(2020, 1, 1)).inDays;
    return 96500000 + (dayNo % 400000);
  }

  Future<void> _deactivatePreset(BehaviorPreset preset) async {
    if (preset.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停用这个预设行为？'),
        content: Text('“${preset.name}”停用后不会再出现在每日确认清单中，历史确认记录仍会保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('停用')),
        ],
      ),
    );
    if (ok == true) {
      await _cancelUpcomingPresetAlarms([preset]);
      await _dao.deactivatePreset(preset.id!);
      await _load();
      await _scheduleGroupedPresetAlarms((await _dao.presets()).where((p) => p.active && p.reminderEnabled).toList());
    }
  }

  Future<void> _confirmDone(BehaviorPreset preset) async {
    final value = TextEditingController(text: preset.targetValue?.toString() ?? '');
    final duration = TextEditingController(text: preset.defaultDurationMin?.toString() ?? '');
    final note = TextEditingController();
    final result = await showModalBottomSheet<_PresetDoneInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text('确认完成：${preset.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
            ]),
            const Text('这是预设行为的每日确认。确认完成后，会生成一条“预设行为”正式记录，并与临时/非计划行为分开。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _PresetField(controller: value, label: '实际完成量', hint: '可不填', keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _PresetField(controller: duration, label: '实际时长（分钟）', hint: '例如 30', keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 10),
            _PresetField(controller: note, label: '备注（可选）', hint: '例如：早上完成 / 分两次完成', maxLines: 2),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, _PresetDoneInput(
                  actualValue: double.tryParse(value.text.trim()),
                  actualDurationMin: int.tryParse(duration.text.trim()),
                  note: note.text.trim(),
                )),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('确认完成'),
              ),
            ),
          ]),
        ),
      ),
    );
    value.dispose();
    duration.dispose();
    note.dispose();
    if (result == null) return;
    await _dao.setPresetCheckIn(
      preset: preset,
      date: _date,
      status: 'done',
      actualValue: result.actualValue,
      actualDurationMin: result.actualDurationMin,
      note: result.note,
    );
    await _load();
    widget.onRecordsChanged();
  }

  Future<void> _setSimpleStatus(BehaviorPreset preset, String status) async {
    await _dao.setPresetCheckIn(preset: preset, date: _date, status: status);
    await _load();
    widget.onRecordsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _presets.where((p) => p.scheduledOn(_date)).toList();
    final done = scheduled.where((p) => _checkIns[p.id]?.status == 'done').length;
    final missed = scheduled.where((p) => _checkIns[p.id]?.status == 'missed').length;
    final skipped = scheduled.where((p) => _checkIns[p.id]?.status == 'skipped').length;
    final pending = scheduled.length - done - missed - skipped;

    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
        _PresetCard(title: '预设行为', icon: Icons.event_available_outlined, children: [
          const Text('预设行为是你提前定义的固定行为，例如阅读、运动、复盘、背单词。它们会进入每日确认清单；临时发生的行为仍按普通记录保存，两者互不混淆。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: () => _editPreset(), icon: const Icon(Icons.add), label: const Text('新增预设行为')),
            FilledButton.tonalIcon(onPressed: _openDailyPresetReview, icon: const Icon(Icons.fact_check_outlined), label: const Text('每日复盘')),
            FilledButton.tonalIcon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined), label: Text(DateFormat('MM/dd').format(_date))),
            OutlinedButton.icon(onPressed: _showAlarmGuideSheet, icon: const Icon(Icons.alarm_on_outlined), label: const Text('闹钟提醒')),
          ]),
        ]),
        const SizedBox(height: 12),
        _PresetAlarmStatusCard(
          presets: _presets,
          onManage: _showAlarmGuideSheet,
          onRegisterAll: _scheduleAllPresetAlarms,
          onEnablePreset: _enableReminderForPreset,
          onScheduleSetupAlarm: _showSetupAlarmTimePicker,
        ),
        const SizedBox(height: 12),
        _PresetCard(title: "${DateFormat('MM月dd日').format(_date)} · 每日确认", icon: Icons.fact_check_outlined, children: [
          Row(children: [
            Expanded(child: _PresetMetric(label: '应确认', value: '${scheduled.length}项')),
            const SizedBox(width: 8),
            Expanded(child: _PresetMetric(label: '已完成', value: '$done项')),
            const SizedBox(width: 8),
            Expanded(child: _PresetMetric(label: '待确认', value: '$pending项')),
          ]),
          if (scheduled.isEmpty) ...[
            const SizedBox(height: 12),
            const Text('这一天没有启用的预设行为。可以先新增一个固定行为，比如“阅读 20 分钟”或“散步 30 分钟”。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
          ] else ...[
            const SizedBox(height: 12),
            for (final preset in scheduled) _PresetCheckTile(
              preset: preset,
              checkIn: preset.id == null ? null : _checkIns[preset.id],
              onDone: () => _confirmDone(preset),
              onMissed: () => _setSimpleStatus(preset, 'missed'),
              onSkipped: () => _setSimpleStatus(preset, 'skipped'),
              onEdit: () => _editPreset(preset),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        _PresetCard(title: '全部预设', icon: Icons.list_alt_outlined, children: [
          if (_presets.isEmpty)
            const Text('还没有预设行为。预设行为适合每天或每周会重复出现、需要确认是否完成的行为。', style: TextStyle(color: Color(0xFF64748B), height: 1.45))
          else
            for (final preset in _presets) _PresetManageTile(
              preset: preset,
              onEdit: () => _editPreset(preset),
              onDeactivate: () => _deactivatePreset(preset),
            ),
        ]),
      ]),
    );
  }
}


class BehaviorPresetDailyReviewPage extends StatefulWidget {
  final List<String> categories;
  final DateTime initialDate;

  const BehaviorPresetDailyReviewPage({super.key, required this.categories, required this.initialDate});

  @override
  State<BehaviorPresetDailyReviewPage> createState() => _BehaviorPresetDailyReviewPageState();
}

class _BehaviorPresetDailyReviewPageState extends State<BehaviorPresetDailyReviewPage> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  final BehaviorPresetAiAnalysisService _aiAnalysisService = BehaviorPresetAiAnalysisService();
  late DateTime _date;
  List<BehaviorPreset> _scheduled = const [];
  Map<int, BehaviorPresetCheckIn> _checkIns = const {};
  List<BehaviorPresetDailyReviewRecord> _reviewRecords = const [];
  BehaviorPresetAiAnalysisRecord? _aiAnalysis;
  final Map<int, _DailyReviewDraft> _drafts = <int, _DailyReviewDraft>{};
  bool _loading = true;
  bool _saving = false;
  bool _aiAnalyzing = false;
  String _aiError = '';

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final presets = await _dao.presets();
    final checkIns = await _dao.presetCheckInMap(_date);
    final reviewRecords = await _dao.recentDailyPresetReviews(limit: 30);
    final aiAnalysis = await _dao.presetAiAnalysisForDate(_date);
    final scheduled = presets.where((p) => p.scheduledOn(_date)).toList();
    final nextDrafts = <int, _DailyReviewDraft>{};
    for (final preset in scheduled) {
      final id = preset.id;
      if (id == null) continue;
      final oldDraft = _drafts[id];
      final check = checkIns[id];
      nextDrafts[id] = oldDraft ?? _DailyReviewDraft.fromCheckIn(check);
    }
    if (!mounted) return;
    setState(() {
      _scheduled = scheduled;
      _checkIns = checkIns;
      _reviewRecords = reviewRecords;
      _aiAnalysis = aiAnalysis;
      _aiError = '';
      _drafts
        ..clear()
        ..addAll(nextDrafts);
      _loading = false;
    });
  }

  int get _total => _scheduled.length;
  int get _done => _scheduled.where((p) => p.id != null && _drafts[p.id]?.done == true).length;
  int get _missed => _scheduled.where((p) => p.id != null && _drafts[p.id]?.done == false).length;
  int get _pending => _total - _done - _missed;
  double get _rate => _total == 0 ? 0 : _done / _total;

  Future<void> _finishReview({required bool openNextStep}) async {
    if (_scheduled.isEmpty) {
      if (openNextStep) {
        await _openTomorrowStarter();
      } else if (mounted) {
        Navigator.pop(context, false);
      }
      return;
    }
    for (final preset in _scheduled) {
      final draft = preset.id == null ? null : _drafts[preset.id];
      if (draft?.done == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请先标记“${preset.name}”完成或未完成')));
        return;
      }
      if (draft!.done == false && draft.reasonText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请填写“${preset.name}”未完成原因')));
        return;
      }
    }

    setState(() => _saving = true);
    final details = <Map<String, dynamic>>[];
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    try {
      for (final preset in _scheduled) {
        if (preset.id == null) continue;
        final draft = _drafts[preset.id]!;
        if (draft.done == true) {
          await _dao.setPresetCheckIn(
            preset: preset,
            date: _date,
            status: 'done',
            actualValue: draft.actualValue,
            actualDurationMin: draft.actualDurationMin,
            note: draft.note.trim().ifEmpty('每日复盘确认完成'),
            reviewedAtMs: nowMs,
          );
          await _cancelPresetAlarmsForDate(preset, _date);
        } else {
          final reason = draft.reasonText.trim();
          await _dao.setPresetCheckIn(
            preset: preset,
            date: _date,
            status: 'missed',
            note: reason,
            missedReason: reason,
            carryForward: draft.carryForward,
            reviewedAtMs: nowMs,
          );
          if (draft.carryForward) {
            await _ensureCarriedToTomorrow(preset, reason);
          } else {
            await _cancelPresetAlarmsForDate(preset, _date);
          }
        }
        details.add({
          'presetId': preset.id,
          'presetName': preset.name,
          'category': preset.category,
          'primaryLayer': preset.primaryLayer,
          'status': draft.done == true ? 'done' : 'missed',
          'missedReason': draft.done == true ? '' : draft.reasonText.trim(),
          'carryForward': draft.done == false && draft.carryForward,
          'targetValue': preset.targetValue,
          'unit': preset.unit,
          'defaultDurationMin': preset.defaultDurationMin,
          'actualValue': draft.actualValue,
          'actualDurationMin': draft.actualDurationMin,
          'reminderEnabled': preset.reminderEnabled,
          'reminderTime': preset.reminderEnabled ? '${_two(preset.reminderHour ?? 21)}:${_two(preset.reminderMinute ?? 0)}' : '',
          'notes': preset.notes,
        });
      }
      await _dao.saveDailyPresetReview(BehaviorPresetDailyReviewRecord(
        reviewDateMs: _date.millisecondsSinceEpoch,
        totalCount: _total,
        doneCount: _done,
        missedCount: _missed,
        completionRate: _rate,
        detailsJson: jsonEncode(details),
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ));
      await _rescheduleAllPresetAlarmsFromDao();
      await _runAiAnalysis(details: details, showSnack: false);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('复盘完成：共 $_total 项，完成 $_done 项，未完成 $_missed 项，完成率 ${(_rate * 100).round()}%')));
      if (openNextStep) {
        await _openTomorrowStarter();
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存复盘失败：$e')));
    }
  }

  Future<void> _openTomorrowStarter() async {
    final tomorrowRaw = _date.add(const Duration(days: 1));
    final tomorrow = DateTime(tomorrowRaw.year, tomorrowRaw.month, tomorrowRaw.day);
    await Navigator.of(context).pushReplacement<bool, bool>(
      MaterialPageRoute(builder: (_) => BehaviorPresetTomorrowStarterPage(categories: widget.categories, date: tomorrow)),
      result: true,
    );
  }

  Future<void> _ensureCarriedToTomorrow(BehaviorPreset preset, String reason) async {
    final tomorrow = _date.add(const Duration(days: 1));
    final day = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    if (preset.scheduledOn(day)) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final copy = BehaviorPreset(
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
      name: '${preset.name}（转入）',
      category: preset.category,
      primaryLayer: preset.primaryLayer,
      targetValue: preset.targetValue,
      unit: preset.unit,
      defaultDurationMin: preset.defaultDurationMin,
      reminderEnabled: preset.reminderEnabled,
      reminderHour: preset.reminderHour,
      reminderMinute: preset.reminderMinute,
      reminderFullScreen: preset.reminderFullScreen,
      reminderVibrate: preset.reminderVibrate,
      weekdays: <int>[day.weekday],
      active: true,
      notes: "由 ${DateFormat('yyyy-MM-dd').format(_date)} 未完成项转入；原因：$reason",
      sortOrder: preset.sortOrder + 1,
    );
    await _dao.savePreset(copy);
  }

  List<Map<String, dynamic>> _decodeReviewDetails(BehaviorPresetDailyReviewRecord record) {
    try {
      final decoded = jsonDecode(record.detailsJson);
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) => e.map<String, dynamic>((key, value) => MapEntry(key.toString(), value))).toList();
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }


  List<Map<String, dynamic>> _currentReviewDetails() {
    return _scheduled.where((preset) => preset.id != null).map((preset) {
      final draft = _drafts[preset.id] ?? const _DailyReviewDraft();
      final status = draft.done == true ? 'done' : (draft.done == false ? 'missed' : 'pending');
      return <String, dynamic>{
        'presetId': preset.id,
        'presetName': preset.name,
        'category': preset.category,
        'primaryLayer': preset.primaryLayer,
        'status': status,
        'missedReason': draft.done == false ? draft.reasonText.trim() : '',
        'carryForward': draft.done == false && draft.carryForward,
        'targetValue': preset.targetValue,
        'unit': preset.unit,
        'defaultDurationMin': preset.defaultDurationMin,
        'actualValue': draft.actualValue,
        'actualDurationMin': draft.actualDurationMin,
        'reminderEnabled': preset.reminderEnabled,
        'reminderTime': preset.reminderEnabled ? '${_two(preset.reminderHour ?? 21)}:${_two(preset.reminderMinute ?? 0)}' : '',
        'notes': preset.notes,
      };
    }).toList();
  }

  Future<void> _runAiAnalysis({List<Map<String, dynamic>>? details, bool showSnack = true}) async {
    if (_aiAnalyzing) return;
    final analysisDetails = details ?? _currentReviewDetails();
    if (analysisDetails.isEmpty) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前没有预设行为可分析')));
      }
      return;
    }
    if (mounted) {
      setState(() {
        _aiAnalyzing = true;
        _aiError = '';
      });
    }
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = await _aiAnalysisService.analyzeDailyPresetBehaviors(
        date: _date,
        details: analysisDetails,
        totalCount: _total,
        doneCount: _done,
        missedCount: _missed,
        completionRate: _rate,
      );
      final record = BehaviorPresetAiAnalysisRecord(
        reviewDateMs: _date.millisecondsSinceEpoch,
        status: result.status,
        analysisJson: jsonEncode(result.analysisJson),
        rawText: result.rawText,
        errorMessage: result.status == 'ok' ? '' : (result.analysisJson['summary'] is Map ? ((result.analysisJson['summary'] as Map)['overall_conclusion'] ?? '').toString() : result.status),
        createdAtMs: startedAtMs,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _dao.savePresetAiAnalysis(record);
      final saved = await _dao.presetAiAnalysisForDate(_date);
      if (!mounted) return;
      setState(() {
        _aiAnalysis = saved;
        _aiAnalyzing = false;
        _aiError = '';
      });
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.status == 'ok' ? 'AI 分析已完成并保存' : 'AI 分析未完整完成，已保存可用信息')));
      }
    } catch (e) {
      final error = e.toString();
      final record = BehaviorPresetAiAnalysisRecord(
        reviewDateMs: _date.millisecondsSinceEpoch,
        status: 'error',
        analysisJson: jsonEncode(<String, dynamic>{
          'schema_version': 'behavior_preset_ai_analysis_v1',
          'review_date': DateFormat('yyyy-MM-dd').format(_date),
          'summary': <String, dynamic>{
            'title': 'AI 分析失败',
            'overall_conclusion': error,
            'human_behavior_position': '修复配置或网络后可重新分析。',
            'total_count': _total,
            'done_count': _done,
            'missed_count': _missed,
          },
          'behaviors': <Map<String, dynamic>>[],
          'rare_high_risk_meaningful_cases': <Map<String, dynamic>>[],
          'method_notes': <String>[error],
        }),
        rawText: '',
        errorMessage: error,
        createdAtMs: startedAtMs,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _dao.savePresetAiAnalysis(record);
      final saved = await _dao.presetAiAnalysisForDate(_date);
      if (!mounted) return;
      setState(() {
        _aiAnalysis = saved;
        _aiAnalyzing = false;
        _aiError = error;
      });
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI 分析失败：$error')));
      }
    }
  }

  Widget _buildAiAnalysisCard() {
    final record = _aiAnalysis;
    final data = record?.decodedAnalysis ?? const <String, dynamic>{};
    final summary = _asMap(data['summary']);
    final behaviors = _asList(data['behaviors']);
    final rareCases = _asList(data['rare_high_risk_meaningful_cases']);
    final notes = _asList(data['method_notes']);
    return _PresetCard(title: 'AI 人类行为坐标分析', icon: Icons.auto_awesome_outlined, children: [
      const Text('复盘保存后会自动调用统一 AI：把当天所有预设行为分别放入人类行为历史坐标中，估算常见程度、概率、全球人数、风险、难度与自我成长意义，并自动保存结果。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(
          onPressed: _aiAnalyzing ? null : () => _runAiAnalysis(showSnack: true),
          icon: _aiAnalyzing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology_alt_outlined),
          label: Text(_aiAnalyzing ? 'AI 分析中…' : (record == null ? '立即分析' : '重新分析')),
        ),
      ]),
      if (_aiError.trim().isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('错误：$_aiError', style: const TextStyle(color: Color(0xFFDC2626), height: 1.4)),
      ],
      const SizedBox(height: 12),
      if (record == null && !_aiAnalyzing)
        const Text('暂无 AI 分析结果。完成复盘时会自动生成，也可以先手动点击“立即分析”。', style: TextStyle(color: Color(0xFF64748B), height: 1.45))
      else if (summary.isNotEmpty) ...[
        Text(_text(summary['title']).ifEmpty('总体结论'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        _aiLine('总体结论', summary['overall_conclusion']),
        _aiLine('人类行为坐标', summary['human_behavior_position']),
        _aiLine('可靠性说明', summary['reliability_statement']),
        if ((record?.status ?? '').isNotEmpty && record?.status != 'ok')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('状态：${record!.status}', style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w800)),
          ),
      ],
      if (behaviors.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('逐项行为分析', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        for (final item in behaviors.take(20)) _buildAiBehaviorTile(_asMap(item)),
      ],
      if (rareCases.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('罕见高风险但长期有价值的行为案例', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        for (final item in rareCases.take(12)) _buildRareCaseTile(_asMap(item)),
      ],
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('方法说明', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        for (final note in notes.take(8)) Text('• ${_text(note)}', style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
      ],
    ]);
  }

  Widget _buildAiBehaviorTile(Map<String, dynamic> item) {
    final title = _text(item['preset_name']).ifEmpty('未命名行为');
    final status = _text(item['status']);
    final level = _text(item['human_commonality_level']);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('$title${level.isEmpty ? '' : ' · $level'}', style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('${status == 'done' ? '完成' : status == 'missed' ? '未完成' : status} · ${_text(item['one_sentence_conclusion'])}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B))),
      children: [
        _aiLine('全球人数估算', item['estimated_population_text']),
        _aiLine('概率/数量级', item['estimated_probability_text']),
        _aiLine('历史占比', item['historical_share_text']),
        _aiLine('是否绝无仅有', item['not_unique_explanation']),
        _aiLine('直观类比', item['intuitive_analogy']),
        _aiLine('风险水平', '${_text(item['risk_level'])} ${_text(item['risk_reasoning'])}'),
        _aiLine('难易程度', '${_text(item['difficulty_level'])} ${_text(item['difficulty_reasoning'])}'),
        _aiLine('自我成长意义', item['self_growth_meaning']),
        _aiLine('正面价值', item['positive_value']),
        _aiLine('负面影响', item['negative_impact']),
        _aiLine('罕见行为额外分析', item['rare_behavior_extra_analysis']),
      ],
    );
  }

  Widget _buildRareCaseTile(Map<String, dynamic> item) {
    final title = _text(item['case_title']).ifEmpty('案例');
    final layer = _text(item['layer']);
    final titleText = layer.isEmpty ? title : '$layer · $title';
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.w900)),
      children: [
        _aiLine('罕见/无人涉足之处', item['why_rare_or_unprecedented']),
        _aiLine('风险', item['risk']),
        _aiLine('长期价值', item['long_term_value']),
        _aiLine('哲学意义', item['philosophical_meaning']),
        _aiLine('可能负面影响', item['possible_negative_impact']),
      ],
    );
  }

  Widget _aiLine(String label, Object? value) {
    final text = _text(value);
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text('• $label：$text', style: const TextStyle(color: Color(0xFF334155), height: 1.45)),
      ),
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map<String, dynamic>((key, v) => MapEntry(key.toString(), v));
    return const <String, dynamic>{};
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  String _text(Object? value) {
    if (value == null) return '';
    if (value is List) return value.map(_text).where((e) => e.trim().isNotEmpty).join('；');
    if (value is Map) return value.entries.map((e) => '${e.key}: ${_text(e.value)}').join('；');
    return value.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('每日预设行为复盘', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 120), children: [
          _PresetCard(title: "${DateFormat('MM月dd日').format(_date)} · 最终完成情况", icon: Icons.fact_check_outlined, children: [
            const Text('请对今天所有已确认/已启用的预设行为做最终标记。未完成项必须填写原因，可选择是否转入明天。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _PresetMetric(label: '总数', value: '$_total项')),
              const SizedBox(width: 8),
              Expanded(child: _PresetMetric(label: '完成', value: '$_done项')),
              const SizedBox(width: 8),
              Expanded(child: _PresetMetric(label: '未完成', value: '$_missed项')),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _rate.clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(99)),
            const SizedBox(height: 6),
            Text('完成率 ${(_rate * 100).round()}% · 待标记 $_pending 项', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          if (_scheduled.isEmpty)
            _PresetCard(title: '今日无预设行为', icon: Icons.inbox_outlined, children: const [
              Text('今天没有需要复盘的预设行为。可以直接进入下一步，开始设置明天的预设行为与闹钟提醒。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
            ])
          else
            for (final preset in _scheduled) _DailyReviewPresetTile(
              preset: preset,
              checkIn: preset.id == null ? null : _checkIns[preset.id],
              draft: preset.id == null ? _DailyReviewDraft() : (_drafts[preset.id] ?? _DailyReviewDraft()),
              onChanged: (draft) {
                if (preset.id == null) return;
                setState(() => _drafts[preset.id!] = draft);
              },
            ),
          const SizedBox(height: 12),
          _PresetCard(title: '记录明细', icon: Icons.receipt_long_outlined, children: [
            if (_scheduled.isEmpty)
              const Text('暂无明细。', style: TextStyle(color: Color(0xFF64748B)))
            else
              for (final preset in _scheduled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text("• ${preset.name}：${_drafts[preset.id]?.statusLabel ?? '待标记'}${_drafts[preset.id]?.reasonText.trim().isNotEmpty == true ? ' · 原因：${_drafts[preset.id]!.reasonText.trim()}' : ''}", style: const TextStyle(color: Color(0xFF334155), height: 1.35)),
                ),
          ]),
          const SizedBox(height: 12),
          _buildAiAnalysisCard(),
          const SizedBox(height: 12),
          _PresetCard(title: '历史复盘记录', icon: Icons.history_outlined, children: [
            if (_reviewRecords.isEmpty)
              const Text('还没有历史复盘记录。完成一次每日复盘后，这里会显示总数、完成率和明细。', style: TextStyle(color: Color(0xFF64748B), height: 1.45))
            else
              for (final record in _reviewRecords.take(10))
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text("${DateFormat('MM/dd').format(record.reviewDate)} · ${record.doneCount}/${record.totalCount} 完成 · ${((record.completionRate) * 100).round()}%", style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('未完成 ${record.missedCount} 项', style: const TextStyle(color: Color(0xFF64748B))),
                  children: [
                    for (final item in _decodeReviewDetails(record))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text("• ${item['presetName'] ?? ''}：${item['status'] == 'done' ? '完成' : '未完成'}${(item['missedReason'] ?? '').toString().trim().isNotEmpty ? ' · 原因：${item['missedReason']}' : ''}${item['carryForward'] == true ? ' · 已转入明天' : ''}", style: const TextStyle(color: Color(0xFF334155), height: 1.35)),
                        ),
                      ),
                  ],
                ),
          ]),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : () => _finishReview(openNextStep: false), icon: const Icon(Icons.save_outlined), label: Text(_saving ? '保存中…' : '保存复盘'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: _saving ? null : () => _finishReview(openNextStep: true), icon: const Icon(Icons.arrow_forward_outlined), label: const Text('下一步'))),
          ]),
        ),
      ),
    );
  }
}

class BehaviorPresetTomorrowStarterPage extends StatefulWidget {
  final List<String> categories;
  final DateTime date;

  const BehaviorPresetTomorrowStarterPage({super.key, required this.categories, required this.date});

  @override
  State<BehaviorPresetTomorrowStarterPage> createState() => _BehaviorPresetTomorrowStarterPageState();
}

class _BehaviorPresetTomorrowStarterPageState extends State<BehaviorPresetTomorrowStarterPage> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  List<BehaviorPreset> _presets = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final presets = await _dao.presets();
    if (!mounted) return;
    setState(() {
      _presets = presets.where((p) => p.scheduledOn(widget.date)).toList();
      _loading = false;
    });
  }

  Future<void> _addPreset() async {
    final saved = await Navigator.of(context).push<BehaviorPreset?>(MaterialPageRoute(
      builder: (_) => _PresetEditorPage(initial: BehaviorPreset.blank(), categories: widget.categories.isEmpty ? behaviorCategories : widget.categories),
    ));
    if (saved == null) return;
    await _dao.savePreset(saved);
    await _load();
  }

  Future<void> _registerTomorrowAlarms() async {
    final granted = await ExactAlarmPermissionCoordinator.ensureGranted(
      context,
      featureName: '明日预设行为闹钟',
      explanation: '已开启提醒的预设会登记为系统闹钟，并按相同时间合并。',
    );
    if (!granted || !mounted) return;
    final count = await _rescheduleAllPresetAlarmsFromDao();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count > 0 ? '已为明天及后续预设行为注册 $count 个闹钟提醒。' : '当前没有可注册的预设闹钟提醒。')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('开始明天的预设行为', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 110), children: [
              _PresetCard(title: "${DateFormat('MM月dd日').format(widget.date)} · 明天预设", icon: Icons.event_available_outlined, children: [
                const Text('这里是复盘后的下一步：确认明天要执行的预设行为，并把对应闹钟提醒注册好。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(onPressed: _addPreset, icon: const Icon(Icons.add), label: const Text('新增明天预设')),
                  FilledButton.tonalIcon(onPressed: _registerTomorrowAlarms, icon: const Icon(Icons.alarm_on_outlined), label: const Text('注册闹钟提醒')),
                ]),
              ]),
              const SizedBox(height: 12),
              _PresetCard(title: '明天清单', icon: Icons.list_alt_outlined, children: [
                if (_presets.isEmpty)
                  const Text('明天还没有预设行为。可以新增一个，或返回预设页调整重复日期。', style: TextStyle(color: Color(0xFF64748B), height: 1.45))
                else
                  for (final preset in _presets)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(preset.reminderEnabled ? Icons.alarm_on_outlined : Icons.event_note_outlined, color: preset.reminderEnabled ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                      title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text("${preset.category.ifEmpty('未分类')} · ${preset.reminderEnabled ? '${_two(preset.reminderHour ?? 21)}:${_two(preset.reminderMinute ?? 0)}' : '未开启闹钟'}"),
                    ),
              ]),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.check), label: const Text('完成')),
        ),
      ),
    );
  }
}

class _DailyReviewPresetTile extends StatelessWidget {
  final BehaviorPreset preset;
  final BehaviorPresetCheckIn? checkIn;
  final _DailyReviewDraft draft;
  final ValueChanged<_DailyReviewDraft> onChanged;

  const _DailyReviewPresetTile({required this.preset, required this.checkIn, required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final custom = draft.reasonOption == '其他';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(preset.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          Text(checkIn?.statusLabel ?? '待复盘', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text("${preset.category.ifEmpty('未分类')} · ${preset.targetValue == null ? '无固定量' : '${_trimDouble(preset.targetValue!)}${preset.unit}'}${preset.defaultDurationMin == null ? '' : ' · ${preset.defaultDurationMin}分钟'}", style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: const Text('完成'),
            selected: draft.done == true,
            onSelected: (_) => onChanged(draft.copyWith(done: true)),
          ),
          ChoiceChip(
            label: const Text('未完成'),
            selected: draft.done == false,
            onSelected: (_) => onChanged(draft.copyWith(done: false)),
          ),
        ]),
        if (draft.done == true) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(
              initialValue: draft.actualValueText,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '实际完成量（可选）', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
              onChanged: (v) => onChanged(draft.copyWith(actualValueText: v)),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(
              initialValue: draft.actualDurationText,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '实际时长/分钟', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
              onChanged: (v) => onChanged(draft.copyWith(actualDurationText: v)),
            )),
          ]),
        ],
        if (draft.done == false) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: draft.reasonOption,
            decoration: const InputDecoration(labelText: '未完成原因（必填）', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
            items: behaviorPresetMissedReasonOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => onChanged(draft.copyWith(reasonOption: v ?? draft.reasonOption)),
          ),
          if (custom) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: draft.customReason,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '自定义原因', hintText: '请写下真实原因', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
              onChanged: (v) => onChanged(draft.copyWith(customReason: v)),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('转入明天预设行为', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('转入后保留已注册闹钟；不转入则移除今天相关闹钟。'),
            value: draft.carryForward,
            onChanged: (v) => onChanged(draft.copyWith(carryForward: v)),
          ),
        ],
      ]),
    );
  }
}

class _DailyReviewDraft {
  final bool? done;
  final String reasonOption;
  final String customReason;
  final bool carryForward;
  final String actualValueText;
  final String actualDurationText;
  final String note;

  const _DailyReviewDraft({
    this.done,
    this.reasonOption = '时间安排冲突',
    this.customReason = '',
    this.carryForward = true,
    this.actualValueText = '',
    this.actualDurationText = '',
    this.note = '',
  });

  factory _DailyReviewDraft.fromCheckIn(BehaviorPresetCheckIn? checkIn) {
    if (checkIn == null) return const _DailyReviewDraft();
    final reason = checkIn.missedReason.ifEmpty(checkIn.note);
    final isKnown = behaviorPresetMissedReasonOptions.contains(reason) && reason != '其他';
    return _DailyReviewDraft(
      done: checkIn.status == 'done' ? true : (checkIn.status == 'missed' || checkIn.status == 'skipped' ? false : null),
      reasonOption: isKnown ? reason : '其他',
      customReason: isKnown ? '' : reason,
      carryForward: checkIn.carryForward,
      actualValueText: checkIn.actualValue?.toString() ?? '',
      actualDurationText: checkIn.actualDurationMin?.toString() ?? '',
      note: checkIn.note,
    );
  }

  String get reasonText => reasonOption == '其他' ? customReason : reasonOption;
  String get statusLabel => done == true ? '完成' : (done == false ? '未完成' : '待标记');
  double? get actualValue => double.tryParse(actualValueText.trim());
  int? get actualDurationMin => int.tryParse(actualDurationText.trim());

  _DailyReviewDraft copyWith({bool? done, String? reasonOption, String? customReason, bool? carryForward, String? actualValueText, String? actualDurationText, String? note}) => _DailyReviewDraft(
        done: done ?? this.done,
        reasonOption: reasonOption ?? this.reasonOption,
        customReason: customReason ?? this.customReason,
        carryForward: carryForward ?? this.carryForward,
        actualValueText: actualValueText ?? this.actualValueText,
        actualDurationText: actualDurationText ?? this.actualDurationText,
        note: note ?? this.note,
      );
}

int _dailyReviewAlarmId(DateTime day) {
  final dayNo = DateTime(day.year, day.month, day.day).difference(DateTime(2020, 1, 1)).inDays;
  return 96200000 + (dayNo % 500000);
}

int _standalonePresetAlarmId(int presetId, DateTime day) {
  final dayNo = DateTime(day.year, day.month, day.day).difference(DateTime(2020, 1, 1)).inDays;
  return 97000000 + ((presetId * 1000 + dayNo) % 900000);
}

int _standalonePresetGroupAlarmId(DateTime day, int hour, int minute) {
  final dayNo = DateTime(day.year, day.month, day.day).difference(DateTime(2020, 1, 1)).inDays;
  final minuteOfDay = hour.clamp(0, 23).toInt() * 60 + minute.clamp(0, 59).toInt();
  return 97100000 + ((dayNo * 1440 + minuteOfDay) % 900000);
}

Future<void> _cancelPresetAlarmsForDate(BehaviorPreset preset, DateTime date) async {
  final day = DateTime(date.year, date.month, date.day);
  final ids = <int>{
    if (preset.id != null) _standalonePresetAlarmId(preset.id!, day),
    _standalonePresetGroupAlarmId(day, preset.reminderHour ?? 21, preset.reminderMinute ?? 0),
  };
  for (final id in ids) {
    try { await NativeScheduler.cancel(id); } catch (_) {}
  }
}

Future<int> _scheduleDailyReviewAlarmsStandalone(BehaviorPresetDailyReviewSettings settings, _PresetAlarmSettings alarmSettings) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var count = 0;
  for (var i = 0; i < 21; i++) {
    final day = today.add(Duration(days: i));
    final id = _dailyReviewAlarmId(day);
    try { await NativeScheduler.cancel(id); } catch (_) {}
    final trigger = DateTime(day.year, day.month, day.day, settings.hour, settings.minute);
    if (!trigger.isAfter(now.add(const Duration(seconds: 20)))) continue;
    final ok = await NativeScheduler.scheduleAlarmClockAt(id: id, epochMs: trigger.millisecondsSinceEpoch, payload: {
      'module': 'behavior_tracking',
      'type': 'behavior_preset_daily_review',
      'templateKey': 'preset_daily_review',
      'title': '每日预设行为复盘',
      'body': '请登记今天预设行为的最终完成/未完成情况，并开始明天预设。',
      'checkDateMs': day.millisecondsSinceEpoch,
      'alarmId': id,
      'reminderHour': settings.hour,
      'reminderMinute': settings.minute,
      'alarmSoundUri': alarmSettings.soundUri,
      'alarmSoundTitle': alarmSettings.soundTitle,
      'alarmVolume': alarmSettings.volume,
      'alarmVibrate': alarmSettings.vibrate,
    });
    if (ok) count++;
  }
  return count;
}

Future<int> _rescheduleAllPresetAlarmsFromDao() async {
  final dao = BehaviorTrackingDao();
  final presets = (await dao.presets()).where((p) => p.active && p.reminderEnabled && p.id != null).toList();
  if (presets.isEmpty) return 0;
  final settings = await _PresetAlarmSettings.load();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final ids = <int>{};
  for (final preset in presets) {
    for (var i = 0; i < 14; i++) {
      final day = today.add(Duration(days: i));
      ids.add(_standalonePresetAlarmId(preset.id!, day));
      ids.add(_standalonePresetGroupAlarmId(day, preset.reminderHour ?? 21, preset.reminderMinute ?? 0));
    }
  }
  for (final id in ids) {
    try { await NativeScheduler.cancel(id); } catch (_) {}
  }

  final grouped = <String, _PresetAlarmGroup>{};
  for (final preset in presets) {
    final hour = preset.reminderHour ?? 21;
    final minute = preset.reminderMinute ?? 0;
    for (var i = 0; i < 14; i++) {
      final day = today.add(Duration(days: i));
      if (!preset.scheduledOn(day)) continue;
      final trigger = DateTime(day.year, day.month, day.day, hour, minute);
      if (!trigger.isAfter(now.add(const Duration(seconds: 20)))) continue;
      final key = '${day.millisecondsSinceEpoch}-$hour-$minute';
      grouped.putIfAbsent(key, () => _PresetAlarmGroup(day: day, hour: hour, minute: minute, trigger: trigger)).presets.add(preset);
    }
  }

  var count = 0;
  for (final group in grouped.values) {
    final id = _standalonePresetGroupAlarmId(group.day, group.hour, group.minute);
    final first = group.presets.first;
    final presetsPayload = group.presets.map((preset) => <String, dynamic>{
      'id': preset.id,
      'presetId': preset.id,
      'name': preset.name,
      'presetName': preset.name,
      'category': preset.category,
      'primaryLayer': preset.primaryLayer,
      'targetValue': preset.targetValue,
      'unit': preset.unit,
      'defaultDurationMin': preset.defaultDurationMin,
      'weekdays': preset.weekdays,
    }).toList();
    final ok = await NativeScheduler.scheduleAlarmClockAt(id: id, epochMs: group.trigger.millisecondsSinceEpoch, payload: {
      'module': 'behavior_tracking',
      'type': 'behavior_preset_alarm',
      'title': '预设提醒',
      'body': group.presets.length == 1 ? '请查看“${first.name}”是否仍是今天要确认的预设；这不是要求你现在完成行为。' : '请查看这个时刻的 ${group.presets.length} 个预设行为；这不是要求你现在完成行为。',
      'presetId': first.id,
      'presetName': first.name,
      'category': first.category,
      'primaryLayer': first.primaryLayer,
      'targetValue': first.targetValue,
      'unit': first.unit,
      'defaultDurationMin': first.defaultDurationMin,
      'checkDateMs': group.day.millisecondsSinceEpoch,
      'alarmId': id,
      'reminderHour': group.hour,
      'reminderMinute': group.minute,
      'alarmSoundUri': settings.soundUri,
      'alarmSoundTitle': settings.soundTitle,
      'alarmVolume': settings.volume,
      'alarmVibrate': settings.vibrate,
      'presets': presetsPayload,
      'presetCount': presetsPayload.length,
    });
    if (ok) count++;
  }
  return count;
}


class _PresetAlarmGroup {
  final DateTime day;
  final int hour;
  final int minute;
  final DateTime trigger;
  final List<BehaviorPreset> presets = <BehaviorPreset>[];

  _PresetAlarmGroup({required this.day, required this.hour, required this.minute, required this.trigger});
}

class _PresetAlarmSettings {
  static const MethodChannel _channel = MethodChannel('behavior.tracking.native');

  final String soundUri;
  final String soundTitle;
  final double volume;
  final bool vibrate;

  const _PresetAlarmSettings({
    required this.soundUri,
    required this.soundTitle,
    required this.volume,
    required this.vibrate,
  });

  factory _PresetAlarmSettings.defaults() => const _PresetAlarmSettings(
        soundUri: '',
        soundTitle: '系统默认闹钟铃声',
        volume: 1.0,
        vibrate: true,
      );

  _PresetAlarmSettings copyWith({String? soundUri, String? soundTitle, double? volume, bool? vibrate}) => _PresetAlarmSettings(
        soundUri: soundUri ?? this.soundUri,
        soundTitle: soundTitle ?? this.soundTitle,
        volume: (volume ?? this.volume).clamp(0.0, 1.0).toDouble(),
        vibrate: vibrate ?? this.vibrate,
      );

  static Future<_PresetAlarmSettings> load() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getPresetAlarmSettings');
      if (raw == null) return _PresetAlarmSettings.defaults();
      return _PresetAlarmSettings(
        soundUri: (raw['soundUri'] ?? '').toString(),
        soundTitle: (raw['soundTitle'] ?? '系统默认闹钟铃声').toString(),
        volume: (raw['volume'] is num ? (raw['volume'] as num).toDouble() : double.tryParse(raw['volume']?.toString() ?? '') ?? 1.0).clamp(0.0, 1.0).toDouble(),
        vibrate: raw['vibrate'] != false,
      );
    } catch (_) {
      return _PresetAlarmSettings.defaults();
    }
  }

  Future<_PresetAlarmSettings> save() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('savePresetAlarmSettings', {
        'soundUri': soundUri,
        'soundTitle': soundTitle,
        'volume': volume.clamp(0.0, 1.0),
        'vibrate': vibrate,
      });
      if (raw == null) return this;
      return _PresetAlarmSettings(
        soundUri: (raw['soundUri'] ?? soundUri).toString(),
        soundTitle: (raw['soundTitle'] ?? soundTitle).toString(),
        volume: (raw['volume'] is num ? (raw['volume'] as num).toDouble() : volume).clamp(0.0, 1.0).toDouble(),
        vibrate: raw['vibrate'] != false,
      );
    } catch (_) {
      return this;
    }
  }

  static Future<void> openSystemRingtonePicker() async {
    try { await _channel.invokeMethod('openPresetAlarmRingtonePicker'); } catch (_) {}
  }

  static Future<bool> requestRuntimePermissions() async {
    try { return await _channel.invokeMethod<bool>('requestPresetAlarmRuntimePermissions') ?? true; } catch (_) { return true; }
  }

  static Future<bool> canUseFullScreenIntent() async {
    try { return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? true; } catch (_) { return true; }
  }

  static Future<bool> openFullScreenIntentSettings() async {
    try { return await _channel.invokeMethod<bool>('openFullScreenIntentSettings') ?? false; } catch (_) { return false; }
  }

  static Future<bool> canDrawOverlay() async {
    try { return await _channel.invokeMethod<bool>('canDrawBehaviorPresetAlarmOverlay') ?? true; } catch (_) { return true; }
  }

  static Future<bool> openOverlaySettings() async {
    try { return await _channel.invokeMethod<bool>('openBehaviorPresetAlarmOverlaySettings') ?? false; } catch (_) { return false; }
  }
}

class _PresetDoneInput {
  final double? actualValue;
  final int? actualDurationMin;
  final String note;
  const _PresetDoneInput({this.actualValue, this.actualDurationMin, required this.note});
}

class _PresetEditorPage extends StatefulWidget {
  final BehaviorPreset initial;
  final List<String> categories;
  const _PresetEditorPage({required this.initial, required this.categories});

  @override
  State<_PresetEditorPage> createState() => _PresetEditorPageState();
}

class _PresetEditorPageState extends State<_PresetEditorPage> {
  late BehaviorPreset _preset;
  late TextEditingController _name;
  late TextEditingController _target;
  late TextEditingController _unit;
  late TextEditingController _duration;
  late TextEditingController _notes;
  late String _category;
  late String _layer;
  late Set<int> _weekdays;
  late bool _reminderEnabled;
  late bool _reminderVibrate;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial;
    _name = TextEditingController(text: _preset.name);
    _target = TextEditingController(text: _preset.targetValue?.toString() ?? '');
    _unit = TextEditingController(text: _preset.unit.ifEmpty('次'));
    _duration = TextEditingController(text: _preset.defaultDurationMin?.toString() ?? '');
    _notes = TextEditingController(text: _preset.notes);
    _category = widget.categories.contains(_preset.category) ? _preset.category : (widget.categories.contains('工作/学习') ? '工作/学习' : widget.categories.first);
    _layer = behaviorLayerInfos.any((e) => e.name == _preset.primaryLayer) ? _preset.primaryLayer : '行为层面';
    _weekdays = _preset.weekdays.toSet();
    _reminderEnabled = _preset.reminderEnabled;
    _reminderVibrate = _preset.reminderVibrate;
    _reminderTime = TimeOfDay(hour: _preset.reminderHour ?? 21, minute: _preset.reminderMinute ?? 0);
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _unit.dispose();
    _duration.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null) return;
    setState(() => _reminderTime = picked);
  }

  void _save() {
    final clean = _name.text.trim();
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写预设行为名称')));
      return;
    }
    final saved = _preset.copyWith(
      name: clean,
      category: _category,
      primaryLayer: _layer,
      targetValue: double.tryParse(_target.text.trim()),
      clearTargetValue: _target.text.trim().isEmpty,
      unit: _unit.text.trim().ifEmpty('次'),
      defaultDurationMin: int.tryParse(_duration.text.trim()),
      clearDefaultDurationMin: _duration.text.trim().isEmpty,
      reminderEnabled: _reminderEnabled,
      reminderHour: _reminderEnabled ? _reminderTime.hour : null,
      reminderMinute: _reminderEnabled ? _reminderTime.minute : null,
      clearReminderTime: !_reminderEnabled,
      reminderFullScreen: true,
      reminderVibrate: _reminderVibrate,
      weekdays: _weekdays.toList()..sort(),
      notes: _notes.text.trim(),
    );
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_preset.id == null ? '新增预设行为' : '编辑预设行为', style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 110), children: [
        _PresetCard(title: '行为方式', icon: Icons.event_note_outlined, children: [
          _PresetField(controller: _name, label: '预设行为名称', hint: '例如：阅读、运动、背单词、睡前复盘'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: '行为类别', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)))),
            items: widget.categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _layer,
            decoration: const InputDecoration(labelText: '主要观察层面', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)))),
            items: behaviorLayerInfos.map((e) => DropdownMenuItem(value: e.name, child: Text(e.name))).toList(),
            onChanged: (v) => setState(() => _layer = v ?? _layer),
          ),
        ]),
        const SizedBox(height: 12),
        _PresetCard(title: '目标与频率', icon: Icons.flag_outlined, children: [
          Row(children: [
            Expanded(child: _PresetField(controller: _target, label: '计划量', hint: '例如 20', keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _PresetField(controller: _unit, label: '单位', hint: '分钟/次/页')),
          ]),
          const SizedBox(height: 10),
          _PresetField(controller: _duration, label: '默认时长（分钟，可选）', hint: '完成后可用它生成时间记录', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          const Text('重复日期', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: const Text('每天'), selected: _weekdays.isEmpty, onSelected: (_) => setState(() => _weekdays.clear())),
            for (var i = 1; i <= 7; i++)
              ChoiceChip(
                label: Text(names[i - 1]),
                selected: _weekdays.contains(i),
                onSelected: (_) => setState(() {
                  if (_weekdays.contains(i)) {
                    _weekdays.remove(i);
                  } else {
                    _weekdays.add(i);
                  }
                }),
              ),
          ]),
          const SizedBox(height: 10),
          _PresetField(controller: _notes, label: '备注（可选）', hint: '例如：晚上睡前确认；周末可跳过', maxLines: 2),
        ]),
        const SizedBox(height: 12),
        _PresetCard(title: '系统闹钟提醒', icon: Icons.alarm_on_outlined, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('到点响铃并弹出预设提醒表单', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('使用系统闹钟铃声响铃，不再发送通知提醒；到点用于提醒你查看/确认预设，不代表现在必须完成行为。'),
            value: _reminderEnabled,
            onChanged: (v) async {
              if (v) {
                final granted = await ExactAlarmPermissionCoordinator.ensureGranted(
                  context,
                  featureName: '行为预设闹钟提醒',
                  explanation: '开启后会在指定时间响铃并弹出预设确认表单。',
                );
                if (!granted || !mounted) return;
              }
              setState(() => _reminderEnabled = v);
            },
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickReminderTime,
              icon: const Icon(Icons.schedule_outlined),
              label: Text('提醒时间：${_reminderTime.format(context)}'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('震动偏好（兼容旧数据）', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('实际响铃的铃声、音量和震动以“闹钟提醒”里的统一闹钟设置为准。'),
              value: _reminderVibrate,
              onChanged: (v) => setState(() => _reminderVibrate = v),
            ),
            const SizedBox(height: 8),
            const Text('保存后会注册未来 14 天内符合重复日期的系统闹钟。响铃使用手机当前系统闹钟铃声；实际完成/未完成仍在每日确认清单中处理。后台进程不在时也会使用系统闹钟级提醒尽量准时弹出。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
          ],
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('保存预设行为')),
        ),
      ),
    );
  }
}

class _PresetCheckTile extends StatelessWidget {
  final BehaviorPreset preset;
  final BehaviorPresetCheckIn? checkIn;
  final VoidCallback onDone;
  final VoidCallback onMissed;
  final VoidCallback onSkipped;
  final VoidCallback onEdit;
  const _PresetCheckTile({required this.preset, required this.checkIn, required this.onDone, required this.onMissed, required this.onSkipped, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final status = checkIn?.statusLabel ?? '待确认';
    final statusColor = checkIn?.status == 'done'
        ? const Color(0xFF16A34A)
        : checkIn?.status == 'missed'
            ? const Color(0xFFDC2626)
            : checkIn?.status == 'skipped'
                ? const Color(0xFF64748B)
                : const Color(0xFFD97706);
    final target = [
      if (preset.targetValue != null) '${_trimDouble(preset.targetValue!)}${preset.unit}',
      if (preset.defaultDurationMin != null) '${preset.defaultDurationMin}分钟',
      if (preset.reminderEnabled) '闹钟 ${_two(preset.reminderHour ?? 21)}:${_two(preset.reminderMinute ?? 0)}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(preset.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 5),
        Text("${preset.category.ifEmpty('未分类')} · ${target.ifEmpty('无固定量')} · ${_weekdayLabel(preset.weekdays)}", style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        if (checkIn?.note.trim().isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(checkIn!.note, style: const TextStyle(color: Color(0xFF64748B))),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(onPressed: onDone, icon: const Icon(Icons.check_circle_outline), label: const Text('完成')),
          OutlinedButton.icon(onPressed: onMissed, icon: const Icon(Icons.cancel_outlined), label: const Text('未完成')),
          OutlinedButton.icon(onPressed: onSkipped, icon: const Icon(Icons.remove_circle_outline), label: const Text('跳过')),
          TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('编辑')),
        ]),
      ]),
    );
  }
}

class _PresetManageTile extends StatelessWidget {
  final BehaviorPreset preset;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  const _PresetManageTile({required this.preset, required this.onEdit, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final detail = [
      preset.category.ifEmpty('未分类'),
      if (preset.targetValue != null) '${_trimDouble(preset.targetValue!)}${preset.unit}',
      if (preset.defaultDurationMin != null) '${preset.defaultDurationMin}分钟',
      _weekdayLabel(preset.weekdays),
      if (preset.reminderEnabled) '系统闹钟 ${_two(preset.reminderHour ?? 21)}:${_two(preset.reminderMinute ?? 0)}',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(detail, style: const TextStyle(color: Color(0xFF64748B))),
      trailing: Wrap(spacing: 4, children: [
        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: '编辑'),
        IconButton(onPressed: onDeactivate, icon: const Icon(Icons.delete_outline), tooltip: '停用'),
      ]),
    );
  }
}


class _PresetAlarmStatusCard extends StatelessWidget {
  final List<BehaviorPreset> presets;
  final Future<void> Function() onManage;
  final Future<void> Function() onRegisterAll;
  final Future<void> Function(BehaviorPreset preset) onEnablePreset;
  final Future<void> Function() onScheduleSetupAlarm;

  const _PresetAlarmStatusCard({
    required this.presets,
    required this.onManage,
    required this.onRegisterAll,
    required this.onEnablePreset,
    required this.onScheduleSetupAlarm,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = presets.where((p) => p.reminderEnabled).toList();
    final disabled = presets.where((p) => !p.reminderEnabled).toList();
    final tomorrowRaw = DateTime.now().add(const Duration(days: 1));
    final tomorrow = DateTime(tomorrowRaw.year, tomorrowRaw.month, tomorrowRaw.day);
    final tomorrowEnabled = enabled.where((p) => p.scheduledOn(tomorrow)).toList();
    final needsTomorrowSetupAlarm = tomorrowEnabled.isEmpty;
    final next = enabled.isEmpty ? null : enabled.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled.isEmpty ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: enabled.isEmpty ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(enabled.isEmpty ? Icons.alarm_add_outlined : Icons.alarm_on_outlined, color: enabled.isEmpty ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
          const SizedBox(width: 8),
          const Expanded(child: Text('系统闹钟提醒', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          TextButton(onPressed: onManage, child: const Text('管理')),
        ]),
        const SizedBox(height: 8),
        if (enabled.isEmpty) ...[
          const Text('当前还没有预设提醒闹钟。闹钟可以先督促你完成当天行为预设；已有预设时，只用于提醒你查看/确认预设，不代表现在必须完成行为。', style: TextStyle(color: Color(0xFF92400E), height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: onScheduleSetupAlarm,
              icon: const Icon(Icons.alarm_add_outlined),
              label: const Text('设置预设提醒闹钟'),
            ),
            if (disabled.isNotEmpty)
              for (final preset in disabled.take(2))
                OutlinedButton.icon(
                  onPressed: () => onEnablePreset(preset),
                  icon: const Icon(Icons.alarm_add_outlined),
                  label: Text('为“${preset.name}”开启'),
                ),
          ]),
        ] else ...[
          Text('已开启 ${enabled.length} 个预设行为提醒。到点会直接弹出全屏表单；同一时刻的多个预设会汇总在一个表单中。', style: const TextStyle(color: Color(0xFF166534), height: 1.45)),
          if (needsTomorrowSetupAlarm) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDE68A))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('明天没有预设行为闹钟提醒', style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('可以先设置一个预设提醒闹钟；如果到点时明天仍没有预设行为，会弹出表单提醒你先完成预设。', style: TextStyle(color: Color(0xFF92400E), height: 1.35)),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(onPressed: onScheduleSetupAlarm, icon: const Icon(Icons.alarm_add_outlined), label: const Text('设置预设提醒闹钟')),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          for (final preset in enabled.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.schedule_outlined, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(child: Text('${preset.name} · ${_two(preset.reminderHour ?? 21)}:${_two(preset.reminderMinute ?? 0)} · ${_weekdayLabel(preset.weekdays)}', style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w700))),
              ]),
            ),
          Row(children: [
            OutlinedButton.icon(onPressed: onRegisterAll, icon: const Icon(Icons.refresh_outlined), label: const Text('重新注册')),
            const SizedBox(width: 8),
            Expanded(child: Text(next == null ? '' : '最近提醒以系统闹钟为准；预设完成情况仍在每日确认清单里处理。', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.35))),
          ]),
        ],
      ]),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _PresetCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: const Color(0xFF2563EB)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 12),
          ...children,
        ]),
      );
}

class _PresetMetric extends StatelessWidget {
  final String label;
  final String value;
  const _PresetMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _PresetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  const _PresetField({required this.controller, required this.label, required this.hint, this.maxLines = 1, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      );
}

String _two(int v) => v.toString().padLeft(2, '0');

String _weekdayLabel(List<int> weekdays) {
  if (weekdays.isEmpty) return '每天';
  const names = {1: '周一', 2: '周二', 3: '周三', 4: '周四', 5: '周五', 6: '周六', 7: '周日'};
  return weekdays.map((e) => names[e] ?? '').where((e) => e.isNotEmpty).join('、');
}

String _trimDouble(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

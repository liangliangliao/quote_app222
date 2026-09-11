import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../platform/exact_alarm_permission_coordinator.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_notification_service.dart';

class EvidenceGrowthReminderPage extends StatefulWidget {
  const EvidenceGrowthReminderPage({super.key, required this.dao, this.trialId, this.onOpenTrial});
  final EvidenceGrowthDao dao;
  final String? trialId;
  final ValueChanged<String>? onOpenTrial;
  @override
  State<EvidenceGrowthReminderPage> createState() => _EvidenceGrowthReminderPageState();
}

class _EvidenceGrowthReminderPageState extends State<EvidenceGrowthReminderPage> with WidgetsBindingObserver {
  final service = const EvidenceGrowthNotificationService();
  var enabled = true, busy = false, loading = true;
  var hours = 24;
  Map<String,dynamic> capability = {};
  List<Map<String,Object?>> records = [];
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); unawaited(_load()); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) unawaited(_load());
  }
  Future<void> _load() async {
    final id = widget.trialId;
    if (id == null) { enabled = await widget.dao.getSetting('reminders_enabled', fallback:'true') == 'true'; }
    else {
      final trial = await widget.dao.byId(id);
      enabled = await widget.dao.getSetting('remind_trial_$id', fallback:trial?.operatorInputs['remind'] ?? 'false') == 'true';
    }
    hours = int.tryParse(await widget.dao.getSetting('missing_result_hours', fallback:'24')) ?? 24;
    await service.reconcile();
    capability = await service.status();
    records = await widget.dao.reminderRecords(trialId:id);
    if (mounted) setState(() => loading = false);
  }
  Future<void> _change(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (value) {
        if (!await service.ensureNotificationsEnabled()) {
          await _load();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
            capability['available'] != true ? '暂时无法读取系统通知状态，请重试。' : '本模块通知尚未开启；请在“系统通知设置”检查应用通知及“现实试验与成长提醒”渠道。')));
          return;
        }
        if (!mounted || !await ExactAlarmPermissionCoordinator.ensureGranted(context,
          featureName:'现实试验提醒', explanation:'按试验开始、结果与恢复窗口准时提醒。')) return;
      }
      await widget.dao.configureReminders(enabled:widget.trialId == null ? value : null,
        trialId:widget.trialId, trialEnabled:widget.trialId == null ? null : value);
      await _load();
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:Text(widget.trialId == null ? '提醒管理' : '本轮提醒')),
    body:loading ? const Center(child:CircularProgressIndicator()) : ListView(padding:const EdgeInsets.all(16),children:[
      SwitchListTile(contentPadding:EdgeInsets.zero, value:enabled, onChanged:busy ? null : _change,
        title:Text(widget.trialId == null ? '允许本模块提醒' : '提醒我完成这一轮'),
        subtitle:const Text('关闭会取消待发提醒；已保存的行动、预测与结果保留。')),
      if (widget.trialId != null) const Text('本轮开关与模块总开关同时开启时生效。'),
      ListTile(contentPadding:EdgeInsets.zero, title:const Text('系统权限'),
        subtitle:Text('通知${capability['notifications'] == true ? '已开启' : '未开启'} · 精准闹钟${capability['exact'] == true ? '已开启' : '未开启'}')),
      Wrap(spacing:8, children:[
        OutlinedButton(onPressed:busy ? null : () async { await service.openSystemSettings(); },child:const Text('系统通知设置')),
        OutlinedButton(onPressed:busy ? null : () => _change(true),child:const Text('授权并恢复提醒')),
      ]),
      if (widget.trialId == null) DropdownButtonFormField<int>(initialValue:hours,
        decoration:const InputDecoration(labelText:'窗口到期后，多久未记录结果再提醒？'),
        items:const [1,6,24,48,168].map((h)=>DropdownMenuItem(value:h,child:Text('$h 小时'))).toList(),
        onChanged:busy ? null : (h) async {
          if (h == null) return;
          setState(()=>busy=true);
          try { await widget.dao.configureReminders(missingHours:h); await _load(); }
          finally { if (mounted) setState(()=>busy=false); }
        }),
      const SizedBox(height:12),
      const Text('默认 24 小时是可调整的提醒设置。连续退出提醒在同一主节点连续三轮 EXIT 后产生，不把主动退出评价为失败。'),
      const SizedBox(height:16), const Text('提醒计划与记录',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      if (records.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Text('还没有提醒。创建试验时选择开始时间和结果窗口，并开启提醒。')),
      ...records.map((row) {
        final at=DateTime.fromMillisecondsSinceEpoch((row['scheduled_at_ms'] as num).toInt());
        final state=const {'pending':'待安排','scheduled':'已安排','delivered':'已发送','cancelled':'已取消','expired':'已合并过期提醒','blocked':'需恢复权限'}[row['state']] ?? row['state'];
        return Card(child:ExpansionTile(title:Text('${row['title']}'),
          subtitle:Text('${at.year}/${at.month}/${at.day} ${at.hour.toString().padLeft(2,'0')}:${at.minute.toString().padLeft(2,'0')} · $state'),
          children:[Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${row['body']}'),const SizedBox(height:8),
            Text('依据：${(jsonDecode(row['source_ids_json'] as String) as List).join(' / ')}'),
            if (widget.onOpenTrial != null) TextButton(onPressed:()=>widget.onOpenTrial!(row['trial_id'] as String),child:const Text('打开对应试验')),
          ]))]));
      }),
    ]));
}

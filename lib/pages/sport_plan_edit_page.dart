import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../data/sport_dao.dart';
import '../platform/native_scheduler.dart';

/// 运动计划编辑/新增页面
///
/// 可用于新增一条运动计划或编辑已存在的计划。支持设置标题、
/// 运动类型（目前仅步行）、目标值和单位、重复频率与时间、通知开关
/// 及提前提醒时间。高级模式如每周/每月的多选日期与自定义日期
/// 暂以简化形式存储在 repeat_detail 中以兼容未来拓展。
class SportPlanEditPage extends StatefulWidget {
  final Map<String, dynamic>? existingPlan;
  const SportPlanEditPage({super.key, this.existingPlan});

  @override
  State<SportPlanEditPage> createState() => _SportPlanEditPageState();
}

class _SportPlanEditPageState extends State<SportPlanEditPage> {
  final _formKey = GlobalKey<FormState>();
  final SportDao _dao = SportDao();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _targetValueCtrl;

  String _sportType = 'walk';
  String _targetType = 'steps';
  String _targetUnit = '步';
  String _repeatType = 'daily';
  List<int> _repeatWeekdays = [];
  List<int> _repeatMonthDays = [];
  List<DateTime> _repeatCustomDates = [];
  TimeOfDay _planTime = const TimeOfDay(hour: 20, minute: 0);
  bool _notifyEnabled = false;
  int _notifyAdvance = 2;

  bool get isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingPlan?['title']?.toString() ?? '');
    final tv = widget.existingPlan?['target_value'];
    _targetValueCtrl = TextEditingController(
        text: tv == null ? '' : tv.toString());
    _sportType = widget.existingPlan?['sport_type']?.toString() ?? 'walk';
    _targetType = widget.existingPlan?['target_type']?.toString() ?? 'steps';
    _targetUnit = widget.existingPlan?['target_unit']?.toString() ?? '步';
    _repeatType = widget.existingPlan?['repeat_type']?.toString() ?? 'daily';
    final detailStr = widget.existingPlan?['repeat_detail']?.toString() ?? '';
    if (detailStr.isNotEmpty) {
      try {
        final map = json.decode(detailStr);
        if (map is Map<String, dynamic>) {
          if (map['weekdays'] is List) {
            _repeatWeekdays = (map['weekdays'] as List).map((e) => int.tryParse(e.toString()) ?? 1).toList();
          }
          if (map['monthDays'] is List) {
            _repeatMonthDays = (map['monthDays'] as List).map((e) => int.tryParse(e.toString()) ?? 1).toList();
          }
          if (map['dates'] is List) {
            _repeatCustomDates = (map['dates'] as List)
                .map((e) => DateTime.tryParse(e.toString()))
                .whereType<DateTime>()
                .toList();
          }
        }
      } catch (_) {}
    }
    final planTimeStr = widget.existingPlan?['plan_time']?.toString();
    if (planTimeStr != null && planTimeStr.isNotEmpty) {
      try {
        final dt = DateTime.tryParse(planTimeStr);
        if (dt != null) {
          _planTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        }
      } catch (_) {}
    }
    _notifyEnabled = (widget.existingPlan?['notify_enabled']?.toString() == '1');
    _notifyAdvance = int.tryParse(widget.existingPlan?['notify_advance']?.toString() ?? '2') ?? 2;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetValueCtrl.dispose();
    super.dispose();
  }

  // update unit when target type changes
  void _updateUnitForTarget(String target) {
    setState(() {
      _targetType = target;
      switch (_targetType) {
        case 'duration':
          _targetUnit = '小时';
          break;
        case 'distance':
          _targetUnit = 'km';
          break;
        default:
          _targetUnit = '步';
      }
    });
  }

  // show weekday picker dialog
  Future<void> _pickWeekdays() async {
    final selected = List<int>.from(_repeatWeekdays);
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择每周的星期几'),
          content: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(7, (index) {
                  final day = index + 1; // Monday=1
                  final names = ['一', '二', '三', '四', '五', '六', '日'];
                  return CheckboxListTile(
                    value: selected.contains(day),
                    title: Text('周${names[index]}'),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selected.add(day);
                        } else {
                          selected.remove(day);
                        }
                      });
                    },
                  );
                }),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(selected), child: const Text('确定')),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        _repeatWeekdays = result;
      });
    }
  }

  // show time picker
  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _planTime);
    if (t != null) {
      setState(() {
        _planTime = t;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final Map<String, dynamic> data = {};
    data['title'] = _titleCtrl.text.trim();
    data['sport_type'] = _sportType;
    data['target_type'] = _targetType;
    final numStr = _targetValueCtrl.text.trim();
    double? targetValue;
    if (numStr.isNotEmpty) {
      targetValue = double.tryParse(numStr);
    }
    data['target_value'] = targetValue;
    data['target_unit'] = _targetUnit;
    data['repeat_type'] = _repeatType;
    // Build repeat detail JSON
    final detail = <String, dynamic>{};
    if (_repeatType == 'weekly') {
      detail['weekdays'] = _repeatWeekdays;
    } else if (_repeatType == 'monthly') {
      detail['monthDays'] = _repeatMonthDays;
    } else if (_repeatType == 'custom') {
      detail['dates'] = _repeatCustomDates.map((e) => e.toIso8601String()).toList();
    }
    data['repeat_detail'] = json.encode(detail);
    // Compose plan_time as today with selected HH:mm
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, _planTime.hour, _planTime.minute);
    data['plan_time'] = dt.toIso8601String();
    data['notify_enabled'] = _notifyEnabled ? 1 : 0;
    data['notify_advance'] = _notifyAdvance;
    data['status'] = widget.existingPlan?['status']?.toString() ?? 'not_started';
    int planId;
    if (isEditing) {
      planId = widget.existingPlan!['id'] as int;
      await _dao.updatePlan(planId, data);
    } else {
      planId = await _dao.insertPlan(data);
    }
    // 同步原生定时（后台/被杀进程也能触发）
    await _syncNativeAlarms(planId, dt, notifyEnabled: _notifyEnabled, advanceMinutes: _notifyAdvance);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _syncNativeAlarms(
    int planId,
    DateTime planTime,
    {required bool notifyEnabled, required int advanceMinutes}
  ) async {
    try {
      // Stable alarm IDs (avoid colliding with other features)
      final fullScreenAlarmId = 1600000000 + planId;
      final reminderAlarmId = 1700000000 + planId;
      await NativeScheduler.cancel(fullScreenAlarmId);
      await NativeScheduler.cancel(reminderAlarmId);

      // If plan time is in the past, schedule for the next day (basic daily fallback).
      var fireAt = planTime;
      final now = DateTime.now();
      if (!fireAt.isAfter(now.add(const Duration(seconds: 1)))) {
        fireAt = fireAt.add(const Duration(days: 1));
      }

      final fullPayload = json.encode({
        'type': 'sport_fullscreen',
        'planId': planId,
        'mode': 'plan',
        'triggerAt': fireAt.millisecondsSinceEpoch,
      });
      await NativeScheduler.scheduleExactAt(fullScreenAlarmId, fireAt.millisecondsSinceEpoch, fullPayload);

      if (notifyEnabled && advanceMinutes > 0) {
        final remindAt = fireAt.subtract(Duration(minutes: advanceMinutes));
        if (remindAt.isAfter(now)) {
          final remPayload = json.encode({
            'type': 'sport_reminder',
            'planId': planId,
            'advanceMinutes': advanceMinutes,
            'triggerAt': remindAt.millisecondsSinceEpoch,
          });
          await NativeScheduler.scheduleExactAt(reminderAlarmId, remindAt.millisecondsSinceEpoch, remPayload);
        }
      }
    } catch (_) {
      // scheduling failure should not block saving the plan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑运动计划' : '新增运动计划')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 标题
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '标题'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return '请输入标题';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // 运动类型
            DropdownButtonFormField<String>(
              value: _sportType,
              decoration: const InputDecoration(labelText: '运动类型'),
              items: const [
                DropdownMenuItem(value: 'walk', child: Text('步行')),
                DropdownMenuItem(value: 'run', child: Text('跑步', style: TextStyle(color: Colors.grey))),
                DropdownMenuItem(value: 'fitness', child: Text('健身', style: TextStyle(color: Colors.grey))),
              ],
              onChanged: (val) {
                if (val != null && val == 'walk') {
                  setState(() {
                    _sportType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            // 目标类型
            DropdownButtonFormField<String>(
              value: _targetType,
              decoration: const InputDecoration(labelText: '目标类型'),
              items: const [
                DropdownMenuItem(value: 'steps', child: Text('步数')),
                DropdownMenuItem(value: 'duration', child: Text('时长')),
                DropdownMenuItem(value: 'distance', child: Text('路程')),
              ],
              onChanged: (val) {
                if (val != null) {
                  _updateUnitForTarget(val);
                }
              },
            ),
            const SizedBox(height: 12),
            // 目标值
            TextFormField(
              controller: _targetValueCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '目标值 ($_targetUnit)'),
              validator: (val) {
                if (_targetValueCtrl.text.trim().isEmpty) return null;
                final v = double.tryParse(_targetValueCtrl.text.trim());
                if (v == null || v <= 0) return '请输入正数';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // 重复类型
            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: const InputDecoration(labelText: '重复频率'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('每天')),
                DropdownMenuItem(value: 'weekly', child: Text('每周')),
                DropdownMenuItem(value: 'monthly', child: Text('每月')),
                DropdownMenuItem(value: 'custom', child: Text('自定义')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _repeatType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            // 显示额外的选择控件
            if (_repeatType == 'weekly')
              ListTile(
                title: const Text('选择星期'),
                subtitle: Text(_repeatWeekdays.isEmpty
                    ? '未选择'
                    : _repeatWeekdays.map((d) => '周${'一二三四五六日'[d - 1]}').join('、')),
                trailing: const Icon(Icons.edit),
                onTap: _pickWeekdays,
              ),
            // 时间选择
            ListTile(
              title: const Text('计划时间'),
              subtitle: Text('${_planTime.format(context)}'),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const SizedBox(height: 12),
            // 通知开关
            SwitchListTile(
              value: _notifyEnabled,
              title: const Text('开启通知提醒'),
              onChanged: (val) {
                setState(() {
                  _notifyEnabled = val;
                });
              },
            ),
            if (_notifyEnabled)
              DropdownButtonFormField<int>(
                value: _notifyAdvance,
                decoration: const InputDecoration(labelText: '提前提醒时间'),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('2 分钟')),
                  DropdownMenuItem(value: 5, child: Text('5 分钟')),
                  DropdownMenuItem(value: 10, child: Text('10 分钟')),
                  DropdownMenuItem(value: 30, child: Text('30 分钟')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _notifyAdvance = val;
                    });
                  }
                },
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
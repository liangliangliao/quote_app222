import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/sport_dao.dart';
import '../platform/native_scheduler.dart';
import 'sport_history_list_page.dart';
import 'sport_history_summary_page.dart';
import 'sport_plan_progress_page.dart';
import 'sport_running_page.dart';

/// 运动详情页
///
/// - 展示计划列表（标题、类型、开始时间、目标、状态、进度入口、历史入口）
/// - 右下角绿色新增按钮：弹窗新增计划
/// - 左下角“立刻开始”：非计划模式新增一条记录并进入进行中页
/// - 有未完成记录时提供“重新进入运动进行时”入口
class SportDetailPage extends StatefulWidget {
  const SportDetailPage({super.key});

  @override
  State<SportDetailPage> createState() => _SportDetailPageState();
}

class _SportDetailPageState extends State<SportDetailPage> with WidgetsBindingObserver {
  final SportDao _dao = SportDao();

  bool _loading = true;
  List<Map<String, dynamic>> _plans = const [];
  Map<String, dynamic>? _unfinishedRecord;

  Timer? _pollTimer;
  bool _refreshing = false;

  bool _isForeground = true;

  // Avoid repeated auto-navigation when we poll every 2s.
  final Set<String> _autoTriggeredPlanKeys = <String>{};
  final Set<int> _autoEnteredQueuedRecordIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Keep plan card status in sync while this page is visible.
    // Use 1s polling while this page is visible so we don't miss the exact plan time.
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshStates();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _refreshStates();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Important: do NOT blank the plan list if renewal fails.
    // Some devices may have legacy/missing tables; renewal should be best-effort.
    try {
      await _dao.renewPlansIfDayChanged();
    } catch (_) {
      // ignore
    }

    List<Map<String, dynamic>> plans = const [];
    Map<String, dynamic>? unfinished;
    try {
      plans = await _dao.getPlansWithComputedStatus();
    } catch (_) {
      // Fallback: at least show raw plans if computed-status logic fails.
      try {
        plans = await _dao.getPlans();
      } catch (_) {
        plans = const [];
      }
    }
    try {
      // Fetch only active records (not_started/in_progress/paused).  Queued records
      // should not block starting new sessions, so they are excluded here.
      unfinished = await _dao.getLatestActiveRecord();
    } catch (_) {
      unfinished = null;
    }

    if (!mounted) return;
    setState(() {
      _plans = plans;
      _unfinishedRecord = unfinished;
      _loading = false;
    });

    // If we enter this page right at the plan time, try auto-start once.
    await _maybeAutoStartDuePlan(plans: plans, unfinished: unfinished);
    // If there are queued items and no active run, promote FIFO head.
    await _maybePromoteQueuedHeadIfIdle(unfinished: unfinished);
  }

  Future<void> _refreshStates() async {
    if (!mounted) return;
    if (_loading) return;
    if (_refreshing) return;
    _refreshing = true;
    try {
      try {
        await _dao.renewPlansIfDayChanged();
      } catch (_) {
        // ignore
      }

      List<Map<String, dynamic>> plans = const [];
      try {
        plans = await _dao.getPlansWithComputedStatus();
      } catch (_) {
        try {
          plans = await _dao.getPlans();
        } catch (_) {
          plans = const [];
        }
      }

      Map<String, dynamic>? unfinished;
      try {
        // Only consider active records (not_started/in_progress/paused) so queued
        // records do not block starting new sessions.
        unfinished = await _dao.getLatestActiveRecord();
      } catch (_) {
        unfinished = null;
      }

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _unfinishedRecord = unfinished;
      });

      // Auto jump into running page when app is foreground and we are on this page.
      // Requirement: if we reach the plan time while on sport home, automatically start with 5s countdown.
      await _maybeAutoStartDuePlan(plans: plans, unfinished: unfinished);
      await _maybePromoteQueuedHeadIfIdle(unfinished: unfinished);
    } catch (_) {
      // ignore
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _maybeAutoStartDuePlan({required List<Map<String, dynamic>> plans, required Map<String, dynamic>? unfinished}) async {
    if (!mounted) return;
    if (!_isForeground) return;

    // Only when this route is on top.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    // Note: if there is an active unfinished record, we will not auto start a new
    // session. Instead, we will queue the triggered plan below.  Do not
    // early-return here; the logic below handles queuing when necessary.

    final now = DateTime.now();
    for (final p in plans) {
      final status = (p['status'] ?? '').toString();
      final ptIso = (p['plan_time'] ?? '').toString();
      final pt = DateTime.tryParse(ptIso);
      if (pt == null) continue;

      // "正好到达"：轮询 + 系统调度可能导致错过精确秒。
      // 允许在计划时间前 0.5s 到 计划时间后 10s 内触发一次，避免漏触发。
      final diffMs = now.millisecondsSinceEpoch - pt.millisecondsSinceEpoch;
      if (diffMs < -500 || diffMs > 10000) continue;

      // NOTE: computed status may flip to 'expired' as soon as pt < now.
      // For auto-start we only care that we just reached the plan time.
      // Still, avoid starting when plan is explicitly canceled.
      if (status == 'canceled') continue;

      final planId = p['id'] as int?;
      if (planId == null) continue;
      final key = '$planId|$ptIso';
      if (_autoTriggeredPlanKeys.contains(key)) continue;
      _autoTriggeredPlanKeys.add(key);
      // Determine if we already have a record for this plan instance.
      int? existingId;
      try {
        existingId = await _dao.getRecordIdForPlanInstance(planId, ptIso);
      } catch (_) {
        existingId = null;
      }

      // If there is an existing active run (unfinished != null), we do not
      // auto-start a new session.  Instead, mark the plan as queued.  If no
      // record exists for this plan instance, insert a new record with
      // status 'queued'.  Otherwise, update the existing record to status
      // 'queued'.  Note: queued records have no start_time because the
      // user has not begun the run yet.
      if (unfinished != null) {
        // Create or update queued record
        if (existingId != null) {
          try {
            await _dao.updateRecord(existingId, {
              'status': 'queued',
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {
            // ignore
          }
        } else {
          try {
            await _dao.insertRecord({
              'plan_id': planId,
              'title': (p['title'] ?? '').toString(),
              'sport_type': (p['sport_type'] ?? 'walk').toString(),
              'mode': 'plan',
              'plan_time': ptIso,
              'status': 'queued',
              'target_type': (p['target_type'] ?? 'steps').toString(),
              'target_value': p['target_value'] ?? 0,
              'target_unit': (p['target_unit'] ?? '步').toString(),
            });
          } catch (_) {
            // ignore
          }
        }
        // Update the plan status to queued so the plan card reflects this state.
        try {
          await _dao.updatePlanStatus(planId, 'queued');
        } catch (_) {
          // ignore
        }
        // Notify the user once about the queued state.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已有运动正在进行，本次计划已加入排队列表'),
          ));
          // Refresh list to show updated plan status.
          await _load();
        }
        return;
      }

      // Otherwise no active session exists. Insert a new record for this
      // plan instance if it doesn't already exist, set status to prestart
      // in_progress (start_time stays NULL), and navigate to the running page.
      // defer setting the start_time until after countdown on the running
      // page.
      final recordId = existingId ??
          await _dao.insertRecord({
            'plan_id': planId,
            'title': (p['title'] ?? '').toString(),
            'sport_type': (p['sport_type'] ?? 'walk').toString(),
            'mode': 'plan',
            'plan_time': ptIso,
            'status': 'in_progress',
            'target_type': (p['target_type'] ?? 'steps').toString(),
            'target_value': p['target_value'] ?? 0,
            'target_unit': (p['target_unit'] ?? '步').toString(),
          });

      // If we reused an existing record (e.g. user tapped the plan time twice),
      // make sure it is in prestart state.
      try {
        await _dao.updateRecord(recordId, {
          'status': 'in_progress',
          'start_time': null,
          'end_time': null,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // ignore
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SportRunningPage(recordId: recordId, plan: p, mode: 'plan')),
      );
      // After returning, refresh list.
      if (mounted) {
        await _load();
      }
      return;
    }
  }

  /// If there are queued records and no active session, promote the earliest
  /// queued record (FIFO) to a prestart in_progress record and allow entering
  /// the running page.
  Future<void> _maybePromoteQueuedHeadIfIdle({required Map<String, dynamic>? unfinished}) async {
    if (!mounted) return;
    if (unfinished != null) return;

    Map<String, dynamic>? q;
    try {
      q = await _dao.getEarliestQueuedRecord();
    } catch (_) {
      q = null;
    }
    if (q == null) return;

    int? qid;
    final rid = q['id'];
    if (rid is int) qid = rid;
    else if (rid is num) qid = rid.toInt();
    else qid = int.tryParse(rid?.toString() ?? '');
    if (qid == null) return;

    final pidRaw = q['plan_id'];
    int? planId;
    if (pidRaw is int) planId = pidRaw;
    else if (pidRaw is num) planId = pidRaw.toInt();
    else planId = int.tryParse(pidRaw?.toString() ?? '');

    try {
      await _dao.promoteQueuedToPrestart(qid);
      if (planId != null) {
        await _dao.updatePlanStatus(planId, 'in_progress');
      }
    } catch (_) {
      // ignore
    }

    // Refresh UI state.
    try {
      final plans2 = await _dao.getPlansWithComputedStatus();
      final active2 = await _dao.getLatestActiveRecord();
      if (!mounted) return;
      setState(() {
        _plans = plans2;
        _unfinishedRecord = active2;
      });
    } catch (_) {}

    // Optional auto-enter: only when foreground and this route is on top.
    if (!_isForeground) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    if (_autoEnteredQueuedRecordIds.contains(qid)) return;
    _autoEnteredQueuedRecordIds.add(qid);

    Map<String, dynamic>? plan;
    if (planId != null) {
      try {
        plan = await _dao.getPlan(planId);
      } catch (_) {
        plan = null;
      }
    }
    final mode = (q['mode'] ?? 'plan').toString();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SportRunningPage(recordId: qid!, plan: plan, mode: mode)),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _onAddPlan() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SportPlanDialog(),
    );
    if (ok == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      _load();
    }
  }

  Future<void> _onEditPlan(Map<String, dynamic> plan) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SportPlanDialog(existingPlan: plan),
    );
    if (ok == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      _load();
    }
  }

  Future<void> _onDeletePlan(Map<String, dynamic> plan) async {
    final id = plan['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除计划'),
        content: const Text('确定删除此计划吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.deletePlan(id);
    // 同时取消已注册的闹钟
    try {
      await NativeScheduler.cancel(1600000000 + id);
      await NativeScheduler.cancel(1700000000 + id);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    _load();
  }

  Future<void> _onStartInstant() async {
    // Prevent starting a new instant session if there is an active record
    // (not_started/in_progress/paused).  Use the DAO to check for any
    // existing active session; queued records are ignored here.
    try {
      final active = await _dao.getLatestActiveRecord();
      if (active != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已有一场运动正在进行或暂停中，请先完成或停止后再开始新的运动'),
          ));
        }
        return;
      }
    } catch (_) {
      // ignore
    }
    final now = DateTime.now();
    final title = '非计划模式-${_fmtFull(now)}';
    final record = <String, dynamic>{
      'plan_id': null,
      'title': title,
      'sport_type': 'walk',
      'mode': 'instant',
      'plan_time': now.toIso8601String(),
      // Prestart: countdown will run on SportRunningPage; start_time is written
      // when countdown ends.
      'start_time': null,
      'status': 'in_progress',
      'target_type': 'steps',
      'target_value': 0,
      'target_unit': '步',
    };
    final recordId = await _dao.insertRecord(record);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SportRunningPage(recordId: recordId, plan: null, mode: 'instant'),
      ),
    );
    _load();
  }

  Future<void> _resumeUnfinished() async {
    final rec = _unfinishedRecord;
    if (rec == null) return;
    final recordId = rec['id'] as int?;
    if (recordId == null) return;
    // recordId is captured by the Route builder closure below; use a non-null
    // local to satisfy null-safety.
    final int rid = recordId;

    Map<String, dynamic>? plan;
    final planId = rec['plan_id'] as int?;
    if (planId != null) {
      plan = await _dao.getPlan(planId);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SportRunningPage(recordId: rid, plan: plan, mode: (rec['mode'] ?? 'plan').toString()),
      ),
    );
    _load();
  }

  Future<void> _resumePlanPaused(Map<String, dynamic> plan) async {
    final rid = plan['_unfinished_record_id'];
    int? recordId;
    if (rid is int) {
      recordId = rid;
    } else if (rid is num) {
      recordId = rid.toInt();
    } else {
      recordId = int.tryParse(rid?.toString() ?? '');
    }
    // Fallback: if UI computed status but record id isn't attached, query DB.
    if (recordId == null) {
      final planId = plan['id'];
      final pid = (planId is int)
          ? planId
          : (planId is num)
              ? planId.toInt()
              : int.tryParse(planId?.toString() ?? '');
      if (pid != null) {
        try {
          final r = await _dao.getLatestUnfinishedRecord(planId: pid);
          final rrid = r?['id'];
          if (rrid is int) recordId = rrid;
          if (rrid is num) recordId = rrid.toInt();
          recordId ??= int.tryParse(rrid?.toString() ?? '');
        } catch (_) {}
      }
    }
    if (recordId == null) return;

    // Concurrency check: if another sport (instant or plan) is already in
    // progress or paused/not_started and it is not this record, do not
    // allow starting/resuming a new one.  Instead, navigate to the
    // existing active session after showing a message.  We call the DAO
    // directly to ensure queued records are ignored.
    try {
      final active = await _dao.getLatestActiveRecord(excludeRecordId: recordId);
      if (active != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已有一场运动正在进行或暂停中，请先完成或停止后再开始新的运动'),
          ));
        }
        // Navigate to the existing active session so the user can resume it.
        final actId = active['id'];
        int? activeId;
        if (actId is int) {
          activeId = actId;
        } else if (actId is num) {
          activeId = actId.toInt();
        } else {
          activeId = int.tryParse(actId?.toString() ?? '');
        }
        Map<String, dynamic>? activePlan;
        final apidRaw = active['plan_id'];
        int? apid;
        if (apidRaw is int) {
          apid = apidRaw;
        } else if (apidRaw is num) {
          apid = apidRaw.toInt();
        } else {
          apid = int.tryParse(apidRaw?.toString() ?? '');
        }
        if (activeId != null) {
          // activeId is captured by the Route builder closure below; use a non-null local.
          final int runningActiveId = activeId;
          if (apid != null) {
            try {
              activePlan = await _dao.getPlan(apid);
            } catch (_) {
              activePlan = null;
            }
          }
          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SportRunningPage(
                  recordId: runningActiveId,
                  plan: activePlan,
                  mode: (active['mode'] ?? 'plan').toString(),
                ),
              ),
            );
            // After returning, refresh list.
            if (mounted) {
              await _load();
            }
          }
        }
        return;
      }
    } catch (_) {
      // ignore
    }
    // recordId is captured by the Route builder closure below; use a non-null
    // local to satisfy null-safety.
    final int runningRecordId = recordId;
    final planId = plan['id'] as int?;
    Map<String, dynamic>? fullPlan;
    if (planId != null) {
      try {
        fullPlan = await _dao.getPlan(planId);
      } catch (_) {
        fullPlan = plan;
      }
    } else {
      fullPlan = plan;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SportRunningPage(recordId: runningRecordId, plan: fullPlan, mode: 'plan'),
      ),
    );
    _load();
  }

  /// Resume a queued plan.  Similar to [\_resumePlanPaused] but allows
  /// starting a previously queued record if no other active session exists.
  /// If another session is active, displays a message and navigates to that
  /// session instead.
  Future<void> _resumePlanQueued(Map<String, dynamic> plan) async {
    // Determine the queued record id associated with this plan.  Use
    // _unfinished_record_id when attached, otherwise query the DAO.
    int? recordId;
    final rid = plan['_unfinished_record_id'];
    if (rid is int) {
      recordId = rid;
    } else if (rid is num) {
      recordId = rid.toInt();
    } else if (rid != null) {
      recordId = int.tryParse(rid.toString());
    }
    // If not provided, fetch the latest queued record for this plan.
    if (recordId == null) {
      final pidRaw = plan['id'];
      int? pid;
      if (pidRaw is int) {
        pid = pidRaw;
      } else if (pidRaw is num) {
        pid = pidRaw.toInt();
      } else {
        pid = int.tryParse(pidRaw?.toString() ?? '');
      }
      if (pid != null) {
        try {
          final qrec = await _dao.getLatestQueuedRecord(planId: pid);
          final qid = qrec?['id'];
          if (qid is int) recordId = qid;
          if (qid is num) recordId = qid.toInt();
          recordId ??= int.tryParse(qid?.toString() ?? '');
        } catch (_) {
          recordId = null;
        }
      }
    }
    if (recordId == null) return;
    // recordId is captured by the Route builder closure below; use a non-null local.
    final int runningRecordId = recordId;
    // Concurrency: check for other active session (not this queued record).
    try {
      final active = await _dao.getLatestActiveRecord(excludeRecordId: recordId);
      if (active != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已有一场运动正在进行或暂停中，请先完成或停止后再开始新的运动'),
          ));
        }
        // Navigate to that active session.
        final actIdRaw = active['id'];
        int? actId;
        if (actIdRaw is int) {
          actId = actIdRaw;
        } else if (actIdRaw is num) {
          actId = actIdRaw.toInt();
        } else {
          actId = int.tryParse(actIdRaw?.toString() ?? '');
        }
        Map<String, dynamic>? actPlan;
        final apidRaw = active['plan_id'];
        int? apid;
        if (apidRaw is int) {
          apid = apidRaw;
        } else if (apidRaw is num) {
          apid = apidRaw.toInt();
        } else {
          apid = int.tryParse(apidRaw?.toString() ?? '');
        }
        if (actId != null) {
          // actId is captured by the Route builder closure below; use a non-null local.
          final int runningActId = actId;
          if (apid != null) {
            try {
              actPlan = await _dao.getPlan(apid);
            } catch (_) {
              actPlan = null;
            }
          }
          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SportRunningPage(
                  recordId: runningActId,
                  plan: actPlan,
                  mode: (active['mode'] ?? 'plan').toString(),
                ),
              ),
            );
            if (mounted) {
              await _load();
            }
          }
        }
        return;
      }
    } catch (_) {
      // ignore
    }
    // No active record exists. Promote queued record to prestart in_progress
    // (start_time stays NULL) so running page can show countdown.
    final nowIso = DateTime.now().toIso8601String();
    try {
      await _dao.updateRecord(recordId, {
        'status': 'in_progress',
        'start_time': null,
        'end_time': null,
        'updated_at': nowIso,
      });
    } catch (_) {}
    // Update plan status to in_progress as well.
    final pidRaw2 = plan['id'];
    int? pid2;
    if (pidRaw2 is int) {
      pid2 = pidRaw2;
    } else if (pidRaw2 is num) {
      pid2 = pidRaw2.toInt();
    } else {
      pid2 = int.tryParse(pidRaw2?.toString() ?? '');
    }
    if (pid2 != null) {
      try {
        await _dao.updatePlanStatus(pid2, 'in_progress');
      } catch (_) {}
    }
    // Load the full plan details if possible.
    Map<String, dynamic>? fullPlan;
    if (pid2 != null) {
      try {
        fullPlan = await _dao.getPlan(pid2);
      } catch (_) {
        fullPlan = plan;
      }
    } else {
      fullPlan = plan;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SportRunningPage(recordId: runningRecordId, plan: fullPlan, mode: 'plan'),
      ),
    );
    // Refresh after returning
    if (mounted) {
      await _load();
    }
  }

  void _openHistoryAll() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SportHistoryListPage()));
  }

  void _openSummaryAll() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SportHistorySummaryPage()));
  }

  void _openHistoryPlan(Map<String, dynamic> plan) {
    final planId = plan['id'] as int?;
    final title = plan['title']?.toString();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SportHistoryListPage(planId: planId, planTitle: title)),
    );
  }

  void _openProgress(Map<String, dynamic> plan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SportPlanProgressPage(plan: plan)),
    );
  }

  static String _fmtFull(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String _fmtPlanTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return _fmtFull(dt);
  }

  String _targetText(Map<String, dynamic> plan) {
    final t = (plan['target_type'] ?? 'steps').toString();
    final v = plan['target_value'];
    if (v == null) return '目标：-';
    if (t == 'duration') return '目标：$v 小时';
    if (t == 'distance') return '目标：$v km';
    return '目标：$v 步';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'stopped':
        return Colors.red;
      case 'canceled':
        return Colors.grey;
      case 'expired':
        return Colors.brown;
      case 'queued':
        return Colors.purple;
      default:
        return Colors.black54;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'in_progress':
        return '进行中';
      case 'paused':
        return '已暂停';
      case 'stopped':
        return '已停止';
      case 'canceled':
        return '已取消';
      case 'expired':
        return '已过期';
      case 'not_started':
        return '未开始';
      case 'queued':
        return '排队中';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('运动'),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), tooltip: '汇总', onPressed: _openSummaryAll),
          IconButton(icon: const Icon(Icons.history), tooltip: '历史', onPressed: _openHistoryAll),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_unfinishedRecord != null &&
                    (_unfinishedRecord!['plan_id'] == null) &&
                    ['paused', 'in_progress'].contains((_unfinishedRecord!['status'] ?? '').toString()))
                  _unfinishedCard(_unfinishedRecord!),
                const SizedBox(height: 8),
                if (_plans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: Text('暂无计划，点击右下角新增')),
                  )
                else
                  ..._plans.map(_planCard),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: _fabBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _unfinishedCard(Map<String, dynamic> rec) {
    final id = rec['id']?.toString() ?? '-';
    final status = (rec['status'] ?? 'paused').toString();
    final title = rec['title']?.toString() ?? '未完成运动';
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text('记录ID: $id  ·  状态: ${_statusLabel(status)}'),
        trailing: ElevatedButton(
          onPressed: _resumeUnfinished,
          child: Text(status == 'in_progress' ? '进入' : '继续'),
        ),
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final title = (plan['title'] ?? '').toString().trim();
    final sportType = (plan['sport_type'] ?? 'walk').toString();
    final planTime = _fmtPlanTime(plan['plan_time']?.toString());
    final status = (plan['status'] ?? 'not_started').toString();

    final sportTypeLabel = sportType == 'walk'
        ? '步行'
        : sportType == 'run'
            ? '跑步'
            : sportType == 'gym'
                ? '健身'
                : sportType;

    // Layout requirements:
    // - Continue button (paused only) at bottom-right of the card.
    // - 3-dots menu should be easy to tap (larger hit area).
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: 76,
                bottom: (status == 'paused' || status == 'in_progress') ? 44 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.isNotEmpty ? title : '未命名计划', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text('类型：$sportTypeLabel'),
                  Text('开始：$planTime'),
                  Text(_targetText(plan)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('状态：'),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '进度',
                      onPressed: () => _openProgress(plan),
                      icon: const Icon(Icons.calendar_today),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: PopupMenuButton<String>(
                      tooltip: '更多',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _onEditPlan(plan);
                        } else if (value == 'delete') {
                          _onDeletePlan(plan);
                        } else if (value == 'history') {
                          _openHistoryPlan(plan);
                        } else if (value == 'summary') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SportHistorySummaryPage(
                                planId: plan['id'] as int?,
                                planTitle: plan['title']?.toString(),
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                        PopupMenuItem(value: 'history', child: Text('历史')),
                        PopupMenuItem(value: 'summary', child: Text('汇总')),
                      ],
                      child: const Center(child: Icon(Icons.more_vert)),
                    ),
                  ),
                ],
              ),
            ),
            if (status == 'paused' || status == 'in_progress')
              Positioned(
                bottom: 0,
                right: 0,
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () => _resumePlanPaused(plan),
                    child: Text(
                      status == 'in_progress' ? '进入' : '继续',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fabBar() {
    return SizedBox(
      width: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'instant',
            onPressed: _onStartInstant,
            backgroundColor: Colors.orange,
            mini: true,
            tooltip: '立刻开始（非计划）',
            child: const Icon(Icons.play_arrow),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _onAddPlan,
            backgroundColor: Colors.green,
            tooltip: '新增计划',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SportPlanDialog extends StatefulWidget {
  final Map<String, dynamic>? existingPlan;

  const _SportPlanDialog({this.existingPlan});

  @override
  State<_SportPlanDialog> createState() => _SportPlanDialogState();
}

class _SportPlanDialogState extends State<_SportPlanDialog> {
  final SportDao _dao = SportDao();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final TextEditingController _customAdvance = TextEditingController();

  String _sportType = 'walk';
  String _repeatType = 'daily';
  int _hour = 9;
  int _minute = 0;
  int _second = 0;

  // selection for weekly/monthly/custom
  final Set<int> _weekdays = <int>{1, 2, 3, 4, 5, 6, 7};
  final Set<int> _monthdays = <int>{};
  final Set<DateTime> _customDates = <DateTime>{};

  bool _notifyEnabled = false;
  int _notifyAdvance = 2; // minutes
  bool _advanceCustomMode = false;

  String _targetUnit = '步';
  String _targetType = 'steps';

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlan;
    if (p != null) {
      _title.text = (p['title'] ?? '').toString();
      _sportType = (p['sport_type'] ?? 'walk').toString();
      _repeatType = (p['repeat_type'] ?? 'daily').toString();
      _notifyEnabled = (p['notify_enabled'] ?? 0) == 1;
      _notifyAdvance = (p['notify_advance'] is num) ? (p['notify_advance'] as num).toInt() : 2;
      _targetType = (p['target_type'] ?? 'steps').toString();
      final tv = p['target_value'];
      if (tv != null) {
        _target.text = tv.toString();
      }
      // derive unit
      if (_targetType == 'duration') {
        _targetUnit = '小时';
      } else if (_targetType == 'distance') {
        _targetUnit = 'km';
      } else {
        _targetUnit = '步';
      }

      // parse repeat_detail
      final detailStr = (p['repeat_detail'] ?? '').toString();
      try {
        if (detailStr.isNotEmpty) {
          final v = jsonDecode(detailStr);
          if (v is Map) {
            final time = v['time']?.toString();
            if (time != null && time.contains(':')) {
              final parts = time.split(':');
              if (parts.length >= 2) {
                _hour = int.tryParse(parts[0]) ?? _hour;
                _minute = int.tryParse(parts[1]) ?? _minute;
                _second = parts.length >= 3 ? (int.tryParse(parts[2]) ?? _second) : _second;
              }
            }
            if (_repeatType == 'weekly' && v['weekdays'] is List) {
              _weekdays
                ..clear()
                ..addAll(List<int>.from(v['weekdays']));
            }
            if (_repeatType == 'monthly' && v['monthdays'] is List) {
              _monthdays
                ..clear()
                ..addAll(List<int>.from(v['monthdays']));
            }
            if (_repeatType == 'custom' && v['dates'] is List) {
              _customDates.clear();
              for (final s in List<String>.from(v['dates'])) {
                final d = DateTime.tryParse(s);
                if (d != null) {
                  _customDates.add(DateTime(d.year, d.month, d.day));
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    else {
      // For new plans, default the time selection to the current time (hour/minute/second).
      final now = DateTime.now();
      _hour = now.hour;
      _minute = now.minute;
      _second = now.second;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _customAdvance.dispose();
    super.dispose();
  }

  void _onUnitChanged(String unit) {
    setState(() {
      _targetUnit = unit;
      if (unit == '小时') {
        _targetType = 'duration';
      } else if (unit == 'km') {
        _targetType = 'distance';
      } else {
        _targetType = 'steps';
      }
    });
  }

  Future<void> _pickTime() async {
    // 支持秒：使用自定义 bottom sheet
    int h = _hour, m = _minute, s = _second;
    final res = await showModalBottomSheet<List<int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheet) {
            DropdownMenuItem<int> item(int v) => DropdownMenuItem(value: v, child: Text(v.toString().padLeft(2, '0')));
            List<DropdownMenuItem<int>> items(int min, int max) => [for (int i = min; i <= max; i++) item(i)];
            Widget drop(String label, int min, int max, int value, void Function(int) onChange) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  DropdownButton<int>(
                    value: value,
                    isExpanded: true,
                    items: items(min, max),
                    onChanged: (v) {
                      if (v == null) return;
                      setSheet(() => onChange(v));
                    },
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('选择时间（时/分/秒）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: drop('时', 0, 23, h, (v) => h = v)),
                        const SizedBox(width: 8),
                        Expanded(child: drop('分', 0, 59, m, (v) => m = v)),
                        const SizedBox(width: 8),
                        Expanded(child: drop('秒', 0, 59, s, (v) => s = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('取消')),
                        ElevatedButton(onPressed: () => Navigator.of(ctx).pop([h, m, s]), child: const Text('确定')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (res != null && res.length == 3) {
      setState(() {
        _hour = res[0];
        _minute = res[1];
        _second = res[2];
      });
    }
  }

  Widget _numDrop(String label, int min, int max, int value, void Function(int) onChanged) {
    final items = <DropdownMenuItem<int>>[];
    for (int i = min; i <= max; i++) {
      items.add(DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0'))));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        DropdownButton<int>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ],
    );
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _customDates.add(DateTime(picked.year, picked.month, picked.day));
      });
    }
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消编辑'),
        content: const Text('确定取消吗？未保存的内容将丢失。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('继续编辑')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('取消')),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  String _timeStr() {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(_hour)}:${two(_minute)}:${two(_second)}';
  }

  DateTime? _computeNextTrigger(DateTime now) {
    DateTime withTime(DateTime d) => DateTime(d.year, d.month, d.day, _hour, _minute, _second);

    if (_repeatType == 'daily') {
      final today = withTime(now);
      if (today.isAfter(now)) return today;
      return withTime(now.add(const Duration(days: 1)));
    }

    if (_repeatType == 'weekly') {
      if (_weekdays.isEmpty) return null;
      for (int i = 0; i < 14; i++) {
        final d = now.add(Duration(days: i));
        final cand = withTime(d);
        if (_weekdays.contains(cand.weekday) && cand.isAfter(now)) {
          return cand;
        }
      }
      return null;
    }

    if (_repeatType == 'monthly') {
      if (_monthdays.isEmpty) return null;
      for (int i = 0; i < 62; i++) {
        final d = now.add(Duration(days: i));
        if (_monthdays.contains(d.day)) {
          final cand = withTime(d);
          if (cand.isAfter(now)) return cand;
        }
      }
      return null;
    }

    if (_repeatType == 'custom') {
      if (_customDates.isEmpty) return null;
      final list = _customDates.toList()..sort();
      for (final d in list) {
        final cand = withTime(d);
        if (cand.isAfter(now)) return cand;
      }
      return null;
    }

    return null;
  }

  Future<void> _save() async {
    // validate target
    final tRaw = _target.text.trim();
    if (tRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入目标数')));
      return;
    }
    final isInt = _targetUnit == '步';
    final value = double.tryParse(tRaw);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目标数不合法')));
      return;
    }
    if (isInt && value % 1 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('步数只支持整数')));
      return;
    }

    if (_repeatType == 'weekly' && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('每周至少选择一天')));
      return;
    }
    if (_repeatType == 'monthly' && _monthdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('每月至少选择一天')));
      return;
    }
    if (_repeatType == 'custom' && _customDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('自定义至少选择一天')));
      return;
    }

    final now = DateTime.now();
    final next = _computeNextTrigger(now);
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法计算下次执行时间')));
      return;
    }

    final detail = <String, dynamic>{'time': _timeStr()};
    if (_repeatType == 'weekly') {
      detail['weekdays'] = _weekdays.toList()..sort();
    } else if (_repeatType == 'monthly') {
      detail['monthdays'] = _monthdays.toList()..sort();
    } else if (_repeatType == 'custom') {
      final dates = _customDates.toList()..sort();
      detail['dates'] = dates.map((d) => DateTime(d.year, d.month, d.day).toIso8601String().substring(0, 10)).toList();
    }

    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'sport_type': _sportType,
      'target_type': _targetType,
      'target_value': isInt ? value.toInt() : double.parse(value.toStringAsFixed(1)),
      'target_unit': _targetUnit,
      'repeat_type': _repeatType,
      'repeat_detail': jsonEncode(detail),
      'plan_time': next.toIso8601String(),
      'notify_enabled': _notifyEnabled ? 1 : 0,
      'notify_advance': _notifyEnabled ? _notifyAdvance : 0,
      'status': 'not_started',
    };

    int planId;
    if (widget.existingPlan != null && widget.existingPlan!['id'] != null) {
      planId = widget.existingPlan!['id'] as int;
      await _dao.updatePlan(planId, data);
    } else {
      planId = await _dao.insertPlan(data);
    }

    // schedule alarms
    final planTimeEpoch = next.millisecondsSinceEpoch;
    final fullScreenId = 1600000000 + planId;
    final reminderId = 1700000000 + planId;

    try {
      await NativeScheduler.cancel(fullScreenId);
      await NativeScheduler.cancel(reminderId);
    } catch (_) {}

    // Countdown changed to 5s: trigger full-screen 5 seconds before the plan time.
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
    final fullEpoch = (planTimeEpoch - 5 * 1000);
    final safeFullEpoch = fullEpoch > nowEpoch + 500 ? fullEpoch : (nowEpoch + 500);
    await NativeScheduler.scheduleExactAt(
      id: fullScreenId,
      epochMs: safeFullEpoch,
      payload: {
        'type': 'sport_fullscreen',
        'planId': planId,
        'planTime': next.toIso8601String(),
      },
    );

    if (_notifyEnabled && _notifyAdvance > 0) {
      final remEpoch = planTimeEpoch - _notifyAdvance * 60 * 1000;
      if (remEpoch > DateTime.now().millisecondsSinceEpoch) {
        await NativeScheduler.scheduleExactAt(
          id: reminderId,
          epochMs: remEpoch,
          payload: {
            'type': 'sport_reminder',
            'planId': planId,
            'planTime': next.toIso8601String(),
          },
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _onSportTypeChanged(String value) {
    // 仅支持步行；跑步/健身灰色不可选
    if (value != 'walk') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('跑步/健身暂未开放')));
      return;
    }
    setState(() => _sportType = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPlan != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑计划' : '新增计划'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sportType,
                decoration: const InputDecoration(labelText: '运动类型'),
                items: const [
                  DropdownMenuItem(value: 'walk', child: Text('步行')),
                  DropdownMenuItem(value: 'run', child: Text('跑步（待开放）')),
                  DropdownMenuItem(value: 'gym', child: Text('健身（待开放）')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _onSportTypeChanged(v);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _target,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '目标数'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      value: _targetUnit,
                      decoration: const InputDecoration(labelText: '单位'),
                      items: const [
                        DropdownMenuItem(value: '步', child: Text('步')),
                        DropdownMenuItem(value: '小时', child: Text('小时')),
                        DropdownMenuItem(value: 'km', child: Text('km')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        _onUnitChanged(v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _repeatType,
                decoration: const InputDecoration(labelText: '计划时间'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('每天')),
                  DropdownMenuItem(value: 'weekly', child: Text('每周')),
                  DropdownMenuItem(value: 'monthly', child: Text('每月')),
                  DropdownMenuItem(value: 'custom', child: Text('自定义')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _repeatType = v);
                },
              ),
              const SizedBox(height: 10),
              _repeatSelector(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text('具体时间：${_timeStr()}')),
                  OutlinedButton(onPressed: _pickTime, child: const Text('选择')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('通知提醒')),
                  Switch(
                    value: _notifyEnabled,
                    onChanged: (v) {
                      setState(() => _notifyEnabled = v);
                    },
                  ),
                ],
              ),
              if (_notifyEnabled) ...[
                Row(
                  children: [
                    const Text('提前'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _advanceCustomMode ? -1 : _notifyAdvance,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('2 分钟')),
                          DropdownMenuItem(value: 4, child: Text('4 分钟')),
                          DropdownMenuItem(value: 6, child: Text('6 分钟')),
                          DropdownMenuItem(value: 8, child: Text('8 分钟')),
                          DropdownMenuItem(value: -1, child: Text('自定义')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          if (v == -1) {
                            setState(() => _advanceCustomMode = true);
                          } else {
                            setState(() {
                              _advanceCustomMode = false;
                              _notifyAdvance = v;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_advanceCustomMode)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customAdvance,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '自定义分钟（整数）'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          final v = int.tryParse(_customAdvance.text.trim());
                          if (v == null || v <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入正整数分钟')));
                            return;
                          }
                          setState(() {
                            _notifyAdvance = v;
                            _advanceCustomMode = false;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _advanceCustomMode = false;
                          });
                        },
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      actions: [
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(onPressed: _save, child: const Text('保存')),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _confirmCancel, child: const Text('取消')),
        ),
      ],
    );
  }

  Widget _repeatSelector() {
    if (_repeatType == 'weekly') {
      return _weekdaySelector();
    }
    if (_repeatType == 'monthly') {
      return _monthdaySelector();
    }
    if (_repeatType == 'custom') {
      return _customDateSelector();
    }
    return const SizedBox.shrink();
  }

  Widget _weekdaySelector() {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('每周：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _weekdays
                    ..clear()
                    ..addAll([1, 2, 3, 4, 5, 6, 7]);
                });
              },
              child: const Text('全选'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: List.generate(7, (i) {
            final day = i + 1;
            return FilterChip(
              label: Text('周${names[i]}'),
              selected: _weekdays.contains(day),
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _weekdays.add(day);
                  } else {
                    _weekdays.remove(day);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _monthdaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('每月：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _monthdays
                    ..clear()
                    ..addAll(List<int>.generate(31, (i) => i + 1));
                });
              },
              child: const Text('全选'),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: List.generate(31, (i) {
            final d = i + 1;
            return FilterChip(
              label: Text(d.toString()),
              selected: _monthdays.contains(d),
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _monthdays.add(d);
                  } else {
                    _monthdays.remove(d);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _customDateSelector() {
    final dates = _customDates.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('自定义日期：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: _pickCustomDate, icon: const Icon(Icons.add), label: const Text('添加')),
          ],
        ),
        const SizedBox(height: 6),
        if (dates.isEmpty)
          const Text('尚未选择日期', style: TextStyle(color: Colors.black54))
        else
          Wrap(
            spacing: 8,
            children: dates.map((d) {
              final s = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              return Chip(
                label: Text(s),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () {
                  setState(() {
                    _customDates.remove(d);
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
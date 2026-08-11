import 'dart:ui' as ui;

import '../data/dao.dart';
import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import '../services/notification_service.dart';
import '../platform/native_notify.dart';
import '../services/native_guard.dart';
import '../xiangji_goal_mentor/xiangji_dao.dart';

class TaskRunner {
  static void _notifyHomeRefresh(){
    try{ final sp = ui.IsolateNameServer.lookupPortByName('HOME_REFRESH_PORT'); sp?.send('tick'); }catch(_){ }
    try{ SimpleBus.pokeHome(); }catch(_){ }
  }

  /// Run task by uid. This is the unified runner used by WM/AM.
  static Future<void> run(String uid) async {
    final task = await TaskDao().getByUid(uid);
    if (task == null) return;
    final status = (task['status'] ?? 'on').toString();
    if (status != 'on') return; // 2.1.2 关闭状态直接退出

    final type = (task['type'] ?? 'manual').toString(); // manual | auto | carousel | vision_focus | xiangji_goal

    if (type == 'auto') {
      await _runAuto(task);
    } else if (type == 'manual') {
      await _runManual(task);
    } else if (type == 'carousel') {
      await _runCarousel(task);
    } else if (type == 'vision_focus') {
      await _runVisionFocus(task);
    } else if (type == 'xiangji_goal') {
      await _runXiangjiGoal(task);
    } else {
      await LogDao().add(taskUid: uid, detail: '错误! 未知任务类型: '+type);
    }
  }

  static Future<void> _runAuto(Map<String,dynamic> t) async {
    final uid = t['task_uid'].toString();
    final prompt = (t['prompt'] ?? '').toString();
    final ai = UnifiedAiService();
    final aiState = await GlobalAiSettings().getState();

    int failCount = 0;
    while (true) {
      try {
        final quote = await ai.generateText(
          prompt: prompt,
          purpose: 'task_runner.quote_generation',
          systemPrompt: '你是一位擅长输出简短、积极、鼓舞人心的名人名言的助手。请只输出中文名人名言正文，不要多余解释。',
          maxTokens: 300,
          expectJson: false,
          forcedProvider: aiState['provider'],
          forcedModel: aiState['model'],
          temperature: 0.6,
        );
        if (quote.trim().isEmpty) {
          throw Exception('统一 AI 返回空内容');
        }
        // Dedup
        final unique = await QuoteDao().isUnique(quote, threshold: 0.90);
        if (!unique) {
          failCount++;
          if (failCount >= 10) {
            await LogDao().add(taskUid: uid, detail: '错误! 连续调用api10次去重检验未通过！');
            return;
          }
          continue; // retry
        }
        // Insert + log
        final qUid = await QuoteDao().insertQuote(taskUid: uid, content: quote);
        await LogDao().add(taskUid: uid, detail: '成功!');

        // Send notification
        final title = (t['name'] ?? '提醒').toString();
        final avatar = (t['avatar_path'] ?? '').toString();
        try {
          var sent = await NativeNotify.show(id: 1001, title: title, body: quote, largeIconPath: avatar.isEmpty ? null : avatar);
          if (!sent) { await NotificationService.show(title: title, body: quote, largeIconPath: avatar.isEmpty ? null : avatar); }
        } catch (e) {
          // rethrow to allow upstream to handle failure
          throw e;
        }

        // Update notified
        await QuoteDao().markNotifiedByUid(qUid);
        _notifyHomeRefresh();
        return;
      } catch (e) {
        if (e.toString().contains('统一 AI') || e.toString().contains('OPENAI_FAIL') || e.toString().contains('OpenAI API 调用失败')) {
          await LogDao().add(taskUid: uid, detail: '调用统一 AI 接口发生错误或失败!');
          throw Exception('OPENAI_FAIL');
        } else {
          // Treat as dedup or transient
          failCount++;
          if (failCount >= 10) {
            await LogDao().add(taskUid: uid, detail: '错误! 连续调用api10次去重检验未通过！');
            return;
          }
        }
      }
    }
  }

  static Future<void> _runManual(Map<String,dynamic> t) async {
    final uid = t['task_uid'].toString();
    // Latest quote for task
    final q = await QuoteDao().latestForTask(uid);
    final content = (q?['content'] ?? '').toString();
    if (content.trim().isEmpty) {
      await LogDao().add(taskUid: uid, detail: '错误! 手动任务未找到名人名言内容');
      return;
    }
    final title = (t['name'] ?? '提醒').toString();
    final avatar = (t['avatar_path'] ?? '').toString();
    try {
      var sent = await NativeNotify.show(id: 1002, title: title, body: content, largeIconPath: avatar.isEmpty ? null : avatar);
      if (!sent) { await NotificationService.show(title: title, body: content, largeIconPath: avatar.isEmpty ? null : avatar); }
    } catch (e) {
      throw e;
    }
    if (q?['quote_uid'] != null) {
      await QuoteDao().markNotifiedByUid(q!['quote_uid'].toString());
    }
    // 成功发送后记录日志
    await LogDao().add(taskUid: uid, detail: '成功!');
  }

  static Future<void> _runCarousel(Map<String,dynamic> t) async {
    final uid = t['task_uid'].toString();
    final row = await QuoteDao().carouselNextSequential(uid);
    if (row == null) {
      await LogDao().add(taskUid: uid, detail: '错误! 轮播任务无名人名言数据');
      return;
    }
    final content = (row['content'] ?? '').toString();
    final title = (t['name'] ?? '提醒').toString();
    final avatar = (t['avatar_path'] ?? '').toString();
    try {
      var sent = await NativeNotify.show(id: 1002, title: title, body: content, largeIconPath: avatar.isEmpty ? null : avatar);
      if (!sent) { await NotificationService.show(title: title, body: content, largeIconPath: avatar.isEmpty ? null : avatar); }
    } catch (e) {
      throw e;
    }
    if (row['quote_uid'] != null) {
      await QuoteDao().markNotifiedByUid(row['quote_uid'].toString());
    _notifyHomeRefresh();
    }
    // 成功发送后记录日志
    await LogDao().add(taskUid: uid, detail: '成功!');
  }

  /// Run a vision focus task: fetch the current vision goal and send a
  /// notification reminding the user to focus on their core goal.
  static Future<void> _runVisionFocus(Map<String, dynamic> t) async {
    final uid = t['task_uid']?.toString() ?? '';
    try {
      // Load the vision goal; it may be null if not configured
      final dao = VisionDao();
      final goal = await dao.loadGoal();
      final title = (goal?['title'] ?? '').toString().trim();
      String body;
      if (title.isNotEmpty) {
        body = '别忘了你的愿景：$title';
      } else {
        body = '是时候开始你的专注时刻了。';
      }
      // Determine notification title; fall back to a generic label
      String notifTitle;
      final rawName = (t['name'] ?? '').toString().trim();
      if (rawName.isNotEmpty) {
        notifTitle = rawName;
      } else {
        notifTitle = '愿景提醒';
      }
      // Send the notification
      try {
        int nid;
        if (uid.isNotEmpty) {
          nid = uid.hashCode & 0x7fffffff;
        } else {
          nid = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        }
        await NotificationService.show(id: nid, title: notifTitle, body: body, payload: 'vision_focus');
      } catch (e) {
        // Propagate to outer catch so that SchedulerService can handle failure
        throw e;
      }
      // Log success
      try {
        await LogDao().add(taskUid: uid, detail: '成功! 已发送愿景提醒');
      } catch (_) {}
    } catch (e) {
      // Log failure and propagate
      try {
        await LogDao().add(taskUid: uid, detail: '错误! 愿景提醒发送失败: '+e.toString());
      } catch (_) {}
      throw e;
    }
  }

  /// Send one gentle goal-protection reminder. The copy is assembled from the
  /// user's active goal, current step, or latest confirmed growth evidence;
  /// it never contains streak loss, ranking, or comparison language.
  static Future<void> _runXiangjiGoal(Map<String, dynamic> task) async {
    final uid = (task['task_uid'] ?? '').toString();
    final dao = XiangjiGoalMentorDao();
    try {
      final reminder = await dao.claimScheduledReminder();
      if (reminder == null || reminder.body.trim().isEmpty) {
        try {
          await LogDao().add(
            taskUid: uid,
            detail: '跳过：当前无需发送或今日已发送向己目标守护提醒',
          );
        } catch (_) {}
        return;
      }
      try {
        await NotificationService.show(
          id: uid.hashCode & 0x7fffffff,
          title: '向己 · 记得你重视的方向',
          body: reminder.body,
          payload: 'xiangji_goal',
        );
      } catch (error) {
        try {
          await dao.markScheduledReminderFailed(reminder.deliveryKey, error);
        } catch (_) {}
        rethrow;
      }
      // Mark immediately after notification delivery. A later logging failure
      // must never make the scheduler send the same reminder again.
      await dao.markScheduledReminderDelivered(reminder.deliveryKey);
      try {
        await LogDao().add(
          taskUid: uid,
          detail: '成功! 已发送向己目标守护提醒（${reminder.contentType}）',
        );
      } catch (_) {}
    } catch (error) {
      try {
        await LogDao().add(
          taskUid: uid,
          detail: '错误! 向己目标守护提醒发送失败: $error',
        );
      } catch (_) {}
      rethrow;
    }
  }
}

import 'dart:ui' as ui;

import '../data/dao.dart';
import '../data/quote_insight_store.dart';
import '../models/quote_insight.dart';
import '../services/notification_service.dart';
import '../services/quote_ai_service.dart';
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
    final config = QuoteAiTaskConfig.fromTask(t);
    if (!config.autoEnabled) {
      await LogDao().add(taskUid: uid, detail: '跳过：AI 自动获取开关已关闭');
      return;
    }

    try {
      // One scheduled run performs exactly one structured AI request. We no
      // longer send local quote history or repeatedly call the model for local
      // similarity checks; variation is driven by a compact rotation cursor.
      final generated = await QuoteAiService().generate(t);
      String? quoteUid;
      if (config.saveLocally) {
        final now = DateTime.now();
        String two(int value) => value.toString().padLeft(2, '0');
        final insertedAt = '${now.year}-${two(now.month)}-${two(now.day)} '
            '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
        quoteUid = await QuoteDao().insertQuote(
          taskUid: uid,
          content: generated.content,
          theme: generated.theme,
          authorName: generated.author,
          sourceFrom: generated.source,
          explanation: generated.explanation,
          avatarPath: generated.avatarPath,
          taskName: (t['name'] ?? '').toString(),
          taskType: 'auto',
          insertedAt: insertedAt,
        );
        // Optional annotations must never turn a successful original save into
        // a failed scheduled run. The quote remains readable if this fails.
        try {
          await QuoteInsightStore().saveAddon(
            QuoteReference(id: quoteUid, content: generated.content,
              author: generated.author, source: generated.source),
            generated.readingAddon,
          );
        } catch (_) {}
      }

      // A monotonically increasing cursor gives deterministic ordered cycling
      // for multiple people and also supplies a tiny variation seed for a
      // single person, without transmitting previous quotes to the model.
      await TaskDao().update(uid, <String, dynamic>{'cursor': generated.nextCursor});

      final taskTitle = (t['name'] ?? 'AI 名人名言').toString().trim();
      final title = generated.author.isEmpty
          ? (taskTitle.isEmpty ? 'AI 名人名言' : taskTitle)
          : '${taskTitle.isEmpty ? 'AI 名人名言' : taskTitle} · ${generated.author}';
      final taskAvatar = (t['avatar_path'] ?? '').toString().trim();
      final avatar = generated.avatarPath.trim().isNotEmpty ? generated.avatarPath.trim() : taskAvatar;
      var sent = await NativeNotify.show(
        id: 1001,
        title: title,
        body: generated.content,
        largeIconPath: avatar.isEmpty ? null : avatar,
      );
      if (!sent) {
        await NotificationService.show(
          title: title,
          body: generated.content,
          largeIconPath: avatar.isEmpty ? null : avatar,
        );
      }

      if (quoteUid != null) await QuoteDao().markNotifiedByUid(quoteUid);
      await LogDao().add(
        taskUid: uid,
        detail: '成功! AI 已获取${generated.author.isEmpty ? '' : ' ${generated.author}'}名言'
            '${config.saveLocally ? '并保存到本地' : ''}',
      );
      _notifyHomeRefresh();
    } catch (error) {
      await LogDao().add(taskUid: uid, detail: '错误! AI 名人名言获取失败: $error');
      rethrow;
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

  /// Send one gentle goal-protection reminder. Reminder claiming is idempotent
  /// per local day and paused/reselecting goals are suppressed by the DAO.
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

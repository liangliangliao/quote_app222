package com.example.quote_app.biz;

import android.content.Context;
import android.text.TextUtils;

import com.example.quote_app.NotifyHelper;
import com.example.quote_app.data.DbRepository;
import com.example.quote_app.data.DbRepository.Task;

import java.util.List;

public final class Biz {
    private Biz() {}

    /** 主入口：根据任务类型执行并发送通知；返回是否已处理 */
    public static boolean run(Context ctx, String uid) {
        Task t = DbRepository.getTaskByUid(ctx, uid);
        if (t == null || !t.enabled) {
            DbRepository.log(ctx, uid, "任务关闭或不存在，跳过");
            return false;
        }
        String typeRaw = t.type == null ? "MANUAL" : t.type.trim();
        String type;
        if ("AUTO".equalsIgnoreCase(typeRaw) || "自动任务".equals(typeRaw) || "批量导入任务".equals(typeRaw)) type = "AUTO";
        else if ("CAROUSEL".equalsIgnoreCase(typeRaw) || "轮播".equals(typeRaw) || "轮播任务".equals(typeRaw)) type = "CAROUSEL";
        else if ("MANUAL".equalsIgnoreCase(typeRaw) || "手动任务".equals(typeRaw) || "手动".equals(typeRaw)) type = "MANUAL";
        else type = typeRaw.toUpperCase();
        /*TYPE_MAP_INSERTED*/
        switch (type) {
            case "AUTO":
                return autoTask(ctx, t);
            case "CAROUSEL":
                return carouselTask(ctx, t);
            case "VISION_FOCUS":
                // Handle vision_focus tasks (daily vision reminders)
                return visionFocusTask(ctx, t);
            default:
                return manualTask(ctx, t);
        }
    }

    private static boolean manualTask(Context ctx, Task t) {
        // 优先从名人名言表取一条（降序），以便标题使用主题(theme)
        String pickedTitle = null, pickedContent = null, pickedAvatar = null;
        try {
            String[] pick = DbRepository.selectQuoteForNotify(ctx, t.uid);
            if (pick != null) { pickedTitle = pick[0]; pickedContent = pick[1]; pickedAvatar = pick[2]; }
        } catch (Throwable ignore) {}
        /*MANUAL_TITLE_FROM_THEME*/
        // For manual tasks the quote text is stored in the quotes table rather than directly in Task.content.
        // If the task content is empty, fetch the latest quote for this task from the database.
        String content = t.content;
        if (content == null || content.trim().isEmpty()) { content = pickedContent; }
        try {
            if (content == null || content.trim().isEmpty()) {
                java.util.List<String> quotes = DbRepository.listQuoteTextsForTask(ctx, t.uid, 1);
                if (quotes != null && !quotes.isEmpty()) {
                    content = quotes.get(0);
                }
            }
        } catch (Throwable ignore) {
            // ignore any DB errors and fall back to original content
        }
        if (content == null || content.trim().isEmpty()) {
            DbRepository.log(ctx, t.uid, "手动任务无名人名言内容");
            return false;
        }
        String title = !TextUtils.isEmpty(pickedTitle) ? pickedTitle : (!TextUtils.isEmpty(t.title) ? t.title : "提醒");
        int id = t.uid != null ? t.uid.hashCode() : 10001;
        try {
            String avatarPath = (pickedAvatar != null && !pickedAvatar.isEmpty()) ? pickedAvatar : t.avatarPath;
            NotifyHelper.send(ctx.getApplicationContext(), id, title, content, avatarPath);
            DbRepository.log(ctx, t.uid, "成功!");
            return true;
        } catch (Throwable e) {
            DbRepository.log(ctx, t.uid, "发送失败: " + e.getMessage());
            return false;
        }
    }

        private static boolean carouselTask(Context ctx, Task t) {
        // 按任务类型与游标选择一条名人名言；若越界等错误，方法内已写中文日志，这里直接失败返回
        String[] pick = DbRepository.selectQuoteForNotify(ctx, t.uid);
        if (pick == null) return false;
        String pickedTitle = pick[0];
        String pickedContent = pick[1];
        String pickedAvatar = pick[2];
        String content = !TextUtils.isEmpty(pickedContent) ? pickedContent : t.content;
        String title = !TextUtils.isEmpty(pickedTitle) ? pickedTitle : (!TextUtils.isEmpty(t.title) ? t.title : "提醒");
        t.avatarPath = (pickedAvatar != null ? pickedAvatar : t.avatarPath);
        int id = t.uid != null ? t.uid.hashCode() : 10003;
        try {
            // 保持原有调用签名，避免工具链对参数名串的误处理
            String avatarPath = (pickedAvatar != null && !pickedAvatar.isEmpty()) ? pickedAvatar : t.avatarPath;
            NotifyHelper.send(ctx.getApplicationContext(), id, title, content, avatarPath);
            DbRepository.log(ctx, t.uid, "成功!");
            return true;
        } catch (Throwable e) {
            DbRepository.log(ctx, t.uid, "发送失败: " + e.getMessage());
            return false;
        }
    }


        private static boolean autoTask(Context ctx, Task t) {
        // 按任务类型与游标选择一条名人名言；若越界等错误，方法内已写中文日志，这里直接失败返回
        String[] pick = DbRepository.selectQuoteForNotify(ctx, t.uid);
        if (pick == null) return false;
        String pickedTitle = pick[0];
        String pickedContent = pick[1];
        String pickedAvatar = pick[2];
        String content = !TextUtils.isEmpty(pickedContent) ? pickedContent : t.content;
        String title = !TextUtils.isEmpty(pickedTitle) ? pickedTitle : (!TextUtils.isEmpty(t.title) ? t.title : "提醒");
        t.avatarPath = (pickedAvatar != null ? pickedAvatar : t.avatarPath);
        int id = t.uid != null ? t.uid.hashCode() : 10002;
        try {
            // 保持原有调用签名，避免工具链对参数名串的误处理
            String avatarPath = (pickedAvatar != null && !pickedAvatar.isEmpty()) ? pickedAvatar : t.avatarPath;
            NotifyHelper.send(ctx.getApplicationContext(), id, title, content, avatarPath);
            DbRepository.log(ctx, t.uid, "成功!");
            return true;
        } catch (Throwable e) {
            DbRepository.log(ctx, t.uid, "发送失败: " + e.getMessage());
            return false;
        }
    }

    /**
     * Handle vision focus tasks. These tasks are generated from daily time-based vision triggers.
     * They do not pick quotes; instead they send a gentle reminder to focus on the user's vision goal.
     */
    private static boolean visionFocusTask(Context ctx, Task t) {
        // Body: use task content if provided, else fall back to a generic reminder.
        String body = (t.content != null && !t.content.trim().isEmpty()) ? t.content.trim() : "别忘了你的一件事！";
        // Title: use the task's title if provided, otherwise fall back to a generic reminder.
        String title;
        if (t.title != null && !t.title.trim().isEmpty()) {
            title = t.title.trim();
        } else {
            title = "愿景提醒";
        }
        int id = (t.uid != null ? t.uid.hashCode() : 10004);
        try {
            // Pass notifType so that tapping the notification opens the VisionFocusPreparePage in Flutter.
            NotifyHelper.send(ctx.getApplicationContext(), id, title, body, null, "vision_focus", null);
            DbRepository.log(ctx, t.uid, "成功!");
            return true;
        } catch (Throwable e) {
            DbRepository.log(ctx, t.uid, "发送失败: " + e.getMessage());
            return false;
        }
    }

}

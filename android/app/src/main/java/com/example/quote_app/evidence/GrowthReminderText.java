package com.example.quote_app.evidence;

/** Shared presentation contract for native delivery, including recovered outbox rows. */
public final class GrowthReminderText {
    public final String node, title, body, actionLabel;
    private GrowthReminderText(String node, String title, String body, String actionLabel) {
        this.node=node; this.title=title; this.body=body; this.actionLabel=actionLabel;
    }
    public static String nodeFor(String kind) {
        switch(kind) {
            case "trial_start": case "recovery_end": return "ACTION";
            case "trial_review_due": case "missing_result": return "OUTCOME";
            case "journey_review": return "REVIEW";
            case "repeated_avoidance": return "CHANGE";
            case "journey_maintenance": return "MAINTENANCE_GATE";
            default: return "GOAL";
        }
    }
    public static String nodeLabel(String node) {
        switch(node) {
            case "BELIEF": return "信念";
            case "GOAL": case "GOAL_GATE": return "目标核验";
            case "ACTION": return "行动";
            case "OUTCOME": return "结果";
            case "REVIEW": return "复盘";
            case "CHANGE": case "BELIEF_CHECKPOINT": return "改变";
            case "MAINTENANCE_GATE": return "保持检查";
            default: return "目标";
        }
    }
    private static String shortText(String text, int max) {
        String s=text == null ? "" : text.replaceAll("\\s+", " ").trim();
        return s.length()<=max?s:s.substring(0,max)+"…";
    }
    public static GrowthReminderText build(String kind, String goal, String action, String prediction,
                                           String when, String maintenanceBand, boolean sensitive) {
        String node=nodeFor(kind), task, cta;
        switch(kind) {
            case "trial_start": task="开始时间已到";cta="查看并开始";break;
            case "recovery_end": task="恢复窗口已到，请核对当前状态";cta="核对恢复";break;
            case "trial_review_due": task="观察窗口已到，请记录实际结果";cta="记录结果";break;
            case "missing_result": task="尚未收到现实反馈，请补充记录";cta="补充反馈";break;
            case "journey_review": task="到了你约定的检查时间，可复盘或继续暂缓";cta="选择复盘时机";break;
            case "repeated_avoidance": task="同一知识节点连续三轮退出，回看条件与下一步";cta="查看本轮记录";break;
            case "journey_maintenance": task="检查是否仍在保持区间，记录稳定或偏离";cta="记录保持状态";break;
            default: task="有一项待核对事项";cta="查看记录";
        }
        String safeGoal=sensitive?"私密目标":shortText(goal,36);
        if(safeGoal.isEmpty())safeGoal="当前目标";
        StringBuilder body=new StringBuilder(safeGoal).append(" · ").append(task);
        if(!sensitive) {
            if(kind.equals("trial_start")&&!shortText(action,80).isEmpty())body.append("\n动作：").append(shortText(action,80));
            if((kind.equals("trial_review_due")||kind.equals("missing_result"))&&!shortText(prediction,64).isEmpty())body.append("\n原预测：").append(shortText(prediction,64));
            if(kind.equals("journey_maintenance")&&!shortText(maintenanceBand,64).isEmpty())body.append("\n保持区间：").append(shortText(maintenanceBand,64));
        }
        if(!shortText(when,24).isEmpty())body.append("\n约定时间：").append(shortText(when,24));
        return new GrowthReminderText(node,"证据成长｜"+nodeLabel(node)+"节点",body.toString(),cta);
    }
}

import com.example.quote_app.evidence.GrowthReminderText;
public class GrowthReminderTextTest {
    static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args){
        String[] kinds={"trial_start","recovery_end","trial_review_due","missing_result","journey_review","repeated_avoidance","journey_maintenance"};
        String[] nodes={"ACTION","ACTION","OUTCOME","OUTCOME","REVIEW","CHANGE","MAINTENANCE_GATE"};
        for(int i=0;i<kinds.length;i++){
            GrowthReminderText v=GrowthReminderText.build(kinds[i],"作品草稿","整理一段","获得一条反馈","09-20 18:30","每周两次",false);
            check(v.node.equals(nodes[i]),"wrong node "+kinds[i]);check(v.title.startsWith("证据成长｜"),"module absent");
            check(v.body.contains("作品草稿")&&v.body.contains("09-20 18:30"),"context absent");check(!v.actionLabel.isEmpty(),"CTA absent");
            GrowthReminderText p=GrowthReminderText.build(kinds[i],"敏感目标内容","秘密动作","秘密预测","09-20 18:30","秘密区间",true);
            check(!p.body.contains("秘密")&&!p.body.contains("敏感目标内容"),"private content leaked");check(p.title.contains(GrowthReminderText.nodeLabel(nodes[i])),"private notification lost node");
        }
        check(GrowthReminderText.build("trial_start","目标","整理一段","预测","时间","",false).body.contains("整理一段"),"action missing");
        check(GrowthReminderText.build("missing_result","目标","动作","具体原预测","时间","",false).body.contains("具体原预测"),"prediction missing");
        check(GrowthReminderText.build("journey_maintenance","目标","","","时间","每周两次",false).body.contains("每周两次"),"band missing");
        System.out.println("7 notification kinds, private presentation and actionable context verified");
    }
}

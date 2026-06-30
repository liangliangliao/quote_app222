import 'boundary_action_coach_catalog.dart';

/// Defines how the ten product modules pass data to one another.
///
/// The product is not a set of isolated cards: every module consumes previous
/// outputs and produces the next input in the boundary action loop.
class BoundaryLinkedStep {
  const BoundaryLinkedStep({
    required this.moduleTitle,
    required this.consumes,
    required this.runsSubFunctions,
    required this.produces,
    required this.feedsInto,
  });

  final String moduleTitle;
  final List<String> consumes;
  final List<String> runsSubFunctions;
  final List<String> produces;
  final List<String> feedsInto;
}

class BoundaryActionCoachOrchestrator {
  static List<BoundaryLinkedStep> linkedSteps() {
    final modules = BoundaryActionCoachCatalog.modules;
    return <BoundaryLinkedStep>[
      BoundaryLinkedStep(
        moduleTitle: modules[0].title,
        consumes: const ['Boundary Case 原始输入', '每日怨气记录', '罪疚感/怨气/能量分数'],
        runsSubFunctions: modules[0].subFeatures,
        produces: const ['边界健康画像', '关系雷达', '怨气警报', '风险分型'],
        feedsInto: <String>[modules[1].title, modules[8].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[1].title,
        consumes: const ['边界健康画像', 'Boundary Case', 'Relationship Profile'],
        runsSubFunctions: modules[1].subFeatures,
        produces: const ['Responsibility Map', 'burdens / loads 判断', '后果错位检测'],
        feedsInto: <String>[modules[2].title, modules[4].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[2].title,
        consumes: const ['Boundary Case', 'Responsibility Map', '场景类型', '安全风险'],
        runsSubFunctions: modules[2].subFeatures,
        produces: const ['场景摘要', '核心价值', '建议边界', '阻力预测', '行动计划草案'],
        feedsInto: <String>[modules[3].title, modules[4].title, modules[5].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[3].title,
        consumes: const ['建议边界', '场景类型', '对方可能反应', '语气目标'],
        runsSubFunctions: modules[3].subFeatures,
        produces: const ['Boundary Script：温柔版/简短版/重复版/高冲突版/职场版/家庭版', '话术检查结果'],
        feedsInto: <String>[modules[4].title, modules[5].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[4].title,
        consumes: const ['Responsibility Map', 'Boundary Script', '后果错位检测', '安全风险'],
        runsSubFunctions: modules[4].subFeatures,
        produces: const ['自然后果', '非惩罚检查', '执行难度', '分阶段执行方案'],
        feedsInto: <String>[modules[5].title, modules[6].title, modules[8].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[5].title,
        consumes: const ['Boundary Script', '对方可能反应', '执行难度', '用户罪疚触发点'],
        runsSubFunctions: modules[5].subFeatures,
        produces: const ['角色扮演回合', '回应评分', '改写建议', '下一轮练习'],
        feedsInto: <String>[modules[6].title, modules[8].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[6].title,
        consumes: const ['执行难度', '安全风险', '角色扮演评分', '用户支持缺口'],
        runsSubFunctions: modules[6].subFeatures,
        produces: const ['行动前支持提醒', '行动后复盘安排', '孤立风险提醒', '安全联系人提示'],
        feedsInto: <String>[modules[4].title, modules[8].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[7].title,
        consumes: const ['Boundary Case 中的自我失控领域', '时间/金钱/身体/语言/欲望记录'],
        runsSubFunctions: modules[7].subFeatures,
        produces: const ['时间限制', '金钱限制', '身体照顾限制', '语言修复', '成瘾风险提醒'],
        feedsInto: <String>[modules[8].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[8].title,
        consumes: const ['行动执行结果', '罪疚变化', '怨气变化', '是否尊重他人边界', '支持系统使用情况'],
        runsSubFunctions: modules[8].subFeatures,
        produces: const ['当前成长阶段', '本周小不', '本周自由的是', '复盘报告', '价值驱动目标'],
        feedsInto: <String>[modules[0].title, modules[9].title],
      ),
      BoundaryLinkedStep(
        moduleTitle: modules[9].title,
        consumes: const ['当前成长阶段', '场景类型', '用户薄弱概念', '复盘报告'],
        runsSubFunctions: modules[9].subFeatures,
        produces: const ['学习主题推荐', '抽象案例卡', '行动化练习', '下次复盘问题'],
        feedsInto: <String>[modules[0].title, modules[2].title],
      ),
    ];
  }
}

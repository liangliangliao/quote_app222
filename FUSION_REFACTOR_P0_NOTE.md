# 三系统融合 P0 落地说明

本次在 `quote_app333_action_engine_refactor.zip` 基础上，真实落地了三系统融合的 P0 四项：

1. **首页统一入口强化**
   - 概念行动引擎为主入口
   - 训练舱模式、世界成长反馈为次入口

2. **行动执行页触发训练舱预演**
   - `ActionStep` 新增 `importance` 与 `linkedCabinType`
   - 关键步骤会显示“进入训练舱预演”按钮

3. **训练舱结果返回行动链**
   - 训练舱完成后，固化层支持“返回行动链继续执行”
   - 会把推荐语气、推荐动作、推荐表达带回执行页

4. **行动结果回写世界层**
   - 行动执行完成后会更新世界 XP / 连胜 / 区域稳定度 / 解锁状态
   - 反馈页新增“世界成长反馈”区块

## 本次关键源码改动
- `lib/concept_engine/action_engine/models/action_engine_models.dart`
- `lib/concept_engine/action_engine/repository/action_engine_repository.dart`
- `lib/concept_engine/action_engine/pages/action_execution_page.dart`
- `lib/concept_engine/action_engine/pages/action_feedback_page.dart`
- `lib/concept_engine/cabins/training_cabin_models.dart`
- `lib/concept_engine/cabins/training_intro_page.dart`
- `lib/concept_engine/cabins/training_prep_page.dart`
- `lib/concept_engine/cabins/training_consolidation_page.dart`
- `lib/concept_engine/concept_engine_dao.dart`
- `lib/concept_engine/concept_engine_home_page.dart`
- `lib/concept_engine/action_engine/pages/action_engine_home_page.dart`

## 说明
本次没有推翻你当前已有的训练舱与虚拟世界，而是按融合架构把它们嵌回行动主线：
- 行动引擎负责“今天做什么”
- 训练舱负责“关键动作先预演”
- 虚拟世界负责“长期成长反馈”

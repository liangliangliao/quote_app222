# To Do 目标价值系统 V57：问题解决树决策支持升级

本次针对“外部数据同步 → Microsoft To Do → 目标价值系统”的 AI 生成问题树进行了深化改造，重点避免 AI 直接替用户做选择，改为提供严谨的问题解决过程、判断依据和多路径参考。

## 核心变化

1. **AI 角色从“给答案”改为“决策支持”**
   - 系统提示词强调：AI 不是替用户做决定的权威，而是帮助用户看见事实、假设、未知条件、可选路径、代价、风险与参考案例。
   - 所有建议必须写成“可验证的候选判断”，最终选择权交还用户。

2. **问题解决树更严格按照现实问题求解过程展开**
   - 继续要求：问题定义、已知事实、关键假设、根因候选、方案比较、证据计划、成功指标、停止条件、用户选择引导。
   - 问题树节点继续区分 goal_state / sub_problem / action，并要求每个节点有逻辑问题、已知事实、假设、证据需求、决策规则。
   - 叶节点必须包含 actionWhen、actionWhere、actionObject、actionProcedure、actionOutput、acceptanceCriteria，防止抽象建议伪装成行动。

3. **新增方案层参考案例 referenceCases**
   - `goal_solution_plans` 新增 `reference_cases` 字段。
   - AI 生成方案概览和单方案问题树时，都要求给出 1-2 个具体参考案例。
   - 案例只用于打开思路和比较不同可能性，不作为用户必须照做的处方。

4. **前端文案去“替用户选择化”**
   - 将“选择为主方案”改为“标记为当前试行方案”。
   - 将“方案结论”改为“候选路径”。
   - 方案卡片说明中明确：这些不是标准答案，而是供用户比较的候选假设。
   - 展开区新增“参考案例”，与判断依据、适用条件、停止条件一起展示。

5. **本地兜底方案同步升级**
   - comfort / stretch / panic 三套本地兜底方案也补充了具体参考案例。
   - 即使 AI 不可用，用户仍能看到多路径、边界条件和案例启发。

## 涉及文件

- `lib/external_data/todo_goal_prompt_config.dart`
- `lib/external_data/todo_goal_ai_service.dart`
- `lib/external_data/todo_goal_models.dart`
- `lib/external_data/todo_goal_dao.dart`
- `lib/external_data/todo_goal_pages.dart`
- `lib/external_data/onenote_pages.dart`

## 结果

AI 生成问题解决树时，不再只给直接建议，而是围绕目标作为现实问题展开：定义问题 → 锁定事实 → 识别未知 → 构造多方案 → 比较条件与代价 → 生成可验证节点 → 用行动证据更新判断。用户看到的是清晰的引导、参考案例和可执行验证路径，最终仍由用户自己判断和选择。

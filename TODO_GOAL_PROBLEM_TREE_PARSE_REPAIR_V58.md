# TODO 目标价值系统：问题树返回结果解析与校验修复 V58

## 修复背景

部分模型已经正常返回了问题树 JSON，但字段命名和包裹结构与前端校验器预期不完全一致，例如：

- 使用 `problemToSolve`、`knownBasis`、`evidenceNeeded` 等语义字段，而不是标准字段 `problemDefinition`、`knownFacts`、`evidencePlan`。
- 直接返回单个方案对象、`nodes/problemTree`，或返回转义后的 JSON 字符串，而不是严格的 `{"solutionPlans":[...]}`。
- 节点缺少 `logicQuestion / decisionRule / relationType` 等校验字段，但已经具备可展示、可执行的问题树信息。

旧逻辑会把这些结果判定为“没有通过结构校验”，导致页面保留旧节点而不展示新数据。

## 本次修改

1. **增强 JSON 提取能力**
   - 支持双重 JSON 字符串、带代码块、带转义引号和 `\\n` 的响应。
   - 支持模型直接返回节点数组或方案数组时自动包装为可解析对象。

2. **兼容更多 AI 字段别名**
   - 方案层兼容：`problemToSolve`、`knownBasis`、`evidenceNeeded`、`decisionRule` 等。
   - 节点层兼容：`problemToSolve`、`knownBasis`、`keyAssumptions`、`validationQuestion`、`successCriteria` 等。
   - 数组或对象型字段会转为适合页面展示的中文文本。

3. **新增问题树修复层**
   - 当 AI 返回的数据有实际节点，但缺少部分标准校验字段时，自动补全：
     - `relationType`
     - `logicQuestion`
     - `decisionRule`
     - `acceptanceCriteria`
     - 行动叶节点的缺失行动契约字段
   - 严格校验通过时按原提供商保存；可修复但非完全严格时以 `hybrid` 保存，不再直接丢弃。

4. **提示词进一步收紧**
   - 单棵问题树生成时明确要求必须返回 `{"solutionPlans":[{"nodes":[...]}]}`。
   - 明确禁止把 `nodes/problemTree` 直接放根对象或只返回节点数组。

5. **持久化补丁**
   - 替换单棵问题树时同步保存 `reference_cases`，避免方案层参考案例在更新树后丢失。

## 修改文件

- `lib/external_data/todo_goal_ai_service.dart`
- `lib/external_data/todo_goal_models.dart`
- `lib/external_data/todo_goal_dao.dart`

## 预期效果

如截图中这种“日志里已有正常 JSON，但页面提示未通过结构校验”的情况，会优先解析并修复后展示，而不是直接丢弃。只有完全没有可识别节点、父子关系严重破损或没有任何可执行叶节点时，才继续提示失败并保留原方案。

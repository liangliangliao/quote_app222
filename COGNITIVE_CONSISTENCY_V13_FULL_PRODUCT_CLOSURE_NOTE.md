# 足下一致行动 V13 完整闭环增强说明

本版本继续围绕 V12 后检查出的 1-8 点落地，重点从“有入口”推进到“有数据沉淀、有链路追踪、有复盘复用、有清空维护”。

## 本次落地点

1. 有效模式库：新增 `cc_effective_patterns`，证据页和 Todo 证据复盘页的“标记有效模式”会真正写入数据库。
2. 报告采纳链路可视化：报告卡片展示 `report -> session -> todo_step -> evidence` 状态链路。
3. 价值洞察强绑定：价值协同/冲突分析保存后，会与后续 session / evidence / Todo step 建立 trace 关系。
4. concept_engine / goal_module 回写增强：从一致行动返回后，可确认是否把原模块当前行动同步标记完成。
5. 智能触发规则基础：`CcSourceEvidenceStatusCard` 根据证据数量、最近证据时间生成触发建议，并写入 `cc_trigger_suggestions`。
6. 问题树证据地图：问题树顶部展示节点证据覆盖率、叶节点证据覆盖率，引导从分析走向行动验证。
7. 批量证据状态：问题树证据地图使用 `evidenceStatusForSources()` 一次性批量查询节点状态。
8. 统一行动追踪图：新增 `cc_action_trace_links`，串联 report / value insight / session / todo step / evidence / effective pattern。
9. 模块清空：价值罗盘功能入口新增“清空本模块数据”，可清空足下一致行动模块所有本地数据。

## 说明
当前环境没有 Flutter / Dart，无法真实执行 `flutter analyze` 或 `flutter build`。本版本已做源码静态检查和压缩包完整性校验。请用该 V13 包重新编译，若还有日志，继续以最新日志为准修复。

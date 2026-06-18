# 足下一致行动 V12 闭环增强说明

本版继续把 V11 编译修复版中重新发现的 1-8 个系统闭环问题落地到源码：

1. 报告行动写入 Todo 后，当前来源会自动切换为新建 `todo_goal_step`，后续保存证据会绑定并回写该 Todo 行动。
2. 新增 `cc_report_action_links`，追踪报告建议 → AI session → Todo step → evidence 的采纳链路。
3. Todo / 问题树从一致行动页面返回后，会尝试调用父页面 `_load()` 重新加载，而不是只做局部 `setState()`。
4. 证据详情页升级为复盘中心：显示核心冲突、原始 AI 输出，并支持转成 Todo 下一步、标记有效模式、继续生成下一步和复盘报告。
5. 多价值协同 / 冲突分析结果会保存到 `cc_value_relation_insights`，并在价值罗盘中展示历史记录。
6. concept action engine 与 goal module 增加一致行动证据状态卡，显示证据数、最近证据、关联价值和智能触发提示。
7. Todo / 问题树 / 行动模块的证据状态提示从静态文案升级为基于证据数和最近证据时间的基础规则提示。
8. `evidenceStatusForSources()` 从逐个 source 查询升级为批量查询接口，为页面级批量预加载打基础。

注意：当前环境没有 Flutter / Dart 命令，未能执行真实 `flutter analyze` 或打包构建；已完成源码级字符串、括号平衡检查和 zip 完整性打包。

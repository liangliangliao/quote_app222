# Cognitive Consistency V13 Compile Buildfix

根据 `logs_74603693362.zip` 修复 V13 编译错误。

## 日志中的直接错误

1. `cognitive_consistency_home_page.dart`
   - `_clearAllModuleData` 未定义
   - `_effectivePatternsCard` 未定义
   - `_markEffectivePattern` 未定义
   - `_openEvidenceTrace` 未定义

2. `todo_goal_pages.dart`
   - `_ProblemEvidenceMapCard` 未定义

3. `cognitive_consistency_dao.dart`
   - `_reportActionLinkFromRow` 未定义
   - `_effectivePatternFromRow` 未定义
   - `_actionTraceLinkFromRow` 未定义

## 修复内容

- 补齐清空本模块数据的 UI 方法与状态清理逻辑。
- 补齐有效模式库卡片、标记有效模式、证据链路查看方法。
- 补齐问题树一致行动证据地图组件。
- 补齐新增 DAO 表对应的 row mapper。
- 对核心修改文件做括号/字符串静态平衡检查。

当前环境没有 Flutter/Dart，仍需在 CI 或本地重新运行真实构建验证。

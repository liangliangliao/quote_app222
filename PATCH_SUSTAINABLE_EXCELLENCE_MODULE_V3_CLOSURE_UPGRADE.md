# PATCH_SUSTAINABLE_EXCELLENCE_MODULE_V3_CLOSURE_UPGRADE

本补丁在 v29「可持续卓越实验室」基础上继续补强 P0/P1/P2，重点从“功能可见”推进到“闭环真实运转”。

## P0 闭环补强

1. Todo 双向关联
   - 从 Todo 详情页进入后，自动查找已有 `sourceTodoId` 对应的可持续卓越实验。
   - 若已存在，直接打开原实验，避免重复生成。
   - 若不存在，自动生成实验并将“已转入可持续卓越实验室”的状态写回原 Todo。
   - `SustainableExcellenceTodoBridge.updateSourceTodoLinked` 会把实验标题、螺旋阶段、下一环建议、生成的下一步 Todo 写回原 Todo 正文与分类标签。

2. 失败复盘反写实验主体
   - 新增 `SustainableExcellenceDao.applyFailureReview`。
   - 失败复盘 AI 结果不再只写入日志，而会反向更新：
     - `failureLearning`
     - `todoWriteback`
     - `obstacleAnalysis`
     - `lastFailureType`
     - `spiralStage`
     - `nextRecommendedStage`

3. 行动执行阶段流
   - 行动执行页从单一倒计时升级为：
     - 准备阶段
     - 行动阶段
     - 恢复阶段
     - 复盘阶段
   - 行动计时结束后自动进入恢复阶段；恢复结束后自动记录恢复证据。
   - 支持重置为准备阶段。

4. 原 Todo 状态同步
   - 选择行动实验、完成行动、失败复盘、恢复记录、训练记录、归档/恢复实验都会尝试回写原 Todo 的状态轨迹。

## P1 训练与复盘补强

1. 每日/周度复盘时间过滤
   - 每日复盘只统计今天的日志。
   - 周度报告统计最近 7 天日志。
   - 复盘列表按 `reviewType` 过滤。
   - 支持删除单条复盘报告。

2. 完美主义训练器动态化
   - 从静态说明页升级为可执行训练页。
   - 支持选择训练、填写练习结果、保存成长证据、可选写回 Todo。

3. 过程享受训练动态化
   - 支持输入任务痛苦点。
   - 支持选择过程锚点：能力感、掌控感、意义感、好奇心、身体节奏、自由感、未来自我连接。
   - 支持保存过程训练证据。

4. 归档与导出
   - 首页支持查看/隐藏归档实验。
   - 详情页支持恢复归档。
   - 支持导出全部成长档案 JSON。
   - 支持导出当前实验 JSON。
   - 首页支持搜索实验与证据文本。

## P2 系统联动补强

1. 课程来源显式化
   - 详情页新增“理论来源：哈佛积极心理 Lecture 14–16”卡片。
   - 明确对应：Lecture 14 压力-恢复与失败学习；Lecture 15 完美主义-卓越；Lecture 16 过程享受。

2. 长期档案能力增强
   - 搜索、归档、恢复、导出能力已补充。
   - SQLite 深度迁移暂未执行，仍沿用现有项目 KeyValue/JSON 架构以降低破坏性；若后续数据量显著增加，可再单独迁移为 SQLite 表。

## 修改文件

- `lib/sustainable_excellence/sustainable_excellence_models.dart`
- `lib/sustainable_excellence/sustainable_excellence_dao.dart`
- `lib/sustainable_excellence/sustainable_excellence_todo_bridge.dart`
- `lib/sustainable_excellence/sustainable_excellence_home_page.dart`
- `lib/sustainable_excellence/sustainable_excellence_pages.dart`

## 注意

当前环境没有 Flutter/Dart SDK，无法执行真实编译；本补丁已做源码结构、括号配对、主要引用路径和压缩包完整性检查。

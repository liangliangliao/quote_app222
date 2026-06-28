# DEFENSE_COMPASS_MODULE_COMPLETION_V3

## 本次补强目标

针对“V2 仍未完全实现终极产品设计方案”的问题，本次 V3 继续以独立模块方式补齐自我防御罗盘的真实产品闭环：

- 事件记录不再只有自由文本，新增深度结构化事件字段。
- 分析结果不只保存为记录，还能自动形成行动、月报和长期上下文。
- 行动系统从简单完成/未完成升级为行动状态机。
- 课程系统从静态阅读升级为课程进度 + 课程转现实练习。
- 仪表盘从统计展示升级为闭环覆盖检查。
- AI Prompt 配置中心继续补齐新增场景 Prompt。

## 独立模块边界

仍保持独立模块目录：

```text
lib/defense_compass/
```

主要文件：

```text
defense_compass_models.dart
defense_compass_dao.dart
defense_compass_prompt_config.dart
defense_compass_ai_service.dart
defense_compass_home_page.dart
defense_compass_content.dart
```

未融合到其他已有业务模块。主项目只保留侧栏入口和 AI Prompt 设置页模块入口。

## V3 新增数据结构

除 V2 的：

```text
defense_compass_sessions
defense_compass_actions
```

本次新增：

```text
defense_compass_reports
```

用于保存月度/阶段成长报告。生成 `monthly_review` 时会自动落库。

```text
defense_compass_course_progress
```

用于保存《自我与防御机制》课程进度，支持标记完成、取消完成、课程备注。

## V3 新增或增强功能

### 1. 深度结构化事件记录

罗盘页新增可选结构化字段：

- 涉及的人
- 已确认事实
- 显性情绪与强度
- 身体反应
- 当时冲动
- 没有做/回避了什么

当用户填写这些字段且场景为事件罗盘时，AI 会自动使用 `deep_event_record` 场景 Prompt。

### 2. 行动状态机

行动清单从“完成/未完成”升级为：

- open：待行动
- completed：已完成
- deferred：已延后
- skipped：已跳过

行动卡支持：

- 快速完成/恢复待行动
- 复盘
- 标记延后
- 标记跳过
- 记录完成后情绪

### 3. 月度报告库

生成月度成长报告后，系统会同时保存到：

```text
defense_compass_reports
```

仪表盘页新增“月度/阶段成长报告库”，展示最近报告。

### 4. 产品闭环覆盖检查

仪表盘新增“产品闭环覆盖检查”，显示：

- 事件与分析记录数
- 待行动数
- 已完成行动数
- 已复盘行动数
- 个人防御地图更新时间
- 已保存报告数

并提供：

- 生成档案更新建议
- 生成月报
- 闭环审计

### 5. 课程进度闭环

课程页从静态课程列表升级为：

- 课程进度总览
- 每节课完成/取消完成
- 每节课转成现实练习
- 学习备注进入统计

### 6. 个人防御地图自动填充

档案页新增：

```text
从统计自动填充
```

可基于近期记录自动填充：

- 常见防御
- 常见触发
- 回避领域
- 关系模式
- 当前焦虑主题

仍保留手动编辑与保存。

## V3 新增 Prompt 配置项

在设置页 AI 提示词统一配置中心中继续新增：

- 场景：深度结构化事件记录
- 场景：行动复盘 / 状态机
- 场景：产品闭环审计

现有自我防御罗盘 Prompt 均仍通过：

```text
ai_prompt.defense_compass.*
```

保存，支持查看默认、编辑、恢复默认、历史备份、导入/导出和 Prompt 拼接预览。

## V3 覆盖的终极方案闭环

当前闭环为：

```text
结构化事件/自由记录
→ AI 三层 Prompt 分析
→ 生成自我三方地图
→ 识别焦虑来源与防御机制
→ 形成现实行动
→ 行动状态机追踪
→ 行动复盘
→ 个人防御地图更新
→ 月度报告保存
→ 仪表盘闭环审计
```

## 尚需本地验证

当前执行环境没有安装 Dart/Flutter SDK，因此无法执行真实编译。请本地运行：

```bash
flutter pub get
dart format lib/defense_compass lib/pages/ai_prompt_settings_page.dart lib/main.dart
flutter analyze
flutter run
```

## 修改范围摘要

重点修改：

```text
lib/defense_compass/defense_compass_models.dart
lib/defense_compass/defense_compass_dao.dart
lib/defense_compass/defense_compass_prompt_config.dart
lib/defense_compass/defense_compass_ai_service.dart
lib/defense_compass/defense_compass_home_page.dart
```

新增文档：

```text
DEFENSE_COMPASS_MODULE_COMPLETION_V3.md
```

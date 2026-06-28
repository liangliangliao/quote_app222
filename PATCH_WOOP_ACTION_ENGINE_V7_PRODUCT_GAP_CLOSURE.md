# PATCH WOOP Action Engine V7 - Product Gap Closure

本版本继续承认 V6 尚未完全实现最初产品设计方案，因此以“产品差距继续补齐”为目标，而不是宣称 100% 完成。

## 新增源码

- `lib/woop_action_engine/woop_action_v7_pages.dart`

## 新增功能

1. **原书课程化训练**
   - 将 Gabriele Oettingen《Rethinking Positive Thinking: Inside the New Science of Motivation》的 8 个核心思想转化为训练单元。
   - 每个单元包含核心思想、现实练习、复盘问题。
   - 用户可标记完成并保存反思。

2. **障碍触发模拟器**
   - 针对已有 WOOP 卡模拟障碍出现情境。
   - 记录 if–then 计划是否可触发。
   - 若未触发，可记录新障碍并写入复盘与计划日志。

3. **下一步行动队列**
   - 从全部行动中卡片中筛选今天最值得执行的 1–3 个最小行动。
   - 支持“完成并记录”或“未启动”记录，避免只是愿望库堆积。

4. **产品覆盖验收审计**
   - 诚实区分“已落地 / 部分落地 / 已落地待使用 / 仍需本地验证”。
   - 逐项检查 Prompt、数据表、复盘、实验、课程、构建验证等覆盖情况。

## 新增数据表

- `woop_action_course_progress`

用于保存原书课程训练进度与用户复盘。

## Prompt 配置中心新增

已将以下 Prompt 加入统一配置中心：

- `woop_scene_sourcebook_course`
- `woop_scene_trigger_simulator`
- `woop_scene_next_action_queue`
- `woop_scene_acceptance_audit`

## DAO 增强

- `upsertCourseProgress`
- `markCourseUnitDone`
- `listCourseProgress`
- `courseProgressMap`
- `fullExportJson` schema_version 升级为 7，并导出 course_progress。

## 首页集成

新增 `WoopActionV7ClosurePanel`，包含：

- 原书训练课
- 触发模拟器
- 下一步行动队列
- 覆盖验收审计

## 仍未宣称完成的事项

- 仍需本地 `flutter analyze` 与 `flutter build apk --release`。
- 后续仍可继续增强：通知触发、趋势图、批量编辑、深度 AI 对话、多设备同步。

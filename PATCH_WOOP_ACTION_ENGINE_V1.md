# PATCH_WOOP_ACTION_ENGINE_V1

## 模块定位

新增独立模块：`lib/woop_action_engine/`。

该模块基于 Gabriele Oettingen《Rethinking Positive Thinking: Inside the New Science of Motivation》的核心思想落地：

- 区分积极期待与积极幻想。
- 保留幻想在等待、安慰、探索真实需要中的价值。
- 用心理对照把愿望与现实障碍连接起来。
- 优先识别内在障碍，而不是停留在外部借口。
- 用 WOOP：Wish / Outcome / Obstacle / Plan 生成行动卡。
- 用 if–then 执行意图触发行动。
- 用失败复盘把负面反馈转化为新版计划。
- 根据目标可行性支持继续、调整、等待或有尊严地放下。

## 独立边界

- 新增目录：`lib/woop_action_engine/`
- 新增数据表：
  - `woop_action_cards`
  - `woop_action_reviews`
- 新增 Prompt KV 命名空间：`ai_prompt.woop_action_engine.*`
- 不复用/改写 ActionMind、RealisticOptimism、Goal、Failure 等已有模块的数据结构。
- 仅在 `lib/main.dart` 侧栏增加入口。

## 新增文件

- `lib/woop_action_engine/woop_action_models.dart`
- `lib/woop_action_engine/woop_action_dao.dart`
- `lib/woop_action_engine/woop_action_prompt_config.dart`
- `lib/woop_action_engine/woop_action_ai_service.dart`
- `lib/woop_action_engine/woop_action_engine_home_page.dart`

## 功能覆盖

1. 愿望输入与真实愿望澄清
2. 积极幻想识别与心理对照转化
3. WOOP 核心练习器
4. 内在障碍诊断
5. 目标可行性/可控性/代价/归属判断
6. 等待与安慰模式
7. 失败复盘与新版 if–then
8. 24 小时 WOOP 快捷入口
9. 障碍雷达统计
10. 愿望—障碍—行动卡列表
11. 行动卡详情与复盘记录
12. 三层 Prompt 查看页
13. AI 不可用时的本地兜底策略

## 接入入口

`RootShell` 左侧抽屉新增：

- 标题：`WOOP 行动引擎 · 愿望转行动`
- 页面：`WoopActionEngineHomePage`

## 验证说明

当前执行环境未安装 `dart` / `flutter` 命令，因此无法在沙盒内运行 `dart format`、`flutter analyze` 或实际构建 APK。已完成源码级检查、独立表命名检查、入口导入检查和明显 Dart 语法修正。建议在本地 Flutter 环境执行：

```bash
flutter analyze
flutter build apk --debug
```

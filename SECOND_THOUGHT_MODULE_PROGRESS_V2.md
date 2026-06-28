# 第二念模块开发进度 V2

## 本轮修正目标
用户反馈：V1 只是初步落地，未完全实现产品设计方案；本模块所有 AI 提示词应进入 App 设置页的“AI 提示词统一配置中心”自由配置。

## 已完成

### 1. 独立模块边界继续保持
- 第二念源码仍位于 `lib/second_thought/`。
- 数据表仍为 `second_thought_cases`、`second_thought_reviews`。
- 价值档案 KV 仍为 `second_thought_value_profile_v1`。
- 没有并入 MI 成长向导、认知一致性或其他已有模块。

### 2. 功能闭环扩展
本轮将首页从 V1 的 8 个 Tab 扩展为 10 个 Tab：
1. 向导
2. 四型诊断
3. 价值地图
4. 内在委员会
5. 全局图景
6. 改变语言
7. 行动实验
8. 复盘整合
9. 共处/社会
10. Prompt

新增/强化：
- 四型矛盾诊断解释与下一步分流。
- 价值地图：核心价值候选、自定义价值、理想自我、长期方向、关系/社会背景。
- 可能自我四格：理想自我、惯性自我、恐惧自我、整合自我。
- 全局图景：A/B/C/D 决策画布、Go/No 力量、第三条路、权重提醒、后悔预演。
- 行动实验：If-Then 应对计划、最小行动、成功标准、复盘入口。
- 共处/社会：长期矛盾共处、社会影响辨析、垂直矛盾提醒、整合表达模板。

### 3. AI Prompt 统一配置中心接入
已把第二念全部 Prompt 接入 `lib/pages/ai_prompt_settings_page.dart`：
- 模块 ID：`second_thought`
- 全局价值层：`st_global_value`
- 场景层：
  - `st_scene_capture`
  - `st_scene_type_diagnosis`
  - `st_scene_inner_committee`
  - `st_scene_values`
  - `st_scene_big_picture`
  - `st_scene_change_talk`
  - `st_scene_action_experiment`
  - `st_scene_review`
  - `st_scene_integration`
  - `st_scene_social_influence`
- 输出格式层：`st_output_json`

支持：
- 在设置页选择“第二念 · 矛盾心理价值行动引擎”模块。
- 查看当前实际模板。
- 修改并保存模板。
- 恢复源码默认模板。
- 预览拼接。
- 导出/导入本模块 Prompt JSON。
- 自动备份历史 Prompt 并可恢复。

### 4. 模块内 Prompt 页改为设置中心入口
`lib/second_thought/second_thought_home_page.dart` 的 Prompt Tab 不再作为分散编辑页，而是展示结构并提供按钮进入统一配置中心。

### 5. 设置页文案同步
`lib/pages/settings_page.dart` 中“AI 提示词统一配置中心”说明已加入第二念与 MI 模块。

## 受限说明
当前容器没有 `dart` / `flutter` 命令，无法在容器中执行：
- `dart format`
- `flutter analyze`
- `flutter build apk --debug`

已做静态括号/结构检查，建议在本地环境继续执行：

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

## 主要修改文件
- `lib/second_thought/second_thought_home_page.dart`
- `lib/second_thought/second_thought_prompt_config.dart`
- `lib/pages/ai_prompt_settings_page.dart`
- `lib/pages/settings_page.dart`
- `SECOND_THOUGHT_MODULE_PROGRESS_V2.md`

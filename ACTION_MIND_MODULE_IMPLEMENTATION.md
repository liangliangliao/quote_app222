# ActionMind · 行动心理学引擎模块落地说明

本次新增 `lib/action_mind/` 独立模块，不与已有 ACT Compass、目标、意志、认知一致性等模块融合。

## 新增源码

- `lib/action_mind/action_mind_models.dart`
  - ActionMindProfile：个人行动档案。
  - ActionMindGoal：目标画像，覆盖目标来源、内在/外在、接近/回避、理想/应该、四层目标结构、障碍与冲突。
  - ActionMindPlan：if–then 执行意图，含启动、障碍应对、诱惑替代、三档行动、环境线索。
  - ActionMindEmotionLog：情绪信号雷达。
  - ActionMindReview：行动反馈循环。
  - ActionMindSession：AI 行动教练会话。

- `lib/action_mind/action_mind_dao.dart`
  - 独立创建并使用 `action_mind_*` 表：
    - `action_mind_sessions`
    - `action_mind_goals`
    - `action_mind_plans`
    - `action_mind_emotions`
    - `action_mind_reviews`
  - 独立 KV key：`action_mind_profile_v1`。

- `lib/action_mind/action_mind_prompt_config.dart`
  - 全局价值层 Prompt。
  - 12 个场景层 Prompt：愿望启动、拖延、失败、情绪、长期目标、幻想现实对照、习惯诱惑、社会互动、多目标冲突、复盘、今日驾驶舱、周目标系统。
  - 4 个输出格式 Prompt：通用、快速、深度、JSON。

- `lib/action_mind/action_mind_ai_service.dart`
  - 调用全局 UnifiedAiService。
  - 支持结构化 JSON 输出。
  - 无 API 或解析失败时提供本地兜底分析，仍覆盖目标澄清、机制诊断、目标重写、现实障碍、过程模拟、if–then、三档行动、情绪处理、社会互动校正和反馈问题。

- `lib/action_mind/action_mind_home_page.dart`
  - 6 个产品页面：
    - 今日行动驾驶舱
    - AI 行动心理学教练
    - 目标系统地图
    - 情绪信号/资源调节
    - if–then 执行意图库
    - 复盘与个人行动档案

## 集成点

- `lib/main.dart`
  - 新增 import：`action_mind/action_mind_home_page.dart`
  - 抽屉新增独立入口：`ActionMind · 行动心理学引擎`

## 覆盖的产品设计思想

- 目标作为行动知识结构。
- 认知与动机整合。
- 内在/外在目标校准。
- 接近/回避目标改写。
- 自我防御与固定型思维识别。
- 情绪即行动信息。
- 心理模拟与现实障碍对照。
- if–then 执行意图。
- 最低/标准/挑战三档行动。
- 环境线索与无意识习惯重构。
- 社会互动中的准确/防御/印象目标校正。
- 多目标系统与长期人生整合。
- 反馈循环：目标 → 行动 → 情绪 → 复盘 → 调整。

## 验证说明

当前运行环境没有安装 `dart` / `flutter` 命令，因此无法在沙盒内执行 `dart format` 或 `flutter analyze`。已做静态文件检查与边界检查；若在本地 Flutter 环境运行，建议执行：

```bash
flutter pub get
flutter analyze
flutter run
```

---

## Phase 2 补强：完整产品方案覆盖与统一 Prompt 配置中心接入

根据复核意见，本轮不把 ActionMind 继续停留在 MVP，而是补齐以下关键差距：

### 1. AI 提示词统一配置中心

已将 ActionMind 的所有 AI Prompt 接入 `lib/pages/ai_prompt_settings_page.dart` 的统一配置中心：

- 模块名：`ActionMind · 行动心理学引擎`
- Prompt KV 命名空间：`ai_prompt.action_mind.*`
- 支持配置项：
  - `am_global_value`：全局价值层 Prompt
  - `am_scene_wish_start`：愿望启动 / 目标澄清器
  - `am_scene_procrastination`：拖延诊断
  - `am_scene_failure`：失败复盘 / 想放弃
  - `am_scene_emotion`：情绪信号雷达
  - `am_scene_long_goal`：长期目标系统
  - `am_scene_fantasy`：愿景-现实心理对照
  - `am_scene_habit`：习惯/诱惑环境线索重构
  - `am_scene_social`：社会互动行动教练
  - `am_scene_goal_conflict`：多目标冲突与生活任务地图
  - `am_scene_review`：日/周/项目复盘
  - `am_scene_daily_cockpit`：今日行动驾驶舱
  - `am_scene_weekly_system`：每周目标系统整合
  - `am_output_common`：通用结构输出
  - `am_output_quick`：快速模式输出
  - `am_output_deep`：深度模式输出
  - `am_output_json`：结构化 JSON 输出

统一配置中心中 ActionMind 已支持：

- 查看源码默认完整 Prompt
- 编辑当前实际 Prompt
- 保存本地自定义 Prompt
- 恢复源码默认 Prompt
- 历史备份恢复
- 导出本模块 Prompt JSON
- 从剪贴板导入本模块 Prompt JSON
- 查看系统自动注入参数：`{{scene}}`、`{{user_input}}`、`{{profile_json}}`、`{{goals_json}}`、`{{recent_context_json}}`、`{{output_mode}}`

### 2. 模块 UI 从 6 页扩展为 8 页

`ActionMindHomePage` 已从 MVP 的 6 个 Tab 扩展为 8 个 Tab：

1. 今日
2. AI教练
3. 目标地图
4. 情绪资源
5. 执行意图
6. 工具箱
7. 生活系统
8. 复盘档案

页面右上角新增 `配置 ActionMind AI 提示词` 快捷入口，直接跳转到统一配置中心并定位到 ActionMind 全局价值层 Prompt。

### 3. 产品设计方案中的 12 类核心能力已入口化

新增 `工具箱` 页，对产品设计方案中的 12 类功能逐项入口化：

1. 目标澄清器
2. 目标价值校准器
3. 目标层级地图
4. 心理模拟与现实对照
5. if–then 执行意图生成器
6. 情绪信号雷达
7. 自我防御识别器
8. 资源与努力调节器
9. 无意识习惯与环境线索管理
10. 社会互动行动教练
11. 个人奋斗与生活任务地图
12. 复盘与反馈循环

每个工具都可以：

- 直接调用对应场景层 Prompt 生成结果
- 带入 AI 教练页继续编辑
- 复用统一全局价值层 Prompt 与输出格式 Prompt

### 4. 生活系统整合页

新增 `生活系统` 页，围绕 Emmons 个人奋斗、Cantor 生活任务和 Carver 控制论反馈循环，提供：

- 核心价值、身份方向、生活任务快照
- 活跃目标、执行意图、情绪、复盘统计
- 每周目标系统图生成
- 多目标冲突检测
- 主线目标 / 支持目标 / 冲突目标 / 暂停目标 / 外部压力目标的 AI 整合入口

### 5. 本地兜底分析加强

`ActionMindAiService.localAnalyze` 的兜底逻辑已补强，不只覆盖拖延、情绪、习惯、社会互动，还增加：

- 长期目标系统
- 心理对照
- 失败复盘
- 多目标冲突
- 每周目标系统
- 每日驾驶舱
- 复盘场景

即使 AI API 不可用，模块仍能生成与产品价值体系一致的基本行动方案。

### 6. 模块隔离边界

本轮仍保持 ActionMind 独立模块边界：

- 新增代码集中在 `lib/action_mind/`
- 只在 `lib/pages/ai_prompt_settings_page.dart` 注册统一配置入口
- 只在 ActionMind 页面添加配置中心跳转
- 不合并 ACT Compass、第二念、目标训练、认知一致性等已有模块逻辑
- 数据仍使用 `action_mind_*` 独立表与 `ai_prompt.action_mind.*` 独立 KV 命名空间

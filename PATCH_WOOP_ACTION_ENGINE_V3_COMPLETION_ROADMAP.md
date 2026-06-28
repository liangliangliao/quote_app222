# WOOP 行动引擎 V3：产品方案补全与独立模块加固

## 这版修正的核心问题

用户反馈 V1/V2 与完整产品设计方案差距仍大。V3 不再只做“首页 + 卡片 + Prompt 常量”，而是按产品方案补齐独立模块的工作台、场景工具、愿望地图、障碍雷达、计划库、复盘闭环与 Prompt 统一配置能力。

## 构建层修复

- 修复 `WoopActionCard.fromJson` 中重复 `createdAtMs` 命名参数，避免 Dart 编译失败。
- 继续保持模块所有文件位于 `lib/woop_action_engine/` 下，独立表名与 KV 前缀均使用 `woop_action_*` / `ai_prompt.woop_action_engine.*`。

## 新增文件

- `lib/woop_action_engine/woop_action_extra_pages.dart`

## 新增页面 / 工作流

1. `WoopActionGuidePage`
   - 价值引导页：明确理论出处《Rethinking Positive Thinking》、积极幻想边界、心理对照、内在障碍、继续/调整/等待/放下、失败反馈等核心价值。

2. `WoopActionSceneLibraryPage`
   - 场景工具库：覆盖愿望澄清、积极幻想、WOOP 行动、障碍诊断、失败复盘、等待安慰、大目标缩小、继续/调整/放下、健康、学习工作、关系沟通、情绪冲动、24小时 WOOP、幻想安全区、障碍雷达、周复盘/愿望地图。
   - 点击场景后自动回填首页输入框和场景选择。

3. `WoopActionWishMapPage`
   - 愿望地图页：按行动中、已完成、暂存、已放下四类管理目标。
   - 支持在地图中直接将目标切换为继续、暂存、放下、完成。
   - 体现原书“该投入时投入，该放下时放下”的精力配置思想。

4. `WoopActionObstacleRadarPage`
   - 障碍雷达独立页：统计高频内在障碍标签。
   - 可基于历史 WOOP 卡与复盘生成 AI 障碍雷达分析卡。
   - 体现“失败/负面反馈是系统信息”的思想。

5. `WoopActionPlanLibraryPage`
   - if–then 计划库：集中查看所有障碍触发器和行动计划。
   - 体现“不是临时靠意志力，而是提前设计障碍—行动连接”。

6. `WoopActionPromptCoveragePage`
   - Prompt 覆盖检查页：列出本模块全部 Prompt ID，并可跳转设置页统一配置中心逐项编辑。

## 首页增强

- 新增“完整产品工作台”功能网格：价值引导、场景工具库、愿望地图、障碍雷达、if–then 计划库、Prompt 配置。
- AppBar 菜单加入完整功能入口。
- 保留原有 WOOP 卡生成、统计、愿望地图摘要、障碍雷达摘要、行动卡列表。

## DAO 增强

新增：

- `listCardsByStatuses`
- `listCardsByDirection`
- `listRecentReviews`
- `deleteCard`
- `historySummaryJson`

用途：愿望地图、障碍雷达、计划库、AI 历史分析、卡片删除。

## 复盘与卡片管理增强

- 卡片详情页新增删除功能。
- 保留完成复盘、障碍复盘、基于复盘生成新版 WOOP。

## Prompt 统一配置中心

V2 已接入，V3 保持并增强可见性：

- `WoopActionPromptCoveragePage` 可列出全部 `WoopActionPromptConfig.allIds`。
- 每个 Prompt 可跳转到 `AiPromptSettingsPage(initialModuleId: 'woop_action_engine', initialPromptId: id)`。
- 仍支持设置页中的保存、恢复源码默认、历史备份、导出/导入本模块 Prompt JSON、Prompt 拼接预览。

## 仍需本地验证

当前沙盒没有安装 `flutter` / `dart`，无法执行：

```bash
flutter analyze
flutter build apk --debug
```

请在本地执行。如果仍有编译错误，请发日志继续做 build fix。

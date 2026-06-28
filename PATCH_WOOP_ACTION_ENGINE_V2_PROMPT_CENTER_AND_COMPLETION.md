# WOOP 行动引擎 V2：统一 Prompt 配置中心接入 + 功能补齐

## 背景
用户反馈 V1 只是核心骨架，未完全覆盖产品设计方案；同时 WOOP 模块 AI 提示词不应只放在模块内部常量，而应进入 App 设置页的 AI 提示词统一配置中心自由配置。

## 本次修正

### 1. 提示词统一配置中心
- 在 `lib/pages/ai_prompt_settings_page.dart` 中新增模块：`WOOP 行动引擎 · 愿望转行动`。
- 注册全部 WOOP AI 子功能 Prompt：
  - 全局价值层 Prompt
  - 自动场景识别器
  - 愿望澄清
  - 积极幻想转心理对照
  - 行动转化 WOOP
  - 内在障碍诊断
  - 失败复盘
  - 低可控等待与安慰
  - 大目标缩小
  - 继续/调整/放下
  - 健康行为
  - 学习工作
  - 关系沟通
  - 情绪与冲动
  - 24 小时 WOOP
  - 幻想安全区 / 愿望探索
  - 障碍雷达模式分析
  - 周复盘 / 愿望地图
  - 标准 WOOP 输出格式
  - 失败复盘输出格式
  - 目标筛选输出格式
  - 结构化 JSON 输出格式
- 支持保存、恢复默认、历史备份、导入导出模块 Prompt JSON、预览拼接。
- App 设置页统一配置中心说明文案已加入 WOOP 行动引擎。

### 2. PromptConfig 架构升级
- `woop_action_prompt_config.dart` 从静态常量升级为与 ActionMind/ACT/MI 同类的可配置 PromptConfig。
- 所有提示词覆盖统一写入：`ai_prompt.woop_action_engine.*`。
- AI 调用时不再固定使用静态默认 Prompt，而是实时读取设置中心保存的模板。

### 3. WOOP 模块页面补齐
- 主页面 Prompt 图标改为直接进入：设置页 → AI 提示词配置中心 → WOOP 行动引擎。
- 新增场景入口：24 小时 WOOP、幻想安全区、障碍雷达分析、周复盘/愿望地图。
- 新增快捷模板按钮：24小时 WOOP、愿望地图、障碍雷达、幻想安全区。
- 新增愿望地图面板，展示行动中、已完成、暂存、已放下，强化“不是所有愿望都要硬扛”的产品价值。

### 4. 复盘闭环增强
- 行动卡详情页新增“基于复盘/当前卡生成新版 WOOP”。
- 可把失败/障碍复盘继续转化为下一张新版 WOOP 行动卡，形成：行动卡 → 复盘 → 新版行动卡 的闭环。

### 5. 本地兜底策略扩展
- 扩展本地场景识别：daily_24h、fantasy_safe_explore、obstacle_radar、weekly_review。
- AI 不可用时仍能生成对应的本地 WOOP 卡。

## 仍需本地验证
当前沙盒没有 Dart / Flutter 命令，无法执行 `flutter analyze` 或 APK 构建。请在本地执行：

```bash
flutter analyze
flutter build apk --debug
```

如有编译错误，把日志发回后继续 build fix。

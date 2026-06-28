# 自我防御罗盘模块 V2 补全说明

本次根据“终极版产品方案”和反馈继续补全，仍保持独立模块边界：所有业务代码位于 `lib/defense_compass/`，仅在主侧栏和 AI Prompt 统一配置中心接入入口。

## 本次新增/增强

### 1. 独立内容库
新增 `lib/defense_compass/defense_compass_content.dart`：
- 16 个防御机制库条目，覆盖内部冲突、外部现实不快、关系防御、发展阶段防御。
- 每个机制包含：一句话定义、出现信号、保护功能、长期代价、替代练习、AI 分析场景、默认输入模板。
- 7 类现实行动训练：现实检验、情绪承受、欲望整合、边界行动、能力恢复、关系修复、转折期实验。
- 16 节微课程，完整覆盖《自我与防御机制》终极归纳中的核心内容。

### 2. 主页面功能从 8 页扩展为 11 页
`DefenseCompassHomePage` 当前包括：
1. 今日自我罗盘
2. 分析记录
3. 现实行动训练中心
4. 行动清单
5. 防御机制库
6. 关系防御工作台
7. 青春期/人生转折/家庭教育
8. 微课程
9. 长期模式仪表盘
10. 个人防御地图
11. 安全边界

### 3. 现实行动系统增强
- 支持训练模板一键进入 AI 引导。
- 支持训练模板一键加入行动清单。
- 支持手动新增现实行动。
- 行动类型覆盖：现实检验、情绪承受、欲望整合、边界、能力恢复、关系修复、转折期实验。
- 行动复盘继续保存完成后情绪与反思。

### 4. 关系与发展阶段模块补强
新增关系防御工作台：
- 投射检查器
- 认同攻击者检查
- 利他性让渡与边界
- 关系沟通句生成

新增转折/家庭页：
- 人生转折期分析
- 理智化落地
- 禁欲主义检查
- 儿童/家庭教育防御理解

### 5. 长期仪表盘增强
- 新增行动完成率。
- 新增行动类型统计。
- 增加成长指标说明：现实检验、情绪承受、愿望表达、边界行动、能力恢复、关系修复。

### 6. AI Prompt 统一配置中心补强
`DefenseCompassPromptConfig` 已从基础三层 Prompt 扩展为可配置的完整 Prompt 体系，新增：
- 现实行动生成器 Prompt
- 个人防御地图更新 Prompt
- 关系对话模拟器 Prompt
- 课程案例转练习 Prompt
- 防御库机制教练 Prompt
- JSON 修复 Prompt
- 关系沟通卡输出 Prompt
- 个人防御地图更新卡输出 Prompt
- 安全支持卡输出 Prompt

这些 Prompt 均已进入 `AiPromptSettingsPage` 的“自我防御罗盘 · Ego Defense Compass”模块，支持：
- 查看默认模板
- 编辑保存
- 删除覆盖恢复默认
- 历史备份恢复
- 导出/导入本模块 Prompt JSON
- Prompt 拼接预览

## 独立边界
- 独立业务目录：`lib/defense_compass/`
- 独立数据表：`defense_compass_sessions`、`defense_compass_actions`
- 独立 KV：`defense_compass_profile_v1`、`ai_prompt.defense_compass.*`
- 不融合其他已有模块业务逻辑。

## 本地建议执行
当前运行环境没有 Flutter SDK，建议本地执行：

```bash
flutter pub get
dart format lib/defense_compass lib/pages/ai_prompt_settings_page.dart lib/main.dart
flutter analyze
flutter run
```

# 足下意志 · 第二阶段完整落地补丁

本补丁在第一阶段 P0 的基础上继续完成 P1/P2 功能集成，并仍然挂载在 `外部数据同步` 首页的 `足下意志 · 行动观念训练` 入口中。

## 新增文件

- `lib/external_data/james_will_training_complete_models.dart`
- `lib/external_data/james_will_training_complete_dao.dart`
- `lib/external_data/james_will_training_complete_ai_service.dart`
- `lib/external_data/james_will_training_complete_page.dart`

## 修改文件

- `lib/external_data/james_will_training_page.dart`
- `lib/external_data/james_will_training_ai_service.dart`
- `lib/external_data/onenote_pages.dart`

## 新增数据库表

- `james_will_habits`：习惯建筑师，固定触发条件、地点、第一身体动作、最低版本、失败恢复方案和等级。
- `james_will_weekly_reports`：每周意志报告，统计完成/记录、平均努力性注意、分心拉回、主要阻碍和下周实验。
- `james_will_prompt_configs`：AI 提示词配置，可覆盖行动观念、决定分析、复盘、周报的附加提示词。

## 完整落地能力

1. 完整落地中心
   - 全局意志教育成长等级
   - 个人意志画像
   - 习惯建筑师列表
   - 每周意志报告
   - AI 提示词配置
   - 完整落地覆盖清单

2. 行动观念卡增强
   - 短期舒服 vs 长期力量
   - 可控域 / 不可控域拆解
   - 阻碍观念干预库
   - 成长等级卡
   - 决定封存 / 冲动冷却提示
   - 习惯建筑师
   - 语音式注意力拉回说明

3. 五分钟启动器增强
   - 接入 `flutter_tts`
   - 支持生成并朗读 30-45 秒注意力拉回文案
   - 分心/想放弃时将行动观念重新放回意识中心

4. AI 服务增强
   - 行动观念生成、决定分析、意志复盘会读取 `james_will_prompt_configs` 中的附加提示词。
   - 新增每周报告生成。
   - 新增语音式注意力拉回文案生成。

## 对应产品方案

已覆盖：

- 目标 → 核心价值 → 行动观念
- 观念竞争面板
- 第一身体动作预演
- 五分钟启动器
- 注意力保持与分心拉回
- 詹姆斯式决定分析
- 决定封存 / 实验执行
- 快乐与痛苦动力分析
- 可控域 / 不可控域拆解
- 阻碍观念库
- 习惯建筑师
- 意志教育成长体系 L1-L6
- 每周意志报告
- 个人意志画像
- AI 提示词配置
- 语音式注意力拉回

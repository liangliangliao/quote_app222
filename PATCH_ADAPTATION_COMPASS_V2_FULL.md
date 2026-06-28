# PATCH_ADAPTATION_COMPASS_V2_FULL

## 本次修复目标

用户反馈 V1 只是骨架，未充分落地《Adaptation to Life》终极产品方案，并要求本模块所有 AI 提示词纳入 App 设置页的「AI 提示词配置中心」统一自由配置。本补丁在保持模块独立的前提下继续补全。

## 已完成

### 1. 提示词统一配置中心接入

新增并接入 `AdaptationCompassPromptConfig` 的完整配置能力：

- 模块 ID：`adaptation_compass`
- Prompt 存储前缀：`ai_prompt.adaptation_compass.*`
- 全局价值层 Prompt：`ac_global_value`
- 输出格式层 Prompt：`ac_output_common_json_markdown`
- 24 个场景/复盘/导出/审计/修复 Prompt：
  - `ac_scene_daily_stress`
  - `ac_scene_defense_identify`
  - `ac_scene_reality_check`
  - `ac_scene_anger_transform`
  - `ac_scene_shame_failure`
  - `ac_scene_anxiety_fear`
  - `ac_scene_relationship_conflict`
  - `ac_scene_intimacy_avoidance`
  - `ac_scene_work_consolidation`
  - `ac_scene_balance_four`
  - `ac_scene_high_functioning`
  - `ac_scene_childhood_climate`
  - `ac_scene_body_health`
  - `ac_scene_acting_out`
  - `ac_scene_generativity`
  - `ac_scene_life_stage_review`
  - `ac_scene_understand_other`
  - `ac_scene_safety_support`
  - `ac_scene_weekly_review`
  - `ac_scene_monthly_review`
  - `ac_scene_profile_update`
  - `ac_scene_therapist_export`
  - `ac_scene_prompt_audit`
  - `ac_scene_json_repair`

设置页支持：

- 查看默认 Prompt
- 保存覆盖 Prompt
- 恢复默认 Prompt
- 历史备份
- 恢复备份
- 导出/导入本模块 Prompt JSON
- Prompt 拼接预览

### 2. 模块入口补强

`AdaptationCompassHomePage` AppBar 新增「提示词配置」入口，直接打开：

`AiPromptSettingsPage(initialModuleId: 'adaptation_compass', initialPromptId: ac_global_value)`

### 3. 产品功能继续落地

在原 V1 基础上新增独立数据结构和 UI：

#### 关系与亲密系统

新增表：`adaptation_compass_relationships`

支持记录：

- 关系类型：安全/亲密/冲突/责任/成长/贡献
- 信任度
- 亲密度
- 冲突度
- 支持度
- 边界清晰度
- 关系防御/触发/修复备注

#### 生命时间线

新增表：`adaptation_compass_timeline`

支持记录：

- 生命章节
- 关键事件
- 当时旧适应方式
- 现在成熟转化方向
- 人生证据墙

#### 生成性贡献计划

新增表：`adaptation_compass_contributions`

支持记录：

- 贡献对象
- 贡献形式
- 痛苦/经验理解
- 贡献边界
- 实际行动/结果
- 意义感评分

### 4. AI 上下文增强

`recentContextJson()` 现在会把以下内容一起注入 AI Prompt：

- 最近分析卡
- 行动闭环
- 四维平衡
- 关系地图
- 生命时间线
- 生成性贡献记录

### 5. 新增焦虑/恐惧预期场景

新增 `anxiety_fear` 场景，对应 Prompt：`ac_scene_anxiety_fear`。

本地 fallback 分析也补充：

- 恐惧转预期
- 可准备事项
- 可求助对象
- 10 分钟 / 24 小时 / 7 天行动

### 6. 模块独立性

本模块仍保持完全独立：

- 独立源码目录：`lib/adaptation_compass/`
- 独立数据库表：`adaptation_compass_*`
- 独立 KV：`adaptation_compass_profile_v1` 与 `ai_prompt.adaptation_compass.*`
- 不复用/不混入 `defense_compass` 的内部实现

## 本地建议验证

```bash
flutter pub get
flutter analyze
flutter build apk
```

当前容器没有 Flutter/Dart SDK，无法在容器内直接执行上述命令。已做文本级括号平衡与关键引用检查。

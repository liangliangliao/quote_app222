# PATCH_ADAPTATION_COMPASS_V3_GAP_CLOSURE

本次继续基于 V2 补齐《Adaptation to Life》终极产品方案中尚未实际落地的关键功能，仍保持 `lib/adaptation_compass/` 独立模块，不与原 `defense_compass` 或其他已有模块融合。

## 主要补充

### 1. 复盘 / 导出 / 审计从“说明卡”升级为实际 AI 入口
在「复盘安全」页新增实际按钮：
- 生成 7 天复盘 `weekly_review`
- 生成 30/90 天复盘 `monthly_review`
- 更新个人适应地图 `profile_update`
- 生成治疗师导出包 `therapist_export`
- Prompt/产品覆盖审计 `prompt_audit`

这些调用都会把本模块近期上下文 JSON 注入 AI，包括分析、行动、四维平衡、关系地图、生命时间线、贡献记录、身体日志和课程进度。

### 2. 新增身体健康与压力日志
新增独立表：
- `adaptation_compass_health`

新增字段：
- 睡眠质量
- 饮酒/成瘾风险
- 运动分钟
- 身体压力强度
- 身体症状
- 备注/医学评估/身体照顾动作

对应终极方案中“身体、酒精、疾病、成瘾、健康行为”的产品落地。

### 3. 新增 12 周课程进度追踪
新增独立表：
- `adaptation_compass_course_progress`

用户可以为每周课程保存完成状态和练习复盘。课程进度会进入 AI 长期上下文，使课程不再只是静态内容。

### 4. 隐私控制与数据导出
在「复盘安全」页新增：
- 复制本模块 JSON 导出
- 清空本模块数据

清空范围仅包括 Adaptation Compass 独立模块：分析、行动、四维平衡、关系、时间线、贡献、身体日志、课程进度和个人背景，不影响其他模块。

### 5. 场景注册补齐
`AdaptationCompassContent.scenes` 补齐此前只在 Prompt 配置中存在但页面未注册的场景：
- weekly_review
- monthly_review
- profile_update
- therapist_export
- prompt_audit

### 6. AI 上下文增强
`recentContextJson()` 现在额外注入：
- health
- course_progress

## 已知边界

当前容器没有 Flutter / Dart SDK，无法执行 `flutter analyze` 或 `flutter build apk`。已完成文本级括号平衡和关键引用检查。请在本地继续运行：

```bash
flutter pub get
flutter analyze
flutter build apk
```

如有编译错误，提供日志后可继续修复。

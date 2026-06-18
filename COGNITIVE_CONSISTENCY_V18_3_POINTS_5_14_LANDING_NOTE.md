# 足下一致行动 V18.3：审计发现 5-14 点落地说明

本补丁基于 `v13work_cognitive_consistency_v18_2_four_point_closure.zip` 继续增量改造，主要落地上一轮审计中编号 5-14 的问题。

## 已落地内容

1. **行动后解释吸收 V18 上下文**
   - `generatePostActionExplanation()` 新增 `v18Context` 参数。
   - 行动后解释 Prompt 新增 V18 失调修复上下文：失调类型、强度、防御/成长解释、自我完整卡、信息回避、身份对话、行动前后温度。
   - 保存证据时会把当前 plan 和温度计状态拼接为结构化上下文传入 AI。

2. **行动前温度 pending 绑定证据**
   - DAO 新增 `bindLatestPendingBeforeTemperature()`。
   - 如果用户提前记录行动前温度，保存证据时优先把 pending before 温度绑定到 evidenceId，不再重复生成 before 记录。
   - 若没有 pending before，才按旧逻辑保存一条 before 温度。

3. **每日一致性复盘支持 AI 草稿**
   - AI Service 新增 `generateDailyReviewDraft()`。
   - PromptConfig 的 Daily Review 模板升级为可输出 JSON 草稿。
   - 行动陪伴页新增“AI生成草稿”按钮，自动填入今日价值行动、主要失调、合理化、成长解释、修复行动和明日行动。

4. **每日复盘一天一条主记录 + 编辑/删除**
   - `saveDailyConsistencyReview()` 默认按 dateLabel 生成稳定 reviewId，同一天保存会覆盖当天主复盘。
   - 页面支持编辑历史复盘并覆盖原日期。
   - 页面支持删除复盘。

5. **价值—行为一致性地图纳入未修复 session**
   - `buildValueConsistencySnapshots()` 新增未修复 session 聚合。
   - 对已生成失调分析但还没有 evidence 的 session，也会计入对应价值的失调统计。
   - 高强度、未行动、未修复的价值断裂不再被遗漏。

6. **离线周报加入 V18 统计**
   - `_localWeeklyReport()` 新增 V18 失调画像：失调类型分布、强度分布、温度变化、验证任务状态、每日复盘摘要。
   - 无 AI 时，报告不再退回旧版行动证据统计。

7. **PromptTemplates 主结构补齐 V18.1/V18.3 场景字段**
   - `CognitiveConsistencyPromptTemplates` 增加：`informationAvoidance`、`identityConflict`、`dailyReview`、`temperatureReview`。
   - `load()`、`copyWith()` 同步补齐。
   - Prompt 版本号升级为 `v18_3_full_feedback_loop`。

8. **Prompt 升级文案修正**
   - 将旧的 v17 提示文案修正为 V18.3 自我完整与完整闭环 Prompt。

9. **验证任务完成后反哺 session / trace**
   - `completeVerificationTask()` 现在会根据验证状态回写对应 session 状态。
   - 同时写入 action trace，后续可追踪“验证任务 → 一致行动 session”的反馈链路。

## 修改文件

- `lib/cognitive_consistency/cognitive_consistency_ai_service.dart`
- `lib/cognitive_consistency/cognitive_consistency_dao.dart`
- `lib/cognitive_consistency/cognitive_consistency_home_page.dart`
- `lib/cognitive_consistency/cognitive_consistency_prompt_config.dart`

## 本地验证建议

当前容器没有 flutter/dart 命令，建议本地继续执行：

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

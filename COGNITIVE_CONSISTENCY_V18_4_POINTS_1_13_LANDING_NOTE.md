# 足下一致行动 V18.4：1-13 点系统反馈闭环落地说明

本版本基于 `v13work_cognitive_consistency_v18_3_1_compile_fix.zip` 增量改造，继续补齐上一轮审计提出的 1-13 点。

## 主要落地内容

1. **周报 Prompt 真正吸收 V18 画像数据**
   - `defaultWeeklyReportPrompt` 已加入 `{{modern_profile_json}}` 与 `{{daily_reviews_json}}`。
   - 周报要求输出失调类型、强度、温度变化、防御/成长解释、自我完整、身份变化、未验证任务和下周最小行动。

2. **温度复盘真正调用并落库**
   - 新增 `generateTemperatureReview()`。
   - 保存行动证据时自动根据 before/after 温度生成 AI 温度复盘。
   - 新增 `cc_temperature_review_items` 表。
   - 证据卡显示“AI 温度复盘”。

3. **信息回避挑战增加结果记录**
   - 新增信息接触结果表单：真实结果、结果类型、灾难化检查、下一步修复行动。
   - 新增 `cc_information_contact_results` 表。
   - 报告页新增“信息接触历史”。

4. **身份冲突增加长期身份转换档案**
   - 新增 `cc_identity_transition_records` 表。
   - 保存 identity 证据时记录旧身份、新身份、旧身份保护、新身份行动、行动后身份解释。
   - 报告页新增“身份转换档案”。

5. **Todo 写入保留结构化三类行动信息**
   - 写入 Todo 时优先使用 `CcActionVariant` 的 title / steps / completionCriteria / linkedValue。
   - Todo 回写分为“简版摘要”和“完整一致行动详情”。

6. **价值地图继续减少纯文本依赖**
   - 继续优先使用 value link、session link、V18 详情、未修复 session、温度日志等结构化来源。
   - 文本匹配仅作为兜底。

7. **验证任务完成后反哺 session / trace / 报告趋势**
   - 验证任务支持 verified / partial / invalid / adjust / exit / need_info。
   - 结果回写 session 状态，并进入 action trace。

8. **每日复盘 AI 草稿优先使用当天证据**
   - 优先读取今天 00:00 后的行动证据。
   - 如果今天没有证据，会明确生成“缺失复盘”，不再假装今天已有行动。

9. **行动前温度 pending 绑定增加 24 小时规则**
   - 只绑定 24 小时内的最近 pending before 温度。
   - 过期 pending 会标记 note，不再误绑定。

10. **证据账本新增 V18 高级筛选**
   - 支持按失调类型、强度、温度变化、验证状态筛选。

11. **Todo 回写简版 / 完整详情分层**
   - Todo 中保留简短摘要。
   - 完整详情保存在一致行动模块回写字段里，避免 Todo 被长文本淹没。

12. **Prompt 备份恢复入口**
   - AI 提示词设置页新增“一致行动 Prompt 历史备份恢复”卡片。
   - 升级 Prompt 后可恢复旧自定义模板。
   - `KeyValueDao` 增加 `keyValuesWithPrefix()`。

13. **自我完整长期画像**
   - 新增 DAO 统计：自我完整卡数量、“我不等于……”数量、下一步证明行动数量。
   - 报告页展示自我完整长期画像。

## 修改文件

- `lib/cognitive_consistency/cognitive_consistency_models.dart`
- `lib/cognitive_consistency/cognitive_consistency_dao.dart`
- `lib/cognitive_consistency/cognitive_consistency_ai_service.dart`
- `lib/cognitive_consistency/cognitive_consistency_home_page.dart`
- `lib/cognitive_consistency/cognitive_consistency_prompt_config.dart`
- `lib/pages/ai_prompt_settings_page.dart`
- `lib/data/kv_dao.dart`

## 版本号

Prompt 版本升级为：`v18_4_full_system_feedback_loop`

## 本地建议验证

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

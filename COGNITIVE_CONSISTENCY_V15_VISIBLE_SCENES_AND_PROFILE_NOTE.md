# 足下一致行动 V15：现代认知失调 1-8 点落地说明

本轮在 V14 基础上继续落地前述 1-8 点，重点从“底层字段 + AI 结果卡片”升级为“可见入口 + 专项流程 + 长期画像 + 双向联动”。

## 已落地

1. 修复真实自我同步过度触发：本地 fallback 不再默认填充羞耻/真实骄傲字段；`usedFallback` 不触发真实自我证据同步。
2. 给真实自我同步加异常保护：同步失败不阻断一致行动证据保存，只把提示追加到状态文本。
3. 足下真实自我 → 足下一致行动双向入口：真实自我结果页新增“转为一致行动 / 1美元行动”。
4. 选择后合理化与沉没成本专项入口：足下一致行动新增“专项场景”Tab，并支持选择后合理化、沉没成本。
5. 虚伪诱导行为改变入口：专项场景支持“价值—行为距离”训练。
6. 群体/关系/文化失调入口：专项场景支持家庭、朋友、团队、社会评价、文化角色冲突分析。
7. 替代性认知失调入口：专项场景支持“我们的人/我支持的人/我的群体”造成的不一致分析。
8. 长期画像：报告页新增“现代认知失调长期画像”，统计场景分布、合理化类型、自我标准触发、责任风险、行动修复率、真实自我联动次数。

## 额外修复

- 修复新增“专项场景”Tab 后旧入口索引偏移问题：奖励降噪、诚实校验、一致性报告、证据页等外部入口已调整到新 Tab 位置。
- 修正输出格式 Prompt 中多余的大括号，避免提示词 JSON 示例结构错误。

## 涉及文件

- `lib/cognitive_consistency/cognitive_consistency_home_page.dart`
- `lib/cognitive_consistency/cognitive_consistency_ai_service.dart`
- `lib/cognitive_consistency/cognitive_consistency_dao.dart`
- `lib/cognitive_consistency/cognitive_consistency_models.dart`
- `lib/cognitive_consistency/cognitive_consistency_prompt_config.dart`
- `lib/cognitive_consistency/cognitive_consistency_source_status_card.dart`
- `lib/shame_transform/shame_transform_home_page.dart`
- `lib/external_data/todo_goal_pages.dart`
- `lib/goal_module/goal_action_runner_page.dart`
- `lib/concept_engine/action_engine/pages/action_execution_page.dart`

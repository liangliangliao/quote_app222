# 足下一致行动 V14：现代认知失调 + 足下真实自我联动落地说明

本次按《Cognitive Dissonance: 50 Years of a Classic Theory》产品方案直接落地开发，未重构旧功能，保留原有“最小充分理由 / 1 美元行动 / 行动证据内化”体系，在其上补充现代认知失调体系。

## 已落地

1. **AI 全局 Prompt 双核心融合**
   - 保留旧体系：最小充分理由、1 美元行动、行动证据内化、外部奖励降噪。
   - 新增体系：自由选择、负面后果、可预见性、责任感、自我标准、合理化识别、群体/文化失调、真实自我联动。

2. **输出结构扩展**
   - `CcPlanResult` 新增事件简述、责任—后果、自我标准、合理化、真实自我桥接等字段。
   - 兼容旧 JSON：旧字段仍然保留，AI 旧格式或本地兜底不会崩。
   - 支持新 JSON 嵌套解析：`dissonanceStructure / triggerConditions / responsibilityBoundary / selfStandards / rationalization / trueSelfBridge`。

3. **数据库结构补充**
   - 新增 `cc_dissonance_events`：保存失调事件结构。
   - 新增 `cc_trigger_conditions`：保存自由选择、后果、可预见性、责任、可修复性。
   - 新增 `cc_self_standards`：保存个人标准、规范标准、家庭/群体标准、理想自我标准、调整后标准。
   - 新增 `cc_rationalization_flags`：保存合理化类型、保护功能、长期代价、诚实改写。
   - 新增 `cc_true_self_links`：保存一致行动证据与真实自我证据墙之间的链路。

4. **页面呈现增强**
   - 在方案卡片中新增：
     - 事件简述
     - 责任—后果雷达
     - 自我标准地图
     - 合理化识别器 2.0
     - 足下真实自我联动
   - 旧的价值—行为—解释雷达、1 美元行动、行动陪伴、证据账本保持不变。

5. **足下真实自我联动**
   - 保存一致行动证据时，如果 AI 识别到羞耻/身份审判/过度自责/真实骄傲信号，会自动同步写入 `shame_evidence`。
   - 同时写入 `cc_true_self_links` 并通过 `cc_action_trace_links` 形成链路：`evidence -> shame_evidence`。
   - 同步内容包括：行动、身份解释、价值锚点、羞耻风险、真实骄傲句、恢复的积极情感、体现的能力。

## 涉及文件

- `lib/cognitive_consistency/cognitive_consistency_models.dart`
- `lib/cognitive_consistency/cognitive_consistency_prompt_config.dart`
- `lib/cognitive_consistency/cognitive_consistency_ai_service.dart`
- `lib/cognitive_consistency/cognitive_consistency_dao.dart`
- `lib/cognitive_consistency/cognitive_consistency_home_page.dart`

## 设计原则

- 不推翻旧模块。
- 不把足下真实自我模块并入一致行动模块。
- 两套价值体系并列融合：旧体系负责行动启动和证据内化，新体系负责责任、后果、自我标准、合理化与真实自我桥接。

# COGNITIVE_CONSISTENCY_V17_DEEP_STRUCTURED_LOOP

本轮在 v16 基础上继续落地 1-8 点，目标是把“现代认知失调专项场景”从可见入口推进到深度结构化、可追踪、可验证的业务闭环。

## 已落地

1. 专项表单必填校验
- 选择后合理化、沉没成本、价值—行为距离、群体/文化、替代性失调、责任—后果雷达、自我标准地图均要求至少填写两个核心字段。
- 补充背景不再能单独触发泛泛分析。
- 真实自我跳转一致行动时会自动预填价值、事件距离和最小行动字段，避免反向链路被校验卡住。

2. 专项结果结构化沉淀
- 新增 `cc_special_scene_items`，把 `choicePaths / sunkCostCheck / hypocrisyInduction / groupConflict / vicariousDissonance` 拆成 section/key/value 明细。
- 保留旧 `cc_special_scene_details` 作为兼容摘要表。

3. 合理化类型多行表
- 新增 `cc_rationalization_flag_items`。
- 一个 session 可对应多个合理化 flag，每条包含类型、证据句、保护功能、长期代价和修复动作。
- 长期画像改为优先统计多行表，不再只依赖字符串分割。

4. 自我标准多行表
- 新增 `cc_self_standard_items`。
- 一个事件可同时记录 personal / normative / family_group / ideal_self / adjusted 等多个标准来源。
- 记录是否可能过度僵硬、调整后标准与对应行动。

5. 真实自我稳定回链
- 真实自我结果页跳转一致行动时，sourceId 改为稳定 FNV 风格哈希 `shame_result_<scene>_<hash>`，不再使用运行期 `hashCode`。
- 一致行动保存证据时继续通过 `cc_true_self_links` 记录原真实自我来源与 shame_evidence。

6. `shouldSyncTrueSelf` 布尔字段
- AI 输出格式新增 `trueSelfBridge.shouldSyncTrueSelf` 与 `trueSelfBridgeReason`。
- 如果 AI raw JSON 明确包含 shouldSyncTrueSelf，则以布尔字段为准，不再依赖文本正则。
- 保留 legacy 正则仅用于旧 session 兼容。

7. 解释型/行动型降低失调标记
- AI 输出格式新增 `dissonanceReductionMode`：`explanation_only / action_repair / responsibility_repair / relationship_repair / value_alignment / avoidance_risk`。
- `cc_dissonance_events` 和 `cc_evidence_records` 均新增该字段。
- 报告页长期画像新增“解释型/行动型降低失调”统计。

8. 专项验证任务系统
- AI 输出格式新增 `verificationTask`，包含 question / successSignal / dueDays。
- 新增 `cc_verification_tasks` 表。
- 专项场景自动生成 3-7 天后现实验证任务。
- 专项场景页新增“专项验证任务”列表，可记录验证结果。

## 注意

当前环境没有 Flutter/Dart 命令，未执行 `flutter analyze` 或真机编译。已进行源码级结构检查、括号平衡检查和压缩包完整性校验。

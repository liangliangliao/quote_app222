# 足下一致行动 V18.2：1-4 点闭环补丁说明

本次基于 `v13work_cognitive_consistency_v18_1_full_loop_landed.zip` 继续增量落地，只处理审计后用户指定的 1-4 点，不推翻原有 V18.1 架构。

## 1. 三类行动组结构化

新增结构化模型：

- `CcActionVariant`
  - `actionType`
  - `label`
  - `title`
  - `steps`
  - `completionCriteria`
  - `linkedValue`
  - `rawText`

`CcPlanResult` 新增：

- `minimumActionVariant`
- `correctiveActionVariant`
- `evidenceActionVariant`

AI Service 不再只把 `actionSet.minimumAction / correctiveAction / evidenceAction` 压成字符串，而是同时解析为结构化行动对象。页面展示时会分开展示“行动名称 / 步骤 / 完成标准 / 对应价值”，按钮仍可继续“设为当前行动”和“写入 Todo”。旧字段 `minimumAction / correctiveAction / evidenceAction` 保留，用于兼容旧数据和旧页面。

## 2. 信息回避挑战改为 AI 个性化三分支

新增结构化模型：

- `CcInformationAvoidanceBranches`
  - `avoidedInformation`
  - `fearedResult`
  - `smallestContactAction`
  - `betterThanExpected`
  - `worseThanExpected`
  - `ambiguous`
  - `nextInformationAction`

`CcPlanResult` 新增：

- `informationAvoidanceBranches`

Prompt 输出格式新增 `informationAvoidanceBranches`，并扩展 `informationAvoidance` 本身，要求 AI 针对具体事件输出：

- 结果比想象好时如何处理；
- 结果确实不好时如何最小修复；
- 结果仍然模糊时补充哪个低成本信息源；
- 下一步信息行动。

页面 `_informationAvoidanceBranchCard()` 已改为读取 AI 个性化字段，不再只显示固定通用文案。

## 3. 身份冲突重构改为结构化旧身份—新身份对话

新增结构化模型：

- `CcIdentityDialogue`
  - `oldIdentity`
  - `oldIdentityVoice`
  - `oldIdentityProtection`
  - `newIdentity`
  - `newIdentityVoice`
  - `fearOfLoss`
  - `newIdentityAction`
  - `postActionIdentitySentence`

`CcPlanResult` 新增：

- `identityDialogue`

Prompt 输出格式新增 `identityDialogue`，并扩展 `identityConflict`，要求 AI 输出完整的旧身份—新身份对话结构。页面 `_identityDialogueCard()` 已改为展示旧身份声音、新身份声音、害怕失去、新身份行动和行动后解释语。

## 4. AI 即时结果页补齐失调强度自动求和

`cognitive_consistency_ai_service.dart` 新增：

- `_asDimensionScore()`：单项分数限制为 0-3；
- `_resolveIntensityTotal()`：如果 AI 没有返回 `totalScore`，自动把 8 个维度相加并限制为 0-24；
- `_normalizeIntensityLevel()`：统一等级为 `低 / 中 / 高 / 深层身份型`。

这样刚生成 AI 结果时就能正确显示失调总分和等级，不必等到 DAO 落库后再靠统计侧修正。

## 兼容性说明

- 旧字段全部保留。
- `toJson/fromJson` 已兼容旧字符串数据和新结构化对象。
- `evidenceCategory` 白名单补充 `information` 与 `identity`，避免信息回避和身份冲突证据被错误归类为 `start`。
- 本补丁没有修改原有 8 个 Tab 的整体结构，只增强 V18.1 的数据结构、解析逻辑和展示闭环。

## 建议本地验证

当前环境无法执行 Flutter 编译。建议本地运行：

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

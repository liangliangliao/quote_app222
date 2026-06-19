# PATCH_COGNITIVE_CONSISTENCY_SOURCEBOOK_V20

本补丁在 v19_sourcebook_cognitive_consistency_integrated 基础上，继续落地前一次审计提出的 P0 / P1 / P2 问题，目标是把《Theories of Cognitive Consistency: A Sourcebook》产品方案从“入口 + Prompt 化”推进到“结构化、流程化、数据化、可复盘化”的完整闭环。

## P0：关键闭环与结构化落地

1. 新增源书结构化数据表：
   - cc_sourcebook_cases
   - cc_cognition_nodes
   - cc_conflict_edges
   - cc_user_confirmations
   - cc_value_layer_records
   - cc_user_choice_records
   - cc_interpersonal_balance_records
   - cc_counter_attitudinal_experiments
   - cc_commitment_action_contracts

2. AI 输出格式升级为 V20：
   - 新增 sourcebookAnalysis 顶层结构。
   - 支持 protectedSelfImage、defensePatterns、cognitiveStructureMap、conflictTypeRouting、psychologicalFunction、valueLayers、alternativeInterpretations、realityTestingQuestions、userChoiceOptions、interpersonalBalance、counterAttitudinalExperiment、commitmentAction、reflectionQuestions、integratedSelfStatement。

3. 新增源书结构化保存逻辑：
   - 每次 AI 生成后自动保存为 sourcebook case。
   - 自动沉淀认知节点、冲突边、价值分层、用户选择、人际平衡、反态度实验、一致性行动契约。

4. 源书专项场景升级：
   - cognitive_structure_map
   - conflict_type_router
   - psychological_function
   - value_layering
   - interpersonal_balance
   - counter_attitudinal_experiment
   均纳入专项场景识别、Prompt 配置与验证任务体系。

5. 专项结果卡片升级：
   - 新增 V20 源书结构化闭环结果卡。
   - 可以展示认知结构节点、冲突边、心理功能、价值分层、三种可能解释、现实检验、用户选择、人际平衡、反态度行为实验、行动契约与复盘问题。

6. 用户确认 / 修正机制：
   - AI 输出后可以记录“确认分析基本准确 / 部分准确 / 需要重新修正”。
   - 确认结果写入 cc_user_confirmations，并同步更新 cc_sourcebook_cases。

7. 已修复审计中发现的小问题：
   - self_standard_map 字段重复与第 5 字段不显示问题。
   - Prompt 一键升级文案从 V18.5 更新为 V20。
   - 新增源书场景加入 _isSpecialScene。

## P1：业务闭环增强

1. 源书工作台从单纯菜单页升级为连续流程展示：
   - 输入事件 → 认知地图 → 矛盾分流 → 自我辩护 → 心理功能 → 价值分层 → 现实检验 → 行动契约 → 复盘整合。

2. 新增最近源书案例档案入口：
   - 在源书工作台中展示最近 5 个源书相关 session。
   - 点击可以回到对应分析结果。

3. 一致性行动契约结构化：
   - 保存核心价值、当前不一致行为、最小修正行动、时间、地点、时长、完成标准、障碍、失败预案、复盘问题。

4. 反态度行为实验结构化：
   - 保存旧信念、保护功能、限制、实验行动、完成标准、观察问题、新信念等字段。

5. 人际平衡分析结构化：
   - 保存我对他人的态度、对象/观点、我对对象的态度、对方态度、失衡点、平衡路径、边界行动。

6. Todo / 问题树深度入口增强：
   - Todo 行动步骤中新增“源书工作台”入口。
   - 问题树节点中新增“源书工作台”入口。
   - 便于从长期拖延、问题卡住、目标失衡直接进入认知一致性源书流程。

## P2：体验与可配置性增强

1. AI Prompt 设置页新增 6 个源书专项 Prompt：
   - 场景：认知结构地图
   - 场景：矛盾类型分流器
   - 场景：心理功能分析器
   - 场景：核心/外围分层
   - 场景：人际平衡分析
   - 场景：反态度行为实验

2. Prompt 配置系统新增对应 key 与默认模板，支持后续单独编辑。

3. 源书工作台新增长期档案基础字段，为后续统计以下画像打基础：
   - 最常被保护的自我形象
   - 高频自我辩护模式
   - 高频核心价值
   - 高频外围解释
   - 高频人际失衡类型
   - 最有效反态度行为

## 修改文件

- lib/cognitive_consistency/cognitive_consistency_prompt_config.dart
- lib/cognitive_consistency/cognitive_consistency_ai_service.dart
- lib/cognitive_consistency/cognitive_consistency_dao.dart
- lib/cognitive_consistency/cognitive_consistency_home_page.dart
- lib/pages/ai_prompt_settings_page.dart
- lib/external_data/todo_goal_pages.dart

## 校验说明

当前执行环境没有 dart / flutter 命令，无法在容器内运行 flutter analyze 或真实编译。已执行结构性检查：

- 修改文件的括号 / 中括号 / 大括号经字符串与注释感知扫描后均平衡。
- Prompt 版本、场景 key、DAO 表创建、源书结构化保存与 UI 调用链已做静态核对。

如在本地编译出现平台或 Flutter SDK 相关错误，优先以实际编译日志继续修复。

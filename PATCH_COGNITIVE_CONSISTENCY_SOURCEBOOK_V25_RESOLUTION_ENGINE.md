# PATCH_COGNITIVE_CONSISTENCY_SOURCEBOOK_V25_RESOLUTION_ENGINE

本补丁在 v24.2 buildfix 基础上，把“认知失调解决方法中心”从静态方法目录升级为“认知失调解决引擎”。

## P0 落地

1. 新增方法使用记录表 `cc_dissonance_resolution_method_usages`：
   - 记录 method_id、method_title、session_id、case_id、source_type、source_id、selected_reason、entered_scene_key、todo_step_id、evidence_id、status、review_text、effect_score、reduced_dissonance、produced_evidence、risk_note、next_use_suggestion。
2. 使用方法、写入 Todo、生成行动契约、产生证据、方法复盘都会写入/更新 usage。
3. `clearAllCognitiveConsistencyData()` 已纳入方法使用记录表。
4. 报告画像加入方法使用、方法闭环状态、方法转 Todo 数、方法产生证据数、平均效果评分。

## P1 落地

1. 解决方法中心新增本地诊断推荐器：用户输入当前失调后，推荐 1-3 个方法。
2. 每个方法支持：
   - 使用此方法：写入 usage 并进入对应专项场景。
   - 写入 Todo：绑定 methodId 与 Todo action step。
   - 生成行动契约：创建 sourcebook case + commitment contract。
3. 不同方法进入专项场景时采用专属字段预填映射，避免所有方法粗暴塞入同一套字段。
4. 专项分析完成后，usage 自动绑定 session/case。
5. 保存行动证据后，usage 自动绑定 evidence，并记录是否降低失调/产生证据。

## P2 落地

1. 方法中心新增筛选：全部、行动导向、解释/认知、现实检验、关系边界、身份/自我。
2. 方法使用历史新增复盘入口，用户可记录效果评分、防误用反思、下次使用建议。
3. 源书案例详情加入“使用过的解决方法”。
4. Prompt 版本升级为 `v25_dissonance_resolution_engine`。

## 编译说明

当前容器没有 flutter/dart，无法运行真实 flutter analyze 或 release build。已进行静态括号检查与私有方法缺失扫描。

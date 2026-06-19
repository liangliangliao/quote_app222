# V26 认知失调解决引擎闭环补丁

本轮在 v25 认知失调解决引擎基础上继续补齐 P0/P1/P2。

## P0
- `cc_dissonance_resolution_method_usages` 新增：
  - `contract_id`
  - `method_workflow_id`
  - `dissonance_type`
  - `sourcebook_support_level`
- “使用方法 → 专项分析/失调分析”成功后，主动把 active method usage 绑定到 `session_id` / `case_id`。
- 保存行动证据后清空 active method usage，避免后续无关证据污染上一轮方法流程。
- 方法复盘勾选“产生现实行动证据”时，自动写入 `cc_evidence_records` 并回写 `evidence_id`。
- 生成行动契约后将 `contract_id` 回写到 method usage。
- “开始一个完整源书案例”不再只是跳转，而是先创建 `sourcebook_case_draft` 与 `cc_sourcebook_cases` 草稿。
- 10 个方法加入 `sourcebook_support_level`，区分：原书直接机制 / 源书理论转译 / 产品化扩展。

## P1
- 新增失调类型诊断：价值—行为距离、信息回避、决策后/沉没成本、人际失衡、责任后果、自我完整性威胁等。
- 推荐器从纯关键词升级为“失调类型 + 方法适配”。
- 增加方法组合建议，例如自我完整性 → 现实接触 → 反态度实验 → 行动一致化。
- 10 种方法进一步补齐专项字段预填映射。
- 方法使用记录增加 workflow 维度，便于后续统一追踪一个方法流程。

## P2
- Prompt 设置页新增 6 个源书专项输出格式项。
- AI 专项场景会优先读取可配置输出格式，未配置时回退到内置精简 JSON。
- 源书案例列表增加搜索与快速筛选：使用过方法 / 有行动契约 / 有行动证据。
- 报告画像新增方法行动契约数、方法—失调类型分布、方法来源性质统计。

## 说明
当前容器无 dart/flutter，无法运行真实编译，只能进行静态结构检查。

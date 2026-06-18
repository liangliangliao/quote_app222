# PATCH: 足下一致行动 · 认知失调模块落地 V1

本次基于 Festinger & Carlsmith《Cognitive Consequences of Forced Compliance》核心价值体系完成产品落地：

## 新增模块
- 新增 `lib/cognitive_consistency/`：
  - `cognitive_consistency_home_page.dart`：足下一致行动首页，包含失调雷达、行动陪伴、身份证据账本、价值一致性报告四个 Tab。
  - `cognitive_consistency_ai_service.dart`：统一 AI 调用与本地兜底策略。
  - `cognitive_consistency_prompt_config.dart`：三层提示词配置（全局价值层、场景层、输出格式层）。
  - `cognitive_consistency_dao.dart`：本地 SQLite 表 `cc_sessions` 与 `cc_evidence_records`。
  - `cognitive_consistency_models.dart`：方案结果、会话、行动证据模型。

## 功能落地
- 价值/目标/阻力输入 → AI 生成“1 美元行动”。
- 认知失调分析：识别价值、行为、自我解释之间的不一致。
- 行动前承诺语、行动中提醒语、行动后解释语。
- 3 分钟行动陪伴计时器。
- 行动完成后写入“身份证据账本”。
- 最近行动证据生成“价值一致性报告”。
- 无 AI 配置时自动使用本地兜底方案，不阻塞产品使用。

## AI 提示词统一配置中心
- 已将本模块所有涉及 AI 的提示词接入 `AI 提示词配置中心`：
  - 全局价值层 Prompt
  - 目标转化为 1 美元行动
  - 认知失调分析
  - 行动前抗犹豫引导
  - 行动后自我解释
  - 外部奖励降噪
  - 自我欺骗与合理化识别
  - 价值一致性报告
  - 输出格式：通用 JSON 结构

## 入口
- 已在首页左侧抽屉新增入口：`足下一致行动`。
- 模块右上角提供快捷入口进入本模块 AI 提示词配置。

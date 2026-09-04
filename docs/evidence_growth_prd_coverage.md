# 六模块证据驱动成长系统覆盖矩阵

基线：PR #158 head `b278e4311153bb23688357a1c0ca81a6c87fbfe1`。

依据：《基于哈佛幸福课六大模块知识库的证据驱动智能成长系统_正式产品方案_v1.0》与《哈佛幸福课_六大模块成长闭环知识库_v3.5_Tal主线_专家延伸II正式整合版》。PDF 是 Source of Truth；K-Node 只做可执行结构化，不改写母库含义。

| 产品要求 | 实现 |
|---|---|
| 发现之旅统一入口 | `discover_page.dart` + `evidence_growth_discover_entry.dart` |
| 实战/复盘/学习/我的证据/设置 | `evidence_growth_home_page.dart` |
| 六模块成长闭环 | BELIEF→GOAL→ACTION→FAILURE→REVIEW→CHANGE，共用 Reality Trial |
| 60+ Tal 核心节点 | 73 个 K-TAL；六模块完整覆盖 |
| 专家延伸层 | 31 个 K-EXT1/K-EXT2，默认折叠，只在显式机制缺口时补位 |
| Tal-first / 最小充分知识 | 规则路由先选 Tal，扩展不得越级 |
| K-Node 完整字段 | ID、版本、模块、来源层、claim、mechanism、触发、反信号、前提、operator、边界、next、物理页/Lecture |
| E3/E2/E1/E0 | 正式路由保存证据等级；未知输入明确返回 `KB_EVIDENCE_INSUFFICIENT/E0` |
| Reality Trial | 预测、概率、窗口、节点、动作、完成定义、风险、结果、复盘、规则更新与决策完整持久化 |
| 单一现实动作 | 首屏只显示一个主动作；可在同一证据范围内换方案 |
| Stretch/Panic/Ruin | 耗竭先恢复；专业边界和不可逆下注硬拦截；AI 不得降级硬门 |
| 结果完整性 | 完成、部分、未做、中止都允许，不能伪造成完成 |
| 预测完整性 | 复盘逐字校验事前预测；AI 改写即回退本地复盘 |
| ACT/ADJUST/EXIT/OBSERVE | 结果后必须进入明确出口；ADJUST 只改一个变量；EXIT 保存 Hypothesis Closed 与学习 |
| 学习母树 | Tal 默认层、折叠专家层、搜索/筛选、是什么/为什么/怎么做/边界/来源/立即应用 |
| Personal Evidence | 激活、完成、失败样本、调整、退出、模块分布与个人节点适配度 |
| 公共/个人隔离 | Trial 只更新个人统计表，不修改公共 K-Node |
| AI Provider | 复用全局 `UnifiedAiService`；无配置或失败时离线路由与本地复盘仍可用 |
| 审计 | router logs、prompt runs、Trial Evidence、KB/Node/Prompt 版本 |
| 提醒 | 用户启用时才申请精准闹钟；稳定 alarm ID；点击直达对应 Trial；保存结果后取消 |
| 隐私 | 可关闭原始文本留存；JSON 导出；确认删除个人证据；公共知识不受影响 |
| 默认数据与验收 | 20 个案例；S1-S9、负向安全、预测完整性、知识隔离和 EXIT 测试 |

## 数据表

`evidence_growth_trials`、`trial_evidence`、`predictions`、`results`、`reviews`、`decisions`、`personal_node_stats`、`router_logs`、`prompt_runs`、`settings`。

个人适配度使用产品方案的工程初始权重：完成率 30% + 积极结果 25% + 可重复性 20% + 情境稳定性 15% + 时效性 10%。该分数不修改公共知识结论。

## 关键来源边界

- 六模块闭环与 Tal-first：KB35 p.62、p.194。
- Stretch 而非 Panic：KB35 p.94。
- 失败分类：KB35 p.175。
- 个人小试验不武断宣布因果：KB35 p.185-186。
- Ruin / 下一轮资格：KB35 p.190、p.195。
- ACT / ADJUST / EXIT：KB35 p.191。

## 验证

- `tool/evidence_growth_smoke.dart`：无 Flutter 依赖的确定性路由烟测。
- `test/evidence_growth/evidence_growth_router_test.dart`：知识完整性、S1-S9 与负向安全案例。
- `test/evidence_growth/evidence_growth_dao_test.dart`：SQLite 闭环、隐私、预测完整性、公共/个人隔离与 EXIT。
- `.github/workflows/evidence_growth_ci.yml`：Flutter 3.35.3 分析与专项测试。

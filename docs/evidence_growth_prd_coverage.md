# 六模块证据驱动成长系统覆盖与验收记录

基线：PR #158 head `b278e4311153bb23688357a1c0ca81a6c87fbfe1`；实现 PR #159。

依据：正式产品方案 v1.0 与 KB35 v3.5 正式整合版。PDF 为来源依据；工程操作符、系统推断和个人样本不能冒充原文结论。

**当前结论：主体代码已实现，尚未完成产品方案的全部功能与上线验收。** “有代码”不等于已部署或通过真实设备验收。下表保留未完成项，不以 APK 构建成功代替验收。

| 产品要求 | 当前覆盖与限制 | 主要实现 |
|---|---|---|
| 发现之旅统一入口与导航 | 实战、复盘、学习、我的证据、设置已接入；尚缺设备界面验收 | discover entry、home page |
| 六模块与 Tal 主线 | 173 个来源卡：142 Tal、21 EXT1、10 EXT2；包含原文、机制、情境、练习、边界和物理页码 | source cards、knowledge |
| 来源准确性 | 173 个节点的结论/练习/边界共 519 项全文定位通过，导入结果与代码一致；另有固定种子 30 条人工抽查，已修正 C02 等操作符误配；全部语义映射仍未完成独立验收 | source audit、KB importer |
| Tal-first 与证据 E0–E3 | 确定性规则先 Tal，显式缺口才补位；未知输入 E0；AI 不能引入未授权节点或降低硬门 | router、AI service |
| 搜索与多索引检索 | 中文分词、BM25、SQLite FTS、个人情境适配已实现；向量相似度仅有可选接口，尚未接入向量生成与完整多索引路由 | search、KB store、DAO |
| Reality Trial 全流程 | 创建、开始、结果、复盘、ACT/ADJUST/EXIT/OBSERVE；事前预测不可改写，下一轮链接与状态校验已实现 | models、DAO、review engine |
| 核心与高级操作符 | 操作符注册、动态输入、完成定义、承诺与暴露字段已实现；仍需逐操作符交互验收 | operator registry、home page |
| 风险与结果真实性 | Panic/Ruin/专业边界硬门；完成、部分、未做、中止、观察中；预测发生与目标有益独立记录 | router、DAO、AI service |
| 首屏与系统草案 | 本地路由先呈现，AI 异步补充受限字段草案；安全确认由用户填写 | home page、AI service |
| 学习母树与证据说明 | Tal 默认展示、专家折叠、筛选、来源、边界、案例与应用入口已实现 | home page |
| 个人证据与指标 | 激活、完成、失败样本、调整、退出、Brier、模块分布、节点适配；新增基于下一轮真实启动时间的恢复趋势、暴露日记和档案入口 | DAO、models、evidence history |
| 反馈与历史证据 | 依据问题分类、反馈队列、Trial 来源快照及历史节点反馈已实现 | DAO、home page |
| 知识版本维护 | Manifest/delta 校验、节点版本约束、原子安装与回滚、缓存失效回退已实现 | KB store |
| AI 与离线回退 | 复用全局 Provider；结构化校验、有限重试、超时及本地复盘；真实模型输出成功率未测定 | AI service |
| 五类提醒 | 原子持久化 outbox、AlarmManager + WorkManager 兜底、重启/授权恢复、触发前状态核对、窗口去重、单轮管理、通知直达；代码及 APK 已通过，真实设备杀进程/锁屏/重启未验收 | reminder plan/page、原生 ReminderNative |
| 审计与隐私 | 路由、提示词版本、时间线、JSON 剪贴板及文件导出、删除及删除同步队列；知识节点朗读及共享朗读配置已接入 | DAO、settings、read aloud |
| 产品规定的 11 个 API | 路由、Trial 生命周期、why、modules、node、summary、feedback 均有本地服务实现 | API、server/evidence_growth |
| 多设备同步 | HTTPS、加密凭据、幂等请求、离线重试；新增两端事实比较、版本选择、双方原记录归档与并发修改拒绝；服务未部署，实际双设备未验收 | sync service/page、API |
| 离线恢复 | SQLite 关闭重开后恢复已保存结果测试已通过；不代替设备杀进程测试 | DAO、regression test |
| 验收集 | S1–S9、负向路由、闭环、来源、版本、同步、HTTP 测试已加入；以对应提交的 CI 结果为准 | test/evidence_growth |
| 性能与发布门槛 | P95 < 2.5 秒、结构化输出成功率 99.5%、真实设备稳定性尚未测量 | 待验收 |

个人适配度采用工程初始权重：完成率 30% + 积极结果 25% + 可重复性 20% + 情境稳定性 15% + 时效性 10%。只更新个人统计，不修改公共知识。

## 已确认的远程验证

提交 `9551c1ae6238a50f665e021a81a2667ea18767f8` 已修复前轮两项失败，专项 CI 与 APK 均通过。

提醒提交 `52f254f66b2a62491b27ee5b54004180a1469871`：

- [Android release APK 构建成功](https://github.com/liangliangliao/quote_app222/actions/runs/34475260554)。
- [Evidence Growth CI 通过](https://github.com/liangliangliao/quote_app222/actions/runs/34475260539)：55 项测试通过，模块、集成及独立 API 分析通过。
- 最新代码提交 `2f2a751076b13f842f4d6062b1d3e63340ef00e1` 的 [Evidence Growth CI](https://github.com/liangliangliao/quote_app222/actions/runs/34486156155) 全部通过：60 项测试，模块、集成及独立 API 分析通过。涵盖后续朗读、图表、文件导出、冲突解决、未开始延期、历史知识快照及来源练习修正。真实提供方朗读、模型输出与设备交互尚未验证。
- 最新代码的 [Android release 构建](https://github.com/liangliangliao/quote_app222/actions/runs/34486155943) 结果以该运行记录为准，不能用旧 APK 替代。
- 提醒实现逐项记录见 `docs/evidence_growth_notifications.md`。

## 交付前仍需完成

1. 确认最新 release APK 并执行设备验收；专项测试与独立服务分析已通过。
2. 完成来源到操作符的全量语义映射核查和关键页面交互验收。
3. 补齐真实向量生成与多索引路由，并验证真实提供方输出；目前向量仅为可选接口，未接入可用 Embedding 配置。
4. 在配置好的服务环境和两台设备上验证同步、删除、提醒与中断恢复。
5. 测量并记录产品性能和真实 AI 输出质量门槛。

# 意志之镜 v2.8 基线与交付审计

## 基线

- 2026-10-13 拉取并 `fetch --all --prune`，最新主线 `ec8f7749`。
- 指定分支 `feature/will-mirror-v28-discovery` 从 `5405855d` 快进到该主线；不修改 main。
- `git branch -r --no-merged origin/main` 为空；GitHub 无开放 PR。V4/V5、向己、知行树、照见和发现页均已在主线。
- 需求原件在 [requirements](requirements)。PRD 的 v2.8 是产品规格版本，原代码 V5 是此前实现版本，二者不能等同。
- 当前技术栈为 Flutter 3.35.3、sqflite、Navigator、独立字段加密 Vault + Android Keystore。保留实际架构，不为采用建议的 Riverpod/Drift 重写宿主。

## P0 差距（开发前）

| 能力 | 原状态 | 实现位置 | 验证方向 |
|---|---|---|---|
| 发现页唯一入口 | 已有 | discover_page / will_mirror_discover_entry | 单入口与旧工具回归 |
| 本地私密数据、KB 来源权限 | 已有 | will_mirror_vault / knowledge_repository | 升级迁移、密文、清除 |
| 一句话创建统一课题、事实/信念/未知 | 部分：V5 目标和行动计划 | v28/case_* | 无问卷、共享 goalId |
| 欲求假设、反证、认知转换 | 部分：V4 假设/证据矩阵 | v28/case_* + 原证据工具 | 引用校验、不可读心 |
| 开放路线、独立适配/风险 | 部分：V5 三条行动模板 | v28/case_* | 安全先于分数、可增删路线 |
| 50–70 动机、Top5、可解释排序 | 缺失 | v28/case_analysis / case_ai | 去重、不凑数、反方、未知 |
| T0 封存、等待、T1 核验、T2 行动、T3 体验 | 缺失 | v28/case_workflow | 状态隔离、封存不变、多轮 |
| 真实历程、因果复盘、能力证据 | 部分：七日实验 | v28/case_page / case_workflow | 准备不等于完成、原因未知 |
| 个人原则候选、认可、应用、反证修订 | 缺失 | v28/case_* | 版本、授权、撤回传播 |
| 在线授权及结构校验 | 部分：统一 Provider 可复用 | v28/case_ai | 默认离线、最小上传、失败降级 |
| 日志隐私 | 缺口：统一日志保存正文 | utils/deepseek_logger | 私密模块不写普通日志 |
| Android 现场提示 | V5 无 Case 深链 | v28/case_reminders + 宿主通知路由 | 权限、离线、撤销、精确节点 |

## 官方接口核实

2026-10-13 阅读 [Decisions 指南](https://developers.openai.com/api/docs/guides/decisions) 和 [API 参考](https://developers.openai.com/api/reference/typescript/resources/decisions/methods/create)。公开 Beta 使用 `POST /v1/decisions`、`gpt-6-luna`；score 为等级索引的概率加权平均，答案按唯一 name 对齐，拒绝单独处理。API 不负责事实核实、Top5 组合或人格判断。线上账户权限、费用和时延需实际凭据验证；文档存在不等于已联调。

## 验收记录

开发后的逐项状态见 [acceptance.md](acceptance.md)，命令结果见 [validation.md](validation.md)，操作步骤见 [demo.md](demo.md)。不把单元测试替代真机通知矩阵、真人盲审或模型效果验证。

## P0 实现与验证（开发后）

| 能力 | 结果 | 代码 / 测试 |
|---|---|---|
| 单入口、原目标同 ID、旧工具保留 | 已接入，Widget 回归通过 | home/discover_entry；widget_test |
| 事实/信念/未知及认识/发生时间 | 已实现，未知不补写为刚发生 | case_models/workflow/page；v28_workflow/widget |
| 证据关联欲求、认识转换 | 数据结构与生成校验已实现；真实语义待评测 | case_ai/analysis；v28_ai |
| 动机池与 Top5 | 批量生成协议、去重、独立量规、反方与风险、降级可用；50–70质量待真实模型 | case_analysis/ai；v28_workflow/ai |
| 路线与风险/技能/可行性 | 已实现；新增事实和新轮次须重核条件 | case_workflow/page；v28_workflow |
| T0→T1→T2→T3、多轮与不可变历史 | 已实现；选择不伪造行动，准备与受阻可并存 | case_workflow/vault；v28_workflow/vault/widget |
| 个人原则、跨题复用、反例修订 | 已实现人工可核实闭环；自动多原则冲突推理待深化 | case_page/workflow/vault；v28_workflow/vault |
| 能力与现实边界 | 已能按任务记录证据/支持/下一步；自动机会匹配待深化 | case_models/workflow/page |
| 加密迁移、撤回与删除 | 已实现并通过替身密码器/SQLite边界回归；硬件密钥真机待核验 | vault/cipher；v28_vault |
| 提醒与语音 | 已接入宿主深链/通用锁屏文本/撤销；系统投递与TalkBack待真机 | case_reminders/notification_service；v28_widget |
| 最小授权、日志隐私、Decisions | 默认本地、单次许可、请求校验/取消、代理契约已实现；真实服务未部署 | case_ai/logger/proxy；v28_ai/test_proxy |
| 高级地图、动效、长期效果、资源图谱 | 未交付为已完成功能 | README 和逐项矩阵明确列出 |

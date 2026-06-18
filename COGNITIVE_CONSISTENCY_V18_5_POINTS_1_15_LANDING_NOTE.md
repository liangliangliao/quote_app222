# Cognitive Consistency V18.5 — 1-15 点数据反哺决策闭环落地说明

本版本基于 V18.4.1 编译修复版继续增量升级，重点从“数据保存完整”推进到“数据反哺决策完整”。

## 已落地

1. 周报输入继续扩展：在 modern_profile / daily_reviews 之外，新增温度复盘明细、信息接触结果、身份转换档案、自我完整画像、验证任务明细等 JSON 输入。
2. 周报 Prompt 已补齐对应占位符，要求 AI 依据证据链级明细而非仅画像级数据生成报告。
3. 温度复盘改为基于数据库中真实绑定的 before/after 温度日志生成，避免 UI 滑块临时值与已落库记录不一致。
4. AI 温度复盘增加 12 秒 timeout fallback，避免保存证据流程被长时间阻塞。
5. 信息接触结果进入单条 evidence card，可直接查看回避信息、害怕结果、真实结果、结果类型、灾难化校验和下一步修复。
6. 身份转换档案进入单条 evidence card，可直接查看旧身份、新身份、旧身份保护、害怕失去、新身份行动和行动后身份解释。
7. 信息接触结果支持编辑、删除。
8. 身份转换档案支持编辑、删除。
9. 信息接触后续修复行动支持一键写入 Todo。
10. 身份转换后的下一个新身份证据行动支持一键写入 Todo。
11. 价值地图趋势算法纳入 verification task 状态：verified / partial / invalid / adjust / exit / need_info 对趋势产生差异化影响。
12. Todo 写入 actionType 不再固定为 value，而是映射 minimum/corrective/evidence/information/identity 类型。
13. 自我完整画像保持展示，同时 modernPatternProfile 增加信息接触、身份转换、温度复盘模式统计。
14. 证据账本高级筛选加入专项筛选：信息回避、身份转换、自我完整、有温度复盘、缺温度复盘。
15. 新表增加 sourceType/sourceId/originScene 迁移字段，并为 V18 新表补充常用索引。

## 主要修改文件

- lib/cognitive_consistency/cognitive_consistency_models.dart
- lib/cognitive_consistency/cognitive_consistency_dao.dart
- lib/cognitive_consistency/cognitive_consistency_ai_service.dart
- lib/cognitive_consistency/cognitive_consistency_prompt_config.dart
- lib/cognitive_consistency/cognitive_consistency_home_page.dart

## 验证说明

当前执行环境没有 dart/flutter 命令，因此未能运行 flutter analyze / flutter build。已完成源码级括号/结构检查和 zip 完整性检查。

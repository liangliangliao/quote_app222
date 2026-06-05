# 训练舱版重构说明（V1）

## 本次落地内容

这次在源码中真正新增了“训练舱模式”的第一阶段页面流，不再只停留在旧版“虚拟世界大厅 + 普通挑战页”。

新增页面：
- `lib/concept_engine/cabins/training_hub_page.dart`
- `lib/concept_engine/cabins/training_intro_page.dart`
- `lib/concept_engine/cabins/training_prep_page.dart`
- `lib/concept_engine/cabins/training_action_page.dart`
- `lib/concept_engine/cabins/training_result_page.dart`
- `lib/concept_engine/cabins/training_consolidation_page.dart`
- `lib/concept_engine/cabins/training_cabin_models.dart`

并在 `concept_engine_home_page.dart` 中新增入口：
- 进入训练舱大厅
- 开始普通练习
- 旧版虚拟世界大厅

## 训练舱当前结构

每个训练舱统一走 6 阶段：
1. 进入舱
2. 准备台
3. 行动舱
4. 冲击层（当前先融入行动舱中的异常事件/风险提示）
5. 结算层
6. 固化层

## 已支持的首批训练舱

- 延期汇报舱
- 边界表达舱
- 自律启动舱

## 现有能力复用

训练舱模式复用了原有能力：
- DeepSeek / OpenAI / 代理模式
- 概念解析
- 场景生成
- 多轮互动
- 评分与复盘
- 练习记录入库
- 世界奖励 / XP / 成就
- 日志记录

## 当前仍未完成的部分

- 独立的冲击层全屏弹层
- 成长档案专页
- 训练舱流程的更细粒度本地状态持久化
- 针对训练舱的专属日志筛选标签
- 训练舱主题化视觉动画

## 建议下一步

1. 将“延期汇报舱”做成完整的高保真示例舱
2. 把冲击层从 ActionPage 中独立为弹层/对话框
3. 增加训练舱记录筛选与成长档案页
4. 让训练舱的准备台结果参与后端代理请求，形成更稳定的一致体验

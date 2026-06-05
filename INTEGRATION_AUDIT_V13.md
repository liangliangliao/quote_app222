# INTEGRATION AUDIT V13

本次继续在 v12 训练舱第一阶段基础上推进，重点不是新增一批空壳页面，而是把以下 3 件事真正落到源码：

1. 延期汇报舱高保真行动面板
2. 冲击层弹层（Impact Overlay）
3. 训练舱成长档案页

## 本次新增内容

### 1. 延期汇报舱高保真版
文件：`lib/concept_engine/cabins/training_action_page.dart`

新增：
- 延期汇报专属“高保真压力板”
- 当前阶段提示（开场承担 / 时间压缩 / 高压解释 / 补救承诺）
- 关键事实与优先风险展示
- 准备台结构回显
- 一句话模板快捷填充

### 2. 冲击层弹层
文件：`lib/concept_engine/cabins/training_action_page.dart`

新增：
- 当训练过程中出现新的 triggered events 时，自动弹出 BottomSheet
- 冲击层会显示：
  - 当前冲击事件
  - 当前风险 / 信任 / 时间 / 推进状态
  - 对用户的现实提醒
- 延期汇报舱会显示更贴近现实的解释提示

### 3. 训练舱成长档案页
文件：`lib/concept_engine/cabins/training_growth_archive_page.dart`

新增：
- 成长总览
- 成功率 / 平均分 / 最近模型
- 最常训练领域
- 薄弱点统计
- 自动训练建议
- 最近关键训练记录入口

### 4. 入口补充
文件：
- `lib/concept_engine/cabins/training_hub_page.dart`
- `lib/concept_engine/concept_engine_home_page.dart`
- `lib/concept_engine/cabins/training_consolidation_page.dart`

新增：
- 训练舱大厅可直接进入成长档案
- 概念实践引擎首页新增“训练成长档案”入口
- 固化层新增“查看成长档案”入口

## 当前训练舱模式进度

### 已完成
- 训练舱大厅
- 进入舱
- 准备台
- 行动舱
- 冲击层弹层
- 结算层
- 固化层
- 延期汇报舱高保真版（第一版）
- 成长档案页（第一版）

### 仍待继续
- 边界表达舱高保真版
- 自律启动舱高保真版
- 冲击层的更强倒计时/震动/动画
- 训练舱过程分阶段入库
- 成长档案的更细粒度能力画像
- 准备台数据对后端代理链路的更深参与

## 建议本地验证
1. 训练舱大厅是否出现“成长档案”入口
2. 首页是否出现“训练成长档案”按钮
3. 延期汇报舱是否出现高保真压力板
4. 行动过程中若出现新的异常，是否弹出冲击层
5. 固化层是否出现“查看成长档案”
6. 成长档案页是否能打开并显示最近训练与薄弱点

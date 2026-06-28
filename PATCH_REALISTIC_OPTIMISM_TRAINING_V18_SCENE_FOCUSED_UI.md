# PATCH_REALISTIC_OPTIMISM_TRAINING_V18_SCENE_FOCUSED_UI

## 修复目标
针对“解决问题”子模块中内部训练工具过多、用户难以理解、不同选项生成结果看起来差不多的问题，按最终版产品设计方案做场景化修复。

## 已修复
1. 解决问题页不再把 13+ 内部工具平铺为普通入口。
2. 普通用户入口压缩为 4 个高频场景：
   - 我今天遇到不顺了 → 今日事件重构
   - 我现在很难受，想先缓一下 → Permission to Be Human
   - 我有个目标一直拖着 → 过程模拟行动器
   - 我失败了，想复盘一下 → 失败免疫
3. 事件强度分级、解释风格雷达、Fault/Benefit 双镜头、身份沉淀改为后台机制说明，不再作为普通用户主入口。
4. Prime / Anti-Prime、感恩与品味、幸福基线周报在文案上明确移动到环境、记录、周报等长期训练页面。
5. 训练结果页按 scene 聚焦展示，不再默认把所有内部模块平铺出来：
   - process_action 重点展示过程路径、If-Then、5 分钟行动。
   - failure_immunity 重点展示预测痛苦、实际恢复、心理抗体。
   - emotion_container 重点展示情绪承认和稳定动作。
   - gratitude_savoring 重点展示具体感恩与 30 秒品味。
6. 修复核心业务流生成时总是传 event_reframe 的问题，改为传入实际 initialScene。
7. 修复本地 fallback 中 process_action 和 failure_immunity 缺少专属场景补全的问题。
8. Prompt 输出质量层增加“scene 区分主次”的强约束，避免统一 JSON 被误用为统一大报告。

## 产品原则
统一 JSON 是数据契约，不代表用户结果页要把所有模块同等展示。用户看到的是少数场景入口，AI 在背后自动调用内部工具。

# PATCH_YANGMING_V38_DAILY_LOOP

本次继续按原 PRD 推进，把“周期训练计划”从静态计划升级为可执行闭环：

- 每日打点：每一天都可记录事实与反思，并单独保存
- 进度追踪：显示已完成天数与整体进度条
- AI 周中纠偏：根据课程、原文、详细解释、人格画像、训练计划和每日打点，给出当前训练模式、保持点、调整点、未来3天重点与提醒
- AI 周末总结：根据同样的上下文，给出完成情况、最大变化、反复障碍、下周重点与提醒
- 持久化：新增 training traces 存储，仅保存每个计划的执行轨迹、纠偏摘要与周总结

主要改动文件：
- lib/yangming_module/yangming_models.dart
- lib/yangming_module/yangming_dao.dart
- lib/yangming_module/yangming_ai_service.dart
- lib/yangming_module/yangming_module_home_page.dart

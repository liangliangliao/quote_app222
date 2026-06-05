# Yangming v35 - AI 动态分支接入状态机

本次更新把“知行书院”虚拟世界从固定四轮状态机，继续推进到“AI 动态分支”模式：

- 关卡页新增“AI 动态分支”输入区
- 用户可输入当前真实困扰
- 系统基于课程原文、详细解释、课程元数据与当前默认状态机，调用宿主 App 现有 OpenAI / DeepSeek 生成动态分支
- 动态分支会替换第 2 轮（结构辨认）和第 3 轮（现实迁移）
- 关卡总结页会优先使用动态分支生成的现实迁移动作与复盘问题

涉及文件：
- lib/yangming_module/yangming_models.dart
- lib/yangming_module/yangming_ai_service.dart
- lib/yangming_module/yangming_module_home_page.dart

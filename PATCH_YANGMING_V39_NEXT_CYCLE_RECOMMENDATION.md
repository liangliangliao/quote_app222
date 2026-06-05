# Yangming Module Patch v39

## 本次推进
- 在训练执行台新增“下一周期推荐”区块
- 支持 AI 基于当前课程、人格画像、每日打点、周中纠偏、周末总结生成：
  - 推荐课程
  - 推荐天数（3/7/14 天）
  - 推荐摘要
  - 为什么是这段课 / 为什么是这个天数
  - 下一轮训练重点
  - 起手动作
  - 下一轮复盘问题
- 支持一键按推荐生成新的周期训练计划

## 主要修改文件
- lib/yangming_module/yangming_models.dart
- lib/yangming_module/yangming_ai_service.dart
- lib/yangming_module/yangming_module_home_page.dart

## 说明
- 仍复用宿主应用现有 OpenAI / DeepSeek 配置
- 仍作为左侧菜单中的独立模块存在
- 本次为源码级推进，未在当前环境执行完整 Flutter 编译验证

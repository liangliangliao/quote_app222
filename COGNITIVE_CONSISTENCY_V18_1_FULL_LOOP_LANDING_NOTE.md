# 足下一致行动 V18.1 完整闭环落地说明

本次基于 V18 自我完整版本继续增量落地审计发现的 1-12 点，保持原有 8 个 Tab 和既有两套价值体系不变，在第三套“自我完整—成长性一致—认知重构体系”基础上补齐实践闭环。

## 已落地

1. 每日一致性复盘从 AI seed 升级为可填写、可保存、可读取、可在报告页展示的业务闭环。
2. 失调温度计扩展为行动前/行动后两阶段维度，补齐内疚、焦虑、羞耻、防御感、责任感等字段，并支持单独记录行动前温度。
3. 三类行动组支持“设为当前行动”和“写入 Todo”，不再只是展示文本。
4. 价值—行为一致性地图改为 DAO 聚合：结合价值链接、证据、失调类型、失调强度、温度变化和修复证据。
5. 新增 V18 详情读取：按 session 读取失调类型、强度、成长性解释、自我完整卡；按 evidence 读取温度日志。
6. Todo / 问题树回写补入 V18 字段：失调类型、强度、防御性解释、成长性解释、自我完整卡、信息回避、身份冲突、三类行动、温度变化。
7. 信息回避挑战新增结果分支：结果好、结果坏、结果模糊分别如何处理。
8. 身份冲突重构新增旧身份—新身份对话卡。
9. 失调强度评分拆分单项 0-3 与总分 0-24，并统一低/中/高/深层身份型等级。
10. 信息回避、身份冲突、每日复盘、温度复盘进入 AI Prompt 设置页，可编辑可恢复默认。
11. 周报 AI 输入吸收 V18 画像数据和最近每日复盘。
12. 证据账本每条证据显示 V18 失调修复证据、温度变化、自我完整证据和成长性解释。

## 修改文件

- lib/cognitive_consistency/cognitive_consistency_models.dart
- lib/cognitive_consistency/cognitive_consistency_dao.dart
- lib/cognitive_consistency/cognitive_consistency_home_page.dart
- lib/cognitive_consistency/cognitive_consistency_ai_service.dart
- lib/cognitive_consistency/cognitive_consistency_prompt_config.dart
- lib/pages/ai_prompt_settings_page.dart

## 注意

当前容器没有 dart/flutter 命令，未能执行 flutter analyze 和 build。已做源码级括号/引用/主要调用链检查。建议本地继续执行：

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

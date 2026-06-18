# 足下一致行动模块 V18 落地说明

本次在既有 v17 足下一致行动模块基础上做增量升级，不推倒原有 8 个 Tab 与两套核心价值体系，而是新增第三套“自我完整、成长性一致与认知重构体系”。

## 保留的两套既有体系

1. 最小充分理由与行动证据内化体系：继续保留 1 美元行动、行动前承诺、行动中提醒、行动后解释、证据账本、奖励降噪与 Todo/问题树回写。
2. 现代认知失调、自我标准与责任修复体系：继续保留责任—后果雷达、自我标准地图、合理化识别、专项场景、真实自我桥接与专项验证任务。

## 新增的第三套体系

第三套体系强调：认知失调不是坏事本身，而是行为、信念、价值、自我形象、后果和身份之间出现不一致的信号。系统新增“防御性一致 vs 成长性一致”“自我完整卡片”“信息回避挑战”“身份冲突重构”“失调强度雷达”“失调温度计”“矛盾同时可及”“三类一致性行动组”和“价值—行为一致性地图”。

## 主要落地文件

- `lib/cognitive_consistency/cognitive_consistency_models.dart`
  - 为 `CcPlanResult` 增加 V18 字段。
  - 新增失调温度与价值一致性快照模型。

- `lib/cognitive_consistency/cognitive_consistency_dao.dart`
  - 新增 V18 SQLite 表：失调类型、失调强度、防御/成长解释、自我完整卡片、失调温度计、每日复盘。
  - 保存 AI 分析结果时同步落库 V18 结构。
  - 保存行动证据时支持失调温度计记录。
  - 报告画像新增失调类型、强度、温度、自我完整与成长重构统计。
  - 清空模块数据时同步清理新增表。

- `lib/cognitive_consistency/cognitive_consistency_ai_service.dart`
  - AI JSON 解析新增 V18 字段。
  - 本地兜底方案新增 V18 结构。
  - 专项场景新增信息回避挑战与身份冲突重构。

- `lib/cognitive_consistency/cognitive_consistency_prompt_config.dart`
  - 全局背景 Prompt 从“两套核心价值体系”升级为“三套核心价值体系”。
  - 默认失调分析 Prompt 增加失调类型、强度、温度、自我完整、矛盾同时可及、三类行动组输出要求。

- `lib/cognitive_consistency/cognitive_consistency_home_page.dart`
  - 失调雷达新增结构化认知失调记录器。
  - 方案卡新增 V18 成长性一致卡与三类行动组卡。
  - 专项场景新增信息回避挑战与身份冲突重构。
  - 行动陪伴新增行动前/后失调温度计。
  - 价值罗盘新增价值—行为一致性地图。
  - 一致性报告新增 V18 画像统计展示。

## 注意

当前运行环境没有 `dart` / `flutter` 命令，无法执行 Flutter 编译或 `flutter analyze`。已进行源码级结构检查，包括新增 Dart 字符串、括号、方法定义和调用链的静态排查。建议在本地执行：

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

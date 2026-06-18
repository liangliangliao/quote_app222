# 足下一致行动 V10：系统闭环收口与可见性修复

本版针对 V9 继续修复与增强，重点按“用户看得见、点得到、能回写、能复盘”标准处理。

## 已修复

1. 修复 `cognitive_consistency_home_page.dart` 中奖励降噪、诚实校验初始化文本的跨行字符串编译问题。
2. 修复 `cognitive_consistency_dao.dart` 中 `saveEvidence()` 的多余 `}`，避免 Dart 语法报错。
3. 删除价值档案时同时清理 `cc_source_value_links`，避免 Todo / 问题树来源残留已删除价值。
4. 从 Todo / 问题树进入奖励降噪、诚实校验后，生成行动不会再把来源覆盖成 `external_reward_detox` 或 `self_deception_check`；会保留原 Todo / 问题树来源链路。
5. 从 Todo / 问题树返回后会尝试触发调用处重建，使“一致行动证据数量”更容易及时刷新。
6. Todo / 问题树的一致行动证据状态卡支持点击查看详情，展示完整证据、旧解释、新解释、行动反思、价值连接。
7. 从 Todo / 问题树带入的 `initialValues` 会尝试自动识别常见价值，并建立 source-value 强关联；缺少价值档案时会自动创建基础价值档案。
8. `sourceValueLabels()` 增加 evidence 文本兜底，避免老数据或弱关联数据下 Todo 卡片“关联价值”为空。
9. 行动陪伴页新增“把当前 1 美元行动写入 Todo 今日行动”，用于报告生成行动、失调雷达行动继续沉淀到 Todo 计划。

## 仍需真实构建验证

当前环境没有 `flutter` / `dart`，无法执行真实编译。建议本地运行：

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

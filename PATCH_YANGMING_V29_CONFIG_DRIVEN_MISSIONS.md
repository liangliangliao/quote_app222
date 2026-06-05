# Yangming Module Patch v29 - Config Driven Mission Engine

本次继续基于原 PRD 推进，重点把“知行书院”的多轮状态机关卡推进为**配置驱动**：

## 本次改动
- 新增 `assets/yangming_module/mission_state_machines.json`
  - 为 27 段课程生成了对应的状态机配置资产
  - 每段包含 4 轮结构：情境进入 / 结构辨认 / 现实迁移 / 守持补救
  - 每轮包含可配置 prompt、guide、choices、feedback、score delta
  - 每段包含 high / mid / low 三档总结模板
- `yangming_models.dart`
  - 新增 `YangmingMissionConfig`
  - 新增 `YangmingMissionSummaryProfile`
  - 新增 `YangmingMissionRouteProfile`
  - 新增资产加载函数 `loadYangmingMissionConfigs()`
  - `buildMissionRounds()` 支持优先读取配置资产，缺失时回退到代码默认生成
  - `summarizeMissionRun()` 支持优先读取配置资产中的总结模板
- `yangming_module_home_page.dart`
  - 模块加载时会同步读取 mission config 资产
  - 进入关卡时传入对应 lesson 的 missionConfig
  - 虚拟世界页增加“已加载状态机配置数量”展示
  - 修正状态机页面中重新演练时的重复 clear 残留
- `pubspec.yaml`
  - 注册 `assets/yangming_module/mission_state_machines.json`

## 这一步对应原 PRD 的意义
原 PRD 里要求虚拟世界不是装饰，而是围绕 27 段理论形成可训练、可扩展、可持续升级的操练系统。
这次推进的核心意义是：

1. 关卡不再主要依赖写死页面逻辑，而开始变成可配置资产。
2. 后续可以在不重写页面的前提下，继续扩展每段课程的多轮剧情。
3. 为下一步的“AI 动态分支 / 人格映射 / 用户真实问题驱动剧情”打下基础。

## 注意
当前仍是源码级推进。由于本环境没有 Flutter 构建器，本次未在此处执行完整 Flutter 编译验证。
建议在本地执行：
- flutter pub get
- flutter run 或 flutter build
并检查：
- 新增 asset 是否已被正确打包
- 虚拟世界页是否能显示 27/27 的配置加载数量
- 进入任一关卡时是否仍可正常完成 4 轮状态机与行动迁移

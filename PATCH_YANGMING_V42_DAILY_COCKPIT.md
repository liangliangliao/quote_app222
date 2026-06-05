# PATCH_YANGMING_V42_DAILY_COCKPIT

本次继续按原 PRD 推进，把知行书院首页从“成长导航”进一步升级为“每日知行驾驶舱”。

## 新增能力
- 首页新增每日知行驾驶舱卡片
- 支持展示：今日焦点、今日最小行动、今日训练入口、今晚复盘问题
- 支持打开今日课程 / 进入今日关卡 / 继续今日训练
- 支持 AI 刷新今日建议
- 新增 `YangmingDailyCockpitResult` 数据结构
- 新增每日驾驶舱持久化：`yangming_latest_daily_cockpit_v1`
- 新增 AI 结构化生成：`generateDailyCockpitStructured(...)`
- 周总结 / 下一周期推荐写回首页导航时，同步写入每日驾驶舱

## 主要文件
- lib/yangming_module/yangming_models.dart
- lib/yangming_module/yangming_dao.dart
- lib/yangming_module/yangming_ai_service.dart
- lib/yangming_module/yangming_module_home_page.dart

## 说明
当前环境没有 Flutter / Dart 构建器，本次为源码级推进，需在本地执行 `flutter pub get && flutter run` 验证。

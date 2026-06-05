# 健康饮食每日定时 Agent 编译修复

本次根据构建日志修复两个 Dart 编译错误：

1. `health_diet_realtime_state_service.dart` 使用 `DailyDietReview` 类型但未直接导入其定义文件。
   - 已补充：`import '../models/daily_diet_entry.dart';`
   - 原因：Dart 的 import 不具备传递导入能力，不能依赖 `daily_diet_review_service.dart` 间接暴露模型类型。

2. `health_diet_daily_scheduler_service.dart` 中通知 id 被推断为 `num`，但 `NotificationService.show` 需要 `int?`。
   - 已把 `math.max(...)` 改为显式 int 计算。
   - 避免 `dart:math` 的 `max` 导致类型推断偏宽。

涉及文件：

- `lib/health_diet/services/health_diet_realtime_state_service.dart`
- `lib/health_diet/services/health_diet_daily_scheduler_service.dart`

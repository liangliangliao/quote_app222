# 验证记录（2026-10-13）

环境：Flutter 3.35.3 / Dart 3.9.2，与现有 CI 一致。使用 SQLite FFI、本地 HTTP 模拟服务、AI Provider 替身；没有真实 API key、没有调用付费模型。

| 检查 | 当前结果 |
|---|---|
| 意志之镜旧版 + v2.8 单元/Widget/Vault/AI 契约 | 50 项通过 |
| 连同修复的旧看板、beautiful_enemy 测试 | 83 项通过 |
| 修改范围 Dart 静态检查 | 通过，无问题 |
| 全仓 `flutter analyze --no-pub` | 已执行；最初 79 个 error 已修复，最终 0 error、1243 个原项目 warning/info；命令仍非零退出，不宣称全仓无告警 |
| 可选 Python Decisions 代理 | 5 项通过，包括服务端答案名称校验 |
| Android arm64 release APK | 已配置 SDK 36 / NDK 27 并尝试；依赖下载遇 Google Maven HTTP 503，尚未产出 APK |
| 原 GitHub Actions | 将随功能分支/PR 执行；以实际运行记录为准 |
| 真机/真实模型/长期效果 | 未执行，参见逐项矩阵和演示待核验清单 |

核心命令：

```bash
flutter pub get
dart analyze lib/will_mirror test/will_mirror lib/services/notification_service.dart lib/utils/deepseek_logger.dart
flutter test test/will_mirror
flutter test test/will_module/will_dashboard_support_test.dart test/beautiful_enemy/enemy_presence_test.dart
python3 -m unittest discover -s server/will_mirror_decisions -p 'test_*.py' -v
flutter analyze --no-pub
flutter build apk --release --no-pub --target-platform android-arm64
```

新回归文件：`v28_workflow_test.dart`（时序/风险/排序/原则/撤回/现实边界）、`v28_vault_test.dart`（v1 迁移、加密边界、乐观锁、不可变历史、跨课题传播、整库删除）、`v28_ai_test.dart`（最小授权、取消、失败降级、Decisions 名称/分值/概率、私密日志）、`v28_widget_test.dart`（手机操作、提醒不伪造触发、失效链接、大字体）。全部位于 `test/will_mirror/`。

基线修复范围：`will_dashboard_support.dart` 的 `title/zoneTitle` 误用导致 57 个级联编译错误；看板测试仍导入旧包名；`enemy_presence_test.dart` 缺少 `LocalFactOracle` 的导入。修正后发现其迁移测试复用了已有 in-memory 数据库，已改为独立连接来真实模拟 v1。修复未改变这些模块的业务规则，33 项相关测试通过。

云环境说明：测试进程需要本地 loopback socket；SQLite 使用系统 `libsqlite3.so.0` 的本地链接。Android 工具使用独立可写 SDK/Gradle 缓存与代理 CA，没有把环境配置或凭证写进仓库。下载故障不是功能测试通过的证据，构建失败也未标记为已发布。

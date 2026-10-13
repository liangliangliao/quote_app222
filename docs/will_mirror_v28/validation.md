# 验证记录（2026-10-13）

环境：Flutter 3.35.3 / Dart 3.9.2，与现有 CI 一致。使用 SQLite FFI、本地 HTTP 模拟服务、AI Provider 替身；没有真实 API key、没有调用付费模型。

| 检查 | 当前结果 |
|---|---|
| 意志之镜旧版 + v2.8 单元/Widget/Vault/AI 契约 | 50 项通过 |
| 连同修复的旧看板、beautiful_enemy 测试 | 83 项通过 |
| 修改范围 Dart 静态检查 | 通过，无问题 |
| 全仓 `flutter analyze --no-pub` | 已执行；最初 79 个 error 已修复，最终 0 error、1243 个原项目 warning/info；命令仍非零退出，不宣称全仓无告警 |
| 可选 Python Decisions 代理 | 5 项通过，包括服务端答案名称校验 |
| Android release APK | GitHub PR 与 push 构建均成功；产物 `quote_app-apk` 已上传，见下方链接 |
| 原 GitHub Actions | 源码提交 `580e0619` 的 11 个 PR workflow 全部通过，包含旧模块回归、APK 构建及既有密钥扫描 |
| 中文手机渲染 | 使用 CJK 字体审阅 390×844 四个工作台页面；无布局溢出，非真机截图 |
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

远程验证均对应源码提交 `580e06195305d5202832da06402b16cc64bdb3cf`（后续交付记录仅更新文档）：

- [PR #172](https://github.com/liangliangliao/quote_app222/pull/172)，保持 draft，尚有专项验收和高级功能未完成。
- [意志之镜 v2.8 / V5 回归通过](https://github.com/liangliangliao/quote_app222/actions/runs/38383308057)。
- [Android release 构建通过及 APK 下载](https://github.com/liangliangliao/quote_app222/actions/runs/38383307974/artifacts/11804059420)。产物 ZIP SHA-256：`1b159aee5d265154407b0941a30b403d7a72127c9711a1c2a8bd7728ca61d9ca`；这是构建验证包，未做真机安装验收或正式发布。
- [宿主心理体检测试、发现页检查、APK 构建与既有密钥扫描通过](https://github.com/liangliangliao/quote_app222/actions/runs/38383308046)。其余既有模块检查可在 PR Checks 查看。

基线修复范围：`will_dashboard_support.dart` 的 `title/zoneTitle` 误用导致 57 个级联编译错误；看板测试仍导入旧包名；`enemy_presence_test.dart` 缺少 `LocalFactOracle` 的导入。修正后发现其迁移测试复用了已有 in-memory 数据库，已改为独立连接来真实模拟 v1。修复未改变这些模块的业务规则，33 项相关测试通过。

云环境说明：测试进程需要本地 loopback socket；SQLite 使用系统 `libsqlite3.so.0` 的本地链接。Android 工具使用独立可写 SDK/Gradle 缓存与代理 CA，没有把环境配置或凭证写进仓库。初次本地编译遇 Maven HTTP 503，随后发现环境仅有 Java 运行时；已补齐 JDK 17 并重试。交付的可下载 APK 以 GitHub 成功构建产物为准，构建成功不等于已发布或完成真机验收。

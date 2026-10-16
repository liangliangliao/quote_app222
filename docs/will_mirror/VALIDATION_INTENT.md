# 2026-10-16 渐进工作台与闭环复核

基线：指定 PR #173 分支 `a02ba5ec`；main@ec8f7749。本轮实现与未完成矩阵：[INTENT_REDEVELOPMENT.md](INTENT_REDEVELOPMENT.md)。

| 实际执行的检查 | 结果与证据 |
|---|---|
| `flutter analyze --no-pub lib/will_mirror test/will_mirror integration_test/will_mirror_storage_test.dart test_driver/will_mirror_storage_driver.dart` | **无问题**；[日志](evidence/2026-10-16-intent-analyze.log) |
| `flutter test --no-pub --reporter expanded test/will_mirror` | **122 项通过**（新增 15 项，原 107 项保留）；[日志](evidence/2026-10-16-intent-tests.log) |
| `python -m pytest -q server/will_mirror/test_contract.py` | **12 项通过**，1 条上游 TestClient 弃用提示；[日志](evidence/2026-10-16-intent-server.log) |
| T1—T366 索引与 24 个合成案例 | 索引校验通过；原索引保留；[本轮补充对照](intent_acceptance_links.json) 仅列实际新增回归范围，没有把真人、模型或设备验收改为通过 |
| 首轮全仓静态检查 | **0 error、429 warning、816 info**；命令因原有告警非零退出 |
| 首轮全仓测试 | **1063 通过、5 失败**；五项属于未改动的 beautiful_enemy |
| 原分支独立复现五项失败 | 在 detached a02ba5ec 上独立执行两个 beautiful_enemy 文件：**53 通过、相同 5 失败**；[基线日志](evidence/2026-10-16-baseline-enemy-tests.log) |
| 最终全仓复核 | **1070 通过、相同 5 失败**；与基线五项失败名称完全一致；[最终摘要](evidence/2026-10-16-intent-full-summary.log) |
| Flutter 手机渲染 | 390×844 中文界面已检查：理解、冲突、认知转换、路线；首页、未知、人生轨迹回归预览保持。320 宽、1.8 倍文字的冲突视图无溢出 |
| 本地 Android release APK 尝试 | 已执行，**因本环境没有 Android SDK 终止**；[日志](evidence/2026-10-16-intent-local-build.log)。不声称本地 APK 编译通过 |
| GitHub Actions / Android API 26、35 / APK | 推送后沿用现有工作流。以 PR Checks 真实状态为准；不能用本地单测替代 Android 原生验收 |
| 真实模型与用户原设备 | **未执行**；没有新增密钥、付费调用、代理部署或合并 main。仍需现场体验与真实生成质量校验 |

## 新回归具体保护什么

- 首轮只执行理解和欲求，已有理解单独落库；不会在用户校对前自动启动 50 项候选工作流。
- 指定路线逐条写回，结果不能写错到另一条路线；重试范围不得变成整个流程。
- 路线新版本替代旧版后，旧理由不占用本轮候选池、不压制新版本去重、不保留失效选择；原历史记录保留。
- 同一动机的正反方向按路线保持，不能全局判成正向/反向。
- 关键新事实使旧预案失效，封存历史字节保持；完成行为不补造决意、尝试或满意。
- 原则遇到新条件或下一轮须重新匹配；打开、采用、结果仍分别记录。
- 认可新认识会使相关两条路线待复核，另一条评估保留；路线比较不能因为“已有一项评估”就误判全部齐全。
- 事后认识修订仍显示事后阶段；无效分析范围不会留下孤立授权或忙碌状态。
- 真实反馈一张表单可保存未知，未知不会解锁结果动画。
- 用同一个虚构 Case 渲染理解、冲突、新认识和路线，未把手写测试候选当作真实 AI 质量证明。

## 设备与效果边界

本轮没有修改 Vault 加密格式或密钥 alias。SQLite 本地回归依赖系统 libsqlite3；Android Keystore/SQLite、原签名覆盖安装、通知/省电/重启需要原生 CI 和真机分别检查。没有真实模型运行日志，因此不能宣称 50–70 条语义候选、个人欲求发掘、反证质量或长期行为效果已经达到 PRD 标准。截图只证明该测试数据下的实际 Flutter 布局。

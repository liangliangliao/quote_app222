# 意志之镜 v2.8 验证记录

## 2026-10-15 续开发与覆盖安装修复

基线 `c94151a1`，首个修复提交 `9cf5cd7d`；分支和 PR #173 保持不变。实现说明和剩余验收见 [CONTINUATION.md](CONTINUATION.md)。

| 检查 | 本轮实际结果 |
|---|---|
| 模块及 Android 集成/driver 静态检查 | 4 个检查目标，No issues found；[日志](evidence/2026-10-15-module-analyze.log) |
| 模块回归 | 107 项通过，含 13 项原则领域/Widget 回归及 Android SQL 调用契约；[日志](evidence/2026-10-15-module-tests.log) |
| 评分服务 | 12 项通过、1 条依赖弃用提示；[日志](evidence/2026-10-15-server-tests.log) |
| T1–T366 索引 | 366 条可追溯，24 个合成案例；新增原则回归文件关联，不更改为完整验收通过 |
| 全仓库静态检查 | 0 error、429 warning、816 info；因既有告警非零退出 |
| 全仓库回归 | 1055 项通过、5 项失败；失败名称与下方原基线记录相同，均属未修改的 beautiful_enemy；[日志](evidence/2026-10-15-full-tests.log) |
| Android 发布构建 | 启动修复提交的 [GitHub APK 构建](https://github.com/liangliangliao/quote_app222/actions/runs/38740171296) 已成功；包含后续原则约束的最终版本继续编译 |
| 原生 SQLite / Keystore | [首轮 API 26/35 CI](https://github.com/liangliangliao/quote_app222/actions/runs/38740171261) 中首次打开 UI、加密写入、关闭重开、AAD 错误保留数据、撤回及删除均通过 |
| 同签名 APK 覆盖测试 | 首轮测试方式失败：Flutter test 结束时自动卸载，API 26 verify 发现空库；API 35 seed 连接中断。改用 drive 保留安装并检查 seed 库存在，重跑结果待补。不能把首轮工作流标为通过 |
| 用户原设备 / 真实模型 | 未取得原设备日志和签名来源，尚未执行原设备直接覆盖验收；未发送真实模型请求 |

本地首次发布构建曾因同时执行 Flutter tests 改写生成的插件注册文件而失败（integration_test 注册与 release 依赖不一致）；在完成 tests 后独立重新构建。GitHub 发布构建运行在独立作业，已成功。

## 初次重建记录（2026-10-14，保留原证据）

验证基线：`origin/main ec8f7749fc2801e97e38da459dabccdda11657a2`；2026-10-14 已重新 fetch，main 未前移。隔离分支 `codex/will-mirror-v28-rebuild`，未合并 main。

| 检查 | 实际结果 |
|---|---|
| 新模块静态检查 | `flutter analyze --no-pub lib/will_mirror test/will_mirror`：No issues found |
| 模块回归 | 85 项通过；含有数据的 Top5/人生折线、宿主通知去重、旧路线版本失效、缓存原始时效与 24 个合成案例；见 evidence/module-tests.log |
| 评分服务 | 12 项通过；仅 Starlette TestClient 的 httpx 弃用提示 |
| T1–T366 索引 | 366 条原文、来源行和文件路径全部可追溯；这是索引校验，不是全部功能验收通过 |
| 跨域案例 | 24 个虚构案例的账本不变量回归通过；真实模型首轮/反向证据盲审未执行 |
| 全仓库静态检查 | 0 error、429 warning、816 info；命令因既有警告非零退出，不宣称全仓库零问题 |
| 全仓库 Flutter 回归 | 992 项通过、5 项失败；5 项在未修改的原 main 基线上独立复现，详见下表 |
| Android 编译 | ARM64 release APK 已成功编译；最终源码交付包正在复编译，见 evidence/android-build.log |
| 真实 Provider / Decisions | 未进行带真实凭据的服务请求；官方文档已核对，HTTP 契约测试通过 |
| Android 设备行为 | 未执行通知/重启/省电/TTS/TalkBack/Keystore 真机矩阵；构建成功不等于设备验收通过 |
| CI | 新增 Will Mirror v2.8 workflow；推送后运行记录在 PR Checks，不能把本地通过称为远端已通过 |

## 关键已自动覆盖的不变量

不可变版本与规范化封存哈希、T2 不能倒填 T0/T1、未知不算失败、真实行动与外部结果独立、同 Case 多轮、来源撤回和跨 Case 权限撤销清理全部历史副本、OS 提醒先取消后删节、SQLite CAS 防旧响应覆盖、密文鉴权失败不换空库、通知打开不算真实触发、结构修复有界、50–70 候选分批/语义去重不足如实说明、无来源不标核实、未知评分不补零、硬安全评估阻断支持路线的高分理由、真实资源互斥、自主知情选择资格、独立内容复核、同输入复用、原评分时间不因改权重刷新、OpenAI/Azure 请求格式及错误不泄露正文。

SQLite 测试用 TestCipher 验证密文边界和事务，不声称测试过 Android AES 实现；通知用 TestReminders 验证路由与取消逻辑，不声称测过设备投递。

## 原基线可复现的五项失败

在独立 detached worktree `ec8f7749` 运行：

```sh
flutter test --no-pub --reporter expanded \
  test/beautiful_enemy/enemy_host_test.dart \
  test/beautiful_enemy/enemy_patrol_test.dart
```

结果 53 项通过、5 项失败，与全仓库失败同名：

| 文件 | 用例/差异 |
|---|---|
| enemy_host_test.dart:92 | 行为记录来源过滤，预期两条，实际空集合 |
| enemy_host_test.dart:184 | 过期截止时间的测试时间基准，预期两小时回退，实际保留了其给定时间 |
| enemy_patrol_test.dart:290 | 新记录/会话时段应静默，实际返回消息 |
| enemy_patrol_test.dart:425 | 自检预期 baseline，实际 opposition_off |
| enemy_patrol_test.dart:463 | 自检预期 capped，实际 opposition_off |

这些模块的生产代码未因本次重建而改动。日志在 [evidence/full-tests.log](evidence/full-tests.log) 与 [evidence/baseline-enemy-tests.log](evidence/baseline-enemy-tests.log)。未借本次功能重写这些无关行为或把测试改成迎合现状。

## 交付边界

- 本地真实记录与远程候选严格分开。没有配置模型时保留事实记录和可用流程，不编造离线 AI 分析。
- 旧版数据库/密钥保留，新版不自动迁入被拒绝实现的推论。未提供跨设备同步或旧格式自动导入。
- 当前不能宣称 T1–T366 全部通过。完整状态在 [acceptance.json](acceptance.json)，真实模型与真机执行步骤分别见 [evaluation/README.md](evaluation/README.md) 和 [DEVICE_CHECKLIST.md](DEVICE_CHECKLIST.md)。

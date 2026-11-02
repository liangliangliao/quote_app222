# 意志之镜 v2.8 验证记录

## 2026-10-29 用户截图修复与 AI 来源标识（续）

基线 `83370d2`，继续 PR #194。实现与覆盖入口见 [截图问题、简明回应与来源标识](RESPONSE_CLARITY_AND_AI_ORIGIN.md)。没有更换用户的 AI 配置、数据库或设备密钥。

| 实际检查 | 结果 |
|---|---|
| 截图问题对应的修改前复现 | 4 项中 **3 项失败**：合法互相引用被筛掉、复核格式错误重生成建议、错误复核无法局部恢复；[原始日志](evidence/2026-10-29-response-before.log) |
| 最终完整模块回归 | **181 项通过**，比 `83370d2` 新增 29 项；[日志](evidence/2026-10-29-response-tests.log) |
| 模块及集成测试/driver 静态检查 | **无问题**；[日志](evidence/2026-10-29-response-analyze.log) |
| 宿主 Dart/资产 bundle 编译 | **通过**，目标 `android-arm64`，退出 0；[构建记录](evidence/2026-10-29-response-bundle.log) |
| 来源标识专项 | 七步、经验/原则、评分、修改后来源、预演、来源弹层、本人观察及混合封存均有回归 |
| 首屏与旧数据 | 新回应必须有卡点/角度/下一步；旧记录可保留并主动重新生成；320 宽/1.8 倍字体布局通过 |
| 手机同模型在线联调、Android 真机 | **未执行**；以上为模拟模型、实际 Flutter 渲染及本地存储测试 |

`AI 生成` 与用户认可分开显示；用户更新 AI 原稿后保留 `AI 原稿 · 你已更新`。评分和规则排序分开标识。新预案用可选 `sourceAnalysisIds` 保留 AI 填充来源，真实观察和行动不因引用 AI 路线而被改标为 AI 内容。没有在客户端静默吞掉未识别的复核问题，也没有把无效内容当成已完成分析。

## 2026-10-29 主分支核查与补齐

基线 `main@5e34413363c73c5c65411fef662d7d9b6d89b711`，开发分支 `codex/will-mirror-v28-audit-20261029`。范围、评分和遗留事项见 [本轮核查报告](AUDIT_2026_10_29.md)。本轮未改动 Android 原生代码、数据库版本或设备密钥。

| 实际检查 | 结果 |
|---|---|
| 独立 main 工作树模块基线 | **123 项通过**；[日志](evidence/2026-10-29-baseline-tests.log) |
| 模块、测试、原生集成测试/driver 静态检查 | **无问题**；[日志](evidence/2026-10-29-module-analyze.log) |
| 最终模块回归 | **152 项通过**，在原 123 项上新增 29 项；[日志](evidence/2026-10-29-module-tests.log) |
| 可选 Decisions 服务契约 | **12 项通过**，1 条上游 TestClient 弃用提示；[日志](evidence/2026-10-29-server-tests.log) |
| T1—T366 追溯索引 | **通过**，保留 24 个合成案例及各项实际验收限制；不是全部功能验收通过 |
| 功能组评分复算 | **82.5 → 92.5 / 100**；人工代码核查的 P0/P1 实现覆盖估算，原模型/设备待验收状态保留 |
| 整个宿主 Dart/资产 bundle 编译 | **通过**，`flutter build bundle --debug --no-pub --target-platform android-arm64`，退出 0；[构建记录](evidence/2026-10-29-bundle.log) |
| 手机卡片与大字 | 390×844 中文渲染、320 宽和 1.8 倍字体的布局回归通过；[虚构数据截图](previews/experience-opportunities-synthetic.png) |
| 真实模型/Decisions 在线调用、部署、Android 真机/原签名覆盖安装 | **本轮未执行**，不纳入已验收项目 |

Linux 最初缺少无版本号的 `libsqlite3.so`，导致 12 项存储基线无法打开测试库。将现有系统库通过工作区库路径提供给 FFI 后，独立 main 整套 123 项及最终 152 项全部通过；没有据此改动应用存储行为。运行所需 SDK、Pub 缓存及分析器状态均位于工作区，不写入用户只读目录。

新增测试分别验证：任务/能力/实际要求的证据资格；已发生事实与未来信念、硬限制与过期要求；反例绑定和版本复核；未行动不冒充应用、真实准备不归零；编辑后可自主采用；跨课题提醒与旧深链失效；SQLite 关闭重开后的版本/反例/应用留存；以及有界内容复核拒绝时禁止提交。AI 和通知仍使用模拟依赖，SQLite 测试使用不透明测试加密器，不能替代 Android Keystore 或真实模型质量验证。

没有把全仓库其他模块测试、Android APK、远端 CI、真人效果或全部 366 项语义/设备验收声明为通过。

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

本地构建曾因 `--no-pub` 保留了含 integration_test 的调试插件注册文件，而 release 原生依赖排除了该开发依赖，导致注册类找不到。核对 Flutter 3.35.3 源码后，发布命令去掉 `--no-pub`，让工具按 release 模式重新生成注册文件；不手改生成代码。GitHub 发布构建原本就会执行该生成步骤，已成功。

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

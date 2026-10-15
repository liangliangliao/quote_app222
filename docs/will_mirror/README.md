# 意志之镜 v2.8 独立重建

发现之旅仅保留一个模块入口，进入后为「课题／逐渐认识的我／设置」。一句话建立一个 Case，沿同一工作台逐步完成事实与欲求、Top5 正反理由、认识转换、路线比较、准备与封存、现实触发、真实反馈及原则修订。

这是遵照用户“删除已开发版本后从头开发”的新实现。基线 `origin/main@ec8f7749`，旧实现删除提交 `483b987b`。没有复用被拒绝的 UI/分析逻辑，也没有把旧 AI 结论自动当成新账本的事实。原数据库文件和 Keystore alias 不主动删除；新库独立，旧历史不在新入口自动读取。

## 结构与宿主接入

| 目录 | 职责 |
|---|---|
| `lib/will_mirror/domain` | 不依赖 Flutter 的不可变记录、逐类 schema、来源/时间/资格验证、版本与撤回、Top5 约束排序 |
| `data` | SQLite 加密聚合与历史；AES-GCM 密文、CAS、事务内撤回及跨 Case 清理 |
| `ai` | S1–S8 结构化协议、分批 50–70 动机/独立语义合并、反证审查、受约束 JSON、质量复核、可选评分适配 |
| `application` | 串行用户命令、异步阶段提交/取消/重试、权限记录、提醒失效、旧榜单与新权重 |
| `integration` | 宿主 AI 配置、无正文日志的 HTTPS 传输、共享运行实例、Android 通知与深链 |
| `presentation` | 一次自由输入、七步可折叠工作台、动机之潮、路线矩阵、人生折线、个人原则与隐私设置 |
| `server/will_mirror` | 可选、无持久化的 Decisions 私有评分网关；OpenAI key 仅配置在服务端 |
| `test/will_mirror` | 领域、数据库、控制器、AI 契约、Widget、24 个合成案例的记录不变量回归 |

宿主改动限于发现入口、通知分发、Android channel/receiver 和依赖。`WillMirrorV28Vault.kt` 使用新的设备密钥 alias。通知和发现入口共用一个运行中的账本实例，撤回立即反映到详情/预演。另有独立基础修复提交 `3e6cda51`，修复原宿主 dashboard 的命名编译错误及两个既有测试的编译/数据库隔离问题。

## 功能的实际约束

- 每条记录有 Case/episode/ID、来源、T0–T3、发生/得知/记录时间、支持/反例/依赖和修订。事后更正不倒填事前快照。
- 模型只能提交候选；不能写本人认可、真实尝试、行动或外部核实。结构不合格最多修复一次；预演/学习另做独立事实、自主性和因果复核。
- 动机分批生成并语义合并，最多 70 条；不足 50 明确说明。默认最多 Top5，保留重要反方、风险、长远理由，可展开代表和全池。
- 四维评分为本次审议量规；不当心理强度或行为概率。未知不补零，模型 confidence 与来源质量分开。旧在线榜单记录原评分时间与 24 小时缓存提示，改权重不伪造新调用时间。
- 路线的欲求适配、任务能力、外部可行性、认识条件、难度、安全门槛分开。高分不覆盖安全变化；已知互斥资源不能确认并行。
- 可选 30–90 秒 S0–S4 预演只采用 1–3 条本人认可动机；未来与想象有标签；现场短提示与双方理由并列。允许跳过、静音和减少动态。
- 预约提醒不等于真实触发，打开不等于注意/认同。决意、尝试、行动、外部结果、实际取得和持续体验分别记录；未知不算失败。
- 同 Case 可有多轮经历。个人原则默认展示一条、最多三条候选，支持本人编辑/拒绝/归档，保留条件、例外、反证和版本。展示、想起、采用、核实效果分别记录。
- 源证据撤回会传递清理本案/获授权其他课题、旧历史副本、预演与提醒；更正保留旧版本并标记派生内容失效。没有跨设备同步、自动上传或真人效果承诺。

## 开发与可复现检查

Flutter 3.35.3 / Dart 3.9.2，JDK 17，Android SDK。Linux 测试需可加载 `libsqlite3.so`；预览可安装 Noto CJK。

```sh
flutter pub get
flutter analyze --no-pub lib/will_mirror test/will_mirror
flutter test --no-pub --reporter expanded test/will_mirror
python3 -m pip install -r server/will_mirror/requirements.txt
python3 -m pytest -q server/will_mirror/test_contract.py
python3 docs/will_mirror/check_acceptance.py
flutter build apk --release --no-pub --target-platform android-arm64
```

`.github/workflows/will_mirror_v28_ci.yml` 执行相同模块与评分服务检查。测试使用模拟 Provider/HTTP/设备能力；不会调用付费 AI。

## 演示路径

1. 发现之旅 → 意志之镜，写下一个具体课题。可看实例自动填入，也可切换“已发生”直接回看。
2. 点击开始；本次授权表只勾选愿意发送的资料。未配置 AI 可取消发送，继续本地记录；配置入口复用宿主设置。
3. 有模型时逐阶段出现理解、欲求、理由、认识与路线。查看重要反方和来源；认可少数理由，比较路线并选择。
4. 准备页核实条件、登记实际准备；预演可全程跳过。本人确认后封存，可选时间提醒。
5. 现场页先亲自核实真实条件，记录变化或选择暂停/改道；若风险变化先停用旧预演。实际尝试单独记录。
6. 反馈页记录真实行为与外部结果；未知不揭晓。查看 T0/T1/T2 对照，分别记录取得与后续体验，再授权复盘。
7. 原则可以接受、修改或拒绝；在后续情境记录是否想起/实际使用。逐渐认识的我显示已有真实道路和条件性认识。
8. 在来源详情撤回记录，或设置中撤销跨 Case 授权/导出/删除，核对旧引用和提醒一起失效。

## 验收资料

- [本轮真机修复、原则开发与 P0 完成/待验收矩阵](CONTINUATION.md)
- [覆盖安装首次打开问题及真机复测](DEVICE_STARTUP_FIX.md)
- [T1–T366 对应表](ACCEPTANCE.md)及 [逐条原文/文件/状态](acceptance.json)
- [验证结果](VALIDATION.md)
- [真实模型跨域验收](evaluation/README.md)
- [Android 设备矩阵](DEVICE_CHECKLIST.md)
- [Decisions 服务配置与官方契约](../../server/will_mirror/README.md)

原始正式 PRD 和两份深化文档保留在 `requirements/`，正式 PRD 优先。自动回归通过不等于 366 项语义/设备/真实效果要求全部验收通过。

# PRP v1.1.0 验证记录

产品方案 v2 的 I0–I6 功能实现已补齐，包含痛感对照、原生声音、潮汐光迹和废稿短句等可选需求。逐项对应为 [C01–C28](docs/prp/REQUIREMENTS_v1.1.0.md)。本次在 Android 8（API 26）和 Android 15（API 35）模拟器运行实际 App，两个系统均通过完整界面流程和各 20 项原生检查，保存共 34 张设备截图。

开发分支为 `feature/prp-plugin`，原始非主分支基线 `d83386c20f8243cd0e35f5c582de03e5a1595a8c`，前版 `b9b6cf9e`。本次 APK 源码为 **`5ce4d70dfc97a44d6a988f136b6f15ea0087a711`**，源码树 `62cb3166a6253205c1edc253f087597d99fb7996`；设备验收为 **`4f61139112ac4e68036242a8626653aa53640c13`**，后续只修正验收脚本和模拟器配置。`lib`、`android`、`assets`、依赖及发布工作流的 Git 对象均核对一致，见溯源记录。后续交付文档提交不改变应用代码；最终源码 ZIP 的 `PRP_DELIVERY.json` 记录其实际提交、源码树和逐文件 SHA-256。

## 已交付的行为

统一复盘包含实际 60 秒前台暂停、事实/解释/自责对账、有效/无效、预警和具体动作、长按 3 秒盖印、近 30 天数据拉远。盖印后进入手册，并在相似场景回访，显式采纳后仍保持未验证，只有用户明确反馈才增加验证/复犯次数；改写保留旧版历史。三个原有失败入口按开关选择统一会话或旧表单，失败模块结果双写。

本版补齐预测/实际曲线、原生闹钟教训及本地声音、松手后静止的粒子体验、12 条原创练习短句、步骤及回访本地指标、复犯间隔、字据事实点阵、可选重新解读和确认后转字据。导出和二次确认清除覆盖 5 张自有表与录音文件。新增表仅 `prp_forecast`、`prp_event`，原有三张 PRP 表通过增量创建升级；旧模块建表语句和护栏文件 [哈希对照](docs/prp/evidence/v1.1.0/schema-guard-hashes.json) 不变。

插件、AI 授权及新增可选功能默认关闭。AI 仅复用 App 统一配置，未创建密钥或执行真实 API 请求。插件关闭会立即撤下各调用点的内容并停止 PRP 声音，数据保留，设置内仍可管理。火种中途退出、没有记录和提醒已收到均不算失败。

## 自动化与构建

| 检查 | 结果与证据 |
| --- | --- |
| 插件/宿主/设备测试 Dart 静态分析 | 无问题；[本地记录](docs/prp/evidence/v1.1.0/analyze-core.log) 与 [云端 CI](https://github.com/liangliangliao/quote_app222/actions/runs/42220803402) |
| 集成模块静态分析 | 无错误，保留 249 项既有 lint 提示；[记录](docs/prp/evidence/v1.1.0/analyze-integrations.log) |
| 插件、真实入口、设置及受影响红线 | **160 项通过**；云端为 111 项插件测试 + 49 项回归；本地 [119 项](docs/prp/evidence/v1.1.0/plugin-and-entry-tests.log) + [41 项](docs/prp/evidence/v1.1.0/regressions.log)，无重复计数 |
| 整应用编译 | Android arm64 Flutter bundle 通过；[本地检查](docs/prp/evidence/v1.1.0/local-checks.json) |
| Android 8 实际 App 和原生组件 | **通过**；[17 张截图、完整结果](docs/prp/evidence/v1.1.0/android-api-26/acceptance-report.json) |
| Android 15 实际 App 和原生组件 | **通过**；[17 张截图、完整结果](docs/prp/evidence/v1.1.0/android-api-35/acceptance-report.json) |
| 两系统设备测试运行 | [PRP Android Acceptance](https://github.com/liangliangliao/quote_app222/actions/runs/42220803343)，各系统 20 项原生检查，共 40 项 |
| 发布 APK | [构建运行](https://github.com/liangliangliao/quote_app222/actions/runs/42215899915)；源码树、包名、签名、ABI、版本和 APK SHA-256 均核对通过 |
| 版本化完整源码 ZIP | `tools/pack_prp.py` 生成，CI 产物 `quote-app-prp-v1.1.0-source`，包含全部源码逐文件校验清单 |

## 设备验收步骤与预期

两个系统均从真实 App 设置入口开始，实际等待 60 秒暂停和 3 秒盖印，实际录制及播放本地声音。没有用手工绘制图片替代设备截图。逐步骤编号和图片链接见 [证据索引](docs/prp/evidence/v1.1.0/README.md)。

1. 默认关闭且 AI 授权关闭 → 开启 → 暂停时无分析控件 → 填写、盖印及拉远 → 手册可见，失败模块历史双写。
2. 痛感预测与实际只补记一次，曲线可见 → 粒子按下分散、松手回落 → 原创短句可见 → 实际 15 秒本地录音/播放 → 本地观察显示本次记录。
3. 单条同意后，在原首页画框中看到自己的名言和印章；收藏不写入名言库 → 危机输入进入求助 → 关闭保留教训 → 二次确认清除 5 张 PRP 表及录音，失败模块既有学习卡保留。
4. 原生探针验证总/分开关、共享预算、静默、危机、静音、相似匹配、跨层幂等、Flutter 引擎销毁、采纳与结果幂等、声音归属/时长；启动实际闹钟表单、MediaPlayer、既有响铃服务和浮层，关闭后卡片消失且声音停止。

原生夹具只在独立测试 APK 的 disposable emulator 中执行，正式 APK 不含测试夹具。模拟器使用标准 Pixel 2 手机配置；此前默认 custom AVD 在 Android 8 启动既有闹钟表单时触发系统导航栏 `NavigationBarFragment` 空指针，截图被系统错误弹窗遮挡，因此该轮虽断言通过，未计作最终外观验收。现设备流程还检查 App 与 System UI 的崩溃日志。原生截图优先用 `UiAutomation`，不可用时回退读取真实显示缓冲的 `screencap`，方法记录在原生结果 JSON；同时检查实际可见 View，关闭状态等待现有广播刷新完成后再断言。

Android 8 验收中发现旧 SQLite 不提供 `json_extract`，已改为在原事务内使用 Dart 解码历史 JSON，损坏旧行也不阻止新双写；[12 项相关宿主测试通过](docs/prp/evidence/v1.1.0/android8-compat-host-tests.log)。粒子松手后停止 ticker、原生连续刷新中过期回调不隐藏新卡片也已修复并回归。

## 安装与溯源

安装操作见 [快速上手](docs/prp/GETTING_STARTED.md)。APK 版本为 `1.1.0（15）`，包名 `com.example.quote_app`，最低 Android API 26，包含 arm64-v8a、armeabi-v7a 和 x86_64。签名沿用既有构建，证书 SHA-256 为 `73982b58bb0aae7e48c20592c1e251c3a0fdbf831d5b7694d3f2f7477a04afab`。覆盖安装保留数据，不需卸载。

APK SHA-256：`aeb22629f43f73e323882e8107d26ea93b0f91c8febf46e99022a62cc017448d`。完整元数据：[build-info](docs/prp/evidence/v1.1.0/build-info.json)、[release-verification](docs/prp/evidence/v1.1.0/release-verification.json)、[应用源码溯源](docs/prp/evidence/v1.1.0/production-source-provenance.json)。两套模拟器与发布包的应用源码一致，验证包是 debug，交付安装包是 release。后续验收脚本和模拟器配置提交没有重发 APK。

## 验证范围与既有基线

本次是 API 26/35 模拟器的实际 Android 运行，全部报告明确 `physical_device=false`。本会话未连接用户手机，未完成物理手机验收；方案第 8.2 节的物理手机验收仍需用上述 APK 在目标手机执行，不能把自动化通过写成物理手机通过。插件不宣称治疗效果。

原仓库美丽的敌人全量测试仍有 **5 项既有失败**（主动巡查/诊断 3 项、证据过滤和 AI 截止时间各 1 项），在未改动基线已复现。云端保留独立可见基线步骤，结果为 179 通过、5 失败；PRP、受影响护栏及设置流程 160 项全部通过。详见 [基线对照](docs/prp/evidence/baseline-comparison.txt) 与 [v1.0.0 审计](AUDIT_prp_v1.0.0.md)。未为变绿而改动无关模块，也未将开发分支合并到主分支。

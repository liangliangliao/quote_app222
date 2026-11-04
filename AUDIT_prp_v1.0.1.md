# PRP v1.0.1 验证记录

此版修正入口不可发现、主动复盘受自动提议额度限制、首页/火种不显示的原因缺少反馈，以及安装包版本难以辨认的问题。用户已确认此前开启过总开关，不能把现象直接归因为未开启或旧安装包。

## 功能核对

- 从实际 `SettingsPage` 首页点 PRP 卡片，完成首次启用，确认 AI、火种和首页授权仍默认关。
- 从设置点“开始一次复盘”，实际填写预期、事实、有效/无效、预警及具体动作，完成 60 秒暂停和 3 秒盖印。
- 返回设置后盖印计数更新为 1，再进入手册看到刚保存的教训。测试没有预填教训或跳过流程来替代这条路径。
- 手动会话的 `counts_offer=0`，自动提议额度为 0 时仍可手动开始；静默治理仍有效。
- 首页和火种条件在设置内明确显示。火种仍在回溯候选步骤只读复用，首页仍须单独开启并逐条同意。

以上为 Flutter 自动化界面/数据库测试，不能代替 Android 真机点击、录音权限和系统行为验证。更新的设置截图及设置首页直达截图见 [截图说明](docs/prp/screenshots/README.md)。

## 构建与交付

本次还核实了前一个提交 `6b7c153d` 的 GitHub APK 已构建成功：[构建 41801150244](https://github.com/liangliangliao/quote_app222/actions/runs/41801150244)。已下载并核对该包的源码树、APK SHA-256 和签名验证报告；这不代表用户截图中的安装包已被识别，也不代表新版已完成设备验收。

新版 APK 由 `.github/workflows/android_build_source_repo.yml` 从本次分支源码构建，版本改为 `1.0.1+14`，沿用既有签名。构建校验版本名/版本号、源码树、签名和 ABI，设置页显示构建 SHA。成功运行的链接和产物应以 GitHub Actions 为准。

最终本地验证日志位于 `docs/prp/evidence/v1.0.1/`。上游已有 5 项敌人测试失败的结论沿用 v1.0.0 的基线对照，未把它们改成通过或混入本次修正。

| 检查 | 结果 |
| --- | --- |
| 插件和实际设置入口 | [92 项全部通过](docs/prp/evidence/v1.0.1/entry-and-plugin-tests.log)，含空白输入到盖印、手册显示的完整界面流程 |
| 插件及宿主静态分析 | [无问题](docs/prp/evidence/v1.0.1/analyze-core.log) |
| 设置集成静态分析 | [无错误](docs/prp/evidence/v1.0.1/analyze-integrations.log) |
| 额外旧功能回归 | [41 项全部通过](docs/prp/evidence/v1.0.1/regressions.log)，不重复计入设置测试 |
| 整应用 Dart 编译 | [Android arm64 Flutter bundle](docs/prp/evidence/v1.0.1/build-bundle.log)，与 APK/设备验收分别记录 |

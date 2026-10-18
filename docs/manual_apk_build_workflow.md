# Android APK 构建：手动、单版本交付

## 为什么修改

过去 `.github/workflows/android_build_source_repo.yml` 同时监听广泛的 push 和 pull_request 路径。
开发者每次修改一个 Dart、测试或配置文件，都会立即打包完整 APK，产生多份带有不同提交 SHA 的“Build Android APK”运行记录。
它们并不是同一份 APK；较早的成功记录通常**不是最终代码版本**。

## 新的行为

- **日常提交 / 更新 PR：不自动构建 APK。** 按相关模块的现有专项 CI 进行分析和测试，例如 `Meditation Mentor CI` 在冥想代码的 PR 中自动运行。
- **准备安装验收时：手动构建一份 APK。** 工作流名称 `Build Android APK (Manual)`，且只声明 `workflow_dispatch`，不再监听 `push`、`pull_request`。
- **重复手动运行同一个分支：自动取消尚未结束的上一次手动构建。** 并发分组按仓库与分支区分；不同分支不会彼此取消。
- **下载文件清晰标记源码版本。** Flutter 产物 ZIP 含 `app-release.apk`、`app-release.sha256`、`build-info.txt`，并在运行摘要显示实际 checkout 的 branch 与 commit SHA。
- **原有可选检查保留。** 手动运行时 `self_os_checks` 默认为 false；按需开启 Self OS 专项检查。
- **传统 Gradle 回退保留。** 本次未改动 Android 生成方式、签名、Flutter 版本、依赖或发布渠道。
- **不影响其他专项工作流。** 原来的其他模块自动 CI 和按专门分支交付的工作流独立存在；例如 `evidence_growth_release.yml` 仍可能在其明确监听的旧功能分支上自动交付。

## 如何生成最新 APK

1. 打开仓库 GitHub → **Actions** → **Build Android APK (Manual)**。
2. 点击 **Run workflow**，**选择准备验收的具体分支**（如 `codex/meditation-eam8-experiential-20261018`，在该分支仍包含最新待验收代码时）。不要误选 `main`，除非新功能已合并。
3. 根据需要决定是否启用 Self OS 检查；点击绿色 **Run workflow** 启动一次完整构建。
4. 等待成功，在运行页面的 **Artifacts** 下载 `quote_app-apk`。解压后，核对 `build-info.txt` 的 `commit_sha` 与准备验收的 GitHub 提交一致，再安装 `app-release.apk`。
5. 同一分支后续新增代码需要再次打包时，才重新点击手动构建。旧 APK 不会因源代码更新而自动替换。

## 验收与边界

- 验证重点：普通 push / PR 不触发这一 APK 工作流；手动选定分支仍能打包；构建摘要、SHA256 和文件内容一致；同分支的重复手动任务只留下最新版继续执行。
- 只取消**未来由本工作流规则管理**的重叠任务，已经由旧定义启动或已成功的历史运行记录不会从 Actions 页面被删除。
- `workflow_dispatch` 在 GitHub UI 中需要工作流文件存在于默认分支。配置合并进 `main` 后，用户可在 Actions 页面选择任何可用的开发分支运行。为了用到新配置，相关分支也应更新或从最新 `main` 同步。
- 专项测试通过不等于最终 APK 编译、真机安装、音频播放或主观冥想质量已经验证。

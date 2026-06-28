# PATCH_WOOP_ACTION_ENGINE_V7.1_BUILD_FIX_PROMPTS

## 修复原因

Flutter release 构建报错：

- `Undefined name 'sceneSourcebookCoursePrompt'`
- `Undefined name 'sceneTriggerSimulatorPrompt'`
- `Undefined name 'sceneNextActionQueuePrompt'`
- `Undefined name 'sceneAcceptanceAuditPrompt'`

原因是 V7 在 `defaultPrompt()` 中新增了 4 个 Prompt ID 的 switch 分支，但遗漏了对应的内置默认 Prompt 常量定义。Dart 编译阶段无法解析这些静态名称，因此 `compileFlutterBuildRelease` 失败。

## 修复内容

修改文件：

- `lib/woop_action_engine/woop_action_prompt_config.dart`

新增内置默认 Prompt：

- `sceneSourcebookCoursePrompt`
- `sceneTriggerSimulatorPrompt`
- `sceneNextActionQueuePrompt`
- `sceneAcceptanceAuditPrompt`

并补充 `outputToPromptId` 中的：

- `experiment: outputExperimentId`

## 影响范围

只修复 WOOP 行动引擎模块内 Prompt 配置，不影响其他模块。

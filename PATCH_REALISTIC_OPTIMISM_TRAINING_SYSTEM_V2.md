# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V2

## 目标
继续补齐“现实主义乐观训练系统”独立模块，使其更严格覆盖最终产品设计方案，并将本模块所有 AI 提示词接入：设置页 → AI 提示词配置中心。

## 关键修复

1. **AI 提示词统一配置中心接入**
   - 新增 `RealisticOptimismTrainingPromptConfig` 的持久化配置能力。
   - 本模块所有 Prompt 均可在 `AiPromptSettingsPage` 中自由编辑、保存、恢复默认、备份恢复、导出和导入。
   - 新增模块项：`现实主义乐观训练系统`。
   - 新增可配置 Prompt：
     - `rot_global` 全局价值层 Prompt
     - `rot_scene_intensity_check` 事件强度分级
     - `rot_scene_event_reframe` 今日事件重构
     - `rot_scene_failure_immunity` 失败免疫复盘
     - `rot_scene_controlled_failure_challenge` 可控失败挑战
     - `rot_scene_process_action` 过程模拟行动
     - `rot_scene_prime_design` 注意力 Prime 设计
     - `rot_scene_anti_prime_cleanup` Anti-Prime 环境清理
     - `rot_scene_gratitude_savoring` 感恩、品味与关系表达
     - `rot_scene_identity_evidence` 身份沉淀
     - `rot_scene_weekly_baseline` 幸福基线周报
     - `rot_output_common` 统一 JSON 输出格式

2. **AI 调用改造**
   - `RealisticOptimismTrainingAiService` 不再使用源码硬编码静态 Prompt 直接调用。
   - 每次生成时会读取设置页中最新保存的全局 Prompt、场景 Prompt 和输出格式 Prompt。
   - 不同场景会自动匹配不同 Prompt ID。

3. **场景补齐**
   - 新增可控失败挑战独立场景：`controlled_failure_challenge`。
   - 新增幸福基线周报独立场景：`weekly_baseline`。
   - 场景下拉框与首页 10+2 功能入口已补齐。

4. **能力档案补齐**
   - 新增“能力档案”Tab。
   - 将记录按最终方案聚合为：
     - 我做成过 / 行动证据
     - 我恢复过 / 失败免疫
     - 我能看见更多现实 / Benefit Finder
     - 我会珍惜 / 感恩与品味
     - 我在设计注意力环境 / Prime 与 Anti-Prime
     - 我正在成为什么样的人 / 身份沉淀

5. **幸福基线闭环增强**
   - 幸福基线 Tab 新增“生成 AI 幸福基线周报”。
   - 周报会自动带入最近训练记录与基线记录作为上下文。

6. **详情页增强**
   - 失败免疫区补充预测痛苦与实际痛苦字段展示。

## 修改文件
- `lib/realistic_optimism_training/realistic_optimism_training_prompt_config.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_ai_service.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_home_page.dart`
- `lib/pages/ai_prompt_settings_page.dart`

## 注意
当前容器环境没有 Dart / Flutter SDK，无法执行 `flutter analyze` 或真机编译。本补丁已做源码级结构检查与引用检查。

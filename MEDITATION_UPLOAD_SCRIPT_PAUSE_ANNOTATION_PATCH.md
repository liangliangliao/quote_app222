# 静心实验室：上传脚本停顿标注完整功能补丁

## 本次落地内容

1. 上传冥想脚本不再只是按文字长度粗略拆段，而是支持用户设置目标时长、冥想类型、停顿风格与处理方式。
2. 默认处理方式为“保留原文，仅自动插入停顿”。AI 的任务被限制为轻微断句、标点整理与 `pause_after_seconds` 停顿标注，不再大幅改写原文。
3. 支持 AI 标注停顿，也支持无 AI 的本地规则兜底。AI 不可用、返回空或解析失败时，自动使用本地规则生成带停顿脚本。
4. 系统支持 `[pause 10s]` 手动停顿标记。TTS 不朗读该标记，App 会把它解析为真实静默停顿。
5. 新增 `MeditationStep.pauseAfterSeconds` 与 `intent` 字段，保存到 `steps_json`，用于预览和后续时间轴计算。
6. 生成后的 `startSecond` 已按“预计朗读时长 + pauseAfterSeconds”计算，因此播放页在相邻句子之间会形成真实留白。
7. Prompt Center 新增“静心实验室 / 上传脚本停顿标注”，可统一编辑默认提示词。

## 主要文件

- `lib/meditation_module/meditation_script_import_page.dart`
- `lib/meditation_module/meditation_script_pause_planner.dart`
- `lib/meditation_module/meditation_ai_service.dart`
- `lib/meditation_module/meditation_models.dart`
- `lib/meditation_module/meditation_dao.dart`
- `lib/services/global_ai_settings.dart`
- `lib/pages/ai_prompt_settings_page.dart`

## 使用路径

发现之旅 → 生理赋能 → 冥想 → 上传脚本


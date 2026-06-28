# 行愿 Compass · ACT 心理灵活性独立模块落地进度

## 已完成

1. 新增独立源码目录：`lib/act_compass/`
   - `act_compass_models.dart`：ACT 价值档案、心理灵活性雷达、AI 会话、价值行动卡、行动复盘、统计模型。
   - `act_compass_dao.dart`：独立 `act_compass_*` 数据表与 `act_compass_*` KV 存储，不复用其他模块表结构。
   - `act_compass_prompt_config.dart`：完整三层 Prompt：全局价值层、场景层、输出格式层。
   - `act_compass_ai_service.dart`：统一 AI 服务调用 + JSON 解析 + 本地兜底引导 + 危机风险识别。
   - `act_compass_home_page.dart`：完整 Flutter 页面，包含今日、AI 教练、训练室、价值罗盘、行动复盘五个 Tab。

2. 已落地产品设计方案中的核心功能
   - 心理灵活性雷达：六过程评分与最弱入口提示。
   - 每日三问 Check-in：体验、价值、最小行动。
   - AI ACT 对话教练：按场景生成引导与行动卡。
   - 头脑故事识别器：作为训练场景接入。
   - 接纳训练室：身体容纳、干净痛苦/二次痛苦、愿意语。
   - 价值罗盘：核心价值、身份方向、生活领域、常见故事、回避策略、有效练习。
   - 承诺行动卡：价值、障碍、头脑故事、解离句、接纳句、最小行动、开始时间、持续时间、完成标准、痛苦出现时回应。
   - 行动后复盘：完成/没做到都可复盘，避免自责化。
   - 场景训练库：焦虑、拖延、自我批评、关系冲突、价值迷茫、行动失败、睡前反刍、冲动行为等。
   - AI 个性化上下文：最近会话、行动、复盘会写入独立上下文 JSON。

3. 已接入 App 入口
   - `lib/main.dart` 新增侧栏入口：`行愿 Compass · ACT 心理灵活性`。

4. 已接入 Prompt 设置中心
   - `lib/pages/ai_prompt_settings_page.dart` 新增 `act_compass` 模块。
   - 支持查看、编辑、预览、备份、恢复、导出、导入 ACT 三层 Prompt。

## 模块隔离说明

- 所有数据表均使用 `act_compass_` 前缀。
- 所有 Prompt 配置 key 均使用 `ai_prompt.act_compass.*`。
- 入口只通过侧栏新增模块卡进入，不改造、不合并已有模块业务逻辑。

## 待真机/本地 Flutter 验证

当前沙盒环境没有 `flutter` / `dart` 命令，无法在此环境执行 `flutter analyze` 或 APK 构建。已完成静态文件落地与基础括号平衡检查；建议你在本地执行：

```bash
flutter analyze
flutter build apk --release
```

如出现项目既有依赖或平台构建问题，可继续把日志发来，我会基于日志修复。

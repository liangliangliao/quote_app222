# PATCH_MI_GROWTH_PROMPT_CENTER_V1_1

本补丁在 `quote_app_mi_growth_navigator_v1` 基础上继续完善“向内生长 · MI 成长向导”。

## 重要说明

当前模块属于 MVP+ 级落地：已经实现 MI 核心闭环与 Prompt 可配置化，但并未把终极产品方案中的所有远期能力一次性全部完成。尚未完整实现的路线图能力包括：AI 忠诚度评分仪表盘、周/月成长报告、专业协作面板、组织版伦理协议、完整安全资源库与多端同步。

## 本次新增/修复

1. 将 MI 成长向导所有 AI 提示词接入“设置 → AI 提示词统一配置中心”。
2. 新增可配置 Prompt：
   - `mi_global`：全局价值层 Prompt
   - `mi_scene_daily_growth`：日常成长向导
   - `mi_scene_habit_change`：习惯改变 / 反复失败
   - `mi_scene_confusion_focus`：混乱聚焦
   - `mi_scene_low_motivation`：暂时没动力
   - `mi_scene_action_failure`：行动失败 / 复发修复
   - `mi_scene_life_transition`：人生转变 / 身份成长
   - `mi_scene_help_others`：帮助别人改变
   - `mi_scene_review`：复盘与维持
   - `mi_scene_repairing_discord`：关系失调修复
   - `mi_scene_safety`：风险与危机安全边界
   - `mi_output_json`：统一 JSON 输出格式
   - `mi_output_action_card`：行动卡输出格式
   - `mi_output_review_card`：复盘卡输出格式
3. MI Prompt 支持：
   - 本地保存覆盖
   - 恢复源码默认模板
   - 自动历史备份
   - 恢复历史备份
   - 拼接预览
   - 导出本模块 Prompt JSON
   - 导入本模块 Prompt JSON
4. MI AI 服务改为运行时读取配置中心保存的 Prompt，下一次 AI 调用立即生效。
5. MI 模块页面的“三层 Prompt 架构”卡片增加跳转按钮，可直接进入配置中心并定位到 MI 模块。

## 本地验证建议

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

当前沙盒未安装 Flutter/Dart SDK，未能在此环境执行 Flutter 构建验证。

# Realistic Positivity OS V2：产品闭环补全 + Prompt 统一配置中心

## 背景
用户指出 V1 仍只是骨架，未完整落地“基于《哈佛积极心理学》Lecture 9–10 的终极产品方案”，且模块所有 AI 提示词必须进入 App 设置页的“AI 提示词统一配置中心”自由配置。

## 本次补全

### 1. Prompt 统一配置中心接入
- 新增 `RealisticPositivityOsPromptConfig` 配置能力：
  - `rpo_global_value` 全局价值层 Prompt
  - `rpo_scene_state_diagnosis` AI 状态诊断/分流器
  - 12 个场景层 Prompt
  - Onboarding 人格地图 Prompt
  - 安全支持/危机分流 Prompt
  - 成长档案更新 Prompt
  - 行动卡 JSON 输出 Prompt
  - 人格档案补丁 JSON 输出 Prompt
- 所有覆盖值保存在 `ai_prompt.realistic_positivity_os.*`，与其他模块完全隔离。
- 支持保存、恢复默认、历史备份、备份恢复、导出/导入本模块 Prompt JSON。
- `lib/pages/ai_prompt_settings_page.dart` 已新增“真实积极行动系统 · RPO”模块。
- 设置页“AI 提示词统一配置中心”说明已加入真实积极行动系统。

### 2. AI 调用从写死 Prompt 改为读取配置中心
- `RealisticPositivityOsAiService` 改为运行时读取：
  - 全局价值层 Prompt
  - 状态诊断 Prompt
  - 当前场景 Prompt
  - 输出格式 Prompt
- 保存后的 Prompt 下一次生成立即生效。

### 3. 模块功能闭环补强
- 首页新增“今日调度建议”，根据记录状态建议今天优先训练方向。
- 12 模块页从静态说明升级为可点击训练入口，并可直接跳转对应 Prompt 配置。
- 模块入口点击时自动填入对应训练样例，降低使用门槛。
- 最新行动卡新增“沉淀到人格地图”按钮。
- 行动证据库新增“完成”按钮，可填写行动复盘并更新证据状态。

### 4. Onboarding 人格地图补强
新增并保存更多独立档案字段：
- 当前困扰地图
- 关系地图 / 感恩与求助对象
- Stretch Zone 成长方向
- 原有：常见情绪、旧问题、旧模式、支持关系、感恩资产、高峰体验、新身份证据、价值绑定。

### 5. 成长档案自动沉淀
新增 `applyRecordToProfile`：
- 将行动卡中的旧问题、旧模式、价值绑定、关系行动、Stretch 建议、感恩资产、高峰体验、新身份证据沉淀到人格地图。

### 6. 产品覆盖增强
- 价值绑定数据库已显式落地到模块页。
- Prompt 页不再作为分散配置页，而是明确指向统一配置中心，并列出所有已注册 Prompt。
- 安全支持、双通道处理、反 quick fix、行为优先、PPEO、Stretch Zone 等均在 Prompt 和 UI 中继续强化。

## 主要改动文件
- `lib/realistic_positivity_os/realistic_positivity_os_prompt_config.dart`
- `lib/realistic_positivity_os/realistic_positivity_os_ai_service.dart`
- `lib/realistic_positivity_os/realistic_positivity_os_models.dart`
- `lib/realistic_positivity_os/realistic_positivity_os_dao.dart`
- `lib/realistic_positivity_os/realistic_positivity_os_home_page.dart`
- `lib/pages/ai_prompt_settings_page.dart`
- `lib/pages/settings_page.dart`

## 编译说明
当前环境没有 Flutter/Dart SDK，无法执行 `flutter analyze`。本次已完成源码结构、括号配对、入口接入和 zip 打包。请本地运行：

```bash
flutter pub get
flutter analyze
flutter build apk
```

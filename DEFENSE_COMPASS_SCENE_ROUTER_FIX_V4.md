# DEFENSE_COMPASS_SCENE_ROUTER_FIX_V4

本次修复针对“今日自我罗盘”场景按钮只高亮、未完整联动输入模板/输出卡片/深度结构化字段的问题。

## 修复内容

1. 新增场景路由配置 `_DefenseCompassSceneSpec`
   - 每个场景绑定：显示名称、输入框标题、默认输入模板、默认输出卡格式、深度结构化提示、6 个结构化字段标签与提示。

2. 场景按钮联动
   - 点击不同场景后自动更新：
     - 输入区标题
     - 默认文本模板
     - 输出卡片格式
     - 深度结构化记录说明
     - 深度结构化字段标签与 hint

3. 防误覆盖交互
   - 输入框为空或仍为旧模板时：自动替换成新场景模板。
   - 用户已手动编辑时：弹窗提供“保留当前内容 / 追加模板 / 替换为模板”。

4. 输出卡格式补强
   - 新增/联动：焦虑来源卡、自我限制突破卡、关系沟通卡、利他让渡与边界卡、转折期稳定卡、家庭教育回应卡、行动复盘卡、闭环审计卡、个人防御地图更新卡、安全支持卡。

5. 深度结构化记录补强
   - 例如“利他让渡”场景下字段变为：
     - 这件事里涉及的人
     - 我为对方承担/争取了什么
     - 这件事是否也代表我的愿望
     - 为自己争取时的身体/情绪
     - 我如果为自己争取会害怕什么
     - 我最小可以收回的一点责任

6. 入口复用修复
   - 训练中心、防御库、关系工作台、转折/家庭工作台进入罗盘时，也统一走场景路由器，而不是各自手写 setState。

## 修改文件

- `lib/defense_compass/defense_compass_home_page.dart`
- `lib/defense_compass/defense_compass_prompt_config.dart`
- `lib/defense_compass/defense_compass_ai_service.dart`

## 本地建议验证

```bash
flutter pub get
dart format lib/defense_compass lib/pages/ai_prompt_settings_page.dart lib/main.dart
flutter analyze
flutter run
```

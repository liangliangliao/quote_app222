# PATCH_WOOP_ACTION_ENGINE_V5_DEEP_GAP_CLOSURE

## 背景
用户指出 V4.1 仍未完整实现最初 WOOP 行动引擎产品设计方案。V4.1 主要修复编译错误和补齐基础执行闭环，但仍存在几个关键产品差距：

- 场景工具库仍偏模板回填，缺少真实场景工作流。
- AI 缺少用户个人长期价值、常见障碍、边界偏好的上下文。
- 产品成功指标没有落地为可视化页面。
- 场景工作流没有直接保存 WOOP 卡，用户需要回首页再生成。

## V5 补齐内容

### 1. 新增 WOOP 个人化配置
新增模型：

- `WoopActionProfile`

新增 DAO：

- `getProfile()`
- `saveProfile()`
- `profileContextJson()`

新增页面：

- `WoopActionProfilePage`

用于配置：

- 长期价值 / 真正重视方向
- 主要生活领域
- 高频内在障碍
- 偏好的最小行动窗口
- 边界 / 专业帮助提醒

这些内容通过 `ai_prompt.woop_action_engine` 独立上下文注入 WOOP AI，不进入其他模块。

### 2. AI 自动注入个人化上下文
修改：

- `lib/woop_action_engine/woop_action_ai_service.dart`

`generateCard()` 调用 AI 前会自动读取 `WoopActionDao.profileContextJson()`，并合并进 `extraContext`。

这补齐产品方案中的：

- 长期愿望地图
- 个人核心价值
- 高频障碍模式
- 专业边界提醒
- 个人化行动窗口

### 3. 场景工具库升级为真实场景工作流
新增页面：

- `WoopActionSceneFlowPage`

原场景工具库点击后不再只是把模板回填首页，而是进入场景工作流，填写：

- 当前愿望或场景
- 最佳结果 / 真实需要
- 现实限制 / 外部背景
- 关键内在障碍猜测
- 边界 / 注意事项

然后直接调用 AI 生成并保存 WOOP 卡。

### 4. 新增 WOOP 行动指标页
新增页面：

- `WoopActionMetricsPage`

展示：

- WOOP 卡总数
- 行动中数量
- 完成卡数量
- 复盘覆盖率
- if–then 触发率
- 每日 Check-in 数量
- 高频内在障碍
- 下一步改进建议

这补齐原方案中的产品成功指标：

- 第一行动启动率
- 计划复盘率
- 障碍识别深度
- 反馈利用度
- 用户是否从幻想进入行动

### 5. 首页工作台扩展
`WoopActionFeatureGrid` 新增：

- 个人化配置
- 行动指标

主菜单也新增：

- WOOP 个人化配置
- WOOP 行动指标

## 文件变更

- `lib/woop_action_engine/woop_action_models.dart`
- `lib/woop_action_engine/woop_action_dao.dart`
- `lib/woop_action_engine/woop_action_ai_service.dart`
- `lib/woop_action_engine/woop_action_extra_pages.dart`
- `lib/woop_action_engine/woop_action_engine_home_page.dart`

## 说明
当前沙盒仍无 Flutter/Dart SDK，无法执行 `flutter analyze` 或 `flutter build apk --release`。本补丁已做源码级结构检查，但仍建议本地编译验证。

# 健康饮食模块：语音输入、食物能量明细、国内条码源与动态数据源标识升级

## 1. 每日分享语音输入体验优化

修改文件：

- `lib/health_diet/daily_share/diet_voice_input_page.dart`

主要改动：

- 参考主流语音输入交互，改成大号麦克风/停止按钮。
- 支持多轮连续识别：系统因停顿进入 `done/notListening` 后，会自动续听下一句。
- 对 `error_busy / recognizer_busy` 增加容错：不再直接失败，而是保留已识别文字并延迟重试。
- 增加识别计时、状态说明、快捷示例短语。
- 支持边识别边手动编辑，最终以用户编辑后的文字进入确认页。
- 增加“清空重说”“重新检测”“手动输入”等兜底操作。

## 2. 拍照/文字/语音识别后显示食物能量明细与总计

修改文件：

- `lib/health_diet/daily_share/diet_food_confirm_page.dart`
- `lib/health_diet/services/health_diet_ai_bridge_service.dart`

主要改动：

- AI 文字/图片识别 Prompt 增加 `estimated_grams` 要求。
- 确认页读取 `food_items` 中的 USDA / Open Food Facts / 国内条码接口 / 本地缓存营养数据。
- 每个食物卡片显示：
  - 来源
  - 份量
  - 粗估热量
  - 蛋白质
  - 碳水
  - 脂肪
  - 钠
- 页面顶部增加“本次食物能量与营养粗估”总计卡片。
- 如果 API 或缓存提供图片，则优先显示数据源图片；否则使用用户上传的食物照片作为缩略图。
- 数据会为后续复盘、健康目标差距、下一餐动态安排提供基础。

## 3. 条形码扫码增加国内候选源

修改文件：

- `lib/health_diet/services/health_diet_settings_service.dart`
- `lib/health_diet/pages/health_diet_settings_page.dart`
- `lib/health_diet/services/health_diet_external_api_service.dart`
- `lib/health_diet/services/health_diet_core_orchestrator.dart`
- `lib/health_diet/daily_share/diet_food_confirm_page.dart`

新增配置：

- 启用国内条码候选源
- 聚合数据条码查询 Key
- 探数数据 Bearer Token
- 探数商品条码 URL
- 探数商品成分 URL
- 自定义国内条码接口 URL 模板
- 自定义国内条码接口 Key / Token
- 自定义条码接口 Header 名
- 阿里云市场/云市场 AppCode

扫码流程升级：

- Open Food Facts 条码查询
- 聚合数据条码查询
- 探数商品基础条码查询
- 探数成分/营养接口查询
- 自定义国内条码接口查询

确认页会把不同数据源的结果分别展示为不同候选项，由用户选择保留最准确的一项。

## 4. 动态数据源与获取时间标识

新增文件：

- `lib/health_diet/widgets/health_diet_data_source_banner.dart`

已接入页面包括：

- 健康饮食首页
- 健康饮食设置
- 健康档案
- Health Connect
- 今日饮食调理
- AI 营养膳食专家
- 每日饮食分享
- 语音输入
- 条码扫码
- 饮食确认
- 今日复盘
- 饮食历史
- 食物利弊查询
- 菜谱搜索
- 菜谱详情
- 购物清单
- 长期报告
- 微行动
- Agent 目标

这些页面现在会显示：

- 当前使用的数据源
- 本次刷新/获取时间
- 该页面哪些是动态结果，哪些只是配置、规则或保底展示

## 注意

本次改造仍属于源码级静态修改，未在当前环境运行 Flutter 编译。若编译出现新错误，请提供完整编译日志继续修复。

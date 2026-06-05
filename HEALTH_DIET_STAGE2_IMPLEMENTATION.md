# 健康饮食模块第二阶段落地说明

## 入口

模块入口仍为：

- 发现之旅 / 生理赋能 / 饮食

第二阶段新增入口：

- 每日饮食分享
- 今日饮食复盘
- 饮食记录历史

## 已实现功能

### 1. 每日饮食分享

路径：`lib/health_diet/daily_share/daily_diet_share_page.dart`

支持：

- 文字描述饮食
- 上传餐食图片 / 包装食品图片 / 营养成分表图片
- 语音转文字记录
- 条形码记录预留

图片会被复制到应用文档目录：

`health_diet/daily_images/`

第二阶段先保存图片路径，后续阶段再接入 AI 视觉识别 / OCR / Open Food Facts / 薄荷健康。

### 2. 语音转文字

路径：`lib/health_diet/daily_share/diet_voice_input_page.dart`

新增依赖：

```yaml
speech_to_text: ^7.3.0
```

新增 Android 权限：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

新增 iOS 权限说明：

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

语音识别结果会进入确认页，用户可以手动编辑后保存。

### 3. 饮食识别确认页

路径：`lib/health_diet/daily_share/diet_food_confirm_page.dart`

功能：

- 显示系统从文字/语音解析出的食物项
- 显示已上传图片
- 支持添加食物
- 支持修改食物名称、份量、餐次
- 支持删除识别错误的食物
- 确认后保存到数据库

### 4. 今日饮食复盘

路径：`lib/health_diet/daily_share/daily_diet_review_page.dart`

第二阶段先实现本地基础规则复盘：

- 今日做得好的地方
- 今日最值得注意的问题
- 明日最小改变
- 基础恢复指数
- 蛋白质、蔬菜、高糖、高盐、加工食品风险粗评分

后续阶段可替换或叠加 AI 复盘、营养数据库和 Health Connect 数据。

### 5. 饮食记录历史

路径：`lib/health_diet/daily_share/daily_diet_history_page.dart`

功能：

- 按日期查看最近饮食记录
- 显示输入类型：文字、图片、语音、条码
- 显示已确认食物
- 支持删除记录

## 新增模型

路径：`lib/health_diet/models/daily_diet_entry.dart`

包含：

- `DailyDietEntry`
- `DetectedDietFood`
- `DailyDietImage`
- `DailyDietReview`

## 新增仓库

路径：`lib/health_diet/repositories/daily_diet_entry_repository.dart`

负责：

- 保存每日饮食记录
- 保存图片索引
- 保存语音转文字记录
- 保存已确认食物项
- 查询今日记录
- 查询历史记录
- 删除记录

## 新增服务

### 1. 饮食文字解析服务

路径：`lib/health_diet/services/diet_input_parser_service.dart`

将自然语言饮食描述解析成结构化食物项。

### 2. 今日饮食复盘服务

路径：`lib/health_diet/services/daily_diet_review_service.dart`

基于已确认食物、健康档案和本地健康规则生成基础复盘。

## 新增数据库表

在 `AppDatabase.ensureHealthDietTables()` 中新增：

- `daily_diet_entries`
- `daily_diet_images`
- `daily_diet_voice_records`
- `detected_diet_foods`
- `daily_nutrition_summary`
- `diet_habit_patterns`
- `diet_micro_actions`
- `health_connect_daily_summary`

并新增对应索引。

数据库版本从 32 升级到 33。

## 新增 Prompt 模板

在 `HealthDietPrompts` 中新增：

- `dietInputParse`
- `dailyDietReview`
- `habitPatternAnalysis`

第二阶段暂未强制调用 AI，先保留模板，为第三阶段接入 AI 复盘做准备。

## 第二阶段边界

已实现：

- 用户可真实记录每日饮食
- 可上传图片
- 可语音转文字
- 可确认食物
- 可保存历史记录
- 可生成基础复盘

暂未实现：

- AI 图片识别
- OCR 营养成分表识别
- Open Food Facts / 薄荷健康条码查询
- USDA 营养数值估算
- Health Connect 实时数据融合
- AI 深度复盘和长期习惯分析

这些内容建议放入第三阶段及后续阶段。

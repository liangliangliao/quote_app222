# 健康饮食模块第三阶段落地说明

## 本阶段目标

第三阶段重点从“能记录”升级到“能生成更可信的饮食复盘与习惯评分”：

- 修复部分设备语音识别 `recognizerNotAvailable` 的 Android 查询声明缺失问题。
- 修复图片/混合记录可能把无关文字、占位内容或文件名误当成食物的问题。
- 强化文字/语音饮食描述解析，过滤“明天/明年/图片/这包”等非食物词。
- 新增本地饮食结构分析服务，按已确认食物生成健康评分。
- 新增饮食习惯报告，统计最近记录中的高糖、高盐、加工食品、低蛋白、低蔬菜、早餐缺失等模式。

## 语音识别修复

修改文件：

- `android/app/src/main/AndroidManifest.xml`
- `lib/health_diet/daily_share/diet_voice_input_page.dart`

新增 Android 11+ package visibility 查询：

```xml
<queries>
  ...
  <intent>
    <action android:name="android.speech.RecognitionService" />
  </intent>
  <intent>
    <action android:name="android.speech.action.RECOGNIZE_SPEECH" />
  </intent>
</queries>
```

说明：
`speech_to_text` 依赖系统自带或第三方语音识别服务。如果设备本身没有可用识别服务，代码无法凭空提供本地识别能力；本次已增加重新检测、友好提示和手动输入兜底。

## 图片记录修复

修改文件：

- `lib/health_diet/daily_share/diet_food_confirm_page.dart`
- `lib/health_diet/daily_share/daily_diet_share_page.dart`
- `lib/health_diet/services/diet_input_parser_service.dart`

核心变化：

- 图片记录目前只保存图片路径，不会自动从图片文件名或占位文本生成食物。
- 确认页必须至少有一个用户确认的食物项才能保存。
- 若只有图片，没有食物项，会提示用户手动添加。
- 过滤“明天/明年/图片/照片/上传/这包/食物”等非食物词，避免错误记录进入复盘。

## 第三阶段新增服务

新增文件：

- `lib/health_diet/services/diet_food_analysis_service.dart`
- `lib/health_diet/services/diet_habit_pattern_service.dart`
- `lib/health_diet/habit/diet_habit_report_page.dart`

### 饮食结构评分

基于已确认食物判断：

- 蛋白质充足分
- 蔬菜水果分
- 膳食纤维分
- 高糖风险
- 高盐风险
- 加工食品风险
- 油炸/烧烤风险
- 餐次规律分
- 饮食恢复指数

### 饮食习惯报告

最近记录会被分析为以下模式：

- 甜饮/高糖食物频繁
- 高盐/重口味出现偏多
- 加工食品出现偏多
- 优质蛋白来源不足
- 蔬菜水果和膳食纤维偏少
- 早餐缺失

每个模式会显示：

- 出现频率
- 证据记录
- 对身体恢复/饮食结构的影响
- 下一步微行动

## 首页变化

修改文件：

- `lib/health_diet/pages/health_diet_home_page.dart`

新增入口：

- 饮食习惯报告

并将阶段说明更新为第三阶段。

## 仍需后续阶段完成

- 真正的 AI 图片识别 / OCR 识别营养成分表。
- 接入薄荷、USDA、Open Food Facts 获取真实营养数值。
- Health Connect 睡眠、步数、体重、运动数据联动。
- 菜谱推荐与购物清单。
- AI 生成更自然的饮食复盘解释。

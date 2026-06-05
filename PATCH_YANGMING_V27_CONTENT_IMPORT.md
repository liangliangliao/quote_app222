# Yangming Module v27 - Content Import Workflow

本次继续按原 PRD 推进，重点完成：

1. 27 段课程的版权合规内容导入机制
2. 批量 JSON 导入 + 逐段手动编辑
3. 课程详情页直接显示已导入的原文 / 深度分析 / 详细解释
4. 课程库与总览加入导入进度反馈
5. 保持继续复用宿主 app 现有 OpenAI / DeepSeek 模型与设置

## 新增
- `lib/yangming_module/yangming_content_import_page.dart`
- `YangmingLessonContent` 内容模型
- `YangmingDao` 内容持久化方法

## 入口
- 知行书院模块 AppBar 新增 “导入课程内容”
- 课程库页新增 “导入内容” 按钮
- 课程详情页新增 “导入内容 / 编辑内容” 按钮

## 支持的 JSON 结构
- `{ "lessons": [ ... ] }`
- `[ { lessonId, originalText, deepAnalysis, detailedExplanation } ]`

## 说明
- 本版本重点是把原 PRD 中的“完整导入机制”打通
- 未预装受版权保护全文
- 需要用户导入其合法持有的内容

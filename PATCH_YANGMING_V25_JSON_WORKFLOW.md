# 知行书院 v25

本次继续基于原 PRD 推进，重点把知行书院的 AI 输出升级为结构化 JSON 工作流，并保持：
- 作为宿主 App 左侧菜单中的独立模块
- 继续复用宿主 App 现有 DeepSeek / OpenAI 配置
- 不新增独立模型系统

## 本次新增
1. 结构化 AI 输出模型
   - 课程深度讲解 -> YangmingExplainResult
   - 行动链 -> YangmingActionPlanResult
   - 问题诊断 -> YangmingDiagnosisResult
   - 复盘总结 -> YangmingReviewResult

2. AI 服务升级
   - 改为请求 JSON 对象
   - 增加 JSON 解析与本地 fallback
   - 继续复用宿主 App 当前 provider / model / key

3. 页面升级
   - 课程详情页：结构化展示 AI 深度讲解与 AI 行动链
   - 问题诊断页：结构化展示 TOP3 课程匹配与推荐起点
   - 复盘页：结构化展示主要问题、值得肯定、修正点、明日行动、提醒
   - 行动链可分别加入“今日最小行动”和“本周行动链”

## 修改文件
- lib/yangming_module/yangming_models.dart
- lib/yangming_module/yangming_ai_service.dart
- lib/yangming_module/yangming_module_home_page.dart

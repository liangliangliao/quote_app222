# PATCH_REALISTIC_OPTIMISM_MODULE_V1

新增完整独立模块：`现实乐观 · 信念行动系统`。

## 新增文件
- `lib/realistic_optimism_module/realistic_optimism_models.dart`
- `lib/realistic_optimism_module/realistic_optimism_prompt_config.dart`
- `lib/realistic_optimism_module/realistic_optimism_dao.dart`
- `lib/realistic_optimism_module/realistic_optimism_ai_service.dart`
- `lib/realistic_optimism_module/realistic_optimism_home_page.dart`

## 接入
- `lib/main.dart` 已导入新模块并在侧边栏新增入口：`现实乐观信念行动系统`。

## 功能闭环
- 四分钟墙：限制性信念扫描
- 现实校准：事实/解释/可控/不可控/资源/风险拆分
- 皮格马利翁期待重构：旧期待 → 现实积极期待
- 环境启动：积极线索、手机提示、反启动清理
- 行动实验：最小行动、时间地点、成功标准、if-then、兜底动作
- 失败复盘：永久化/普遍化/人格化/灾难化检测并转成反馈资料
- Cope 训练：舒适区/伸展区/恐慌区三档行动
- 基线追踪：情绪、自尊、自我效能、cope/avoid、最小行动、现实乐观解释

## 数据表
所有表由 DAO 启动时幂等创建，无需修改数据库版本：
- `realistic_optimism_cases`
- `realistic_optimism_action_logs`
- `realistic_optimism_failure_reviews`
- `realistic_optimism_baselines`

## AI
复用全局统一 AI 配置；AI 不可用时自动使用本地规则兜底生成完整行动闭环。

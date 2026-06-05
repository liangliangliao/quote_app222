# Action Tree Split Update

本次更新把概念行动树生成改成了“两段式”AI流程：

1. 首先只生成“至少 10 个行动方向”的概览树（更快、更稳）
2. 用户进入某个行动方向后，再按需调用 AI 展开成模块与具体步骤
3. 自定义步骤也支持调用 AI 继续拆分成更小的可执行步骤
4. AI 输出会自动给步骤打 `importance` / `linkedCabinType` 标签（如模型有返回），并在本地做兜底推断

相关改动：
- `ConceptEngineService`
  - `generateActionConceptTreeOverview(...)`
  - `expandActionDirection(...)`
  - `expandCustomActionStep(...)`
- `ActionEngineRepository`
  - `generateConceptTree(...)` 改为先取概览树
  - 新增 `expandDirection(...)`
  - 新增 `expandCustomStep(...)`
- `ActionDirection` 新增：
  - `needsExpansion`
  - `previewModuleCount`
  - `previewStepCount`
- `ActionConceptTreePage`
  - 显示预估模块/步骤数量
- `ActionBreakdownPage`
  - 进入页面后按需展开行动方向
  - 自定义步骤可通过 AI 继续扩展

说明：
- 如果 AI 展开失败，会自动回退到本地方向展开，不会阻塞页面。
- 这一步主要目标是提升 DeepSeek 直连下的成功率与响应速度。

# ACTION ENGINE AI INTEGRATION NOTE

本次更新把“概念行动引擎”往你要求的方向推进了两步：

1. **行动树改为 AI 动态生成主导**
   - 用户输入概念、目标、语境、维度（可选）
   - 系统优先调用 AI 生成行动树
   - 默认要求至少生成 10 个行动方向
   - 每个行动方向继续细化为模块和可执行步骤
   - 如果 AI 失败，则自动回退到内置概念或本地 fallback 行动树

2. **行动引擎与训练舱进一步整合**
   - 行动链中的关键步骤继续支持进入训练舱强化
   - 训练舱大厅新增“先从行动引擎生成行动树”入口
   - 行动引擎现在是主线，训练舱是关键节点强化器

## 主要改动文件

- `lib/concept_engine/concept_engine_service.dart`
- `lib/concept_engine/action_engine/models/action_engine_models.dart`
- `lib/concept_engine/action_engine/repository/action_engine_repository.dart`
- `lib/concept_engine/action_engine/pages/action_engine_home_page.dart`
- `lib/concept_engine/action_engine/pages/action_concept_tree_page.dart`
- `lib/concept_engine/action_engine/pages/action_breakdown_page.dart`
- `lib/concept_engine/cabins/training_hub_page.dart`

## 说明

- 当前 AI 生成使用新的 `concept_engine.action_tree` 日志模块写入请求/响应日志。
- 当前没有新增独立设置项，维度由行动引擎首页输入。
- 关键步骤与训练舱的关系保持现有融合方式：步骤带 `importance + linkedCabinType`，执行页进入训练舱强化。

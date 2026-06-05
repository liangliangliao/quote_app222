# Action Tree Paths & Cabin Tags Update

本次更新重点：
1. 行动拆解页新增 **AI 补充更多实现路径** 按钮。
2. 新增日志模块：
   - `concept_engine.action_tree.more_paths`
   - `concept_engine.action_tree.more_paths.fast_retry`
3. 新增服务方法：
   - `expandActionDirectionMorePaths(...)`
4. 仓库层新增：
   - `expandDirectionMorePaths(...)`
   - 更稳定的关键步骤推断：
     - `importance`
     - `linkedCabinType`
5. 即使 AI 未显式返回标签，也会基于概念/方向/步骤文本自动推断：
   - `delayReport`
   - `boundaryExpression`
   - `selfDisciplineStart`
6. 本地 fallback 也会补充不同实现路径，避免页面只有单一路线。

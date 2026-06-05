本次修复：DeepSeek 生成行动树超时

问题现象：
- 概念行动引擎页面提示“AI 暂时不可用，已根据概念生成本地 fallback 行动树”
- 日志中出现 `concept_engine.action_tree` 的 `TimeoutException after 0:01:00.000000`

本次修复内容：
1. 行动树生成改为“两段式 AI 请求”
   - 第一段：标准行动树 prompt
   - 第二段：快速精简 prompt（fast retry）
2. 行动树生成专用超时提升
   - 首次尝试：至少 120 秒
   - 快速重试：至少 75 秒
3. 行动树请求缩小输出体量
   - 标准请求 `maxTokens` 从 6000 降到 3200
   - 快速重试 `maxTokens` 为 2200
4. 代理模式也同步支持超时覆盖
   - 避免代理链路仍然卡在全局 60 秒

预期效果：
- DeepSeek 在生成 10 个行动方向时，更不容易因为 `deepseek-reasoner` 思考过久而直接超时
- 即便第一次超时，也会自动走一次精简快速重试
- 只有两次都失败时，才会回退到本地 fallback 行动树


# DeepSeek 行动树空响应修复说明

本次修复针对 `concept_engine.action_tree.overview.fast_retry` 在 DeepSeek `deepseek-reasoner` 下出现：

- 解析模型响应失败
- 模型返回内容为空

## 修复内容

1. 行动树概览生成增加 4 段式尝试：
   - 标准 JSON 模式
   - 快速 JSON 模式
   - 关闭 `response_format` 的 plain retry
   - 当提供商为 DeepSeek 且模型为 `reasoner` 时，自动用 `deepseek-chat` 做最后一次 chat retry

2. `action_tree` 专用超时分层：
   - 标准概览：至少 120 秒
   - 快速重试：至少 75 秒
   - plain/chat retry：至少 75 秒

3. 允许在直连与代理两种模式下都覆盖：
   - `useJsonResponseFormat`
   - `modelOverride`

4. 代理日志与请求体中的模型名现在会显示实际生效模型，而不是固定显示原模型。

## 预期效果

日志中如果 `overview` 与 `fast_retry` 失败，应该还能继续看到：

- `concept_engine.action_tree.overview.plain_retry`
- `concept_engine.action_tree.overview.chat_retry`

其中 `chat_retry` 会把 DeepSeek 的 `reasoner` 最后降级为 `deepseek-chat`，以规避部分空响应问题。

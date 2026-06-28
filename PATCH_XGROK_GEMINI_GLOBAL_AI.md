# PATCH: xGrok / Gemini Global AI Provider Support

本补丁在设置页和统一 AI 调用链中新增 xGrok 与 Gemini：

- 设置页新增 xGrok API Key、Gemini API Key 输入框。
- 全局 AI 提供方下拉新增 xGrok、Gemini。
- 全局 AI 模型版本刷新支持：
  - xGrok: https://api.x.ai/v1/models
  - Gemini: https://generativelanguage.googleapis.com/v1beta/openai/models
- 统一调用支持：
  - xGrok: https://api.x.ai/v1/chat/completions
  - Gemini: https://generativelanguage.googleapis.com/v1beta/openai/chat/completions
- 首页左侧复用统一 AI 的模块会通过 GlobalAiSettings / UnifiedAiService 自动读取新 provider、模型与密钥。
- 概念实践引擎、AI 助手的 provider 标签与基础调用兼容已同步扩展。

默认模型：
- xGrok: grok-4.3
- Gemini: gemini-3.5-flash

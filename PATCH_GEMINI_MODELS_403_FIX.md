# Gemini 模型列表 403 修复

## 问题
设置页刷新 Gemini 全局 AI 模型列表时，请求 `https://generativelanguage.googleapis.com/v1beta/openai/models`，部分账号/网络环境会返回 Google HTML 403：

`Your client does not have permission to get URL /v1beta/openai/models from this server.`

## 修复
- Gemini 聊天调用继续使用 OpenAI-compatible 接口：
  `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`
- Gemini 模型列表查询改为 Gemini 原生 Models API：
  `https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000`
- 模型列表鉴权改为 `x-goog-api-key` header，避免把 API Key 放进日志 URL。
- 解析 Gemini 原生 `models[]` 响应，优先使用 `baseModelId`，并过滤仅支持 `generateContent` 的模型。
- 自动把 `models/gemini-xxx` 规范化为 `gemini-xxx`，避免下拉选中后实际聊天调用失败。

## 修改文件
- `lib/services/unified_ai_service.dart`
- `lib/services/global_ai_settings.dart`
- `lib/utils/deepseek_logger.dart`（补充隐藏 `x-goog-api-key`）

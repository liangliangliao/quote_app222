# AI 助手图片与文件分析增强

本补丁把 AI 助手附件能力从“基础上传展示”升级为“按模型平台能力路由的多模态/文件分析”。

## 已实现

1. 图片上传分析
   - OpenAI / OpenRouter / Eden AI：按 OpenAI-compatible `image_url` 多模态内容发送 base64 data URL。
   - DeepSeek：当模型名包含 `v4` / `vision` / `vl` 时按多模态图片发送；否则只发送附件说明。

2. 文件上传分析
   - OpenAI Responses/Chat：支持以 `input_file` / `file` content part 发送本地文件 base64 data URL。
   - OpenRouter：支持 PDF 以 `file` content part 发送，并启用 `file-parser` 插件，默认使用 `cloudflare-ai` 引擎。
   - Eden AI：上传文件到 `/v3/upload`，保存并复用 `file_id`，然后在 `/v3/chat/completions` 中以 `file_id` 引用。
   - DeepSeek：当前不使用原生文件输入；会把本地可提取文本拼入消息。

3. 本地文本提取兜底
   - 支持 TXT/MD/CSV/JSON/XML/HTML/代码/日志等文本类文件。
   - 支持 DOCX 文本提取。
   - 支持 PPTX 幻灯片文本提取。
   - 支持 XLS/XLSX 前 1000 行/表提取。
   - 支持 PDF 文本型内容的轻量提取；扫描件 PDF 仍建议走 OpenRouter PDF parser / OpenAI / Eden AI 原生文件能力。

4. 数据库升级
   - DB version: 31
   - `ai_assistant_attachments` 新增：
     - `provider`
     - `provider_file_id`
     - `provider_uploaded_at_ms`
     - `provider_expires_at`

5. UI 增强
   - 附件卡片显示图片缩略图。
   - 待发送附件显示图片缩略图。

## 注意

- 并不是所有模型都支持所有附件类型。OpenRouter 官方也说明不同模型支持的输入模态不同，模型会按请求内容和模型能力处理。
- Eden AI 的 LLM 文件功能依赖 `/v3/upload` 上传后的 `file_id`。
- OpenAI 官方 Responses API 支持 PDF、文档、表格等文件输入，但大文件和复杂表格仍建议使用专门检索/表格处理。

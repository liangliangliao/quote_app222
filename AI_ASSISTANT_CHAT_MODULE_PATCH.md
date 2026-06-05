# AI 助手聊天模块接入补丁

本补丁在外部数据同步首页加入可拖动悬浮 AI 助手入口，并新增本地 AI 聊天模块。

## 已实现

- 新增 `lib/ai_assistant/` 模块：
  - `ai_assistant_models.dart`
  - `ai_assistant_dao.dart`
  - `ai_assistant_service.dart`
  - `ai_assistant_page.dart`
  - `ai_assistant_bubble.dart`
- 新增本地数据库表：
  - `ai_assistant_conversations`
  - `ai_assistant_messages`
  - `ai_assistant_ui_state`
- 数据库版本从 21 升级到 22，并在 onCreate/onUpgrade/运行时 ensure 中幂等创建 AI 助手表。
- 在 `UnifiedAiService` 增加 `generateChatMessages()`，支持按 `messages[]` 形式发送完整本地历史上下文。
- DeepSeek / OpenRouter / EdenAI 均走本地历史拼接：
  - 从本地 DB 读取当前会话全部 user/assistant 消息
  - 按 created_at/id 正序组成 messages
  - 当前用户消息作为最后一条 user 消息
  - 不使用远端 conversation_id / previous_response_id
  - 不做摘要压缩
- 在 `ExternalDataSyncHomePage` 中加入 `AiAssistantFloatingBubble`：
  - 圆形 AI 图标
  - 可拖动
  - 位置本地保存
  - 点击打开 AI 聊天页面
- 聊天页面支持：
  - 新建会话
  - 历史会话列表
  - 删除当前会话
  - 删除全部历史聊天
  - 本地保存用户消息与 AI 回复
  - 从设置页已有全局 AI 模型配置读取当前 provider/model

## 重要说明

当前版本按你的要求不设置复杂系统提示词，主要让用户像普通 AI 模型应用一样直接聊天。聊天上下文完全依赖本地 `ai_assistant_messages` 表拼接。

如果单个会话历史非常长，可能超过所选模型上下文限制；当前版本不做压缩，会将 provider 返回的错误展示并保存到会话中。

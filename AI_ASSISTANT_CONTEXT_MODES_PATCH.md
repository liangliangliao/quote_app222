# AI Assistant Context Modes Patch

本次改动基于 `quote_app_conscious_change_v28_ai_assistant_patched.zip` 重新调整 AI 聊天助手的历史上下文传送规则。

## 已实现

聊天界面新增“上下文模式”选择，支持两种方式：

1. **拼接全部历史**
   - 默认模式。
   - 每次调用聊天模型时，读取当前本地会话下全部 `user/assistant` 消息。
   - 按真实时间顺序作为 `messages[]` 发送给当前设置页选中的模型。

2. **OpenRouter Embedding 语义检索**
   - 使用 OpenRouter Embedding API：`openai/text-embedding-3-small`。
   - 先为当前用户问题生成 embedding。
   - 为当前会话中缺少 embedding 的历史消息补齐 embedding，并保存到本地 SQLite。
   - 用 cosine similarity 从历史记录里选出语义相关消息。
   - 只把语义相关历史消息 + 当前用户消息发送给当前设置页选中的聊天模型。
   - 聊天模型仍然可以是 DeepSeek / OpenRouter / EdenAI；embedding 固定走 OpenRouter。

## 明确未实现

按本次需求，以下能力已不作为上下文策略参与：

- 最近 N 条消息窗口
- 关键词检索
- 本地记忆抽取
- 摘要压缩
- 远端 conversation_id / previous_response_id

## 数据库改动

数据库版本升级到 `23`。

`ai_assistant_conversations` 新增：

```sql
context_mode TEXT NOT NULL DEFAULT 'full_history'
```

`ai_assistant_messages` 新增：

```sql
embedding_json TEXT
embedding_model TEXT
embedding_updated_at_ms INTEGER
```

## 主要文件

- `lib/ai_assistant/ai_assistant_models.dart`
- `lib/ai_assistant/ai_assistant_dao.dart`
- `lib/ai_assistant/ai_assistant_embedding_service.dart`
- `lib/ai_assistant/ai_assistant_service.dart`
- `lib/ai_assistant/ai_assistant_page.dart`
- `lib/data/db.dart`
- `lib/external_data/onenote_pages.dart`

## 注意

当前环境没有 Flutter/Dart SDK，无法执行 `flutter analyze` 或 `flutter build`。已进行基础括号匹配检查，并修复了之前 `onenote_pages.dart` 中误把多个页面 body 包成 Stack 的问题。

## Superseded note

The semantic embedding mode in this document was superseded by `AI_ASSISTANT_EDENAI_EMBEDDING_AND_LOGS_PATCH.md`: it now uses Eden AI `/v3/embeddings` with `openai/text-embedding-3-small`, not OpenRouter embeddings.

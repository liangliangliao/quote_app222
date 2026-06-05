# Concept Engine Proxy API Contract (Client -> Backend)

## Endpoint
`POST /api/concept-engine/proxy`

## Request Body
```json
{
  "route": "concept_engine_json_task",
  "provider": "deepseek",
  "target_endpoint": "https://api.deepseek.com/chat/completions",
  "model": "deepseek-reasoner",
  "response_format": "json_object",
  "max_tokens": 3000,
  "system_prompt": "...",
  "user_payload": {"concept": "责任感", "domain": "职场"},
  "module": "concept_engine.parse",
  "trace_id": "ce_xxx",
  "session_id": "ces_xxx"
}
```

## Compatible Response Shapes
客户端当前支持以下任一结构：

### Shape A
```json
{ "json": { ...最终结构化 JSON... } }
```

### Shape B
```json
{ "result": { ...最终结构化 JSON... } }
```

### Shape C
```json
{ "data": { ...最终结构化 JSON... } }
```

### Shape D
```json
{ "content": "{ \"concept\": \"责任感\" }" }
```

### Shape E
直接返回目标 JSON：
```json
{ "concept": "责任感", "definitions": ["..."] }
```

## Recommendations
- 后端统一接管：
  - DeepSeek / OpenAI 鉴权
  - Prompt 版本化
  - 日志审计
  - 风险过滤
  - 状态机和评分规则
- 后端返回前最好做 JSON 校验。

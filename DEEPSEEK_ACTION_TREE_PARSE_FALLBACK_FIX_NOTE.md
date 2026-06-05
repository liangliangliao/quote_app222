# DeepSeek 行动树解析修复

本次修复针对 `concept_engine.action_tree.overview*` 链路中：
- DeepSeek 返回空 `message.content`
- 但响应体里可能仍存在可解析文本 / reasoning_content / text 片段
- 原逻辑直接报“模型返回内容为空”

## 修复内容
1. 增强 `ConceptEngineService._extractMessageContent`
   - 先走直接提取
   - 再递归扫描响应中的 `content / text / output_text / reasoning_content / message`
   - 只要找到可疑 JSON 文本就继续解析
2. 新增 `_extractDirectContent`
   - 兼容 `choices[].message.content`
   - 兼容 `choices[].message.reasoning_content`
   - 兼容 `choices[].text`
   - 兼容 Responses API 的 `output[].content[]`

## 目标
即使 DeepSeek 在某次重试中没有把 JSON 放进标准 `message.content`，
只要响应体里仍有可用文本，就尽量继续解析，而不是直接失败。

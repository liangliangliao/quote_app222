# Azure / Microsoft Foundry 模型接入

本补丁把 Azure 加入全局 AI 提供方，支持同时接入多个 Azure 资源（项目），把各资源里已部署的模型合并成一张统一模型表；选中任意一个 Azure 模型后，全 app 走统一 AI 路径的调用都会切到 Azure。

## 已实现

### 1. 多资源模型列表

- 新增 `lib/services/azure_ai_settings.dart`：`AzureAiResource` + `AzureAiSettings`。
- 资源表存在 KV 键 `global_ai_azure_resources`（JSON 数组），每条记录包含：
  - `name`：资源/项目名，例如 `AzureOpenAI`、`modleapikey`
  - `endpoint`：Microsoft Foundry 项目终结点或 Azure OpenAI 终结点
  - `api_key`、`api_version`、`kind`（接入方式）、`deployments`（手填部署名兜底）、`enabled`
- 终结点归一化：`https://<res>.services.ai.azure.com/api/projects/<project>`、`https://<res>.openai.azure.com`、
  以及已带 `/openai`、`/openai/v1`、`/models` 后缀的写法，都会被裁成同一个资源根地址；缺少协议头时自动补 `https://`。
- 模型列举按资源依次尝试并在第一条成功的地址上停止：
  1. `/openai/deployments?api-version=2023-03-15-preview`（部署列举，最权威）
  2. `/openai/models?api-version=<版本>`
  3. `/openai/v1/models`
  4. `/models?api-version=<版本>`（Foundry 资源会提前到第 2 位）
  全部失败时退回该资源手工登记的部署名，因此订阅关闭列举接口时仍可选模型。
- 列举结果会过滤掉 embedding / whisper / dall-e / tts / rerank 等非聊天部署，以及未部署成功的条目。
- 模型 id 使用 `资源名/部署名` 的限定写法（例如 `AzureOpenAI/gpt-5.6-chat`、`modleapikey/claude-sonnet-4-5`），
  因此不同项目里的同名部署不会互相覆盖，选中后也能唯一定位回所属资源与终结点。

### 2. 调用参数

- 鉴权：Azure 走 `api-key` 头；`/models/…` 与 `/openai/v1/…` 两条路径额外带 `Authorization: Bearer`。
- api-version：留空时按接入方式取默认值（Azure OpenAI `2024-10-21`，Foundry `2024-05-01-preview`）。
- 调用地址按接入方式排出候选优先级，命中 404 / 405 / `DeploymentNotFound` 一类“路径或部署不存在”的错误时自动换下一条重试：
  - Azure OpenAI 部署：`/openai/deployments/<部署名>/chat/completions` → `/openai/v1/chat/completions` → `/models/chat/completions`
  - Foundry 模型推理：`/models/chat/completions` → `/openai/v1/chat/completions` → `/openai/deployments/<部署名>/chat/completions`
  这样同一个资源里的 gpt / Claude / Grok 都能打通。模型自身的错误（内容过滤、超限等）不做无意义回退，直接抛出。
- gpt-5 / o 系列部署改用 `max_completion_tokens`，并且不下发 `temperature` / `top_p`（Azure 只接受默认值）。
- Claude / Grok / Llama / Mistral 部署不下发 `response_format: json_object`（这些模型会直接 400），
  严格 JSON 任务继续依赖 prompt 约束。
- 设置页“全局 AI 请求关键参数”（超时、最大输出 tokens、temperature、top_p、重试次数与间隔）同样作用于 Azure。

### 3. 全局生效范围

- `GlobalAiSettings`：新增 `azure` 提供方与 `global_ai_model_azure`，`getState()` 返回 `azure_model` / `azure_resource_count`，
  并在未显式选择提供方时把“已配置 Azure 资源”纳入自动推断。
- `UnifiedAiService`：`resolveGlobalConfig` / `fetchAvailableModels` / `generateText` / `generateChatMessages` 全部支持 Azure。
  `UnifiedAiResolvedConfig` 新增 `deployment`、`azureResourceName`、`azureKind`、`apiVersion`、`endpointCandidates`、`authHeaders`。
- 由于全 app 的 AI 调用都收敛在 `UnifiedAiService`，以下路径切换到 Azure 后自动生效，无需逐个改动：
  目标训练、概念实践引擎、AI 助手、冥想、语义一致性判定、羞耻转化、健康饮食、翻译、电影角色实验室等。
- 概念实践引擎自建请求：`ConceptEngineRuntimeConfig` 新增 `deployment` 与 `authHeaders`，
  `_postDirect` 按之改用 `api-key` 鉴权、下发部署名、并套用上面的 gpt-5 / Claude 参数规则。
- 语音闹钟原生侧：Dart 下发 `authHeaders`、`maxTokensField`、`allowSamplingParams`，
  `VoiceAlarmActivity` 新增 `applyAiAuthHeaders()` 统一按下发内容设置鉴权头；旧 payload 缺字段时回退 `Bearer`，保持兼容。
- AI 助手多模态：Azure 按部署名里的模型线索判断是否可发图片；文件附件走本地文本提取兜底
  （Azure chat/completions 不接受 OpenAI 的 file part）。

### 4. 设置页

- 新增“Azure / Microsoft Foundry 资源”区块：资源卡片列表 + 添加/编辑/删除，编辑在独立弹窗里完成。
- 弹窗内可填资源名、终结点、密钥、接入方式、api-version、部署名，并实时预览归一化后的资源根地址、项目名与调用地址。
- “全局 AI 提供方”新增 `Azure / Microsoft Foundry` 选项；选中后展示当前调用地址，未配置资源时给出明确提示。
- 点“刷新模型列表”会先落盘编辑中的资源表再拉取，因此刚填完密钥即可直接刷新。
- 保存时资源名若因重名被去重改写，已选模型会按新资源名重新限定，避免指向不存在的资源名。

## 测试

`test/services/azure_ai_settings_test.dart`：19 条用例，覆盖终结点归一化、调用地址候选与优先级、
鉴权头、限定模型 id 往返转换、部署名输入解析、接入方式规范化与内置模板。

## 未包含

- 语义一致性模块的 Embedding 提供方仍是独立设置（OpenRouter / OpenAI / Eden AI），不随全局提供方切换；
  该行为与 Gemini、xGrok 接入时保持一致，本次未改动。

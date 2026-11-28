# 语音闹钟逐轮起床提醒（2026-11-18）

起床模式默认开启“逐轮调整起床提醒”；睡觉模式默认关闭，可逐模式选择。安装后在语音闹钟页保存设置，同步现有闹钟。

## 播报组成与轮次

1. 保存的“到点朗读内容”。
2. 闹钟触发时读取本机 quotes.db 中最多 3 条近期未完成事项：目标设置中的 todo/doing 行动、WOOP active 卡、Microsoft To Do 本地待办（含我的一天、近期修改和即将到期）。无数据或解锁前不可读则略过。不读取完整聊天、个人档案、原始同步 JSON 或密钥表。
3. 本轮起床提醒。启用 AI Wakeup 且返回当天有效正式内容时，第一轮使用其 body 原文，不额外请求 AI 改写或生成第一轮；否则调用当前全局 AI 配置。后续每次重复重新读取事项，结合首轮与历次尝试生成新的提醒。

每轮历史记录含正文、来源、策略、播报状态。未关闭按用户指定规则推定仍未起床，不冒充传感器观测，不上传“已经起床”或“失败”作为网站实际反馈。超过 13 轮时仍保留每轮结果，较早正文明确标为摘要片段，首轮原文及最近 12 轮原文保留。网络失败用明确标记的本地动作提示；重复正文最多重试一次，不伪称 AI 生成成功。

重播尊重用户间隔；上一轮未播完时不叠加或截断。用户对话时延后重播，完成后继续；关闭闹钟取消请求、待播回调及会话。插话中断会记录未播完，TTS 引擎失败则保留未读段重试。耳机切换不清空多轮历史。动态组合由系统 TTS 完整分段播报，云端 TTS 仍用于已支持的对话回复及非动态模式预生成音频。

## 系统识别与播报

未选择服务商及新设置默认为系统识别/系统 TTS；明确选定的已有服务商不重置。系统识别不再强制 on-device/offline 引擎，避免未安装中文离线模型造成失败。不会因为其他服务商保存过凭据而擅自切换到它。

修复识别在 onEndOfSpeech 先释放忙状态、然后 cancel/start 抢跑导致 final 结果丢失的问题。等待 onResults/onError 后重启；空 final 或 error 保留已有 partial；播报切换不停止系统监听；播报期间识别错误也会恢复。看门狗区分等待最终结果和正在讲话，避免长句在 18 秒被截断。仍需手机系统提供可用中文识别/TTS，外放回声、距离、系统服务响应会影响实机准确率。

## Azure / Microsoft Foundry 联网

普通 Azure deployment、Foundry /models/chat/completions 和 /openai/v1/chat/completions 在开启搜索时转换为同一资源的 /openai/v1/responses，使用配置中的部署名和 web_search 工具。不会把资源凭据发送至 OpenAI 官方域名。模型名不设 GPT 白名单；实际部署须支持 Responses 和工具。

不支持原生搜索的模型可在语音闹钟页填写“Azure 搜索部署名”，指定同一资源内支持 web_search 的 GPT 部署。先检索并验证来源，再用当前模型回答；支持 Foundry Chat Completions 及 Claude Messages，保持两种请求格式和鉴权。检索失败不宣称联网成功。搜索与模型调用按服务商账户计费，本次验证没有调用任何真实付费模型。

代码层也处理带项目连接的 bing_grounding Responses 请求；本次 UI 的可用配置路径是上面的同资源搜索部署，不自动创建 Foundry 项目、Bing 资源或 Entra 凭据。

## 验证

- JVM 回归：15 语音 + 16 AI Wakeup HTTP + 19 长播报/音乐/识别 + 16 新多轮/系统识别/Azure = 66 项；全部使用虚构数据和本地 HTTP。
- 新 HTTP 场景实际走“Azure 搜索部署 → 带来源资料 → Foundry Claude 回答”的请求链，验证正文、部署名、来源和鉴权头隔离；没有连接真实 Azure 资源。
- 原生 Kotlin 编译；完整 Flutter/Android APK 由 GitHub Actions 构建并核对源码树、签名与校验和。
- 安装验收：不选云语音服务；设置短固定朗读、虚构目标和 15 秒重播；检查首轮 Wakeup 与第二轮不同内容，连续三轮上下文、外放/耳机插话、音乐开关、音量调节、说关闭闹钟后全屏退出且不再返回。真实手机声学效果及账户服务权限仍需实机验收。

参考官方接口：
- https://developer.android.com/reference/android/speech/SpeechRecognizer
- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/web-search
- https://learn.microsoft.com/en-us/azure/ai-foundry/model-inference/concepts/endpoints
- https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/bing-tools

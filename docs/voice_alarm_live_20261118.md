# 语音闹钟修复（2026-11-18）

基于最新非主分支 `fix/ai-quote-dedup-original-language-20261116` 的 `af647d7`，保留已有 AI Wakeup 鉴权、正式内容校验、手动音量和全屏退出功能。

## 行为

- AI Wakeup 正文按句末优先、最多 180 个 UTF-16 单位分段，逐段等待 TTS 完成。不再由旧本地文案和 60 秒上限推断播放结束。延后下次重播不会截断当前正文。TTS 失败只重试当前段两次，保留未播段并报告失败。
- 调整语音音量只重播当前小段，保留后续段落。当前小段可能重复。超过 600 字的 AI 对话回复使用分段系统语音，避免云合成限制；不再截取前 600 字。
- “请关闭背景音乐”“把背景音乐关掉”“播放背景音乐”“恢复播放音乐”等本地执行。关闭音乐不关闭闹钟。手动关闭优先于临时静音恢复计时器，保持到本次闹钟结束。
- 连续录音会话与 AEC/降噪保持开启。输出切换不再清空 PCM，分批识别保留 600ms 开头及句内停顿，时长按音频计数。录音和网络识别分离，失败录音可手动重试。
- 流式识别用稳定候选触发暂停输出，最终修正提交文字。系统识别也可在播放时监听。xAI 的 chunk final 按顺序累积；完整 final 覆盖草稿；等待服务 ready 后发送音频，等待 audio.done 对应的最终结果后结束。
- 分批模式等转写确认非回声后再打断，避免单凭音量把闹钟自己的声音当成用户而切断。延迟取决于静音端点和网络；更快交互请选流式识别。所有模式有“打断播报，我来说”按钮。
- 插话取消旧 AI 请求和待播音频，旧回调不能再次出声；被打断回复不把未听部分留在下一次模型上下文。

## 联网设置

默认开启“语音 AI 联网搜索”，保存后同步当前模式的已排闹钟。沿用全局配置，不新增密钥，不调用 ChatGPT Plus 内部接口。

| 服务 | 搜索请求 |
| --- | --- |
| 官方 OpenAI | Responses + web_search |
| 官方 xAI | Responses + web_search |
| OpenRouter | Responses + openrouter:web_search |

模型须支持对应工具；服务商可能收取搜索费用。显示实际搜索状态和可点击来源；不支持、失败或本次未搜索均明确标注。关闭联网恢复普通对话。DeepSeek 官方直连及自定义代理不在原生搜索支持范围，可使用 OpenRouter 上的相应模型。不会自动迁移密钥到别的服务。

## 验证与实机验收

自动化只使用虚构数据和本地 HTTP 测试服务，不调用付费模型：原有语音 15 项，AI Wakeup 16 项，新增播放/音乐/PCM/联网/流式文字 19 项。APK 由 Android workflow 构建。测试证明程序逻辑及协议约定，不能替代实机声学与服务商联网验证。

安装后保存当前模式设置，并检查：

1. 超过五分钟的虚构正文无说话时完整播完；途中改两种音量不能漏掉后续正文。
2. 两种音乐语音指令分别生效；关闭后等 60 秒、拖动滑块，不能被旧定时器重新打开。
3. 流式识别播放时插话，核对首字、长句、最终纠错；分批模式在完整转写后打断。测试轻声、短暂停顿、外放及耳机；失败录音可重试。
4. 实时问题返回搜索状态与来源；断网/不支持工具应明确失败，关闭联网普通对话正常。
5. AI 请求中插话、播报时关闭闹钟，等待旧请求返回，确保没有复活播报或残留全屏。

参考公开协议（不声称复刻 ChatGPT Live 内部实现或达到同等声学效果）：

- https://developers.openai.com/api/docs/guides/realtime-vad
- https://developers.openai.com/api/docs/guides/realtime-conversations
- https://developers.openai.com/api/docs/guides/tools-web-search
- https://docs.x.ai/developers/tools/web-search
- https://docs.x.ai/developers/model-capabilities/audio/speech-to-text
- https://openrouter.ai/docs/guides/features/server-tools/web-search

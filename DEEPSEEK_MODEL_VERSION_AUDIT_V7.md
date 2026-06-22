# DeepSeek 模型版本调用审计与修复 V7

## 结论

源码中确实存在“看起来使用 DeepSeek 最新接口，但实际模型名仍可能停留在旧别名”的问题。

DeepSeek 官方当前推荐的 API 模型名是：

- `deepseek-v4-pro`
- `deepseek-v4-flash`

旧模型名：

- `deepseek-chat`
- `deepseek-reasoner`

已进入弃用倒计时，当前只是兼容别名，并指向 `deepseek-v4-flash` 的非思考/思考模式。因此，如果 App 仍保存或默认使用 `deepseek-chat` / `deepseek-reasoner`，虽然还能调用成功，但不是显式调用 `deepseek-v4-pro`。

## 本次修复

1. 默认 DeepSeek 模型统一改为 `deepseek-v4-pro`。
2. 旧别名 `deepseek-chat` / `deepseek-reasoner` 在读取和保存时自动归一化为 `deepseek-v4-pro`，避免旧数据库配置继续影响实际请求。
3. 设置页 DeepSeek 模型列表内置官方推荐项：
   - `deepseek-v4-pro`
   - `deepseek-v4-flash`
   - `deepseek-chat`
   - `deepseek-reasoner`
4. 设置页即使模型列表接口加载失败，也会显示官方推荐模型，避免只显示旧模型。
5. DeepSeek V4 请求显式增加：
   - `thinking: { type: enabled }`
   - `reasoning_effort: high`
6. DeepSeek V4 请求不再发送 `temperature` / `top_p`，因为官方说明 thinking mode 下这些参数不会生效。

## 重要说明

用户问模型“你是什么版本”并不能作为可靠判断依据。模型可能不知道服务端路由名称，也可能按训练语料或系统提示回答知识截止时间。更可靠的判断方式是查看请求日志中的：

- endpoint 是否为 `https://api.deepseek.com/chat/completions`
- body.model 是否为 `deepseek-v4-pro` 或 `deepseek-v4-flash`

本项目已有 `DeepSeekLogger`，请求日志会记录实际发送的 model 字段。

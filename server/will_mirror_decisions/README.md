# 可选 Decisions 代理

移动端默认离线。分析复用宿主 AI 配置；只有用户逐条选中资料并确认本次发送后才调用。额外的 Decisions 协同评分使用本服务，缺少服务、拒绝评分或校验失败时明确降级为本地规则。

Python 3.11+，仅标准库。服务端通过安全的环境配置提供 `OPENAI_API_KEY` 和不同的 `WILL_MIRROR_ACCESS_TOKEN`（至少 24 个字符），然后运行 `python3 proxy.py`。不要将密钥写进命令历史、源码或 APK。默认仅监听 `127.0.0.1:8088`，用受控 HTTPS 反向代理转发 `/v1/will-mirror/decisions`，并关闭代理请求体与 Authorization 日志。

在课题「事实与想要 → 更多分析设置 → 协同评分服务」填写 HTTPS 地址和服务访问令牌。二者保存在现有加密 Vault 中。OpenAI 密钥只在服务端。

固定上游 `POST https://api.openai.com/v1/decisions`，固定 Beta 模型 `gpt-6-luna`，按固定四维量规重新生成问题。请求最多 25 条候选 / 100 个问题、200KB；响应 500KB；上游超时 35 秒；每分钟 10 次。每次响应只返回 answers，关闭业务与访问日志，不持久化资料。客户端校验名称、拒绝、分数、置信度和五档概率，缺失维度保留未知。

这是供应用拥有者部署的单租户适配器。若作为公共多用户服务，需接入现有账号认证、按用户额度和令牌轮换；不要将单一共享令牌内置进发布 APK。本次仅完成模拟契约测试，未部署服务、未使用真实 API 密钥调用收费接口。

依据：[Decisions 指南](https://developers.openai.com/api/docs/guides/decisions)、[Create Decisions](https://developers.openai.com/api/reference/typescript/resources/decisions/methods/create)。Beta 接口应在实际部署时再次确认模型权限与契约。

验证：`python3 -m unittest discover -s server/will_mirror_decisions -p 'test_*.py'`（仓库根目录执行）。

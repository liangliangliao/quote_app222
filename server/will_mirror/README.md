# 意志之镜的可选 Decisions 评分服务

独立、无数据库的 FastAPI 服务；只为最多 25 个已有动机做固定四维量规评分，不生成行动事实、心理诊断或个人原则。普通 S1–S8 推理由客户端经单次资料授权后使用宿主 Provider；没有部署此服务也能使用来源规则摘要、动机图和本地记录。

## 官方契约与当前验证状态

2026-10-14 核对 OpenAI 官方 [Decisions 指南](https://developers.openai.com/api/docs/guides/decisions) 和 [Create Decisions](https://developers.openai.com/api/reference/resources/decisions/methods/create)：`POST /v1/decisions`，模型 `gpt-6-luna`，具名 `score` questions，5 个有文字说明的 levels，响应按 `answer.name` 对齐。原始 score 为 0–4 的加权值；confidence 独立保留，refusal/缺项保留未评分。不同批次不更换量规。

本仓库测试使用 HTTP 合约模拟；没有使用真实 OpenAI 凭据请求 Decisions，也没有部署线上服务。上线前必须用有权限的账户完成端到端核验。API 处于 beta，若契约变化先更新适配与测试，不能填默认分冒充在线结果。

## 运行

```sh
cd server/will_mirror
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
# 在受保护的服务环境中设置 .env.example 中的两个变量；uvicorn 不自动读取该文件。
uvicorn app:app --host 127.0.0.1 --port 8000 --no-access-log
pytest -q
```

容器：从本目录构建 Dockerfile，以受保护的环境变量启动；只将端口暴露给自己的 HTTPS 反向代理。代理关闭请求/响应 body 日志并限制请求体 500 KB。服务器及代理均不能公开 OpenAI key。客户端设置中填写 HTTPS 服务根地址及独立的 `WILL_MIRROR_ACCESS_TOKEN`；该 token 存本机加密配置，不是 OpenAI key。共享 token 适用于本人私有部署；多用户部署需要接入自己的账户鉴权、配额与费用管理。

## 本服务契约

- `GET /health`：仅版本和状态。
- `POST /v1/will-mirror/motives/score`：Bearer token，`case_id`、固定 `rubric_version`、`motives`、最小授权 `evidence`。字段以 `app.py` Pydantic 模型和 Dart `DecisionsGateway` 为准。最多 25 条动机，每批 5 条 × 4 维，最多 20 questions。
- 四维：`personal_fit / evidence_quality / decision_materiality / context_relevance`；客户端默认权重 0.35 / 0.25 / 0.25 / 0.15，可调整并保留历史榜单。
- 返回每条 motive 的四维原始 score、confidence、status 和 answerName；未知不补零。名称错位、重复、量规变化、概率分布不一致均拒收。
- 无配置 503、权限失败 401、输入无效 422、上游失败 502。错误不带私人输入或上游响应体。客户端展示来源规则摘要并保留原榜单的记录时间。
- 请求无持久化、无正文日志、不跟随重定向；并发上限 2。请求体限额与鉴权在请求模型验证之前执行。

# 健康饮食模块：Open Food Facts 条码 404 / 未收录兜底修复

## 问题

条码 `6906664826854` 调用：

`/api/v2/product/6906664826854.json`

Open Food Facts 返回：

```json
{"code":"6906664826854","status":0,"status_verbose":"product not found"}
```

这表示：扫码识别到了条码，但 Open Food Facts 公开库未收录该包装食品。它不是网络失败，也不是 API Key 问题；Open Food Facts 本身不需要 API Key。

## 本次修改

### 1. 条码查询增加 fallback search

文件：`lib/health_diet/services/health_diet_external_api_service.dart`

- `lookupBarcode()` 不再把 404 简单当作失败静默返回。
- 对 404/status=0 记录明确日志：“公开库未收录”。
- 自动追加一次 `/cgi/search.pl?search_terms=<barcode>` 按 code 兜底搜索。
- 只有 exact code 命中才接受结果，避免把错误商品当成用户吃过的食物。

### 2. 条码未收录时，允许使用包装图片 AI 兜底

文件：`lib/health_diet/services/health_diet_core_orchestrator.dart`

- `foodsFromBarcode()` 新增 `imagePaths` 参数。
- 当 Open Food Facts 查不到条码且用户已上传包装正面/营养成分表图片时，会调用 AI 视觉识别。
- AI 只能根据图片中清楚可见的信息识别，不允许凭条码编造商品名。

### 3. 每日饮食分享页面把图片传入条码确认流程

文件：`lib/health_diet/daily_share/daily_diet_share_page.dart`

- 用户可以先上传包装图片，再扫描/输入条码。
- 点击“查询并确认”时，图片会随条码一起传给识别流程。
- 页面说明改为：公开库未录入时可以用包装图片 AI 兜底；仍识别不了则手动改名。

### 4. 防止把“未识别包装食品”保存为真实饮食记录

文件：`lib/health_diet/daily_share/diet_food_confirm_page.dart`

- 如果所有食物项都是“条码未在公开库录入/未识别包装食品”，点击保存会被拦截。
- 用户必须点卡片修改成真实食品名称，或返回上传包装图片重新识别。
- 避免后续复盘把无效占位符当成真实食物分析。

## 正确用户路径

1. 扫描条码。
2. 若 Open Food Facts 已收录：直接返回商品营养数据。
3. 若未收录：
   - 上传包装正面、配料表或营养成分表图片。
   - 再次“查询并确认”。
   - AI 从图片识别食品名称。
4. 若仍识别不了：手动修改食品名称和份量后保存。

## 注意

条码本身无法可靠推出商品名称。不能让 AI 仅凭 `6906664826854` 编造商品名，否则会污染饮食记录和复盘结果。

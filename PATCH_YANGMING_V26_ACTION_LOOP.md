# PATCH_YANGMING_V26_ACTION_LOOP

本次继续按原 PRD 推进，重点补上“事实记录 → AI 诊断 → 复盘回流”的行动闭环。

## 新增内容
- 行动任务支持补充事实记录。
- 行动任务支持 AI 执行诊断（结构化 JSON 输出）。
- 诊断结果可保存回行动卡。
- 诊断结果可直接生成“下一步行动”。
- 诊断后可直接带着事实进入复盘页。
- 复盘总结支持把“明天最小行动”再次加入行动中心。

## 主要修改文件
- lib/yangming_module/yangming_models.dart
- lib/yangming_module/yangming_dao.dart
- lib/yangming_module/yangming_ai_service.dart
- lib/yangming_module/yangming_module_home_page.dart

## 说明
- 仍然复用宿主 app 现有 OpenAI / DeepSeek 设置。
- 未新增独立模型配置。
- 未预装受版权保护全文内容。

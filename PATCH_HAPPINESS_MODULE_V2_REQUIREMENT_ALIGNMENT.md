# Happiness Module V2 Requirement Alignment

本次补齐重点：

1. 新增 `lib/happiness_module/happiness_full_content.dart`
   - 39 个单元全部加入“完整复制版课程学习内容”字段
   - 对应前面对话中已整理的 39 段中文简化版课程内容

2. 更新 `happiness_models.dart`
   - `HappinessUnit` 新增 `fullContent`

3. 更新 `happiness_seed.dart`
   - 39 个单元全部绑定 `fullContent`

4. 更新 `happiness_module_home_page.dart`
   - 单元详情页新增“课程完整学习内容（完整复制版）”展示区
   - 问题诊断搜索增加对 `fullContent` 的匹配

5. 更新 `happiness_ai_service.dart`
   - AI 行动生成时纳入单元完整学习内容，增强概念对齐

说明：
- 模型 / 版本 / key 仍按宿主 App 全局设置读取
- 模块内 Prompt Studio 仅控制提示词层

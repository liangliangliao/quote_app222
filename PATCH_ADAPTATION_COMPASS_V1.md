# PATCH_ADAPTATION_COMPASS_V1

## 目标
基于 George E. Vaillant《Adaptation to Life》与课程《成熟适应力：从防御机制到现实行动》，新增独立模块 `adaptation_compass`，把终极版产品方案落地为 Flutter 源码。

## 独立性
- 新增目录：`lib/adaptation_compass/`
- 新增表：`adaptation_compass_sessions`、`adaptation_compass_actions`、`adaptation_compass_balance`
- 新增 KV：`adaptation_compass_profile_v1`、`ai_prompt.adaptation_compass.*`
- 未复用/修改 `defense_compass` 模块内部模型、DAO、AI 服务或 Prompt。
- 仅在主抽屉新增入口，以便用户进入该独立模块。

## 新增文件
- `lib/adaptation_compass/adaptation_compass_models.dart`
- `lib/adaptation_compass/adaptation_compass_content.dart`
- `lib/adaptation_compass/adaptation_compass_prompt_config.dart`
- `lib/adaptation_compass/adaptation_compass_dao.dart`
- `lib/adaptation_compass/adaptation_compass_ai_service.dart`
- `lib/adaptation_compass/adaptation_compass_home_page.dart`

## 功能落地
1. 适应力首页：核心价值、统计、最近分析、行动闭环。
2. 今日适应记录：17 个场景层 Prompt，AI 生成成熟适应力分析卡。
3. 防御机制地图：四层防御、11 张防御机制卡、现实检查室。
4. 冲突转化实验室：愤怒、羞耻、恐惧、嫉妒、孤独、行动化转化路径。
5. 关系与亲密系统：关系分层、修复对话公式、亲密/童年/理解他人场景入口。
6. 工作-爱-游戏-身体平衡盘：四维评分、保存、趋势记录。
7. 成人发展地图：身份、亲密、职业巩固、生成性、意义守护、生命整合。
8. 生成性与贡献计划：痛苦转贡献、贡献边界、12 周课程、案例原型。
9. AI 深度复盘与安全：7/30/90/年度复盘框架、个人价值档案、安全支持。
10. 自动行动闭环：每次 AI 分析后自动生成 10 分钟、24 小时、7 天行动。

## AI 三层 Prompt
- 全局价值层 Prompt：明确书籍名 George E. Vaillant《Adaptation to Life》与课程名《成熟适应力：从防御机制到现实行动》。
- 场景层 Prompt：覆盖日常压力、防御识别、现实检查、愤怒、羞耻、关系、亲密、工作、四维平衡、高功能不鲜活、童年、身体、行动化、生成性、生命阶段、理解他人、安全支持。
- 输出格式 Prompt：统一 JSON + Markdown 分析卡，便于保存、统计和复盘。

## 安全与边界
- 不诊断、不贴标签、不羞辱防御。
- 高风险输入进入安全支持，不继续普通成长分析。
- 身体相关场景明确“不把身体问题简单心理化”，必要时提示医学评估。

## 构建说明
当前容器未提供 Dart/Flutter SDK，因此无法在本环境执行 `flutter analyze` 或 `flutter build`。已完成文本级静态检查：括号/花括号/方括号平衡、入口导入、旧模块隔离、明显 Flutter API 兼容问题修正。

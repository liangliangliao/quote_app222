# PATCH_REALISTIC_POSITIVITY_OS_V4_COVERAGE_AUDIT_AND_LONG_EXPERIMENTS

## 背景
用户指出 V3 仍未完全实现终极产品方案。V3 主要解决了深度工作台，但仍缺少：
- 设计方案功能项是否真正落地的可见审计；
- 单次行动卡之外的长期训练实验；
- 各子模块是否具有 Prompt / 表单 / 记录 / 沉淀 / 复盘 / 指标的闭环证据；
- 对“当前还缺什么”的诚实反馈。

## 本次新增

### 1. 新增终极功能矩阵
新增文件：
- `lib/realistic_positivity_os/realistic_positivity_os_feature_matrix.dart`

将终极方案拆成 14 个子模块与 50+ 个可审计功能项：
- Onboarding 人格地图
- Reality Lens 真实看见
- Question Reframing 问题重构
- Gratitude Practice 感恩训练
- Relational Gratitude 关系感恩
- Emotional Processing 允许为人
- Meaning-Making 痛苦整合
- Savoring & Peak Experience 积极经验
- Change Lab 改变实验室
- ABC Change 改变计划
- Behavior First 行为优先
- Stretch Zone 成长挑战
- Weekly Integration 每周整合
- Safety Support 安全支持

每个模块包含：
- 课程价值
- 产品目标
- Prompt ID
- 对应资产类型
- 设计边界
- 可审计功能项
- 功能项证据要求

### 2. 新增覆盖度审计页
新增文件：
- `lib/realistic_positivity_os/realistic_positivity_os_coverage_page.dart`

能力：
- 统计终极功能项覆盖率；
- 展示每个模块真实记录数、资产数、行动证据数、完成行动数；
- 逐项展示功能是否已有使用证据；
- 对缺失模块给出差距清单；
- 从审计页直接进入对应专用工作台；
- 从审计页直接进入对应 Prompt 配置；
- 为任意模块创建 7 天长期实验；
- 创建 14 天完整闭环实验。

### 3. 新增长期训练实验能力
新增文件：
- `lib/realistic_positivity_os/realistic_positivity_os_experiment_page.dart`

新增数据表：
- `realistic_positivity_os_experiments`

新增 DAO 方法：
- `createExperiment`
- `listExperiments`
- `updateExperimentProgress`
- `updateExperimentStatus`
- `deleteExperiment`

长期实验支持：
- RPO 14 天完整闭环实验；
- 7 天感恩 Freshness 实验；
- 7 天价值绑定拆解实验；
- 7 天行为优先启动实验；
- 每天对应一个子模块、训练焦点、工作台入口；
- 每天完成后写复盘；
- 完成复盘自动沉淀为行动证据。

### 4. 首页新增独立 Tab
`RealisticPositivityOsHomePage` Tab 从 6 个扩展为 8 个：
- 今日训练
- 行动卡
- 12/14 模块
- 覆盖审计
- 长期实验
- 成长档案
- 历史记录
- Prompt

### 5. 模块列表补齐安全支持
`RealisticPositivityOsPromptConfig.moduleMatrix` 新增：
- `crisis / Safety Support 安全支持`

## 仍未声称完成的内容
本次 V4 仍不声称已经达到商业级完全成品。仍可继续增强：
- 多周趋势图；
- 本地通知/提醒调度；
- 同伴支持/真实联系人交互；
- 更强的 AI 档案补丁自动合并；
- 模块专属统计图表；
- Flutter 实机编译后的 UI 细节修复。

## 验证建议
```bash
flutter pub get
flutter analyze
flutter build apk
```

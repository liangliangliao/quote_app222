# PATCH_REALISTIC_POSITIVITY_OS_V5_SYSTEM_LAYER_AND_BUILD_FIX

## 目标
回应“仍未完全实现终极产品设计方案”的反馈。V5 不再只增加覆盖矩阵，而是补齐此前隐藏但未真正接入的系统层能力，并修复 V4 中生命周期/覆盖审计相关 DAO 缺口。

## 关键修复

### 1. 修复 V4 潜在编译缺口
V4 已存在以下页面，但 DAO 缺少配套方法/表字段：
- `realistic_positivity_os_lifecycle_page.dart`
- `realistic_positivity_os_coverage_audit_page.dart`

本次在 `realistic_positivity_os_dao.dart` 中补齐：
- `realistic_positivity_os_checkins` 表
- experiments 表兼容字段：`scene_type`、`source_record_id`、`day_index`、`horizon_days`、`metrics_json`
- `createExperimentFromRecord`
- `updateExperiment`
- `addCheckIn`
- `listCheckIns`
- `coverageCounts`
- `clearAll` 同步清理 checkins

### 2. 新增 RPO 系统层页面
新增文件：
- `lib/realistic_positivity_os/realistic_positivity_os_system_page.dart`

补齐终极产品方案中此前未充分落地的四层：
1. 课程思想层：14 个 Lecture 9–10 概念，每个概念可进入对应训练工作台和 Prompt 配置。
2. 成长路径层：看见 → 接纳 → 感恩 → 行动 → 整合。
3. 成长档案/资产库层：旧问题、价值绑定、支持关系、感恩资产、高峰体验、新身份证据、数据库资产。
4. 安全计划层：Panic Zone 降级、安全支持工作台、可配置安全 Prompt。

### 3. 首页 Tab 扩展
`RealisticPositivityOsHomePage` 从 8 个 Tab 扩展为 11 个：
- 今日训练
- 行动卡
- 12模块
- 系统层
- 覆盖审计
- 生命周期
- 长期实验
- 激活审计
- 成长档案
- 历史记录
- Prompt

### 4. 生命周期入口真实接入
已把 `RealisticPositivityOsLifecyclePage` 接入首页 Tab，用户可以从行动卡创建 7/14 天实验，进行 Check-in，记录 Comfort / Stretch / Panic，并自动沉淀行动证据。

### 5. 激活审计真实接入
已把 `RealisticPositivityOsCoverageAuditPage` 接入首页 Tab，并由 DAO 的 `coverageCounts()` 提供数据。

## 仍未声明“商业级完全完成”
V5 明显补强终极产品设计方案的系统层和生命周期闭环，但仍需本地 Flutter analyze / build 验证。后续还可以继续补：
- 实际通知调度
- 同伴支持/真实联系人互动
- 更细图表
- 云同步
- 导出报告
- 实机 UI polish

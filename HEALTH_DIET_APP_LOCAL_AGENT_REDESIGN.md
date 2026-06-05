# 健康饮食模块：App 内置 Agent 改造说明

本次改造把健康饮食模块从“后端 Agent 网关 / 服务器地址模式”改回 **纯手机 App 内置 Agent 模式**。

## 核心原则

- 所有健康饮食 Agent 编排代码仍在 Flutter App 内。
- API Key 仍保存在手机 App 前端配置中。
- AI Provider、模型、max_tokens、temperature、timeout 等仍由用户选择。
- 不再需要 Agent 网关基础地址、Bearer Token，也不会把 API Key 临时发送给自有后端。
- App 内 `HealthDietAppAgentService` 作为统一 Agent 编排入口，读取健康目标、健康档案、Health Connect、每日饮食分享、长期饮食模式、外部营养/菜谱 API 与 AI 模型，生成主动专家方案。

## 主要变更

### 1. 健康饮食配置页

移除/隐藏：

- Agent 网关基础地址
- Agent 网关 Bearer Token
- 请求时临时发送本机 API Key 给网关

保留：

- USDA / Open Food Facts / 薄荷 / Edamam / Spoonacular API 配置
- AI 个性化饮食建议开关
- Health Connect 联动开关
- Agent 主动等级 L1-L4
- API Key 默认隐藏、支持长按粘贴和右侧粘贴按钮

### 2. 新增 App 内置 Agent 服务

新增文件：

```text
lib/health_diet/services/health_diet_app_agent_service.dart
```

职责：

- 输出当前 App 内置 Agent 状态说明；
- 统一调用 `HealthDietExpertService.buildTodayPlan()` 生成专家方案；
- 统一调用 `HealthDietExpertService.generateAiCoachNarrative()` 生成 AI 专家解释。

### 3. 专家方案服务

`HealthDietExpertService` 不再调用任何后端网关。它现在只保存：

```text
source = app_local_agent
```

并在 App 内完成：

- 健康目标读取；
- 健康档案读取；
- Health Connect 摘要读取；
- 今日饮食分享读取；
- 最近 7 天模式分析；
- 本地 Agent 记忆更新；
- 本地规则方案生成；
- AI 专家解释生成。

### 4. 首页文案

首页显示“App 内置 Agent 已启用”，说明不需要服务器地址；API Key 与模型选择仍由手机端配置。

## 当前运行模式

```text
Flutter App
  ├── 健康档案 / 健康饮食目标
  ├── Health Connect
  ├── 每日饮食分享
  ├── 外部营养 / 菜谱 API
  ├── 用户选择的 AI 模型
  └── App 内置 AgentService
        ↓
      主动专家方案 / 今日调理 / 复盘 / 微行动 / 菜谱建议
```

## 注意

App 内置 Agent 能主动分析，但受手机系统后台限制，不能像云服务器一样全天候运行。当前推荐触发方式：

- 用户打开饮食模块时自动刷新；
- 用户同步 Health Connect 后自动刷新；
- 用户保存每日饮食分享后自动复盘；
- 用户进入专家方案页时生成当日方案。

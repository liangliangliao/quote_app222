# 健康饮食模块专家化重构说明

本次重构目标：把“饮食查询/记录工具”升级为“营养膳食、调理恢复健康于一体的主动专家系统”。

## 1. 发现的问题

此前实现的主要问题：

- 功能分散：健康档案、Health Connect、每日饮食、菜谱、API 数据之间没有形成统一判断。
- 偏被动：用户需要自己点查询、点记录，系统没有主动围绕目标安排饮食。
- 目标弱：健康档案中的 mainGoal 没有成为所有推荐的中心。
- API 弱：外部 API 返回空时页面仍像“成功”，缺少数据缺口提示。
- AI 弱：AI 主要用于解析输入，没有作为“基于证据的解释层”参与专家方案。

## 2. 参考主流健康 App 的重构方向

- MyFitnessPal：Today dashboard，把记录、目标、进展放在每日首页。
- Cronometer：强调宏量/微量营养和数据质量。
- Noom：行为心理学、最小改变、非羞辱式反馈。
- Fooducate：食品质量不仅看热量，也看糖、钠、加工程度和配料。
- Health Connect：把睡眠、步数、运动、体重等身体状态引入饮食判断。

## 3. 新增核心能力

### 3.1 营养膳食专家方案页

新增入口：

`发现之旅 / 生理赋能 / 饮食 / 营养膳食专家方案`

新页面会主动整合：

- 健康档案
- 健康目标
- Health Connect 今日身体状态
- 今日饮食分享
- 最近 7 天饮食模式
- 已命中的外部/API 营养数据
- API 配置和数据缺口

然后生成：

- 今日核心判断
- 依据列表
- 优先问题
- 今日 / 明日 24 小时策略
- 分餐安排
- 推荐食物与谨慎食物
- 数据缺口与 API 状态
- AI 专家深度分析

### 3.2 今日饮食调理重构

原来的静态模板式建议已改为读取 `HealthDietExpertService` 的专家方案，围绕当前目标与身体数据生成分餐建议。

### 3.3 AI 角色升级

AI 不再单独瞎猜，而是接收结构化数据包：

- 健康档案
- Health Connect 摘要
- 今日饮食分享
- 最近 7 天习惯模式
- 外部营养数据命中情况
- 数据缺口
- 风险提示

AI 只负责把已有证据解释成人能理解的主动调理方案。

### 3.4 API 返回空的处理

API 返回空不再被当作功能正常完成，而会在“数据缺口与 API 状态”里提示：

- USDA 未命中
- Open Food Facts 没有今日条码数据
- Spoonacular / Edamam 失败或为空时会回退本地菜谱
- 薄荷健康因缺少可确认公开接口，暂保留配置位

## 4. 新增文件

- `lib/health_diet/models/health_diet_expert_plan.dart`
- `lib/health_diet/services/health_diet_expert_service.dart`
- `lib/health_diet/expert/health_diet_expert_dashboard_page.dart`

## 5. 修改文件

- `lib/health_diet/pages/health_diet_home_page.dart`
- `lib/health_diet/pages/today_meal_plan_page.dart`
- `lib/health_diet/prompts/health_diet_prompts.dart`

## 6. 产品逻辑变化

旧逻辑：

记录饮食 -> 简单复盘 -> 用户自己找菜谱

新逻辑：

健康目标 + 健康档案 + 身体数据 + 今日饮食 + 7天模式 + 外部营养数据
-> 主动专家判断
-> 今日/明日饮食安排
-> 一个最小改变
-> 分餐建议
-> 对应菜谱
-> AI 专家解释


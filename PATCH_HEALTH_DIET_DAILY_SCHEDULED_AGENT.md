# 健康饮食每日定时托管 Agent 升级

## 目标
把健康饮食模块从“打开页面才生成方案”升级为“每日按关键时间点自动巡检、自动安排、自动复盘”的 App 内置膳食 Agent。

## 新增能力

1. 新增每日定时膳食 Agent 服务
   - 文件：`lib/health_diet/services/health_diet_daily_scheduler_service.dart`
   - 默认任务：
     - 08:00 早晨今日饮食计划
     - 10:30 早餐记录与能量检查
     - 12:00 午餐动态安排
     - 15:30 下午加餐与甜饮风险检查
     - 18:00 晚餐恢复型安排
     - 21:30 晚间饮食复盘
     - 周日 21:00 每周趋势报告
   - 任务到点时会触发 `HealthDietAutopilotService.run(force: true)`，自动同步 Health Connect、调用营养/菜谱 API、生成复盘、生成专家方案、必要时调用 AI。

2. 接入 Workmanager 后台执行
   - 文件：`lib/services/wm_dispatcher.dart`
   - 新增 `health_diet_agent` job 分发。
   - App 启动、健康饮食首页打开、开机 WM boot 时都会自动注册下一轮定时任务。

3. 新增实时饮食状态引擎
   - 文件：`lib/health_diet/services/health_diet_realtime_state_service.dart`
   - 计算：
     - 今日记录餐次数
     - 确认食物数量
     - 营养匹配数量
     - 复盘可信度
     - 当前阶段/下一餐
     - 下一步最优行动
     - 今日风险/健康冲突
     - 已吃 / 还缺 / 已超：蛋白质、纤维、钠、糖、饮水
   - 对肾脏问题、脂肪肝、便秘、睡眠不足等做更保守的提示。

4. 今日饮食调理页升级
   - 文件：`lib/health_diet/pages/today_meal_plan_page.dart`
   - 显示“每日定时膳食 Agent”状态。
   - 显示“实时饮食状态”与营养预算。
   - 提供“立即让 Agent 重新安排今天饮食”。
   - 修复找菜谱参数：`initialGoal` 传健康目标 code，`initialQuery` 传今日调理搜索词。

5. 健康饮食首页升级
   - 文件：`lib/health_diet/pages/health_diet_home_page.dart`
   - 进入模块时自动补跑已到点但未执行的膳食 Agent 任务。
   - 首页文案改为每日定时托管模式。

6. 设置页新增开关
   - 文件：`lib/health_diet/pages/health_diet_settings_page.dart`
   - 新增：开启每日定时膳食托管。
   - 新增：定时托管完成后发送通知。
   - 配置键在 `HealthDietSettingsService` 中新增：
     - `health_diet_agent_daily_schedule_enabled`
     - `health_diet_agent_schedule_notify_enabled`

## 重要说明
手机端后台定时受 Android 厂商、省电策略、Workmanager 调度限制影响，因此采用“双保险”：
- 后台可用时，Workmanager 自动执行。
- 如果后台被系统限制，用户打开健康饮食模块时会自动补跑已经到点但未执行的任务。

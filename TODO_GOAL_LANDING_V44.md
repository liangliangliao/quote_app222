# Microsoft To Do 目标落地系统 V44

本次在“外部数据同步 → Microsoft To Do”模块中落地融合前面拟定的积极心理学目标设定方案。

## 新增能力

1. **To Do 目标落地入口**
   - Microsoft To Do 首页新增“Todo 目标落地系统”入口。
   - 任务详情页新增“AI 转化为目标”入口。
   - 外部数据同步首页的 Microsoft To Do 描述已更新。

2. **目标层本地数据表**
   - `goal_profiles`：保存从 Microsoft To Do 任务转化出的目标档案。
   - `goal_action_steps`：保存今日最小行动、最低标准、推荐标准、拉伸挑战、难度区间。
   - `goal_reflections`：保存每日复盘。
   - `goal_ai_analysis`：保存 AI 分析结果。
   - `goal_sync_links`：保存目标行动与 To Do 写回任务之间的关系。

3. **AI 目标转化服务**
   - 新增 `TodoGoalAiService`。
   - 支持把 To Do 任务分析为：目标名称、深层意义、想成为的人、自我和谐评分、过程价值、阻力、今日最小行动。
   - 未配置 AI 时自动使用本地策略兜底，避免功能不可用。

4. **今日旅程**
   - 聚合今日最小行动。
   - 显示最低完成标准、推荐完成标准、过程提醒、舒适区/拉伸区/恐慌区。
   - 支持完成/取消完成。
   - 支持把今日最小行动写回 Microsoft To Do，并在本地加入“我的一天”。

5. **复盘洞察**
   - 支持对今日行动进行复盘。
   - AI 生成复盘总结、过程洞察、意义连接、明日最小一步。
   - 未配置 AI 时使用本地复盘策略兜底。

## 新增文件

- `lib/external_data/todo_goal_models.dart`
- `lib/external_data/todo_goal_dao.dart`
- `lib/external_data/todo_goal_ai_service.dart`
- `lib/external_data/todo_goal_pages.dart`

## 修改文件

- `lib/external_data/todo_pages.dart`
  - 引入目标落地页面。
  - Microsoft To Do 首页新增目标落地入口卡片。
  - To Do 任务详情页新增 AI 转化入口。

- `lib/external_data/onenote_pages.dart`
  - 外部数据同步首页 To Do 描述更新。
  - 初始化时确保目标层数据表创建。

## 使用流程

1. 进入首页左侧菜单 → 外部数据同步 → Microsoft To Do。
2. 同步任务后，点击“To Do 目标落地系统”。
3. 在“目标转化”页选择一个未完成 To Do 任务，点击“AI 转化为目标”。
4. App 自动生成目标档案和今日最小行动。
5. 在“今日旅程”中执行行动、写回 To Do 或进入复盘。
6. 在“复盘洞察”中查看 AI 总结和历史记录。

## 设计原则

- 目标不是终点崇拜，而是方向感。
- 任务不只是待办事项，也可能是人生方向的线索。
- 今日行动必须足够小，能在现实中开始。
- 复盘不用于自责，而用于看见过程、阻力和下一步。

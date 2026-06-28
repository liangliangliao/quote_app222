# PATCH_MI_GROWTH_NAVIGATOR_V1

## 已落地模块
新增 `lib/mi_growth/`：基于动机式访谈（MI）的「向内生长 · MI 成长向导」。

## 接入位置
- `lib/main.dart`
  - 新增导入：`mi_growth/mi_growth_home_page.dart`
  - 抽屉顶部新增入口：`向内生长 · MI 成长向导`

## 核心功能
1. 价值罗盘
   - 核心价值选择
   - 身份方向
   - 重要关系/责任
   - 长期方向
   - 用户自己的改变理由

2. AI 向导
   - 三层 Prompt：全局价值层、场景层、输出格式层
   - 场景：日常成长、习惯改变、混乱聚焦、低动机、行动失败、人生转变、帮助别人、复盘
   - 四任务流程：参与、聚焦、唤起、计划
   - 有全局 AI Key 时调用统一 AI 服务；无 Key 或请求失败时使用本地 MI 规则 fallback

3. 改变语言捕捉
   - Desire / Ability / Reasons / Need / Commitment / Activation / Taking steps
   - 自动保存进成长记录与价值罗盘

4. 小步行动
   - 时间、地点、动作、时长、备用方案、复盘问题
   - 行动不是打卡惩罚，而是价值连接的小实验

5. 复盘与维持
   - 完成 / 部分完成 / 未完成但获得信息
   - 未完成不羞辱，转成阻碍模式与下一次更小行动

6. 帮助者训练
   - 把命令、批评、说教改写成开放式问题、反映、肯定和邀请
   - 明确不用于操控别人

7. 伦理与安全
   - 自伤/自杀/他伤/严重虐待/戒断/幻觉等风险词进入安全模式
   - 关系失调语言进入修复模式
   - 防羞耻、防操控、防过度承诺

## 新增文件
- `lib/mi_growth/mi_growth_models.dart`
- `lib/mi_growth/mi_growth_dao.dart`
- `lib/mi_growth/mi_growth_ai_service.dart`
- `lib/mi_growth/mi_growth_prompt_config.dart`
- `lib/mi_growth/mi_growth_home_page.dart`

## 数据表
运行时自动创建：
- `mi_growth_sessions`
- `mi_growth_actions`
- `mi_growth_reviews`

价值罗盘存储在现有 `notify_config` KV 表中：
- `mi_growth_value_profile_v1`

## 构建说明
当前执行环境没有 Flutter/Dart SDK，因此无法在沙盒内运行 `flutter analyze` 或 `flutter build`。代码已按现有项目结构做静态接入与语法平衡检查；请在本地 Flutter 环境执行：

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

如本地 analyze 出现具体日志，可继续按日志修复。

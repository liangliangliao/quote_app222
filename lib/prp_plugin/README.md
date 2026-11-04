# PRP 插件 · 失败成长

入口：设置 → 功能模块 → PRP 插件 · 失败成长。默认关闭；AI 默认关闭。

核心只依赖 Flutter、SQLite 和通用平台包。调用模块只 import `prp_plugin.dart`；App 存储、已有护栏、AI、语音和失败模块双写都在 `prp_plugin_host` 中实现。启动先同步注册门面，首帧后读取配置，没有独立通知或后台任务。

## 调用

```dart
final offer = await PrpPlugin.instance.signal(PrpSignal(
  surface: PrpSurface.behavior,
  kind: 'habit_missed',
  subjectKey: 'habit:preset:5',
  expected: '阅读 20 分钟',
  facts: ['用户明确确认本次未完成'],
  confirmed: true,
  reference: 'preset:5:2026-11-04',
  tsMs: DateTime.now().millisecondsSinceEpoch,
));
if (context.mounted && offer != null) {
  await PrpPlugin.instance.showOffer(context, offer);
}

PrpPlugin.instance.recallChip(const PrpContext(
  surface: PrpSurface.behavior,
  subjectKey: 'habit:preset:5',
  location: 'habit_reminder',
));
```

`confirmed` 不可用于表达“没有记录”。自动到期不发信号。火种永远不发失败信号，只读取 `workedItems()`。传入稳定 `reference`，重复保存同一件事不会消耗新预算。结果使用 `reportSubjectOutcome` 或回访条上的显式反馈；历史补登记需传入 `occurredMs`，避免验证更晚的回访。

总开关或对应分开关关闭时：信号为 null，回访为空，插槽折叠，不写 PRP 数据。关闭会取消在途写事务并立即隐藏已挂载插槽。设置中的管理手册是显式只读例外，仍可查看、导出、二次确认清除。配置整体原子保存在 `notify_config` 的 `prp.preferences.v1`；安全退场期限单独存为 `prp.crisis_until_ms`。不修改已有模块表结构。

## 数据和行为

只有 `prp_lesson`、`prp_session`、`prp_recall` 三张新表，首次有效使用时幂等建表。读取空手册不建表。未盖印的内容为 draft；长按 3 秒且完成缓一缓后才可 sealed。自责不入证据；危机输入立即退场，不保留输入内容，暂停提议与回访 24 小时。没有护栏的 Noop 宿主拒绝保存。

已盖印教训按对象、明确类别或文本相似度匹配。展示与结果写入均幂等，每日预算跨重启有效；忽略后 24 小时降低打扰。继续编辑和导入草稿不占自动提议预算。改写成功盖印后旧版才 retired，保留 parent_id 版本链。未验证不会增加复犯次数。安全退场经宿主调用敌人现有的 24 小时安全阀并停止声音；敌人页面立即刷新到既有求助状态。

敌人读取 PRP 须另行开启其证据源授权，只同步盖印标记、记录引用及验证次数，不复制复盘原文。会话卡片显示期间暂停敌人自动插话和语音，退出后恢复既有治理。

自己的名言需要总开关、首页分开关、名言流开关和逐条同意，受每日回访预算及至少 24 小时间隔限制。只在首页内存中展示，不写 quotes、不进入持久收藏；撤销开关或同意后立即撤下。自己的话不会送去作者查询或 AI 配画。

AI 沿用 App 的统一配置，只在独立授权后由用户点击分类/整理，或在已授权的日复盘中提取候选。严格 JSON、逐字来源检查和已有 DraftValidator / SafetyValve 双重保护；无配置、超时、格式错误或新增事实均回到离线引导。未经盖印，AI 候选始终只是草稿。

录音使用 `record`，播放使用已有 audioplayers；手动录、手动播，最多 15 秒，后台/关闭时停止。音频位于应用文档目录 `prp_voice/`，不会自动上传。JSON 导出包含记录和本地音频路径，不包含音频文件本身；清除会删除该目录中的录音。

## 验证

```sh
flutter pub get
flutter analyze --no-pub --no-fatal-infos lib/prp_plugin lib/prp_plugin_host test/prp_plugin
flutter test --no-pub test/prp_plugin
python3 tools/pack_prp.py
```

Flutter 与现有 CI 对齐为 3.35.3。Linux 测试需要 `libsqlite3-dev`。验收与限制见根目录 `AUDIT_prp_v1.0.0.md`；不把自动化截图称为真机验收。

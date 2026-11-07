/// PRP 插件 · 失败成长（设置页里可开关的插件）。
///
/// 功能模块只需要：
///   1. 在“没做到”的地方调用 `PrpPlugin.instance.handleMissed(...)`（或 `signal(...)`）；
///   2. 在需要的位置放插槽：`commitmentHint(...)`、`playbook()`、`sessionCard(...)`。
/// 插件关闭或没接上时，这些调用什么都不会发生，也不会写任何数据。
///
/// 宿主适配器（lib/prp_plugin_host）实现 [PrpHost]，把插件需要的外部能力接进来。
library prp_plugin;

export 'src/core.dart' show PrpCore, PrpPlaybookData;
export 'src/governance.dart' show PrpBreaker;
export 'src/host.dart';
export 'src/models.dart';
export 'src/plugin.dart';
export 'src/settings.dart' show MemoryPrpKv, PrpKv, PrpSettings;
export 'src/sqflite_store.dart' show SqflitePrpStore;
export 'src/store.dart' show MemoryPrpStore, PrpSchema, PrpStore;
export 'src/text_guard.dart' show BuiltinTextGuard;
export 'src/ui/seal_stamp.dart' show PrpSealStamp, kPrpSeal;
export 'src/ui/session_card.dart' show PrpCloseCallback, openPrpSessionPage;
export 'src/ui/settings_page.dart' show PrpSettingsPage;

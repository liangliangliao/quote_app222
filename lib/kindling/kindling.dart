/// 火种（Kindling）模块。
///
/// 独立 Flutter 模块，除 sqflite 外零外部依赖，可整体拷入/移出。
/// 设计原则：动力是果不是因。模块只做两件事——清障与接通。
///
/// 宿主 app 只需接触本文件导出的符号，其余全部 library private。
library kindling;

export 'src/kindling_entry.dart' show KindlingEntry;
export 'src/data/kindling_schema.dart' show KindlingSchema;
export 'src/kindling_oracle.dart' show KindlingOracle, LocalOracle;

/// 「发现之旅」页面的入口卡片。集成点在发现页而非抽屉，故一并导出。
export 'src/ui/kindling_discover_entry.dart' show KindlingDiscoverEntry;

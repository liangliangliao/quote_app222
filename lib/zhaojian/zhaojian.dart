/// 照见（Zhaojian）模块。
///
/// 独立 Flutter 模块，除 sqflite 外零外部依赖，可整体拷入/移出。
/// 设计原则：性格与根本欲求不变，能改的是认识、动机局面，以及行为与环境。
/// 模块做的事：补全动机、封存预测、事后开牌，并用行为证据检验对自己的认识。
///
/// 宿主 app 只需接触本文件导出的符号，其余全部 library private。
library zhaojian;

export 'src/zhaojian_entry.dart' show ZhaojianEntry;
export 'src/data/zhaojian_schema.dart' show ZhaojianSchema;
export 'src/zhaojian_oracle.dart'
    show
        ZhaojianOracle,
        LocalZhaojianOracle,
        ZScoreResult,
        ZDesire,
        ZAlignRow,
        ZAlignResult,
        ZDifficulty,
        ZExternal;
export 'src/data/models.dart' show ZMotive;
export 'src/copy.dart' show ZCopy;

/// 「发现」页面的入口卡片。集成点在发现页而非抽屉，故一并导出。
export 'src/ui/zhaojian_discover_entry.dart' show ZhaojianDiscoverEntry;

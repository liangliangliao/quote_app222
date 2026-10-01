/// 美丽的敌人（Beautiful Enemy）模块。
///
/// 独立 Flutter 模块，除 sqflite 外零外部依赖，可整体拷入/移出。
/// 铁律：无证据不开口；只评行为，不评人；痛必须有用。
///
/// 宿主 app 只需接触本文件导出的符号，其余全部 library private。
library beautiful_enemy;

export 'src/enemy_entry.dart' show EnemyEntry;
export 'src/data/enemy_schema.dart' show EnemySchema;
export 'src/data/enemy_dao.dart' show EnemyDao, EnemySettings;
export 'src/domain/enemy_engine.dart' show EnemyEngine, EnemyOutcome, EnemyOutcomeKind;
export 'src/domain/evidence_source.dart' show EvidenceSource;
export 'src/data/models.dart' show EventDraft, EnemyEvent, EnemyMessage, MessageKind, MessageRole;
export 'src/domain/enemy_presence.dart' show EnemyPresence, SayResult;
export 'src/enemy_oracle.dart' show EnemyOracle, EnemyDraft, LocalFactOracle;
export 'src/enemy_talker.dart' show EnemyTalker, EnemyVoiceOut, NoopEnemyVoiceOut;
export 'src/enemy_reminder.dart' show EnemyReminder, NoopEnemyReminder;
export 'src/ui/enemy_discover_entry.dart' show EnemyDiscoverEntry;

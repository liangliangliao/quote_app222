import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../evidence_growth/evidence_growth_dao.dart';
import '../evidence_growth/evidence_growth_discovery.dart' show GrowthJevAccess;
import '../services/unified_ai_service.dart';
import '../zhaojian/zhaojian.dart';
import 'zhaojian_ai_oracle.dart';
import 'zhaojian_decisions_oracle.dart';
import 'zhaojian_host_oracle.dart';
import 'zhaojian_jev_oracle.dart';

/// 宿主侧的装配点：把已经打开的库和 AI 引擎接上模块。
///
/// 模块不自己开库，而宿主的 [AppDatabase.instance] 是异步的，路由表拿不到
/// 实例——所以这一层负责等库，再把 [ZhaojianEntry] 建出来。
class ZhaojianHostPage extends StatefulWidget {
  const ZhaojianHostPage({super.key});

  static const Key loadingKey = ValueKey<String>('zhaojian_host_loading');

  @override
  State<ZhaojianHostPage> createState() => _ZhaojianHostPageState();
}

class _ZhaojianHostPageState extends State<ZhaojianHostPage> {
  late final Future<Database> _db = AppDatabase.instance();

  /// 只用来读「证据成长」里已配置的 JEV 密钥，不写任何数据。
  late final EvidenceGrowthDao _jevDao =
      EvidenceGrowthDao(database: AppDatabase.instance);

  /// 只在全局 AI 配置的服务商是 OpenAI、可用、并且地址指向官方 api.openai.com 时，
  /// 才用它的密钥去调 Decisions API：DeepSeek、Azure 等其它服务商，以及指向第三方网关的
  /// 「OpenAI」配置，一律不用（那些密钥不能发给 OpenAI）。不另存任何密钥。
  Future<ZDecisionsAccess?> _decisionsAccess() async {
    try {
      final UnifiedAiResolvedConfig c = await UnifiedAiService().resolveGlobalConfig();
      if (!c.available || c.provider.trim().toLowerCase() != 'openai') return null;
      if (!ZhaojianDecisionsOracle.isOfficialEndpoint(c.endpoint)) return null;
      return ZDecisionsAccess(Map<String, String>.from(c.authHeaders));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _db,
      builder: (BuildContext context, AsyncSnapshot<Database> snapshot) {
        final Database? db = snapshot.data;
        if (db == null) {
          return const Scaffold(
            key: ZhaojianHostPage.loadingKey,
            backgroundColor: Colors.white,
            body: SizedBox.shrink(),
          );
        }
        return ZhaojianEntry.build(
          db: db,
          // AI 与 JEV 都只是增强：没配置或调用失败会自己落回内置动机库与规则推荐。
          oracle: ZhaojianHostOracle(
            text: ZhaojianAiOracle(),
            scorer: ZhaojianJevOracle(
              readKey: () => GrowthJevAccess.key(_jevDao),
            ),
            extraScorers: <ZhaojianOracle>[
              ZhaojianDecisionsOracle(access: _decisionsAccess),
            ],
          ),
        );
      },
    );
  }
}

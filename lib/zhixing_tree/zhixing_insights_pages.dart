import 'package:flutter/material.dart';

import 'zhixing_engine.dart';
import 'zhixing_models.dart';
import 'zhixing_repository.dart';

class ZhixingProfilePage extends StatefulWidget {
  final ZhixingRepository repository;

  const ZhixingProfilePage({super.key, required this.repository});

  @override
  State<ZhixingProfilePage> createState() => _ZhixingProfilePageState();
}

class _ZhixingProfilePageState extends State<ZhixingProfilePage> {
  ZhixingDashboard? _dashboard;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.repository.loadDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = value;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F3),
        surfaceTintColor: Colors.transparent,
        title: const Text('动态行动画像'),
      ),
      body: _dashboard == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: Color(0xFF247A57))
                  : Text(_error!),
            )
          : _body(_dashboard!),
    );
  }

  Widget _body(ZhixingDashboard dashboard) {
    final profile = dashboard.profile;
    final dimensions = <_Dimension>[
      _Dimension('价值自主度', profile.autonomy, '目标是否真正被自己认同'),
      _Dimension('行动清晰度', profile.clarity, '下一步、触发与证据是否明确'),
      _Dimension('认知弹性', profile.cognitiveFlexibility, '能否把解释当作可检验假设'),
      _Dimension('不适承载力', profile.willingness, '能否在安全范围内带着不适行动'),
      _Dimension('自我效能', profile.selfEfficacy, '真实掌握经验形成的“做得到”'),
      _Dimension('最优主义', profile.optimalism, '能否允许不完美、失败与再投入'),
      _Dimension('习惯结构', profile.habitStructure, '触发、环境与复归是否稳定'),
      _Dimension('能量恢复', profile.energy, '身体、注意与心理资源'),
      _Dimension('环境机会', profile.opportunity, '工具、时间、权限和社会支持'),
      _Dimension('安全条件', profile.safety, '现实风险是否处于可自助范围'),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF213A31), Color(0xFF315B49)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '这是情境画像，不是人格标签',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                const Text(
                  '系统根据当前任务、阻力、资源与现实反馈逐步校准。分数用于选择下一步，不用于评判你。',
                  style: TextStyle(color: Color(0xFFC5D7CE), height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SummaryValue(
                        value: '${profile.completedCount}',
                        label: '完成证据',
                      ),
                    ),
                    Expanded(
                      child: _SummaryValue(
                        value: '${profile.recalibrationCount}',
                        label: '主动校准',
                      ),
                    ),
                    Expanded(
                      child: _SummaryValue(
                        value: '${dashboard.game.returnCount}',
                        label: '复归次数',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE0E8E3)),
            ),
            child: Column(
              children: dimensions
                  .map(
                    (item) => _DimensionBar(item: item),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2ED),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.north_east_rounded, color: Color(0xFF247A57)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '真正的成长指标不是 App 使用时长，而是你越来越能自主识别问题、选择方法、开始行动、承受反馈并完成复归。',
                    style: TextStyle(color: Color(0xFF29493D), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ZhixingEvidencePage extends StatefulWidget {
  final ZhixingRepository repository;

  const ZhixingEvidencePage({super.key, required this.repository});

  @override
  State<ZhixingEvidencePage> createState() => _ZhixingEvidencePageState();
}

class _ZhixingEvidencePageState extends State<ZhixingEvidencePage> {
  List<ZhixingPrescription> _actions = const <ZhixingPrescription>[];
  Map<String, List<ZhixingEvidence>> _evidence = const <String, List<ZhixingEvidence>>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actions = await widget.repository.listActions(limit: 200);
    final evidence = await widget.repository.listEvidence(limit: 400);
    final grouped = <String, List<ZhixingEvidence>>{};
    for (final item in evidence) {
      grouped.putIfAbsent(item.prescriptionId, () => <ZhixingEvidence>[]).add(item);
    }
    if (!mounted) return;
    setState(() {
      _actions = actions
          .where(
            (item) =>
                item.status == ZhixingActionStatus.completed ||
                item.status == ZhixingActionStatus.recalibrate,
          )
          .toList();
      _evidence = grouped;
      _loading = false;
    });
  }

  Future<void> _delete(ZhixingPrescription action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条行动及其证据？'),
        content: const Text('这只删除当前条目，不影响其他行动、画像和树木数据。删除后无法恢复。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB54B4B)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.deleteAction(action.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F3),
        surfaceTintColor: Colors.transparent,
        title: const Text('行动证据库'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF247A57)))
          : _actions.isEmpty
              ? const _EmptyEvidence()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: _actions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final action = _actions[index];
                      final records = _evidence[action.id] ?? const <ZhixingEvidence>[];
                      return _EvidenceCard(
                        action: action,
                        records: records,
                        onDelete: () => _delete(action),
                      );
                    },
                  ),
                ),
    );
  }
}

class ZhixingThoughtLibraryPage extends StatefulWidget {
  const ZhixingThoughtLibraryPage({super.key});

  @override
  State<ZhixingThoughtLibraryPage> createState() => _ZhixingThoughtLibraryPageState();
}

class _ZhixingThoughtLibraryPageState extends State<ZhixingThoughtLibraryPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modules = ZhixingEngine.thoughtCatalog.where((item) {
      final haystack =
          '${item.name}${item.coreValue}${item.mechanism}${item.suitableFor}${item.source}';
      return _query.isEmpty || haystack.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F3),
        surfaceTintColor: Colors.transparent,
        title: const Text('思想模块与来源'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: '搜索思想、机制或适用场景',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Text(
              '理论用于解释机制和生成行动，不用于给用户贴思想家人格标签。来源分为原典、现代研究与产品行动转译。',
              style: TextStyle(color: Color(0xFF6C7972), fontSize: 12, height: 1.45),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              itemCount: modules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (_, index) => _ThoughtModuleCard(module: modules[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class ZhixingDataSettingsPage extends StatefulWidget {
  final ZhixingRepository repository;

  const ZhixingDataSettingsPage({super.key, required this.repository});

  @override
  State<ZhixingDataSettingsPage> createState() => _ZhixingDataSettingsPageState();
}

class _ZhixingDataSettingsPageState extends State<ZhixingDataSettingsPage> {
  ZhixingGameState? _game;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final game = await widget.repository.loadGame();
    if (!mounted) return;
    setState(() => _game = game);
  }

  Future<void> _toggleDormant(bool value) async {
    final game = await widget.repository.setDormant(value);
    if (!mounted) return;
    setState(() => _game = game);
  }

  Future<void> _rebirth() async {
    final game = await widget.repository.rebirth();
    if (!mounted) return;
    setState(() => _game = game);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('复归种子已经重新开始生长；经验、证据与最高阶段均已保留。')),
    );
  }

  Future<void> _clearAll() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部知行树数据？'),
        content: const Text(
          '将删除知行诊断、行动卡、反馈证据、思想匹配历史、动态画像、金币与树木状态。此操作不可恢复。',
          style: TextStyle(height: 1.5),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB54B4B)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB54B4B), size: 38),
        title: const Text('最后确认'),
        content: const Text('请确认你确实要永久清空整个知行树子系统的本地数据。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('保留数据')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB54B4B)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久清空'),
          ),
        ],
      ),
    );
    if (second != true) return;
    await widget.repository.clearAll();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F3),
        surfaceTintColor: Colors.transparent,
        title: const Text('休眠、隐私与数据'),
      ),
      body: game == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF247A57)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: <Widget>[
                _SettingsSection(
                  title: '树木保护',
                  children: <Widget>[
                    SwitchListTile(
                      value: game.dormant,
                      activeColor: const Color(0xFF247A57),
                      secondary: const Icon(Icons.ac_unit_rounded),
                      title: const Text('主动休眠保护', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('疾病、危机、长期暂停或主动恢复时，树木停止衰退，不把休息当作失败。'),
                      onChanged: _toggleDormant,
                    ),
                    if (game.condition == 'seed_waiting' || game.health <= 0)
                      ListTile(
                        leading: const Icon(Icons.restart_alt_rounded, color: Color(0xFF247A57)),
                        title: const Text('用复归种子重生', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('保留经验、行动证据、最高阶段和重生次数。'),
                        trailing: FilledButton(
                          onPressed: _rebirth,
                          child: const Text('重生'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SettingsSection(
                  title: '本地优先与可信边界',
                  children: <Widget>[
                    ListTile(
                      leading: Icon(Icons.phone_android_rounded),
                      title: Text('个人数据默认保存在本机'),
                      subtitle: Text('行动、情绪、画像、证据和树木状态写入现有本地数据库。'),
                    ),
                    ListTile(
                      leading: Icon(Icons.data_object_rounded),
                      title: Text('AI 最小必要上下文'),
                      subtitle: Text('只发送生成当前知行卡所需的诊断、画像摘要与有限历史信号。'),
                    ),
                    ListTile(
                      leading: Icon(Icons.health_and_safety_outlined),
                      title: Text('不是临床诊断或专业意见'),
                      subtitle: Text('医疗、心理危机、法律、重大财务和现实安全问题会升级到专业支持。'),
                    ),
                    ListTile(
                      leading: Icon(Icons.no_accounts_outlined),
                      title: Text('不设排行榜，不出售行动金币'),
                      subtitle: Text('未完成不扣金币、不降级，不以羞耻和攀比驱动行动。'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: '删除数据',
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFB54B4B)),
                      title: const Text(
                        '清空整个知行树子系统',
                        style: TextStyle(color: Color(0xFF9E3F3F), fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('行动证据库中也支持逐条删除。'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _clearAll,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Dimension {
  final String name;
  final double value;
  final String description;

  const _Dimension(this.name, this.value, this.description);
}

class _DimensionBar extends StatelessWidget {
  final _Dimension item;

  const _DimensionBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.value >= .65
        ? const Color(0xFF247A57)
        : item.value >= .4
            ? const Color(0xFFD08A2D)
            : const Color(0xFFB54B4B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF17352C)),
              ),
              const Spacer(),
              Text(
                '${(item.value * 100).round()}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.description,
            style: const TextStyle(color: Color(0xFF7A867F), fontSize: 11),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: item.value,
              minHeight: 8,
              color: color,
              backgroundColor: const Color(0xFFE8EEEA),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryValue({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFC5D7CE), fontSize: 11),
        ),
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final ZhixingPrescription action;
  final List<ZhixingEvidence> records;
  final VoidCallback onDelete;

  const _EvidenceCard({
    required this.action,
    required this.records,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = action.status == ZhixingActionStatus.completed;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E8E3)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(15, 5, 8, 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
        leading: CircleAvatar(
          backgroundColor: completed ? const Color(0xFFE4F1EA) : const Color(0xFFFFF0E1),
          child: Icon(
            completed ? Icons.check_rounded : Icons.tune_rounded,
            color: completed ? const Color(0xFF247A57) : const Color(0xFFA66A24),
          ),
        ),
        title: Text(
          action.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${action.challengeType.label} · ${_formatDate(action.updatedAtMs)}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'delete',
              child: Text('删除这条记录'),
            ),
          ],
        ),
        children: <Widget>[
          _EvidenceRow(label: '现实行动', value: action.action),
          _EvidenceRow(label: '完成证据', value: action.successEvidence),
          _EvidenceRow(label: '思想匹配', value: action.thoughtMatch.dominant),
          if (records.isEmpty)
            const _EvidenceRow(label: '反馈', value: '没有可读取的反馈明细。')
          else
            ...records.map(
              (item) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.completed ? '完成反馈' : '校准反馈',
                      style: const TextStyle(
                        color: Color(0xFF247A57),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('事实：${item.factResult}', style: const TextStyle(height: 1.45)),
                    if (item.learning.isNotEmpty)
                      Text('学习：${item.learning}', style: const TextStyle(height: 1.45)),
                    if (item.nextStep.isNotEmpty)
                      Text('下一步：${item.nextStep}', style: const TextStyle(height: 1.45)),
                    const SizedBox(height: 5),
                    Text(
                      '不适预测 ${item.predictedDiscomfort.round()} / 实际 ${item.actualDiscomfort.round()} · '
                      '${item.fit} · ${item.scale}',
                      style: const TextStyle(color: Color(0xFF75817B), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }
}

class _EvidenceRow extends StatelessWidget {
  final String label;
  final String value;

  const _EvidenceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF738079), fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _ThoughtModuleCard extends StatelessWidget {
  final ZhixingThoughtModule module;

  const _ThoughtModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE0E8E3)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE4F1EA),
          child: Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF247A57)),
        ),
        title: Text(module.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(module.coreValue),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: <Widget>[
          _EvidenceRow(label: '核心判断', value: module.mechanism),
          _EvidenceRow(label: '适用断点', value: module.suitableFor),
          _EvidenceRow(label: '行动规则', value: module.actionRule),
          _EvidenceRow(label: '误用边界', value: module.boundary),
          _EvidenceRow(label: '主要来源', value: module.source),
          _EvidenceRow(label: '证据类型', value: module.evidenceLevel),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 5),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF17352C),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _EmptyEvidence extends StatelessWidget {
  const _EmptyEvidence();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inventory_2_outlined, size: 54, color: Color(0xFF8AA096)),
            SizedBox(height: 13),
            Text('还没有行动证据', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            SizedBox(height: 7),
            Text(
              '完成或校准一张知行卡后，事实、预测—现实差异与下一步会保存在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718078), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

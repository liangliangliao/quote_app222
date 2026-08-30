import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'xiangji_database.dart';
import 'xiangji_knowledge_router.dart';
import 'xiangji_method_catalog.dart';
import 'xiangji_models.dart';
import 'xiangji_ui_support.dart';

class XiangjiKnowledgeCenterPage extends StatefulWidget {
  const XiangjiKnowledgeCenterPage({
    super.key,
    required this.dao,
  });

  final XiangjiDao dao;

  @override
  State<XiangjiKnowledgeCenterPage> createState() =>
      _XiangjiKnowledgeCenterPageState();
}

class _XiangjiKnowledgeCenterPageState
    extends State<XiangjiKnowledgeCenterPage> {
  late final XiangjiKnowledgeImportService _importer;
  late final XiangjiProviderService _providers;
  late final XiangjiKnowledgeGovernanceService _governance;
  bool _loading = true;
  bool _working = false;
  List<XiangjiKnowledgeSourceRecord> _sources =
      const <XiangjiKnowledgeSourceRecord>[];
  List<XiangjiProviderCapability> _capabilities =
      const <XiangjiProviderCapability>[];
  List<XiangjiProviderFileRecord> _providerFiles =
      const <XiangjiProviderFileRecord>[];
  List<Map<String, Object?>> _methodNodes = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _knowledgeRules = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _candidates = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _conflicts = const <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    _importer = XiangjiKnowledgeImportService(dao: widget.dao);
    _providers = XiangjiProviderService(dao: widget.dao);
    _governance = XiangjiKnowledgeGovernanceService(dao: widget.dao);
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.dao.knowledgeSources(includeRetired: true),
        widget.dao.providerCapabilities(),
        widget.dao.providerFiles(),
        widget.dao.knowledgeNodes(
          sourceId: XiangjiMethodCatalog.sourceId,
          limit: 100,
        ),
        widget.dao.knowledgeRules(sourceId: 'XF-K0-SCHOPENHAUER'),
        widget.dao.candidateKnowledge(),
        widget.dao.knowledgeConflicts(),
      ]);
      if (!mounted) return;
      setState(() {
        _sources = values[0] as List<XiangjiKnowledgeSourceRecord>;
        _capabilities = values[1] as List<XiangjiProviderCapability>;
        _providerFiles = values[2] as List<XiangjiProviderFileRecord>;
        _methodNodes = values[3] as List<Map<String, Object?>>;
        _knowledgeRules = values[4] as List<Map<String, Object?>>;
        _candidates = values[5] as List<Map<String, Object?>>;
        _conflicts = values[6] as List<Map<String, Object?>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await operation();
      await _load();
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importFile() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'txt',
        'md',
        'pdf',
        'docx',
        'epub',
        'json',
      ],
    );
    final platformFile = picked?.files.single;
    final path = platformFile?.path ?? '';
    if (path.isEmpty) return;
    if (!mounted) return;
    final values = await showXiangjiFormDialog(
      context,
      title: '导入知识源',
      note: '请选择这份材料主要服务的用途。本地认识边界与安全规则受保护，外部文件不能覆盖。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'title',
          label: '来源标题',
          initialValue: platformFile?.name ?? '',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'layer',
          label: '主要用途',
          hint: '问题求解 / 战略决策 / 思想与行动方法 / 个人经验与战史',
          initialValue: '思想与行动方法',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'kind',
          label: '来源类型',
          hint: '书籍 / 文档 / 笔记 / 战史',
          initialValue: '书籍',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'sensitivity',
          label: '敏感级别',
          hint: '普通 / 敏感 / 高度敏感',
          initialValue: '普通',
          required: true,
        ),
      ],
      submitLabel: '本地保存并建立原文索引',
    );
    if (values == null) return;
    final layer = switch (values['layer']!.trim()) {
      '问题求解' => XiangjiKnowledgeLayer.k1,
      '战略决策' => XiangjiKnowledgeLayer.k2,
      '个人经验与战史' => XiangjiKnowledgeLayer.k4,
      _ => XiangjiKnowledgeLayer.k3,
    };
    if (layer == XiangjiKnowledgeLayer.k0) {
      xiangjiShowMessage(context, 'K0 是受保护的离线硬规则层，不能从外部文件覆盖。');
      return;
    }
    await _run(() async {
      await _importer.importFile(
        file: File(path),
        title: values['title']!,
        layer: layer,
        kind: switch (values['kind']!.trim()) {
          '文档' => 'document',
          '笔记' => 'note',
          '战史' => 'battle_history',
          _ => 'book',
        },
        sensitivity: switch (values['sensitivity']!.trim()) {
          '敏感' => 'sensitive',
          '高度敏感' => 'highly_sensitive',
          _ => 'normal',
        },
      );
    });
  }

  Future<void> _sync(
    XiangjiKnowledgeSourceRecord source,
  ) async {
    final eligible = _capabilities
        .where((item) => item.mayClaimPersistentStorage)
        .toList();
    if (eligible.isEmpty) {
      xiangjiShowMessage(context, '没有已验证且支持持久复用的远程 AI 服务。');
      return;
    }
    final providerId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择远程知识服务'),
        children: [
          for (final capability in eligible)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(capability.providerId),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(capability.label),
                subtitle: Text(
                  '${capability.retentionPolicy} · ${capability.indexingMode}',
                ),
              ),
            ),
        ],
      ),
    );
    if (providerId == null) return;
    await _run(() async {
      await _providers.syncSource(
        sourceId: source.id,
        providerId: providerId,
      );
    });
  }

  Future<void> _deleteRemote(XiangjiProviderFileRecord file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除远程副本'),
        content: Text(
          '将从所选远程 AI 服务删除文件与索引。本地原始文件和引用定位不会删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认删除远程副本'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _providers.deleteRemoteCopy(file));
  }

  Future<void> _showSource(XiangjiKnowledgeSourceRecord source) async {
    final values = await Future.wait<Object?>(<Future<Object?>>[
      widget.dao.sourcePassages(source.id),
      widget.dao.knowledgeNodes(sourceId: source.id, limit: 300),
    ]);
    final passages = values[0] as List<Map<String, Object?>>;
    final nodes = values[1] as List<Map<String, Object?>>;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: XiangjiPalette.mist,
          appBar: AppBar(
            title: Text(source.title),
            backgroundColor: XiangjiPalette.mist,
          ),
          body: passages.isEmpty && nodes.isEmpty
              ? const XiangjiEmptyState(
                  title: '暂无可读内容',
                  message: '来源已经保留，但当前还没有可展示的原文段落或概念节点。',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (passages.isNotEmpty) ...[
                      const Text(
                        '依据与定位',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      for (final passage in passages) ...[
                        XiangjiSectionCard(
                          title:
                              (passage['locator'] ?? '可追溯位置').toString(),
                          subtitle: (passage['text_kind'] ?? '').toString() ==
                                  'verified_locator_summary'
                              ? '定位性内容要旨 · 非逐字引文'
                              : '原文 · 可追溯定位',
                          child: SelectableText(
                            _passageText(passage),
                            style: const TextStyle(height: 1.55),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (nodes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '概念与方法节点',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      for (final node in nodes) ...[
                        _methodNodeCard(node),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _validateCandidate(Map<String, Object?> item) async {
    final values = await showXiangjiFormDialog(
      context,
      title: '验证候选知识',
      note: '请写真实发生的支持材料和反例，不需要填写内部编号。模型输出或文本相似不能单独成为现实证据；稳定化还需多个事件支持或你的明确确认。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'support',
          label: '真实支持材料（每行一项）',
          initialValue:
              _naturalList(item['supporting_refs_json']).replaceAll('；', '\n'),
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'counter',
          label: '已知反例（可为空）',
          initialValue:
              _naturalList(item['counter_refs_json']).replaceAll('；', '\n'),
          maxLines: 3,
        ),
        XiangjiFormFieldSpec(
          keyName: 'scope',
          label: '适用范围',
          initialValue: (item['scope'] ?? '').toString(),
          required: true,
          maxLines: 2,
        ),
        XiangjiFormFieldSpec(
          keyName: 'plan',
          label: '后续验证计划',
          initialValue: (item['validation_plan'] ?? '').toString(),
          required: true,
          maxLines: 3,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'events',
          label: '来自多少个不同现实事件',
          initialValue: '1',
          required: true,
          keyboardType: TextInputType.number,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'counter_reviewed',
          label: '是否已主动检查并保留反例（是/否）',
          initialValue: '否',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'stable',
          label: '希望怎样处理（继续验证/稳定保留/标记冲突）',
          initialValue: '继续验证',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'confirm',
          label: '若请求 stable，输入“我确认适用范围与反例”',
        ),
      ],
      submitLabel: '执行治理校验',
    );
    if (values == null) return;
    final target = values['stable']!.trim();
    await _run(() => _governance.validateCandidate(
          id: item['id'].toString(),
          supportingRefs: xiangjiLines(values['support']!),
          counterRefs: xiangjiLines(values['counter']!),
          validationPlan: values['plan']!,
          scope: values['scope']!,
          distinctEventCount: int.tryParse(values['events']!) ?? 0,
          userExplicitlyConfirmed:
              values['confirm'] == '我确认适用范围与反例',
          counterexamplesReviewed:
              values['counter_reviewed']!.toLowerCase() == 'yes' ||
                  values['counter_reviewed'] == '是',
          requestStable: target == '稳定保留',
          hasStrongConflict: target == '标记冲突',
        ));
  }

  String _naturalList(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        final values = decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        return values.isEmpty ? '当前没有已确认材料' : values.join('；');
      }
    } catch (_) {}
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? '当前没有已确认材料' : value;
  }

  String _knowledgeState(String value) => switch (value.toUpperCase()) {
        'DRAFT' => '草案',
        'ACTIVE' => '当前使用中',
        'STALE' => '现实已变化，等待复核',
        'CANDIDATE' => '候选，等待现实验证',
        'SUPPORTED' => '已有现实支持',
        'STABLE' => '在明确范围内稳定保留',
        'CONFLICTED' => '与现实或其他材料冲突',
        'RETIRED' => '已停用',
        _ => '当前仍可修订',
      };

  String _sourceKind(String value) => switch (value.toLowerCase()) {
        'original_source_framework' => '内置原典框架',
        'product_method_catalog' => '内置产品方法目录',
        'book' => '书籍',
        'document' => '文档',
        'note' => '笔记',
        'battle_history' => '战史',
        _ => '可追溯材料',
      };

  String _layerLabel(XiangjiKnowledgeLayer value) => value.label;

  bool _isBundled(XiangjiKnowledgeSourceRecord source) =>
      source.localUri.startsWith('bundled://') ||
      source.localUri.startsWith('asset://') ||
      source.kind == 'original_source_framework' ||
      source.kind == 'product_method_catalog';

  String _processState(String value) => switch (value.toLowerCase()) {
        'ready' || 'complete' || 'completed' => '已完成',
        'processing' || 'pending' => '处理中',
        'failed' => '需要重新处理',
        _ => '已记录',
      };

  String _sensitivity(String value) => switch (value.toLowerCase()) {
        'sensitive' => '敏感',
        'highly_sensitive' => '高度敏感',
        _ => '普通',
      };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: XiangjiPalette.mist,
        appBar: AppBar(
          title: const Text('我的知识库'),
          backgroundColor: XiangjiPalette.mist,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '内置体系'),
              Tab(text: '知识源'),
              Tab(text: '候选知识'),
              Tab(text: '冲突'),
              Tab(text: '远程服务'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '此次知识来源',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => XiangjiRetrievalTracePage(dao: widget.dao),
                ),
              ),
              icon: const Icon(Icons.route_outlined),
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _working ? null : _importFile,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('导入本地知识'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  TabBarView(
                    children: [
                      _builtInKnowledgeTab(),
                      _sourcesTab(),
                      _candidatesTab(),
                      _conflictsTab(),
                      _providersTab(),
                    ],
                  ),
                  if (_working)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _builtInKnowledgeTab() {
    final sckRules = _rulesStartingWith('SCK-');
    final celRules = _rulesStartingWith('CEL-');
    final solverRules = _rulesStartingWith('PS-');
    final boundaryRules = _knowledgeRules.where((row) {
      final code = (row['rule_code'] ?? '').toString();
      return !code.startsWith('SCK-') &&
          !code.startsWith('CEL-') &&
          !code.startsWith('PS-');
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        XiangjiSectionCard(
          title: '完整内置知识体系',
          subtitle: '产品能力、原概念、运行原则和持续求解合同分别保留，不再混成一组二次命名。',
          icon: Icons.account_tree_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  XiangjiStateBadge(label: '${_methodNodes.length} 项方法能力'),
                  XiangjiStateBadge(label: '${sckRules.length} 条 SCK 原则'),
                  XiangjiStateBadge(label: '${celRules.length} 条体验原则'),
                  XiangjiStateBadge(label: '${solverRules.length} 条求解原则'),
                  XiangjiStateBadge(label: '${boundaryRules.length} 条 K0 边界'),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '当前问题每轮仍只显示真正触发的 0–3 项方法；这里是可完整核对的知识目录，不会把全部概念强塞进一次对话。',
                style: TextStyle(color: XiangjiPalette.muted, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '14 项认识与持续求解方法',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          '名称严格按 Rev5.2 产品能力；展开后可分别核对原概念、产品含义、状态效果和来源。',
          style: TextStyle(color: XiangjiPalette.muted, height: 1.4),
        ),
        const SizedBox(height: 8),
        if (_methodNodes.isEmpty)
          const XiangjiEmptyState(
            title: '内置方法目录未加载',
            message: '数据库中没有找到 Rev5.2 方法节点，请重新初始化未来军师。',
            icon: Icons.warning_amber_outlined,
          )
        else
          for (final node in _methodNodes) ...[
            _methodNodeCard(node),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        _ruleGroup(
          title: '认识与判断原则',
          subtitle: '系统内部怎样区分事实、体验、解释、概念、根据与现实纠错。',
          rows: sckRules,
          icon: Icons.psychology_alt_outlined,
        ),
        const SizedBox(height: 8),
        _ruleGroup(
          title: '用户可见的认知体验原则',
          subtitle: '这些原则约束页面必须怎样让用户看见方法的真实作用。',
          rows: celRules,
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: 8),
        _ruleGroup(
          title: '持续问题求解原则',
          subtitle: '这些原则约束同一问题的身份、版本、尝试、反馈、解决与重开。',
          rows: solverRules,
          icon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: 8),
        _ruleGroup(
          title: '不可覆盖的认识与安全边界',
          subtitle: '外部文件、检索结果和 AI 输出都不能绕过这些本地规则。',
          rows: boundaryRules,
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }

  Widget _methodNodeCard(Map<String, Object?> node) {
    final provenance = _jsonObject(node['provenance_json']);
    final domain = (provenance['domain'] ?? '认识与求解方法').toString();
    final concept = (provenance['source_concept'] ?? '').toString();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.hub_outlined, color: XiangjiPalette.pine),
        title: Text(
          (node['name'] ?? '内置方法').toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          concept.isEmpty ? domain : '$domain · $concept',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          XiangjiLabeledValue(
            label: '产品方案中的能力',
            value: (node['name'] ?? '').toString(),
          ),
          XiangjiLabeledValue(
            label: '对应的原概念 / 求解概念',
            value: concept,
          ),
          XiangjiLabeledValue(
            label: '在产品中意味着什么',
            value: (node['definition'] ?? '').toString(),
          ),
          XiangjiLabeledValue(
            label: '什么时候使用',
            value: (provenance['trigger_summary'] ?? '').toString(),
          ),
          XiangjiLabeledValue(
            label: '必须改变什么状态',
            value: (provenance['state_effect'] ?? '').toString(),
          ),
          XiangjiLabeledValue(
            label: '怎样用现实验算',
            value: (provenance['reality_test'] ?? '').toString(),
          ),
          XiangjiLabeledValue(
            label: '知识来源与定位',
            value: (provenance['source_locator'] ?? '').toString(),
          ),
          XiangjiLabeledValue(
            label: '关联运行原则（高级映射）',
            value: _naturalList(provenance['related_rule_ids']),
          ),
        ],
      ),
    );
  }

  Widget _ruleGroup({
    required String title,
    required String subtitle,
    required List<Map<String, Object?>> rows,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(icon, color: XiangjiPalette.pine),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$subtitle\n完整收录 ${rows.length} 条'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (rows.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('当前数据库没有加载这一组内置原则。'),
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              _ruleRow(rows[index]),
              if (index != rows.length - 1) const Divider(height: 18),
            ],
        ],
      ),
    );
  }

  Widget _ruleRow(Map<String, Object?> row) {
    final code = (row['rule_code'] ?? '').toString();
    final condition = _jsonDescription(row['condition_json']);
    final action = _jsonDescription(row['action_json']);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action.isEmpty ? '一条内置原则' : action,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
          ),
          if (condition.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '触发条件：$condition',
              style: const TextStyle(color: XiangjiPalette.muted, height: 1.4),
            ),
          ],
          if (code.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '规范映射：$code',
              style: const TextStyle(
                color: XiangjiPalette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, Object?>> _rulesStartingWith(String prefix) =>
      _knowledgeRules
          .where((row) =>
              (row['rule_code'] ?? '').toString().startsWith(prefix))
          .toList();

  Map<String, Object?> _jsonObject(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}
    return const <String, Object?>{};
  }

  String _jsonDescription(Object? raw) =>
      (_jsonObject(raw)['description'] ?? '').toString();

  String _passageText(Map<String, Object?> passage) {
    final original = (passage['original_text'] ?? '').toString().trim();
    if (original.isNotEmpty) return original;
    final summary = (passage['translation'] ?? '').toString().trim();
    return summary.isEmpty ? '此位置当前只有来源定位，没有可展示文本。' : summary;
  }

  Widget _sourcesTab() {
    if (_sources.isEmpty) {
      return const XiangjiEmptyState(
        title: '还没有知识源',
        message: '导入原始文件后，系统会保存哈希、原文件、解析状态与可追溯段落。',
        icon: Icons.library_books_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _sources.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final source = _sources[index];
        final files = _providerFiles
            .where((item) => item.sourceId == source.id)
            .toList();
        return XiangjiSectionCard(
          title: source.title,
          subtitle:
              '${_layerLabel(source.layer)} · ${_sourceKind(source.kind)} · 第 ${source.version} 版',
          trailing: XiangjiStateBadge(
            label: _knowledgeState(source.status.name),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  XiangjiStateBadge(
                    label: '读取 ${_processState(source.parseStatus)}',
                  ),
                  XiangjiStateBadge(
                    label: '检索 ${_processState(source.indexStatus)}',
                  ),
                  XiangjiStateBadge(
                    label: '敏感度 ${_sensitivity(source.sensitivity)}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'SHA-256 ${source.contentHash.isEmpty ? '未记录' : source.contentHash.substring(0, source.contentHash.length.clamp(0, 16).toInt())}…',
                style: const TextStyle(
                  color: XiangjiPalette.muted,
                  fontSize: 12,
                ),
              ),
              if (files.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final file in files)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('远程 AI 知识副本'),
                    subtitle: Text(
                      '${file.state.label} · ${file.retentionInfo}${file.lastError.isEmpty ? '' : '\n${file.lastError}'}',
                    ),
                    trailing: file.state == XiangjiProviderFileState.ready
                        ? IconButton(
                            tooltip: '删除远程副本',
                            onPressed: _working
                                ? null
                                : () => _deleteRemote(file),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
                  ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showSource(source),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(_isBundled(source) ? '查看依据与概念' : '查看原文'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: source.localUri.isEmpty ||
                            _isBundled(source) ||
                            _working
                        ? null
                        : () => _sync(source),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(_isBundled(source) ? '内置知识受保护' : '同步到 AI'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _providersTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _capabilities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _capabilities[index];
        return XiangjiSectionCard(
          title: item.label,
          subtitle: '远程 AI 服务能力与数据留存边界',
          trailing: XiangjiStateBadge(
            label: item.verified ? '已验证' : '未验证',
            color: item.verified
                ? XiangjiPalette.pine
                : const Color(0xFFC8641B),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _capability('持久文件', item.supportsPersistentFile),
                  _capability('知识库', item.supportsStore),
                  _capability('可删除', item.supportsDelete),
                  _capability('可复用', item.supportsReuse),
                  _capability('引用', item.supportsCitations),
                  _capability('结构化输出', item.supportsStructuredOutput),
                ],
              ),
              const SizedBox(height: 12),
              XiangjiLabeledValue(label: '留存策略', value: item.retentionPolicy),
              XiangjiLabeledValue(label: '索引模式', value: item.indexingMode),
              XiangjiLabeledValue(label: '限制与说明', value: item.notes),
              if (!item.mayClaimPersistentStorage)
                const Text(
                  '不会向用户宣称“已经永久进入 AI 知识库”。',
                  style: TextStyle(
                    color: Color(0xFFC8641B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _capability(String label, bool value) => XiangjiStateBadge(
        label: '${value ? '✓' : '×'} $label',
        color: value ? XiangjiPalette.pine : XiangjiPalette.muted,
      );

  Widget _candidatesTab() {
    if (_candidates.isEmpty) {
      return const XiangjiEmptyState(
        title: '暂无候选知识',
        message: 'AI 推理产生的模式只会先进入候选层；不会因一次输出自动成为稳定个人规律。',
        icon: Icons.science_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _candidates[index];
        final status = (item['status'] ?? 'CANDIDATE').toString();
        return XiangjiSectionCard(
          title: (item['statement'] ?? '').toString(),
          subtitle: '由军师发现，必须经过现实材料与反例验证',
          trailing: XiangjiStateBadge(label: _knowledgeState(status)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              XiangjiLabeledValue(
                label: '适用范围',
                value: (item['scope'] ?? '').toString(),
              ),
              XiangjiLabeledValue(
                label: '验证计划',
                value: (item['validation_plan'] ?? '').toString(),
              ),
              XiangjiLabeledValue(
                label: '支持材料',
                value: _naturalList(item['supporting_refs_json']),
              ),
              XiangjiLabeledValue(
                label: '反例',
                value: _naturalList(item['counter_refs_json']),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed:
                        _working ? null : () => _validateCandidate(item),
                    child: const Text('提交证据与反例验证'),
                  ),
                  TextButton(
                    onPressed: _working
                        ? null
                        : () => _run(() => widget.dao
                            .updateCandidateKnowledgeState(
                              item['id'].toString(),
                              XiangjiKnowledgeItemState.retired,
                            )),
                    child: const Text('停用'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '稳定化需要多事件支持、适用范围、反例检查与明确确认；本页不会一键跳过这些条件。',
                style: TextStyle(color: XiangjiPalette.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _conflictsTab() {
    if (_conflicts.isEmpty) {
      return const XiangjiEmptyState(
        title: '暂无知识冲突',
        message: '当两个来源、规则或个人经验互相冲突时，会保留双方和处置状态，而不是静默覆盖。',
        icon: Icons.compare_arrows,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _conflicts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = _conflicts[index];
        return ListTile(
          tileColor: Colors.white,
          title: Text((row['impact'] ?? '知识冲突').toString()),
          subtitle: const Text('两组材料或解释给出了不一致结论；双方都会保留，等待按现实复核。'),
        );
      },
    );
  }
}

class XiangjiRetrievalTracePage extends StatefulWidget {
  const XiangjiRetrievalTracePage({super.key, required this.dao});

  final XiangjiDao dao;

  @override
  State<XiangjiRetrievalTracePage> createState() =>
      _XiangjiRetrievalTracePageState();
}

class _XiangjiRetrievalTracePageState
    extends State<XiangjiRetrievalTracePage> {
  List<XiangjiRetrievalTrace> _traces = const <XiangjiRetrievalTrace>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final traces = await widget.dao.retrievalTraces(limit: 100);
      if (!mounted) return;
      setState(() {
        _traces = traces;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      xiangjiShowMessage(context, error);
    }
  }

  String _traceState(String value) => switch (value.toUpperCase()) {
        'COMPLETE' => '已形成可追溯判断',
        'PARTIAL' => '部分来源可用',
        'BLOCKED' => '关键来源不可用',
        _ => '已记录本次来源选择',
      };

  String _sourceSummary(List<String> values) {
    if (values.isEmpty) return '本次没有采用额外来源';
    final labels = <String>{};
    for (final value in values) {
      final lower = value.toLowerCase();
      if (lower.contains('k0') || lower.contains('rule')) {
        labels.add('本地认识边界与安全规则');
      } else if (lower.contains('todo')) {
        labels.add('你的待办与行动记录');
      } else if (lower.contains('experience') || lower.contains('reality')) {
        labels.add('你的现实经验与行动结果');
      } else if (lower.contains('knowledge') || lower.contains('passage')) {
        labels.add('已导入的可追溯原文');
      } else {
        labels.add('当前问题中的可追溯材料');
      }
    }
    return labels.join('；');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XiangjiPalette.mist,
      appBar: AppBar(
        title: const Text('此次知识来源'),
        backgroundColor: XiangjiPalette.mist,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _traces.isEmpty
              ? const XiangjiEmptyState(
                  title: '还没有检索记录',
                  message: '军师运行后，这里会显示路由顺序、采用/拒绝来源、K0 规则与冲突。',
                  icon: Icons.route_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _traces.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final trace = _traces[index];
                    return XiangjiSectionCard(
                      title: '一次军师判断',
                      subtitle:
                          '${_traceState(trace.state.wire)} · ${xiangjiDateTime(trace.createdAtMs)}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          XiangjiLabeledValue(
                            label: '怎样选择材料',
                            value: '先使用本地硬边界，再查当前现实与已导入原文；远程来源只有在授权且必要时才参与。',
                          ),
                          XiangjiLabeledValue(
                            label: '采用来源',
                            value: _sourceSummary(trace.sourcesUsed),
                          ),
                          XiangjiLabeledValue(
                            label: '拒绝来源',
                            value: trace.rejectedSources.isEmpty
                                ? '没有需要拒绝的来源'
                                : '有 ${trace.rejectedSources.length} 项材料因授权、可追溯性或现实根据不足而未采用',
                          ),
                          XiangjiLabeledValue(
                            label: '认识边界',
                            value: '有 ${trace.ruleIds.length} 条约束参与，防止把模型输出、相似文本或复杂推理冒充现实事实',
                          ),
                          XiangjiLabeledValue(
                            label: '冲突',
                            value: trace.conflicts.isEmpty
                                ? '当前采用材料之间没有已发现冲突'
                                : '发现 ${trace.conflicts.length} 处冲突；双方均保留，等待现实复核',
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

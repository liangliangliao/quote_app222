import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'xiangji_database.dart';
import 'xiangji_knowledge_router.dart';
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
        widget.dao.candidateKnowledge(),
        widget.dao.knowledgeConflicts(),
      ]);
      if (!mounted) return;
      setState(() {
        _sources = values[0] as List<XiangjiKnowledgeSourceRecord>;
        _capabilities = values[1] as List<XiangjiProviderCapability>;
        _providerFiles = values[2] as List<XiangjiProviderFileRecord>;
        _candidates = values[3] as List<Map<String, Object?>>;
        _conflicts = values[4] as List<Map<String, Object?>>;
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
      note: 'K1=认识论/判断力，K2=问题求解，K3=战略与方法，K4=个人经验与战史。K0 是离线硬规则，不能通过文件导入覆盖。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'title',
          label: '来源标题',
          initialValue: platformFile?.name ?? '',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'layer',
          label: '知识层',
          initialValue: 'K3',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'kind',
          label: '来源类型',
          initialValue: 'book',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'sensitivity',
          label: '敏感级别',
          initialValue: 'normal',
          required: true,
        ),
      ],
      submitLabel: '本地保存并建立原文索引',
    );
    if (values == null) return;
    final layer = XiangjiKnowledgeLayer.values.firstWhere(
      (item) => item.wire == values['layer']!.toUpperCase(),
      orElse: () => XiangjiKnowledgeLayer.k3,
    );
    if (layer == XiangjiKnowledgeLayer.k0) {
      xiangjiShowMessage(context, 'K0 是受保护的离线硬规则层，不能从外部文件覆盖。');
      return;
    }
    await _run(() async {
      await _importer.importFile(
        file: File(path),
        title: values['title']!,
        layer: layer,
        kind: values['kind']!,
        sensitivity: values['sensitivity']!,
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
      xiangjiShowMessage(context, '没有已验证且支持持久复用的 AI Provider。');
      return;
    }
    final providerId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择远程知识 Provider'),
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
          '将从 ${file.providerId} 删除远程文件/索引。本地原始文件和引用定位不会删除。',
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
    final passages = await widget.dao.sourcePassages(source.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: XiangjiPalette.mist,
          appBar: AppBar(
            title: Text(source.title),
            backgroundColor: XiangjiPalette.mist,
          ),
          body: passages.isEmpty
              ? const XiangjiEmptyState(
                  title: '暂无可读原文段落',
                  message: '原文件仍保存在本地，但当前格式未能提取文字。',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: passages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final passage = passages[index];
                    return XiangjiSectionCard(
                      title: (passage['locator'] ?? '原文段落').toString(),
                      subtitle: '原文 · 可追溯定位',
                      child: SelectableText(
                        (passage['original_text'] ?? '').toString(),
                        style: const TextStyle(height: 1.55),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _validateCandidate(Map<String, Object?> item) async {
    final values = await showXiangjiFormDialog(
      context,
      title: '验证候选知识',
      note: '“支持材料”必须是 Experience/Evidence/RealityResult 的可追溯 ID，不是模型输出或向量相似度。稳定化还需至少两个不同现实事件，或由你明确确认。',
      fields: <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'support',
          label: '真实支持材料 ID（每行一项）',
          initialValue: (item['supporting_refs_json'] ?? '').toString(),
          required: true,
          maxLines: 4,
        ),
        XiangjiFormFieldSpec(
          keyName: 'counter',
          label: '已知反例 ID（可为空）',
          initialValue: (item['counter_refs_json'] ?? '').toString(),
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
          label: '是否已主动检查并保留反例（yes/no）',
          initialValue: 'no',
          required: true,
        ),
        const XiangjiFormFieldSpec(
          keyName: 'stable',
          label: '目标状态（supported/stable/conflicted）',
          initialValue: 'supported',
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
    final target = values['stable']!.toLowerCase();
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
          requestStable: target == 'stable',
          hasStrongConflict: target == 'conflicted',
        ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: XiangjiPalette.mist,
        appBar: AppBar(
          title: const Text('我的知识库'),
          backgroundColor: XiangjiPalette.mist,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '知识源'),
              Tab(text: 'Provider'),
              Tab(text: '候选知识'),
              Tab(text: '冲突'),
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
                      _sourcesTab(),
                      _providersTab(),
                      _candidatesTab(),
                      _conflictsTab(),
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
              '${source.layer.label} · ${source.kind} · v${source.version}',
          trailing: XiangjiStateBadge(label: source.status.name.toUpperCase()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  XiangjiStateBadge(label: '解析 ${source.parseStatus}'),
                  XiangjiStateBadge(label: '索引 ${source.indexStatus}'),
                  XiangjiStateBadge(label: '敏感度 ${source.sensitivity}'),
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
                    title: Text(file.providerId),
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
                    label: const Text('查看原文'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: source.localUri.isEmpty || _working
                        ? null
                        : () => _sync(source),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('同步到 AI'),
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
          subtitle: item.providerId,
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
                  _capability('知识库/Store', item.supportsStore),
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
          subtitle: '来自模型运行 ${item['origin_run_id'] ?? ''}',
          trailing: XiangjiStateBadge(label: status),
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
                value: (item['supporting_refs_json'] ?? '').toString(),
              ),
              XiangjiLabeledValue(
                label: '反例',
                value: (item['counter_refs_json'] ?? '').toString(),
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
          subtitle: Text(
            '${row['left_ref']} ↔ ${row['right_ref']} · ${row['conflict_type']}\n状态：${row['resolution_status']}',
          ),
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
                      title: trace.requestId,
                      subtitle:
                          '${trace.state.wire} · ${xiangjiDateTime(trace.createdAtMs)}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          XiangjiLabeledValue(
                            label: '路由顺序',
                            value: trace.routePlan.join(' → '),
                          ),
                          XiangjiLabeledValue(
                            label: '采用来源',
                            value: trace.sourcesUsed.join('\n'),
                          ),
                          XiangjiLabeledValue(
                            label: '拒绝来源',
                            value: trace.rejectedSources.join('\n'),
                          ),
                          XiangjiLabeledValue(
                            label: '触发硬规则',
                            value: trace.ruleIds.join('、'),
                          ),
                          XiangjiLabeledValue(
                            label: '冲突',
                            value: trace.conflicts.join('\n'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

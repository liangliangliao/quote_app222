import 'package:flutter/material.dart';

import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_knowledge_base_service.dart';
import 'mental_health_knowledge_models.dart';

class MentalHealthKnowledgeBasePage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;

  const MentalHealthKnowledgeBasePage({
    super.key,
    required this.catalog,
    required this.repository,
  });

  @override
  State<MentalHealthKnowledgeBasePage> createState() =>
      _MentalHealthKnowledgeBasePageState();
}

class _MentalHealthKnowledgeBasePageState
    extends State<MentalHealthKnowledgeBasePage> {
  late final MentalHealthKnowledgeBaseService _service;
  CheckupKnowledgeProviderSnapshot? _snapshot;
  CheckupKnowledgeCorpus? _corpus;
  List<CheckupProviderKnowledgeResource> _resources =
      const <CheckupProviderKnowledgeResource>[];
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = MentalHealthKnowledgeBaseService(repository: widget.repository);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final corpus = await widget.repository.buildCourseKnowledgeCorpus(
        catalog: widget.catalog,
      );
      final snapshot = await _service.snapshot(catalog: widget.catalog);
      final resources =
          await widget.repository.loadProviderKnowledgeResources();
      if (!mounted) return;
      setState(() {
        _corpus = corpus;
        _snapshot = snapshot;
        _resources = resources;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _upload() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_upload_outlined),
        title: const Text('上传课程知识库？'),
        content: Text(
          '将把本机编译生成的课程知识文件上传到'
          '${snapshot.config.label}，后续生成候选时直接复用文件ID。'
          '\n\n文件只含课程位置、指标和证据关系，不含用户回答、报告、'
          '行动记录、安装标识或支持号码。供应商侧保存期限和删除能力'
          '仍受其账号与服务条款约束。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认上传'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      final resource = await _service.uploadCurrentCourse(
        catalog: widget.catalog,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resource.ready
                ? '课程知识库已上传并启用；后续请求将复用文件ID。'
                : '供应商未返回可复用文件ID，已继续保留本地RAG。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败：$error')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
    await _load();
  }

  Future<void> _toggle(
    CheckupProviderKnowledgeResource resource,
    bool enabled,
  ) async {
    if (resource.status != CheckupKnowledgeResourceStatus.ready) return;
    setState(() => _working = true);
    await _service.setEnabled(resource, enabled);
    if (mounted) setState(() => _working = false);
    await _load();
  }

  Future<void> _detach(CheckupProviderKnowledgeResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
        title: const Text('删除或解除关联？'),
        content: Text(
          '系统会先尝试从${resource.providerLabel}删除远端文件，再删除'
          '本机启用关联。若供应商不支持API删除，只能解除本机关联，'
          '你仍需到供应商控制台手动删除远端文件。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    final remoteDeleted = await _service.deleteOrDetach(resource);
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          remoteDeleted ? '远端文件已删除，本机关联已解除。' : '本机关联已解除；请在供应商控制台确认并手动删除远端文件。',
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final corpus = _corpus;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI课程知识库'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _loading || _working ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _KnowledgeError(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: <Widget>[
                    const _LocalFirstNotice(),
                    const SizedBox(height: 12),
                    if (corpus != null) _CorpusCard(corpus: corpus),
                    const SizedBox(height: 12),
                    if (snapshot != null)
                      _ProviderCard(
                        snapshot: snapshot,
                        working: _working,
                        onUpload: _upload,
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      '供应商资源记录',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '文件ID按供应商账号指纹、课程版本和内容哈希隔离；'
                      'API密钥不会写入这些记录。',
                      style: TextStyle(color: Color(0xFF667085), height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    if (_resources.isEmpty)
                      const _KnowledgeEmpty()
                    else
                      for (final resource in _resources)
                        _ResourceCard(
                          resource: resource,
                          currentProvider:
                              snapshot?.config.provider == resource.provider &&
                                  snapshot?.accountFingerprint ==
                                      resource.accountFingerprint,
                          working: _working,
                          onToggle: (value) => _toggle(resource, value),
                          onDetach: () => _detach(resource),
                        ),
                  ],
                ),
    );
  }
}

class _LocalFirstNotice extends StatelessWidget {
  const _LocalFirstNotice();

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFECFDF3),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.offline_bolt_outlined, color: Color(0xFF39715D)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '默认模式始终是本地权威知识库 + 本地检索。远端文件ID只是'
                  '可选加速层：未配置、不支持、失效或请求失败时，候选生成'
                  '会自动回退到本地证据摘录，不影响体检、报告和处方闭环。',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _CorpusCard extends StatelessWidget {
  final CheckupKnowledgeCorpus corpus;

  const _CorpusCard({required this.corpus});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '本地课程语料',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _KnowledgePill(text: '${corpus.indicatorCount} 项指标'),
                  _KnowledgePill(text: '${corpus.courseLocationCount} 个课程位置'),
                  _KnowledgePill(text: '${corpus.evidenceRelationCount} 条证据关系'),
                  _KnowledgePill(text: _formatBytes(corpus.bytes.length)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '课程版本：${corpus.courseVersion}\n'
                '内容哈希：${_shortId(corpus.sourceSha256, head: 16)}',
                style: const TextStyle(color: Color(0xFF667085), height: 1.45),
              ),
            ],
          ),
        ),
      );
}

class _ProviderCard extends StatelessWidget {
  final CheckupKnowledgeProviderSnapshot snapshot;
  final bool working;
  final VoidCallback onUpload;

  const _ProviderCard({
    required this.snapshot,
    required this.working,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final config = snapshot.config;
    final active = snapshot.activeResource;
    final canUpload =
        config.available && snapshot.supportsPersistentFile && !working;
    return Card(
      color: const Color(0xFFF3F6FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.cloud_outlined, color: Color(0xFF4554C5)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    config.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(
                  text: active != null ? '文件ID已启用' : '本地RAG',
                  active: active != null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              !config.available
                  ? '当前供应商尚未配置API密钥，请先在App全局AI设置中配置。'
                  : !snapshot.supportsPersistentFile
                      ? '该供应商当前不支持可复用文件ID；每次仅发送经本地检索'
                          '筛选后的课程证据摘录。'
                      : active == null
                          ? '支持首次上传后复用文件ID；尚未启用与当前课程哈希'
                              '匹配的资源。'
                          : '后续候选指标、题目和任务生成将携带此文件ID，'
                              '同时保留本地证据ID用于可追溯校验。',
              style: const TextStyle(height: 1.45),
            ),
            if (active != null) ...[
              const SizedBox(height: 8),
              Text(
                '文件ID：${_shortId(active.providerFileId)}',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canUpload ? onUpload : null,
                icon: working
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(active == null ? '上传并启用' : '重新上传当前版本'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final CheckupProviderKnowledgeResource resource;
  final bool currentProvider;
  final bool working;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDetach;

  const _ResourceCard({
    required this.resource,
    required this.currentProvider,
    required this.working,
    required this.onToggle,
    required this.onDetach,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _resourceColor(
                    resource.status,
                  ).withValues(alpha: 0.12),
                  child: Icon(
                    _resourceIcon(resource.status),
                    color: _resourceColor(resource.status),
                  ),
                ),
                title: Text(
                  resource.providerLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${resource.status.label} · '
                  '${_formatBytes(resource.byteCount)}\n'
                  '${resource.courseVersion} · '
                  '${_shortId(resource.providerFileId)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: '删除或解除关联',
                  onPressed: working ? null : onDetach,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: resource.enabled &&
                    resource.status == CheckupKnowledgeResourceStatus.ready,
                onChanged: !working &&
                        currentProvider &&
                        resource.status == CheckupKnowledgeResourceStatus.ready
                    ? onToggle
                    : null,
                title: const Text('允许生成流程复用此文件ID'),
                subtitle: Text(
                  currentProvider ? '仅“就绪”且匹配当前供应商的资源可启用。' : '切换回该供应商后才可启用。',
                ),
              ),
            ],
          ),
        ),
      );
}

class _KnowledgePill extends StatelessWidget {
  final String text;

  const _KnowledgePill({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4554C5).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF4554C5),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String text;
  final bool active;

  const _StatusPill({required this.text, required this.active});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: (active ? const Color(0xFF39715D) : const Color(0xFF667085))
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF39715D) : const Color(0xFF667085),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
}

class _KnowledgeEmpty extends StatelessWidget {
  const _KnowledgeEmpty();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, size: 34),
              SizedBox(height: 8),
              Text('没有供应商资源记录', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('系统当前按默认本地RAG工作。',
                  style: TextStyle(color: Color(0xFF667085))),
            ],
          ),
        ),
      );
}

class _KnowledgeError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _KnowledgeError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 38),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
}

extension on CheckupKnowledgeResourceStatus {
  String get label => switch (this) {
        CheckupKnowledgeResourceStatus.uploading => '上传中',
        CheckupKnowledgeResourceStatus.ready => '就绪',
        CheckupKnowledgeResourceStatus.stale => '课程已变化',
        CheckupKnowledgeResourceStatus.failed => '上传失败',
        CheckupKnowledgeResourceStatus.detached => '已解除关联',
      };
}

Color _resourceColor(CheckupKnowledgeResourceStatus status) => switch (status) {
      CheckupKnowledgeResourceStatus.ready => const Color(0xFF39715D),
      CheckupKnowledgeResourceStatus.uploading => const Color(0xFF4554C5),
      CheckupKnowledgeResourceStatus.stale => const Color(0xFFB54708),
      CheckupKnowledgeResourceStatus.failed => const Color(0xFFC62828),
      CheckupKnowledgeResourceStatus.detached => const Color(0xFF667085),
    };

IconData _resourceIcon(CheckupKnowledgeResourceStatus status) =>
    switch (status) {
      CheckupKnowledgeResourceStatus.ready => Icons.cloud_done_outlined,
      CheckupKnowledgeResourceStatus.uploading => Icons.cloud_upload_outlined,
      CheckupKnowledgeResourceStatus.stale => Icons.sync_problem_outlined,
      CheckupKnowledgeResourceStatus.failed => Icons.error_outline,
      CheckupKnowledgeResourceStatus.detached => Icons.link_off_outlined,
    };

String _shortId(String value, {int head = 8}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '无文件ID';
  if (trimmed.length <= head + 4) return trimmed;
  return '${trimmed.substring(0, head)}…${trimmed.substring(trimmed.length - 4)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

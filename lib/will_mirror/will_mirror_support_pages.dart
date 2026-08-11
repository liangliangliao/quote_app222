import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'will_mirror_knowledge_repository.dart';
import 'will_mirror_models.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorKnowledgePage extends StatefulWidget {
  const WillMirrorKnowledgePage({super.key, this.knowledge});

  final WillMirrorKnowledgeRepository? knowledge;

  @override
  State<WillMirrorKnowledgePage> createState() =>
      _WillMirrorKnowledgePageState();
}

class _WillMirrorKnowledgePageState extends State<WillMirrorKnowledgePage> {
  late final bool _ownsKnowledge = widget.knowledge == null;
  late final WillMirrorKnowledgeRepository _knowledge =
      widget.knowledge ?? WillMirrorKnowledgeRepository();
  final _query = TextEditingController();
  List<WillMirrorKnowledgePassage> _results =
      const <WillMirrorKnowledgePassage>[];
  WillMirrorKnowledgeManifest? _manifest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    if (_ownsKnowledge) unawaited(_knowledge.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final manifest = await _knowledge.manifest();
      final records = await _knowledge.allPassages();
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _results = records;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final result = _query.text.trim().isEmpty
          ? await _knowledge.allPassages()
          : await _knowledge.search(_query.text.trim(), limit: 30);
      if (!mounted) return;
      setState(() {
        _results = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('离线理论证据 KB'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: _loading && _results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: <Widget>[
                if (_error != null)
                  WillMirrorSectionCard(
                    color: WillMirrorPalette.rose,
                    child: Text('KB 校验失败：$_error'),
                  )
                else ...<Widget>[
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      WillMirrorBadge(
                        label: _manifest?.kbVersion ?? 'V4 KB',
                        icon: Icons.verified_outlined,
                      ),
                      WillMirrorBadge(
                        label: '${_manifest?.recordCount ?? 0} 条证据',
                      ),
                      const WillMirrorBadge(label: '只读 · SHA-256 · SQLite'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '原文、研究译文、忠实摘要、产品规则与误用边界严格分层。C 级产品推导永远不能伪装成作者原话。',
                    style: TextStyle(
                      height: 1.45,
                      color: WillMirrorPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _query,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: '搜索：Deep Why / 自主 / 反证 / 获得性格…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _search,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (_results.isEmpty)
                    const WillMirrorSectionCard(
                      child: Text('没有找到匹配证据。系统不会用模型记忆补造依据。'),
                    )
                  else
                    ..._results.map(_recordCard),
                ],
              ],
            ),
    );
  }

  Widget _recordCard(WillMirrorKnowledgePassage item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WillMirrorSectionCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            '${item.creator} · ${item.workPart} ${item.sectionRef}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            item.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: WillMirrorBadge(label: item.evidenceLevel.value),
          children: <Widget>[
            const Divider(),
            _field('稳定定位', item.locatorText),
            _field('原文短证据', item.originalText),
            _field('研究版中译', item.zhTranslation),
            _field('忠实摘要', item.summary),
            _field('产品操作化', item.productRule),
            _field('误用边界', item.misuseBoundary),
            _field('翻译状态', item.translationStatus),
            _field('权利状态', item.rightsStatus),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: WillMirrorPalette.forest,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}

class WillMirrorPrivacyPage extends StatefulWidget {
  const WillMirrorPrivacyPage({
    super.key,
    this.vault,
    this.knowledge,
  });

  final WillMirrorVault? vault;
  final WillMirrorKnowledgeRepository? knowledge;

  @override
  State<WillMirrorPrivacyPage> createState() => _WillMirrorPrivacyPageState();
}

class _WillMirrorPrivacyPageState extends State<WillMirrorPrivacyPage> {
  late final bool _ownsVault = widget.vault == null;
  late final bool _ownsKnowledge = widget.knowledge == null;
  late final WillMirrorVault _vault = widget.vault ?? WillMirrorVault();
  late final WillMirrorKnowledgeRepository _knowledge =
      widget.knowledge ?? WillMirrorKnowledgeRepository();
  WillMirrorVaultStatus? _status;
  WillMirrorKnowledgeValidation? _kbValidation;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_ownsVault) unawaited(_vault.close());
    if (_ownsKnowledge) unawaited(_knowledge.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await _vault.status();
      final validation = await _knowledge.validateCompiledDatabase();
      if (!mounted) return;
      setState(() {
        _status = status;
        _kbValidation = validation;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('安全状态检查失败：$error');
    }
  }

  Future<void> _export() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出将生成明文副本'),
        content: const Text(
          'Vault 内部是加密的；为了让你能迁移和阅读，导出的 JSON 是明文。请只保存在你信任的位置，不要随意发送给第三方。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('我理解，继续导出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final payload = const JsonEncoder.withIndent('  ').convert(
        await _vault.exportDecrypted(),
      );
      final now = DateTime.now();
      final date = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出意志之镜明文数据',
        fileName: 'will-mirror-$date.json',
        bytes: Uint8List.fromList(utf8.encode(payload)),
      );
      if (!mounted) return;
      setState(() => _working = false);
      if (path == null) {
        _message('已取消导出，没有生成明文副本。');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导出完成'),
          content: SelectableText(path),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _message('导出失败：$error');
    }
  }

  Future<void> _deleteAll() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('彻底删除意志之镜数据？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '这会删除目标、Why Tree、人生证据、实验和 AI 推理记录，并销毁 Android Keystore 密钥。理论 KB 不含个人信息，会保留。此操作无法撤销。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '输入“彻底删除”确认',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (controller.text.trim() != '彻底删除') return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('删除并销毁密钥'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await _vault.deleteAll();
      if (!mounted) return;
      setState(() => _working = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('已彻底删除'),
          content: const Text('私密 Vault 文件与 Keystore 密钥均已删除。'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(this.context, true);
              },
              child: const Text('返回'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _message('删除失败：$error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final validation = _kbValidation;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('数据与隐私'),
        backgroundColor: const Color(0xFFFAFBF9),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: <Widget>[
                WillMirrorSectionCard(
                  color: status?.keystoreAvailable == true
                      ? WillMirrorPalette.sage
                      : WillMirrorPalette.rose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Private Life Vault',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _line(
                        'Android Keystore',
                        status?.keystoreAvailable == true ? '可用' : '不可用，禁止写入',
                      ),
                      _line('静态保护', 'AES-256-GCM；用户文本先加密再进入 SQLite'),
                      _line('云同步', status?.localOnly == true ? '关闭（本地优先）' : '已选择同步'),
                      _line('普通日志', '不写入 Why Tree、关系、性、创伤或原始对话'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                WillMirrorSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Evidence KB',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _line('个人信息', '不包含'),
                      _line('数据库', '独立只读 will_mirror_kb.sqlite'),
                      _line('完整性', validation?.integrityCheck ?? '未检查'),
                      _line('结构校验', validation?.valid == true ? '通过' : '未通过'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const WillMirrorSectionCard(
                  color: WillMirrorPalette.cream,
                  child: Text(
                    '云端 AI 默认不调用。只有你在某个候选页逐次确认后，才会发送该候选已连接的最小证据和短理论摘要；整个 Vault 不会被自动上传。',
                    style: TextStyle(height: 1.5),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _working ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出我的全部意志之镜数据'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  onPressed: _working ? null : _deleteAll,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('彻底删除 Vault 并销毁密钥'),
                ),
                if (_working) ...<Widget>[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: WillMirrorPalette.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

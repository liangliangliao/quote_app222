import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/kv_dao.dart';
import '../pages/settings_page.dart';
import 'concept_engine_models.dart';
import 'concept_engine_service.dart';

class BehaviorActionChainPage extends StatefulWidget {
  final String concept;
  final String domain;
  final String goal;
  final String behavior;
  final String? sessionId;

  const BehaviorActionChainPage({
    super.key,
    required this.concept,
    required this.domain,
    required this.goal,
    required this.behavior,
    this.sessionId,
  });

  @override
  State<BehaviorActionChainPage> createState() => _BehaviorActionChainPageState();
}

class _BehaviorActionChainPageState extends State<BehaviorActionChainPage> {
  static const List<String> _statuses = ['未开始', '进行中', '失败', '成功'];

  final _service = ConceptEngineService();
  final _kvDao = KeyValueDao();

  ConceptEngineRuntimeConfig? _runtimeConfig;
  BehaviorActionChain? _chain;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await _service.loadRuntimeConfig();
      final saved = await _kvDao.getString(_chainCacheKey());
      BehaviorActionChain? chain;
      if ((saved ?? '').trim().isNotEmpty) {
        try {
          chain = BehaviorActionChain.fromJson(Map<String, dynamic>.from(jsonDecode(saved!) as Map));
        } catch (_) {
          chain = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _runtimeConfig = cfg;
        _chain = chain;
        _loading = false;
      });
      if (chain == null) {
        Future.microtask(_generateChain);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _scopeKey() {
    final raw = '${widget.concept.trim()}||${widget.domain.trim()}||${widget.goal.trim()}||${widget.behavior.trim()}';
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }

  String _chainCacheKey() => 'ce_behavior_chain_cache_${_scopeKey()}';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _generateChain() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final cfg = await _service.loadRuntimeConfig();
      final chain = await _service.generateBehaviorActionChain(
        concept: widget.concept,
        domain: widget.domain,
        goal: widget.goal,
        behavior: widget.behavior,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _runtimeConfig = cfg;
        _chain = chain;
      });
      await _persistChain(showToast: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _persistChain({bool showToast = false}) async {
    final chain = _chain;
    if (chain == null) return;
    await _kvDao.setString(_chainCacheKey(), jsonEncode(chain.toJson()));
    if (showToast) _toast('行动链已保存');
  }

  void _updateNodeStatus(int index, String status) {
    final chain = _chain;
    if (chain == null) return;
    final nodes = List<BehaviorActionNode>.from(chain.nodes);
    nodes[index] = nodes[index].copyWith(status: status);
    setState(() => _chain = chain.copyWith(nodes: nodes));
    _persistChain();
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _metaChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
    );
  }

  Widget _statusChip(String text, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(text),
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chain = _chain;
    return Scaffold(
      appBar: AppBar(
        title: const Text('行为行动链'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            icon: const Icon(Icons.tune_outlined),
            tooltip: '前往设置页配置 AI 提示词',
          ),
          IconButton(
            onPressed: chain == null ? null : () => _persistChain(showToast: true),
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存行动链',
          ),
          IconButton(
            onPressed: chain == null
                ? null
                : () {
                    final snapshot = jsonEncode(chain.toJson());
                    Clipboard.setData(ClipboardData(text: snapshot));
                    _toast('已复制行动链 JSON');
                  },
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: '复制 JSON',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('当前行为', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(widget.behavior, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.45)),
                        const SizedBox(height: 12),
                        Wrap(
                          children: [
                            _metaChip('概念：${widget.concept}'),
                            _metaChip('领域：${widget.domain}'),
                            if (_runtimeConfig != null) _metaChip('模型：${_runtimeConfig!.model}'),
                          ],
                        ),
                        if (widget.goal.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('训练目标：${widget.goal}', style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI 配置来源', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          _runtimeConfig == null
                              ? '未加载设置页配置。'
                              : '当前提供商：${_runtimeConfig!.providerLabel} · 模型：${_runtimeConfig!.model} · 行动链节点 ${_runtimeConfig!.behaviorChainMinNodes}-${_runtimeConfig!.behaviorChainMaxNodes} · max tokens ${_runtimeConfig!.behaviorChainMaxTokens}',
                          style: const TextStyle(color: Color(0xFF4B5563), height: 1.45),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '行为行动链提示词与参数已移到 App 设置页统一管理。修改设置后，回到这里点击“重新生成”，就会按最新配置重新调用 AI。',
                          style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                          icon: const Icon(Icons.tune_outlined),
                          label: const Text('打开设置页'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('行动链结果', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            ),
                            FilledButton.icon(
                              onPressed: _generating ? null : _generateChain,
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(chain == null ? '生成行动链' : '重新生成'),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                        if (_generating) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                        ] else if (chain == null) ...[
                          const SizedBox(height: 12),
                          const Text(
                            '点击“生成行动链”后，会把当前行为作为参数提交给 AI，生成一条由多个行为节点组成的行动链。',
                            style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(chain.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          if (chain.summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(chain.summary, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                          ],
                          const SizedBox(height: 12),
                          ...List.generate(chain.nodes.length, (index) {
                            final node = chain.nodes[index];
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('节点 ${index + 1} · ${node.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  if (node.detail.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(node.detail, style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
                                  ],
                                  const SizedBox(height: 10),
                                  const Text('状态', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    children: _statuses
                                        .map((status) => _statusChip(
                                              status,
                                              node.status == status,
                                              () => _updateNodeStatus(index, status),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

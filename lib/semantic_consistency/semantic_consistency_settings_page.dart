import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/dao.dart';
import '../services/global_ai_settings.dart';
import 'semantic_consistency_models.dart';

class SemanticConsistencySettingsPage extends StatefulWidget {
  const SemanticConsistencySettingsPage({super.key});

  @override
  State<SemanticConsistencySettingsPage> createState() => _SemanticConsistencySettingsPageState();
}

class _SemanticConsistencySettingsPageState extends State<SemanticConsistencySettingsPage> {
  bool _loading = true;
  bool _saving = false;
  SemanticPrecisionMode _mode = SemanticPrecisionMode.standardJudge;
  String _embeddingProvider = SemanticConsistencySettings.defaultEmbeddingProvider;
  bool _enableReranker = false;
  bool _loadingEmbeddingModels = false;
  List<String> _availableEmbeddingModels = <String>[];

  final _embeddingModelCtrl = TextEditingController();
  final _embeddingDimensionsCtrl = TextEditingController();
  final _lowThresholdCtrl = TextEditingController();
  final _highThresholdCtrl = TextEditingController();
  final _strictThresholdCtrl = TextEditingController();
  final _rerankerProviderCtrl = TextEditingController();
  final _rerankerModelCtrl = TextEditingController();
  final _rerankerApiKeyCtrl = TextEditingController();
  final _rerankerEndpointCtrl = TextEditingController();
  final _titleEvidenceTopKCtrl = TextEditingController();
  final _judgeSystemPromptCtrl = TextEditingController();
  final _judgeUserPromptTemplateCtrl = TextEditingController();
  final Map<SemanticPrecisionMode, TextEditingController> _modeInstructionCtrls = <SemanticPrecisionMode, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final mode in SemanticPrecisionMode.values) {
      if (mode == SemanticPrecisionMode.fastEmbedding) continue;
      _modeInstructionCtrls[mode] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    _embeddingModelCtrl.dispose();
    _embeddingDimensionsCtrl.dispose();
    _lowThresholdCtrl.dispose();
    _highThresholdCtrl.dispose();
    _strictThresholdCtrl.dispose();
    _rerankerProviderCtrl.dispose();
    _rerankerModelCtrl.dispose();
    _rerankerApiKeyCtrl.dispose();
    _rerankerEndpointCtrl.dispose();
    _titleEvidenceTopKCtrl.dispose();
    _judgeSystemPromptCtrl.dispose();
    _judgeUserPromptTemplateCtrl.dispose();
    for (final ctrl in _modeInstructionCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await SemanticConsistencySettings.load();
    if (!mounted) return;
    setState(() {
      _mode = s.defaultMode;
      _embeddingProvider = s.embeddingProvider;
      _embeddingModelCtrl.text = s.embeddingModel;
      _embeddingDimensionsCtrl.text = s.embeddingDimensions.toString();
      _lowThresholdCtrl.text = s.lowThreshold.toString();
      _highThresholdCtrl.text = s.highThreshold.toString();
      _strictThresholdCtrl.text = s.strictThreshold.toString();
      _enableReranker = s.enableReranker;
      _rerankerProviderCtrl.text = s.rerankerProvider;
      _rerankerModelCtrl.text = s.rerankerModel;
      _rerankerApiKeyCtrl.text = s.rerankerApiKey;
      _rerankerEndpointCtrl.text = s.rerankerEndpoint;
      _titleEvidenceTopKCtrl.text = s.titleEvidenceTopK.toString();
      _judgeSystemPromptCtrl.text = s.judgeSystemPrompt.trim().isEmpty
          ? SemanticConsistencyPromptDefaults.systemPrompt
          : s.judgeSystemPrompt;
      _judgeUserPromptTemplateCtrl.text = s.judgeUserPromptTemplate.trim().isEmpty
          ? SemanticConsistencyPromptDefaults.userPromptTemplate
          : s.judgeUserPromptTemplate;
      for (final entry in _modeInstructionCtrls.entries) {
        entry.value.text = s.judgeModeInstructions[entry.key.id]?.trim().isNotEmpty == true
            ? s.judgeModeInstructions[entry.key.id]!.trim()
            : SemanticConsistencyPromptDefaults.instructionForMode(entry.key);
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final s = SemanticConsistencySettings(
      defaultMode: _mode,
      embeddingProvider: _embeddingProvider.trim().isEmpty ? SemanticConsistencySettings.defaultEmbeddingProvider : _embeddingProvider.trim(),
      embeddingModel: _embeddingModelCtrl.text.trim().isEmpty ? SemanticConsistencySettings.defaultEmbeddingModel : _embeddingModelCtrl.text.trim(),
      embeddingDimensions: _parseInt(_embeddingDimensionsCtrl.text, SemanticConsistencySettings.defaultEmbeddingDimensions, 64, 8192),
      lowThreshold: _parseDouble(_lowThresholdCtrl.text, SemanticConsistencySettings.defaultLowThreshold, -1, 1),
      highThreshold: _parseDouble(_highThresholdCtrl.text, SemanticConsistencySettings.defaultHighThreshold, -1, 1),
      strictThreshold: _parseDouble(_strictThresholdCtrl.text, SemanticConsistencySettings.defaultStrictThreshold, -1, 1),
      enableReranker: _enableReranker,
      rerankerProvider: _rerankerProviderCtrl.text.trim().isEmpty ? SemanticConsistencySettings.defaultRerankerProvider : _rerankerProviderCtrl.text.trim(),
      rerankerModel: _rerankerModelCtrl.text.trim().isEmpty ? SemanticConsistencySettings.defaultRerankerModel : _rerankerModelCtrl.text.trim(),
      rerankerApiKey: _rerankerApiKeyCtrl.text.trim(),
      rerankerEndpoint: _rerankerEndpointCtrl.text.trim().isEmpty ? SemanticConsistencySettings.defaultRerankerEndpoint : _rerankerEndpointCtrl.text.trim(),
      titleEvidenceTopK: _parseInt(_titleEvidenceTopKCtrl.text, SemanticConsistencySettings.defaultTitleEvidenceTopK, 1, 12),
      judgeSystemPrompt: _judgeSystemPromptCtrl.text.trim().isEmpty
          ? SemanticConsistencyPromptDefaults.systemPrompt
          : _judgeSystemPromptCtrl.text.trim(),
      judgeUserPromptTemplate: _judgeUserPromptTemplateCtrl.text.trim().isEmpty
          ? SemanticConsistencyPromptDefaults.userPromptTemplate
          : _judgeUserPromptTemplateCtrl.text.trim(),
      judgeModeInstructions: <String, String>{
        for (final entry in _modeInstructionCtrls.entries)
          entry.key.id: entry.value.text.trim().isEmpty
              ? SemanticConsistencyPromptDefaults.instructionForMode(entry.key)
              : entry.value.text.trim(),
      },
    );
    await s.save();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('语义一致性精判配置已保存')));
  }

  void _restoreDefaults() {
    setState(() {
      _mode = SemanticPrecisionMode.standardJudge;
      _embeddingProvider = SemanticConsistencySettings.defaultEmbeddingProvider;
      _embeddingModelCtrl.text = SemanticConsistencySettings.defaultEmbeddingModel;
      _embeddingDimensionsCtrl.text = SemanticConsistencySettings.defaultEmbeddingDimensions.toString();
      _lowThresholdCtrl.text = SemanticConsistencySettings.defaultLowThreshold.toString();
      _highThresholdCtrl.text = SemanticConsistencySettings.defaultHighThreshold.toString();
      _strictThresholdCtrl.text = SemanticConsistencySettings.defaultStrictThreshold.toString();
      _enableReranker = false;
      _rerankerProviderCtrl.text = SemanticConsistencySettings.defaultRerankerProvider;
      _rerankerModelCtrl.text = SemanticConsistencySettings.defaultRerankerModel;
      _rerankerApiKeyCtrl.text = '';
      _rerankerEndpointCtrl.text = SemanticConsistencySettings.defaultRerankerEndpoint;
      _titleEvidenceTopKCtrl.text = SemanticConsistencySettings.defaultTitleEvidenceTopK.toString();
      _restorePromptDefaultsInternal();
    });
  }

  void _restorePromptDefaultsInternal() {
    _judgeSystemPromptCtrl.text = SemanticConsistencyPromptDefaults.systemPrompt;
    _judgeUserPromptTemplateCtrl.text = SemanticConsistencyPromptDefaults.userPromptTemplate;
    for (final entry in _modeInstructionCtrls.entries) {
      entry.value.text = SemanticConsistencyPromptDefaults.instructionForMode(entry.key);
    }
  }

  void _restorePromptDefaults() {
    setState(_restorePromptDefaultsInternal);
  }

  int _parseInt(String raw, int fallback, int min, int max) {
    final value = int.tryParse(raw.trim()) ?? fallback;
    return value.clamp(min, max).toInt();
  }

  double _parseDouble(String raw, double fallback, double min, double max) {
    final value = double.tryParse(raw.trim()) ?? fallback;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }


  void _applyEmbeddingPreset({required String provider, required String model, required int dimensions}) {
    setState(() {
      _embeddingProvider = provider;
      _embeddingModelCtrl.text = model;
      _embeddingDimensionsCtrl.text = dimensions.toString();
    });
  }

  int? _knownEmbeddingDimensions(String model) {
    final m = model.trim().toLowerCase();
    if (m == 'openai/text-embedding-3-small' || m == 'text-embedding-3-small') return 1536;
    if (m == 'openai/text-embedding-3-large' || m == 'text-embedding-3-large') return 3072;
    if (m.contains('qwen3-embedding-4b')) return 2560;
    if (m.contains('qwen3-embedding-8b')) return 4096;
    if (m.contains('bge-m3')) return 1024;
    if (m.contains('gemini-embedding-001') || m.contains('gemini-embedding-2')) return 3072;
    if (m.contains('embed-multilingual-v3.0') || m.contains('embed-v4')) return 1024;
    if (m.contains('jina-embeddings-v3')) return 1024;
    return null;
  }

  Future<void> _refreshEmbeddingModels() async {
    setState(() => _loadingEmbeddingModels = true);
    try {
      final provider = _embeddingProvider.trim().toLowerCase();
      late final Uri uri;
      late final String apiKey;
      if (provider == 'edenai') {
        uri = Uri.parse('https://api.edenai.run/v3/embeddings/models');
        apiKey = await GlobalAiSettings().getEdenAiKey();
      } else if (provider == 'openrouter') {
        uri = Uri.parse('https://openrouter.ai/api/v1/models');
        apiKey = await ConfigDao().getOpenRouterKey();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OpenAI 直连不需要刷新列表，请填写 text-embedding-3-small 或 text-embedding-3-large。')),
        );
        return;
      }
      if (apiKey.trim().isEmpty) {
        throw StateError("未配置 ${provider == 'edenai' ? 'Eden AI' : 'OpenRouter'} API Key。");
      }
      final resp = await http
          .get(uri, headers: {'Authorization': 'Bearer $apiKey'})
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('获取 Embedding 模型列表失败：HTTP ${resp.statusCode} ${resp.body}');
      }
      final decoded = jsonDecode(resp.body);
      final data = decoded is Map ? decoded['data'] : null;
      final models = <String>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final id = (item['id'] ?? item['canonical_slug'] ?? '').toString().trim();
            if (id.isEmpty) continue;
            if (provider == 'openrouter') {
              final lower = id.toLowerCase();
              if (lower.contains('embedding') || lower.contains('embed') || lower.contains('bge')) {
                models.add(id);
              }
            } else {
              models.add(id);
            }
          }
        }
      }
      models.sort();
      if (!mounted) return;
      setState(() => _availableEmbeddingModels = models);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("已获取 ${models.length} 个 ${provider == 'edenai' ? 'Eden AI' : 'OpenRouter'} Embedding 模型")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), duration: const Duration(seconds: 5)),
      );
    } finally {
      if (mounted) setState(() => _loadingEmbeddingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语义一致性精判配置'),
        actions: [
          IconButton(
            tooltip: '恢复默认',
            onPressed: _restoreDefaults,
            icon: const Icon(Icons.restore),
          ),
          IconButton(
            tooltip: '保存',
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _infoCard(),
                const SizedBox(height: 12),
                _section(
                  title: '默认精准性模式',
                  children: [
                    DropdownButtonFormField<SemanticPrecisionMode>(
                      value: _mode,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '默认模式'),
                      items: SemanticPrecisionMode.values
                          .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _mode = v ?? SemanticPrecisionMode.standardJudge),
                    ),
                    const SizedBox(height: 8),
                    Text(_mode.description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                  ],
                ),
                _section(
                  title: 'LLM Judge 提示词配置（可自定义）',
                  children: [
                    const Text(
                      '这些提示词会真正参与语义关系精判请求。可在这里修改系统提示词、用户提示词模板，以及不同模式的附加提示词；留空或点击恢复默认即可回到内置提示词。',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    const SelectableText(
                      '可用变量：{{modeLabel}}、{{modeId}}、{{embeddingCosine}}、{{extraInstruction}}、{{titleEvidenceBlock}}、{{textA}}、{{textB}}、{{jsonSchema}}。\n模式附加提示词可用变量：{{embeddingInstruction}}、{{eventA}}、{{eventB}}、{{candidatesForJudge}}。',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _restorePromptDefaults,
                          icon: const Icon(Icons.restore),
                          label: const Text('恢复提示词默认'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('系统提示词 System Prompt'),
                      subtitle: const Text('控制模型扮演什么角色、总体判断原则、输出约束。'),
                      children: [
                        _textField(
                          _judgeSystemPromptCtrl,
                          '系统提示词',
                          '用于 generateText 的 systemPrompt',
                          maxLines: 14,
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('用户提示词模板 User Prompt Template'),
                      subtitle: const Text('控制每次请求如何组织文本A、文本B、证据和JSON Schema。'),
                      children: [
                        _textField(
                          _judgeUserPromptTemplateCtrl,
                          '用户提示词模板',
                          '必须保留 {{textA}}、{{textB}}，建议保留 {{jsonSchema}} 和 {{extraInstruction}}',
                          maxLines: 14,
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('各模式附加提示词'),
                      subtitle: const Text('不同模式的专项判断要求，例如严格事实、标题忠实性、候选精排。'),
                      children: [
                        for (final entry in _modeInstructionCtrls.entries)
                          _textField(
                            entry.value,
                            '${entry.key.label} 附加提示词',
                            '该模式下会填入 {{extraInstruction}}；可使用对应变量。',
                            maxLines: 10,
                          ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('内置默认提示词源码参考'),
                      subtitle: const Text('只读参考，用于对照自定义是否遗漏关键要求。'),
                      children: const [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            '默认 System Prompt：\n${SemanticConsistencyPromptDefaults.systemPrompt}\n\n默认 User Prompt Template：\n${SemanticConsistencyPromptDefaults.userPromptTemplate}',
                            style: TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _section(
                  title: 'Embedding / 多路召回配置',
                  children: [
                    DropdownButtonFormField<String>(
                      value: _embeddingProvider,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Embedding Provider'),
                      items: const [
                        DropdownMenuItem(value: 'openrouter', child: Text('OpenRouter（只用 OpenRouter Key，模型必须是 OpenRouter 上可用的 Embedding 模型）')),
                        DropdownMenuItem(value: 'edenai', child: Text('Eden AI（只用 Eden AI Key，模型使用 provider/model 格式）')),
                        DropdownMenuItem(value: 'openai', child: Text('OpenAI 直连（需要 OpenAI Key）')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _embeddingProvider = v ?? SemanticConsistencySettings.defaultEmbeddingProvider;
                          _availableEmbeddingModels = <String>[];
                          if (_embeddingProvider == 'openrouter') {
                            if (_embeddingModelCtrl.text.trim().isEmpty || _embeddingModelCtrl.text.startsWith('text-embedding-')) {
                              _embeddingModelCtrl.text = 'qwen/qwen3-embedding-4b';
                              _embeddingDimensionsCtrl.text = '2560';
                            }
                          } else if (_embeddingProvider == 'edenai') {
                            if (_embeddingModelCtrl.text.trim().isEmpty || _embeddingModelCtrl.text == 'qwen/qwen3-embedding-4b') {
                              _embeddingModelCtrl.text = 'openai/text-embedding-3-large';
                              _embeddingDimensionsCtrl.text = '3072';
                            }
                          } else if (_embeddingProvider == 'openai') {
                            if (_embeddingModelCtrl.text.startsWith('openai/')) {
                              _embeddingModelCtrl.text = _embeddingModelCtrl.text.replaceFirst('openai/', '');
                            }
                            if (_embeddingModelCtrl.text.trim().isEmpty || _embeddingModelCtrl.text.contains('/')) {
                              _embeddingModelCtrl.text = 'text-embedding-3-large';
                              _embeddingDimensionsCtrl.text = '3072';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _applyEmbeddingPreset(provider: 'openrouter', model: 'qwen/qwen3-embedding-4b', dimensions: 2560),
                          child: const Text('OpenRouter：Qwen3 Embedding 4B'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyEmbeddingPreset(provider: 'openrouter', model: 'baai/bge-m3', dimensions: 1024),
                          child: const Text('OpenRouter：BGE-M3'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyEmbeddingPreset(provider: 'edenai', model: 'cohere/embed-multilingual-v3.0', dimensions: 1024),
                          child: const Text('Eden AI：Cohere 多语言（中文推荐）'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyEmbeddingPreset(provider: 'edenai', model: 'google/gemini-embedding-001', dimensions: 3072),
                          child: const Text('Eden AI：Gemini Embedding'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyEmbeddingPreset(provider: 'edenai', model: 'openai/text-embedding-3-large', dimensions: 3072),
                          child: const Text('Eden AI：OpenAI Embedding 3 Large（通用）'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loadingEmbeddingModels ? null : _refreshEmbeddingModels,
                          icon: _loadingEmbeddingModels
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: const Text('刷新当前 Provider 可用 Embedding 模型'),
                        ),
                      ],
                    ),
                    if (_availableEmbeddingModels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _availableEmbeddingModels.contains(_embeddingModelCtrl.text.trim()) ? _embeddingModelCtrl.text.trim() : null,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '当前 Provider 返回的可用 Embedding 模型'),
                        items: _availableEmbeddingModels
                            .map((model) => DropdownMenuItem(value: model, child: Text(model, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _embeddingModelCtrl.text = v;
                            final dims = _knownEmbeddingDimensions(v);
                            if (dims != null) _embeddingDimensionsCtrl.text = dims.toString();
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    _textField(_embeddingModelCtrl, 'Embedding Model', 'OpenRouter/Eden AI 使用 provider/model；OpenAI 直连使用 text-embedding-3-large'),
                    _textField(_embeddingDimensionsCtrl, 'Embedding Dimensions', '仅对明确支持 dimensions 的模型发送；其他模型使用默认维度', keyboardType: TextInputType.number),
                  ],
                ),
                _section(
                  title: '阈值配置',
                  children: [
                    _textField(_lowThresholdCtrl, '中等多路相关阈值', '多路召回诊断默认 0.45；原生 cosine、片段命中、概念/关键词规则都会作为证据', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    _textField(_highThresholdCtrl, '高多路相关阈值', '默认 0.65；不要把该阈值理解为严格等价阈值，严格判断请使用 LLM 精判', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    _textField(_strictThresholdCtrl, '严格一致阈值', '保留给严格模式参考，默认 0.80', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 6),
                    const Text('提示：原生 Embedding 余弦会单独显示，仅表示向量空间/语义场接近度，不代表同义或最终判断。通用语义关系精判会额外输出语义相关度、同义/等价度、覆盖度、局部最高匹配和关系类型，用于覆盖概念—实例、外延、表现、效果、句段篇章局部匹配等情况。', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                  ],
                ),
                _section(
                  title: '标题/摘要忠实性',
                  children: [
                    _textField(_titleEvidenceTopKCtrl, '证据段落 TopK', '从文章切片中选多少段给模型判断，默认 5', keyboardType: TextInputType.number),
                  ],
                ),
                _section(
                  title: 'Reranker 精排配置（默认关闭）',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _enableReranker,
                      onChanged: (v) => setState(() => _enableReranker = v),
                      title: const Text('启用 Reranker'),
                      subtitle: const Text('只建议在大量候选文本排序时启用，短句一对一判断不需要。'),
                    ),
                    _textField(_rerankerProviderCtrl, 'Reranker Provider', '当前内置 Cohere'),
                    _textField(_rerankerModelCtrl, 'Reranker Model', '默认 rerank-v3.5'),
                    _textField(_rerankerEndpointCtrl, 'Reranker Endpoint', '默认 https://api.cohere.com/v2/rerank'),
                    _textField(_rerankerApiKeyCtrl, 'Reranker API Key', 'Cohere / 兼容服务 API Key', obscureText: true),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('保存配置'),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: const Text(
        '本模块已升级为“原生 Embedding 参考 → 多路召回诊断 → 多粒度语义关系精判 → 可选结构化事实抽取 / Reranker”的分层方案。原生 Embedding cosine 会单独保留，定位为语义场接近度参考；最终判断会区分语义相关度、同义/等价度、覆盖度、局部最高证据、关系类型和匹配范围，支持概念/句子/段落/文章之间的概念—实例、外延、表现、效果、因果、局部命中、全文相关和方向相反等关系。Embedding Provider 与模型分离配置：OpenRouter 只用 OpenRouter Key，Eden AI 只用 Eden AI Key，OpenAI 直连才需要 OpenAI Key。LLM Judge 的系统提示词、用户提示词模板和各模式附加提示词均可在本页自定义，并可一键恢复默认。',
        style: TextStyle(height: 1.45),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscureText = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
        minLines: obscureText ? 1 : (maxLines > 1 ? 4 : 1),
        maxLines: obscureText ? 1 : maxLines,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}

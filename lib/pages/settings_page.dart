import '../diary/diary_settings_page.dart';
import 'package:path/path.dart' as p;
import '../services/sport_music_service.dart';
import '../services/youtube_music_service.dart';
import '../services/open_music_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

import 'package:quote_app/services/native_am.dart';
import 'package:quote_app/services/native_wm.dart';
import 'package:quote_app/services/native_guard.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// removed duplicate import of path_provider
// 用于选择和上传量表 Excel 模板文件
import 'package:file_picker/file_picker.dart';

// Import http for fetching DeepSeek model list. We keep this import scoped
// here rather than in a shared service since settings page performs
// configuration loading and saving directly.
import 'package:http/http.dart' as http;
import 'dart:convert';

// 导入量表数据和自动报告配置相关的 DAO
import '../data/scale_dao.dart';

import '../data/dao.dart';
import '../data/kv_dao.dart';
import '../services/scheduler_service.dart';
import '../utils/debug_logger.dart';
import '../utils/deepseek_logger.dart';
import '../concept_engine/concept_engine_service.dart';
import '../services/azure_ai_settings.dart';
import '../services/global_ai_settings.dart';
import '../services/global_ai_request_settings.dart';
import '../services/unified_ai_service.dart';
import 'ai_prompt_settings_page.dart';
import '../movie_role_lab/movie_role_lab_settings_page.dart';
import '../voice_lab/voice_lab_home_page.dart';
import '../semantic_consistency/semantic_consistency_settings_page.dart';
import '../health_diet/pages/health_diet_settings_page.dart';
import '../kindling_host/kindling_host_reminder.dart';
import '../services/notification_service.dart';
// removed duplicate import of native_guard (already imported above)

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _configDao = ConfigDao();
  final _taskDao = TaskDao();
  final _kvDao = KeyValueDao();
  final _conceptEngineService = ConceptEngineService();
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final GlobalAiRequestSettings _globalAiRequestSettings = GlobalAiRequestSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _endpointCtrl = TextEditingController();
  final _recentHoursCtrl = TextEditingController();
  final _overviewThresholdCtrl = TextEditingController();
  final _moodCardDelayMsCtrl = TextEditingController();

  // TMDb movie token controller. Holds the user configured read access token.
  final _movieTokenCtrl = TextEditingController();
  final _youtubeApiKeyCtrl = TextEditingController();
  final _jamendoClientIdCtrl = TextEditingController();
  final _kugouAppIdCtrl = TextEditingController();
  final _kugouAppKeyCtrl = TextEditingController();

  // DeepSeek configuration controllers and state. The DeepSeek API key
  // allows translation via the DeepSeek chat completion API. Users can
  // configure both the API key and choose a specific model from the
  // available DeepSeek models. These values are persisted in the
  // configs table via ConfigDao. When empty, DeepSeek translation is
  // effectively disabled and the app falls back to other translation
  // providers.
  final _deepseekKeyCtrl = TextEditingController();
  final _openRouterKeyCtrl = TextEditingController();
  final _edenAiKeyCtrl = TextEditingController();
  final _xGrokKeyCtrl = TextEditingController();
  final _geminiKeyCtrl = TextEditingController();
  // Azure / Microsoft Foundry 支持同时接入多个资源（项目），因此这里保存的是一张
  // 资源表而不是单个密钥；每个资源单独维护终结点、密钥、api-version 和部署名。
  final AzureAiSettings _azureAiSettings = AzureAiSettings();
  List<AzureAiResource> _azureResources = <AzureAiResource>[];
  // 上一次 Azure 模型列举的失败原因。Azure 终结点写法很多，填错时表现就是一串
  // 404，这里直接展示原因，免得用户只看到一个空的模型下拉框。
  List<String> _azureModelDiagnostics = <String>[];
  // 概念实践引擎配置（复用上方 DeepSeek 密钥）
  final _ceModelCtrl = TextEditingController();
  final _ceEndpointCtrl = TextEditingController();
  final _ceTimeoutCtrl = TextEditingController();
  final _ceSceneCountCtrl = TextEditingController();
  final _ceTurnTargetCtrl = TextEditingController();
  final _ceProxyEndpointCtrl = TextEditingController();
  final _ceProxyTokenCtrl = TextEditingController();
  final _cePromptExtraCtrl = TextEditingController();
  final _cePromptParseCtrl = TextEditingController();
  final _cePromptSceneCtrl = TextEditingController();
  final _cePromptTurnCtrl = TextEditingController();
  final _cePromptReplayCtrl = TextEditingController();
  final _cePromptBehaviorChainCtrl = TextEditingController();
  final _ceParseMinIntuitiveCtrl = TextEditingController();
  final _ceParseMinBehaviorsCtrl = TextEditingController();
  final _ceParseRetryCountCtrl = TextEditingController();
  final _ceBehaviorChainMinNodesCtrl = TextEditingController();
  final _ceBehaviorChainMaxNodesCtrl = TextEditingController();
  final _ceParseMaxTokensCtrl = TextEditingController();
  final _ceSceneMaxTokensCtrl = TextEditingController();
  final _ceTurnMaxTokensCtrl = TextEditingController();
  final _ceReplayMaxTokensCtrl = TextEditingController();
  final _ceBehaviorChainMaxTokensCtrl = TextEditingController();
  final _globalAiModelCtrl = TextEditingController();
  final _goalSettingPromptCtrl = TextEditingController();
  final _goalSettingActionPromptCtrl = TextEditingController();
  final _goalSettingLoopPromptCtrl = TextEditingController();
  final _globalTimeoutCtrl = TextEditingController();
  final _globalMaxTokensCtrl = TextEditingController();
  final _globalTemperatureCtrl = TextEditingController();
  final _globalTopPCtrl = TextEditingController();
  final _globalRetryCountCtrl = TextEditingController();
  final _globalRetryDelayMsCtrl = TextEditingController();
  String _ceProvider = 'deepseek';
  String _globalAiProvider = 'deepseek';
  String _globalAiModelRaw = '';
  String _ceTransportMode = ConceptEngineService.transportDirect;
  bool _checkingCeGateway = false;
  String? _ceGatewayCheckMessage;
  bool? _ceGatewayCheckOk;
  // List of available DeepSeek models fetched from the DeepSeek /models
  // endpoint. When the key is invalid or models cannot be fetched,
  // this list may remain empty.
  List<String> _deepseekModels = <String>[];
  // Currently selected DeepSeek model. Defaults to 'deepseek-v4-pro'.
  String _selectedDeepseekModel = 'deepseek-v4-pro';
  // Whether the DeepSeek models list is being loaded.
  bool _loadingDeepseek = false;
  bool _loadingGlobalAiModels = false;
  List<String> _globalAiModels = <String>[];

  // ====== 量表自动报告与模板导入 ======
  // 是否启用量表自动报告
  bool _autoReportEnabled = false;
  // 正在加载自动报告状态标记
  bool _loadingAutoReport = true;
  // 已选择的 Excel 模板文件
  PlatformFile? _selectedExcelFile;
  // 已选择文件的名称，用于界面展示
  String? _selectedFileName;

  bool _editingConfig = false;
  List<Map<String, dynamic>> _tasks = [];

  // ====== EMA / SSES 设置 ======
  // 是否启用 EMA / SSES 自尊问答
  bool _emaEnabled = false;
  // 自尊评分尺度：100 或 30
  int _esteemScale = 100;

  bool _moodCardPopupEnabled = true;
  // 火种：「说不准」7 天后的复问通知，方案规定默认关。
  bool _kindlingReaskNotifyEnabled = false;
  bool _drawerHeaderAiEnabled = false;

  // ====== 运动设置 ======
  String? _sportBgPath;
  String? _sportSoundPath;
  List<String> _sportMusicList = <String>[];
  Map<String, List<String>> _sportMusicBgBindings = <String, List<String>>{};
  String _sportMusicMode = 'order'; // order / random

  /// 选择量表 Excel 文件
  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedExcelFile = result.files.first;
          _selectedFileName = _selectedExcelFile?.name;
        });
      }
    } catch (e) {
      // 弹出错误提示
      showToast('选择文件失败: ${e.toString()}');
    }
  }

  /// 导入量表 Excel 模板
  Future<void> _importExcel() async {
    if (_selectedExcelFile == null) {
      showToast('请选择 Excel 文件');
      return;
    }
    final ext = _selectedExcelFile!.extension?.toLowerCase();
    if (ext != 'xlsx') {
      showToast('仅支持导入 .xlsx 格式的文件');
      return;
    }
    final path = _selectedExcelFile!.path;
    if (path == null || path.isEmpty) {
      showToast('无法读取文件路径');
      return;
    }
    try {
      final file = File(path);
      final dao = ScaleDao();
      await dao.importFromExcel(file);
      showToast('导入成功');
      // 导入成功后清空选择的文件，刷新量表列表时可在测评中心看到
      setState(() {
        _selectedExcelFile = null;
        _selectedFileName = null;
      });
    } catch (e) {
      showToast('导入失败: ${e.toString()}');
    }
  }



  Widget _promptConfigSection({
    required String title,
    required TextEditingController controller,
    required String defaultPrompt,
    required List<MapEntry<String, String>> placeholders,
    required String hintText,
    required VoidCallback onReset,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          '可编辑部分：下方“当前模板”文本框中的内容。你可以整体改写提示词，也可以在模板中调整占位符出现的位置。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('当前模板（可修改）', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                enabled: _editingConfig,
                minLines: 8,
                maxLines: 16,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hintText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _editingConfig ? onReset : null,
                    icon: const Icon(Icons.restore),
                    label: const Text('恢复源码默认模板'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('系统自动填充参数（占位符）', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                '下面这些是系统会从课程原文、行动、事实记录、结果等数据中自动同步进提示词的参数。建议保留这些占位符；即使删掉关键项，系统也会自动补齐必要上下文。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              ...placeholders.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey.shade100),
                          ),
                          child: SelectableText(
                            entry.key,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(entry.value, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('源码中的默认完整提示词（只读）', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText(
                defaultPrompt,
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, String>> _goalUnderstandingPromptParams() => const [
        MapEntry('{{segment_title}}', '当前课程段落标题，由系统从课程原文库同步。'),
        MapEntry('{{original_text}}', '该段完整课程原文，由系统从课程原文库同步。'),
      ];

  List<MapEntry<String, String>> _goalActionPromptParams() => const [
        MapEntry('{{segment_title}}', '当前课程段落标题。'),
        MapEntry('{{original_text}}', '该段完整课程原文。'),
        MapEntry('{{core_concepts}}', '系统提取的本段核心概念。'),
        MapEntry('{{default_action_title}}', '当前默认行动标题。'),
        MapEntry('{{default_action_body}}', '当前默认行动说明。'),
        MapEntry('{{how_steps}}', '系统整理的课程建议步骤。'),
        MapEntry('{{user_concern}}', '用户在行动页输入的当前真实困扰。'),
      ];

  List<MapEntry<String, String>> _goalLoopPromptParams() => const [
        MapEntry('{{analysis_input_json}}', '完整结构化输入 JSON。默认闭环模板主要使用这个占位符；若保留它，系统会把课程、行动、本轮记录、历史闭环等上下文一次性注入。'),
        MapEntry('{{segment_title}}', '当前课程段落标题。'),
        MapEntry('{{original_text}}', '该段完整课程原文。'),
        MapEntry('{{action_title}}', '当前行动标题。'),
        MapEntry('{{action_body}}', '当前行动说明。'),
        MapEntry('{{action_steps}}', '当前行动链 / 行动步骤。'),
        MapEntry('{{behavior_chain}}', '行为链提示。'),
        MapEntry('{{success_criteria}}', '完成标准。'),
        MapEntry('{{fallback_action}}', '降级方案。'),
        MapEntry('{{action_status}}', '当前行动状态。'),
        MapEntry('{{latest_fact}}', '最新一次已保存事实。'),
        MapEntry('{{latest_feedback}}', '最新一次已保存反馈。'),
        MapEntry('{{latest_result}}', '最新一次已保存结果。'),
        MapEntry('{{current_records}}', '当前行动下已保存的事实记录、反馈与结果（文本版）。'),
        MapEntry('{{historical_closed_loops}}', '同课程同行动且已成功生成 AI 闭环总结的历史闭环记录（JSON 版）。'),
        MapEntry('{{fact_records}}', '历史事实记录与反馈（JSON 版），由后端 / 本地缓存同步提供。'),
      ];
  @override
  void initState() {
    super.initState();
    // 监听设置页刷新 bus，在切换到设置页或数据变更时刷新配置和任务列表
    SimpleBus.settingsTick.addListener(_onBus);
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _endpointCtrl.dispose();
    _recentHoursCtrl.dispose();
    _overviewThresholdCtrl.dispose();
    _moodCardDelayMsCtrl.dispose();
    _movieTokenCtrl.dispose();
    _youtubeApiKeyCtrl.dispose();
    _jamendoClientIdCtrl.dispose();
    _kugouAppIdCtrl.dispose();
    _kugouAppKeyCtrl.dispose();
    _deepseekKeyCtrl.dispose();
    _openRouterKeyCtrl.dispose();
    _edenAiKeyCtrl.dispose();
    _xGrokKeyCtrl.dispose();
    _geminiKeyCtrl.dispose();
    _ceModelCtrl.dispose();
    _ceEndpointCtrl.dispose();
    _ceTimeoutCtrl.dispose();
    _ceSceneCountCtrl.dispose();
    _ceTurnTargetCtrl.dispose();
    _ceProxyEndpointCtrl.dispose();
    _ceProxyTokenCtrl.dispose();
    _cePromptExtraCtrl.dispose();
    _cePromptParseCtrl.dispose();
    _cePromptSceneCtrl.dispose();
    _cePromptTurnCtrl.dispose();
    _cePromptReplayCtrl.dispose();
    _cePromptBehaviorChainCtrl.dispose();
    _ceParseMinIntuitiveCtrl.dispose();
    _ceParseMinBehaviorsCtrl.dispose();
    _ceParseRetryCountCtrl.dispose();
    _ceBehaviorChainMinNodesCtrl.dispose();
    _ceBehaviorChainMaxNodesCtrl.dispose();
    _ceParseMaxTokensCtrl.dispose();
    _ceSceneMaxTokensCtrl.dispose();
    _ceTurnMaxTokensCtrl.dispose();
    _ceReplayMaxTokensCtrl.dispose();
    _ceBehaviorChainMaxTokensCtrl.dispose();
    _globalAiModelCtrl.dispose();
    _goalSettingPromptCtrl.dispose();
    _goalSettingActionPromptCtrl.dispose();
    _goalSettingLoopPromptCtrl.dispose();
    _globalTimeoutCtrl.dispose();
    _globalMaxTokensCtrl.dispose();
    _globalTemperatureCtrl.dispose();
    _globalTopPCtrl.dispose();
    _globalRetryCountCtrl.dispose();
    _globalRetryDelayMsCtrl.dispose();

    // 移除监听，避免在页面销毁后回调
    SimpleBus.settingsTick.removeListener(_onBus);
    super.dispose();
  }

  /// 当接收到设置页刷新通知时重新加载配置和任务数据
  void _onBus() {
    _load();
  }

  
  Future<void> _reloadTasksAfterSave() async {
    _tasks = await _taskDao.all();
      if (mounted) setState(() {});
    
  }

  Widget _aiPromptCenterEntry() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI 提示词统一配置中心', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            '真实积极行动系统、ActionMind、WOOP 行动引擎、第二念、向内生长 MI、足下真实自我、认知一致性、可持续卓越实验室的全局价值层/场景层/输出格式，以及目标训练、人生注解、电影角色实验室、发现之旅/看电影、首页侧栏等提示词都会集中到这里。进入后先选择模块，再选择 AI 子功能，即可查看默认模板、系统参数，并自由修改、恢复默认或导入导出。',
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.45),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiPromptSettingsPage()),
              );
              await _load();
            },
            icon: const Icon(Icons.tune),
            label: const Text('打开提示词配置中心'),
          ),
        ],
      ),
    );
  }

void showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  static const List<String> _officialDeepseekModels = <String>[
    'deepseek-v4-pro',
    'deepseek-v4-flash',
    'deepseek-chat',
    'deepseek-reasoner',
  ];

  String _normalizeDeepseekUiModel(String model) {
    final m = model.trim();
    if (m.isEmpty || m == 'deepseek-chat' || m == 'deepseek-reasoner') {
      return 'deepseek-v4-pro';
    }
    return m;
  }

  /// Fetch the list of available DeepSeek models from the DeepSeek API.
  ///
  /// Requires that a non‑empty API key has been entered. When the key is
  /// missing, this method clears the models list. Errors during fetch
  /// are silently ignored; the list remains unchanged in that case.
  Future<void> _fetchDeepseekModels() async {
    final key = _deepseekKeyCtrl.text.trim();
    if (key.isEmpty) {
      // No key: clear models and return.
      if (mounted) {
        setState(() {
          _deepseekModels = List<String>.from(_officialDeepseekModels);
        });
      }
      return;
    }
    // Mark as loading while fetching.
    if (mounted) {
      setState(() {
        _loadingDeepseek = true;
      });
    }
    try {
      http.Response? res;
      // DeepSeek provides an OpenAI-compatible Models API. Some environments
      // use /models, others use /v1/models. Try both.
      final endpoints = <String>[
        'https://api.deepseek.com/models',
        'https://api.deepseek.com/v1/models',
      ];
      for (final ep in endpoints) {
        try {
          final uri = Uri.parse(ep);
          final headers = {'Authorization': 'Bearer $key'};
          await DeepSeekLogger.logRequest(
            module: 'settings.models',
            endpoint: ep,
            headers: headers,
            body: const {'action': 'list_models'},
            method: 'GET',
            model: 'models/list',
          );
          final r = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          await DeepSeekLogger.logResponse(
            module: 'settings.models',
            endpoint: ep,
            statusCode: r.statusCode,
            body: r.body,
            model: 'models/list',
          );
          if (r.statusCode == 200) {
            res = r;
            break;
          }
        } catch (e, st) {
          await DeepSeekLogger.logError(
            module: 'settings.models',
            endpoint: ep,
            error: e,
            stackTrace: st,
            model: 'models/list',
          );
          // try next endpoint
        }
      }
      if (res == null || res.statusCode != 200) {
        // Ensure UI updates even on failure.
        if (mounted) {
          setState(() {
            _deepseekModels = List<String>.from(_officialDeepseekModels);
          });
        }
        return;
      }

      final decoded = jsonDecode(res.body);
      // The response may have a 'data' or 'models' key with a list of
      // model objects or simple strings. We normalize to a list of names.
      List<dynamic>? list;
      if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is List) {
          list = decoded['data'] as List<dynamic>;
        } else if (decoded['models'] is List) {
          list = decoded['models'] as List<dynamic>;
        }
      } else if (decoded is List) {
        list = decoded;
      }
      final models = <String>[];
      if (list != null) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            // Use 'id' or 'model' or 'name' as model identifier.
            final v = item['id'] ?? item['model'] ?? item['name'];
            if (v != null) {
              final name = v.toString().trim();
              if (name.isNotEmpty) {
                models.add(name);
              }
            }
          } else if (item is String) {
            final name = item.trim();
            if (name.isNotEmpty) models.add(name);
          }
        }
      }
      // De-duplicate while keeping stable order.
      final uniq = <String>[];
      final seen = <String>{};
      for (final m in _officialDeepseekModels) {
        if (seen.add(m)) uniq.add(m);
      }
      for (final m in models) {
        if (seen.add(m)) uniq.add(m);
      }
      if (mounted) {
        setState(() {
          _deepseekModels = uniq;
          if (_deepseekModels.isNotEmpty && !_deepseekModels.contains(_selectedDeepseekModel)) {
            _selectedDeepseekModel = _officialDeepseekModels.first;
          }
        });
      }
    } catch (_) {
      // Ignore errors: don't update models on failure.
    } finally {
      if (mounted) {
        setState(() {
          _loadingDeepseek = false;
        });
      }
    }
  }


  Future<void> _fetchGlobalAiModels() async {
    if (mounted) {
      setState(() {
        _loadingGlobalAiModels = true;
      });
    }
    // 允许用户刚填完密钥后直接刷新模型列表；这里会先同步当前输入框中的密钥，保证
    // OpenAI / DeepSeek / OpenRouter / Eden AI / xGrok / Gemini / Azure 的模型列表加载都读取设置页最新值。
    final provider = _normalizeProviderKey(_globalAiProvider);
    try {
      if (provider == 'edenai') {
        await _globalAiSettings.setEdenAiKey(_edenAiKeyCtrl.text.trim());
      } else if (provider == 'xgrok') {
        await _globalAiSettings.setXGrokKey(_xGrokKeyCtrl.text.trim());
      } else if (provider == 'gemini') {
        await _globalAiSettings.setGeminiKey(_geminiKeyCtrl.text.trim());
      } else if (provider == 'azure') {
        // Azure 的模型列举需要读取每个资源的终结点与密钥，所以先落盘当前编辑中的资源表。
        await _azureAiSettings.saveResources(_azureResources);
        _azureResources = await _azureAiSettings.listResources();
      } else if (provider == 'openrouter') {
        await _configDao.setOpenRouterKey(_openRouterKeyCtrl.text.trim());
      } else if (provider == 'deepseek') {
        await _configDao.setDeepseekKey(_deepseekKeyCtrl.text.trim());
      } else if (provider == 'openai') {
        await _configDao.save(
          apiKey: _apiKeyCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          endpoint: _endpointCtrl.text.trim(),
        );
      }
      final List<String> models;
      final List<String> diagnostics;
      if (provider == 'azure') {
        final discovery = await _unifiedAiService.discoverAzureModels();
        models = discovery.models;
        diagnostics = discovery.diagnostics;
      } else {
        models = await _unifiedAiService.fetchAvailableModels(_globalAiProvider);
        diagnostics = <String>[];
      }
      if (!mounted) return;
      setState(() {
        _globalAiModels = models;
        _azureModelDiagnostics = diagnostics;
        if (_globalAiModels.isNotEmpty) {
          final preferred = _globalAiModelRaw.trim();
          if (!_globalAiModels.contains(preferred)) {
            _globalAiModelRaw = _globalAiModels.first;
          }
          _globalAiModelCtrl.text = _formatGlobalAiModelDisplay(_globalAiProvider, _globalAiModelRaw);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _globalAiModels = <String>[];
        _azureModelDiagnostics = provider == 'azure' ? <String>['模型列举失败：$e'] : <String>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGlobalAiModels = false;
        });
      }
    }
  }

  // ====== Sport settings helpers ======
  Future<List<String>> _pickSportBgImagesFromGallery() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: false,
      );
      if (res == null || res.files.isEmpty) return <String>[];
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(dir.path, 'sport_music_bg'));
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      final List<String> results = <String>[];
      for (final f in res.files) {
        final src = f.path;
        if (src == null || src.isEmpty) continue;
        final ext = p.extension(src).isEmpty ? '.jpg' : p.extension(src);
        final base = p.basenameWithoutExtension(src);
        final ts = DateTime.now().microsecondsSinceEpoch;
        final dst = p.join(outDir.path, 'bg_${ts}_$base$ext');
        await File(src).copy(dst);
        results.add(dst);
      }
      return results;
    } catch (_) {
      return <String>[];
    }
  }

  Future<String?> _pickSingleSportBgImage() async {
    final list = await _pickSportBgImagesFromGallery();
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<void> _manageSportMusicBgBindings() async {
    if (_sportMusicList.isEmpty) {
      showToast('请先设置运动进行时音乐');
      return;
    }
    final Map<String, List<String>> working = <String, List<String>>{};
    for (final music in _sportMusicList) {
      working[music] = List<String>.from(_sportMusicBgBindings[music] ?? const <String>[]);
    }

    Future<void> persistBindings() async {
      final cleaned = <String, List<String>>{};
      for (final music in _sportMusicList) {
        cleaned[music] = List<String>.from(working[music] ?? const <String>[]);
      }
      await _configDao.setSportMusicBgBindings(cleaned);
      if (!mounted) return;
      setState(() {
        _sportMusicBgBindings = cleaned;
      });
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setD) {
            return AlertDialog(
              title: const Text('管理音乐背景图绑定'),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: ListView.separated(
                  itemCount: _sportMusicList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final music = _sportMusicList[index];
                    final imgs = working[music] ?? <String>[];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.basename(music), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(imgs.isEmpty ? '未设置背景图片，运行时将恢复默认背景色' : '已绑定 ${imgs.length} 张背景图', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final picked = await _pickSportBgImagesFromGallery();
                                  if (picked.isEmpty) {
                                    showToast('未选择背景图');
                                    return;
                                  }
                                  setD(() {
                                    imgs.addAll(picked);
                                    working[music] = imgs;
                                  });
                                },
                                child: const Text('添加背景图'),
                              ),
                              if (imgs.isNotEmpty)
                                TextButton(
                                  onPressed: () async {
                                    final replaced = await _pickSportBgImagesFromGallery();
                                    if (replaced.isEmpty) return;
                                    setD(() {
                                      working[music] = List<String>.from(replaced);
                                    });
                                  },
                                  child: const Text('替换全部'),
                                ),
                              if (imgs.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setD(() {
                                      working[music] = <String>[];
                                    });
                                  },
                                  child: const Text('清空背景图'),
                                ),
                            ],
                          ),
                          if (imgs.isNotEmpty)
                            ...imgs.asMap().entries.map((entry) {
                              final i = entry.key;
                              final img = entry.value;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(p.basename(img), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('第 ${i + 1} 张', style: const TextStyle(fontSize: 12)),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        final replacement = await _pickSingleSportBgImage();
                                        if (replacement == null || replacement.isEmpty) return;
                                        setD(() {
                                          imgs[i] = replacement;
                                          working[music] = List<String>.from(imgs);
                                        });
                                      },
                                      child: const Text('修改'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setD(() {
                                          imgs.removeAt(i);
                                          working[music] = List<String>.from(imgs);
                                        });
                                      },
                                      child: const Text('删除'),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('取消')),
                FilledButton(
                  onPressed: () async {
                    await persistBindings();
                    if (!mounted) return;
                    Navigator.pop(ctx2);
                    showToast('已保存音乐与背景图绑定');
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickSportStartSound() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3','wav','ogg','m4a','aac','flac','opus','caf','aiff','aif','amr','3gp','mp4'],
        withData: false,
      );
      if (res == null || res.files.isEmpty) return;
      final src = res.files.first.path;
      if (src == null || src.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(src).isEmpty ? '.mp3' : p.extension(src);
      final dst = p.join(dir.path, 'sport_start_sound$ext');
      await File(src).copy(dst);
      await _configDao.setSportStartSound(dst);
      if (!mounted) return;
      setState(() { _sportSoundPath = dst; });
      showToast('已设置运动开始铃声');
    } catch (_) {
      showToast('选择铃声失败');
    }
  }

  Future<void> _clearSportStartSound() async {
    try {
      await _configDao.setSportStartSound('');
      if (!mounted) return;
      setState(() { _sportSoundPath = null; });
      showToast('已恢复默认铃声');
    } catch (_) {
      showToast('清除失败');
    }
  }

  Future<void> _pickSportMusicPlaylist() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['mp3','wav','ogg','m4a','aac','flac','opus','caf','aiff','aif','amr','3gp','mp4'],
        withData: false,
      );
      if (res == null || res.files.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(dir.path, 'sport_music'));
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      final List<String> dstList = [];
      for (final f in res.files) {
        final src = f.path;
        if (src == null || src.isEmpty) continue;
        final ext = p.extension(src).isEmpty ? '.mp3' : p.extension(src);
        final base = p.basenameWithoutExtension(src);
        final ts = DateTime.now().millisecondsSinceEpoch;
        final dst = p.join(outDir.path, 'music_${ts}_$base$ext');
        await File(src).copy(dst);
        dstList.add(dst);
      }
      // Append to existing list (avoid duplicates)
      final merged = <String>[..._sportMusicList];
      for (final x in dstList) {
        if (!merged.contains(x)) merged.add(x);
      }
      final bindings = <String, List<String>>{};
      for (final music in merged) {
        bindings[music] = List<String>.from(_sportMusicBgBindings[music] ?? const <String>[]);
      }
      await _configDao.setSportMusicPlaylist(merged);
      await _configDao.setSportMusicBgBindings(bindings);
      await SportMusicService.instance.applySettings(playlist: merged);
      if (!mounted) return;
      setState(() {
        _sportMusicList = merged;
        _sportMusicBgBindings = bindings;
      });
      showToast('已更新运动播放清单');
    } catch (_) {
      showToast('选择音乐失败');
    }
  }

  Future<void> _manageSportMusicPlaylist() async {
  if (_sportMusicList.isEmpty) return;
  final List<String> working = List<String>.from(_sportMusicList);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx2, setD) {
          return AlertDialog(
            title: const Text('管理播放清单'),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: ReorderableListView(
                buildDefaultDragHandles: true,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex -= 1;
                  if (oldIndex < 0 || oldIndex >= working.length) return;
                  if (newIndex < 0 || newIndex > working.length) return;
                  final item = working.removeAt(oldIndex);
                  working.insert(newIndex, item);
                  setD(() {});
                },
                children: [
                  for (int i = 0; i < working.length; i++)
                    ListTile(
                      key: ValueKey(working[i]),
                      title: Text(p.basename(working[i])),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          if (i < 0 || i >= working.length) return;
                          working.removeAt(i);
                          setD(() {});
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx2).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _configDao.setSportMusicPlaylist(working);
                              await SportMusicService.instance.applySettings(playlist: working);
                    if (!mounted) return;
                    setState(() {
                      _sportMusicList = List<String>.from(working);
                    });
                    showToast('已保存播放清单');
                  } catch (_) {
                    showToast('保存失败');
                  }
                  if (Navigator.of(ctx2).canPop()) {
                    Navigator.of(ctx2).pop();
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _clearSportMusicPlaylist() async {
    try {
      await _configDao.setSportMusicPlaylist(<String>[]);
      await _configDao.setSportMusicBgBindings(<String, List<String>>{});
      await SportMusicService.instance.applySettings(playlist: <String>[]);
      if (!mounted) return;
      setState(() {
        _sportMusicList = <String>[];
        _sportMusicBgBindings = <String, List<String>>{};
      });
      showToast('已清空播放清单');
    } catch (_) {
      showToast('清除失败');
    }
  }

  Future<void> _setSportMusicMode(String mode) async {
    final val = (mode == 'random') ? 'random' : 'order';
    try {
      await _configDao.setSportMusicMode(val);
      await SportMusicService.instance.applySettings(mode: val);
      if (!mounted) return;
      setState(() {
        _sportMusicMode = val;
      });
      showToast('已更新播放模式');
    } catch (_) {
      // ignore
    }
  }

  /// Compute the next run time for the given task map.
  /// This replicates the logic of SchedulerService._computeNextRun so that we
  /// always cancel alarms based on the latest future trigger, rather than a
  /// possibly stale next_time stored in the database. If next_time is valid
  /// and in the future, it is used directly. Otherwise we derive the next
  /// run from start_time, freq_type, freq_weekday and freq_day_of_month.
  DateTime? _computeNextRunFor(Map<String, dynamic> t) {
    final now = DateTime.now();
    // Prefer next_time if it exists and is in the future.
    try {
      final raw = (t['next_time'] ?? '').toString();
      if (raw.isNotEmpty) {
        final dt = DateTime.tryParse(raw);
        if (dt != null && dt.isAfter(now.subtract(const Duration(seconds: 10)))) {
          return dt;
        }
      }
    } catch (_) {}
    // Parse start_time which may be HH:mm or absolute date time string
    String start = (t['start_time'] ?? '09:00').toString().trim();
    if (start.isEmpty) start = '09:00';
    DateTime? absDt;
    int hh = 9, mm = 0;
    // absolute date-time, e.g., 2025-10-25 10:05 or 2025-10-25 10:05:00
    final reAbs = RegExp(r'^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?\$');
    if (reAbs.hasMatch(start)) {
      try {
        // replace space with 'T' to parse ISO-like string
        final s = start.replaceFirst(' ', 'T');
        absDt = DateTime.parse(s);
        hh = absDt.hour;
        mm = absDt.minute;
      } catch (_) {
        absDt = null;
      }
    } else {
      final m = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(start);
      if (m != null) {
        hh = int.tryParse(m.group(1) ?? '') ?? 9;
        mm = int.tryParse(m.group(2) ?? '') ?? 0;
      }
    }
    // Determine frequency type; treat manual/empty/null as daily
    String freqType = (t['freq_type'] ?? 'daily').toString();
    if (freqType.isEmpty || freqType == 'null' || freqType == 'manual') {
      freqType = 'daily';
    }
    final int? weekDay = t['freq_weekday'] is int ? t['freq_weekday'] as int : null;
    final int? dayOfMonth = t['freq_day_of_month'] is int ? t['freq_day_of_month'] as int : null;
    // If start_time is an absolute future date-time, use it
    if (absDt != null && absDt.isAfter(now)) {
      return absDt;
    }
    // Weekly frequency
    if (freqType == 'weekly' && weekDay != null) {
      final wd = weekDay;
      int delta = (wd - now.weekday) % 7;
      var cand = DateTime(now.year, now.month, now.day, hh, mm).add(Duration(days: delta));
      if (!cand.isBefore(now)) {
        return cand;
      }
      return cand.add(const Duration(days: 7));
    }
    // Monthly frequency
    if (freqType == 'monthly' && dayOfMonth != null) {
      final d = dayOfMonth.clamp(1, 31);
      int y = now.year;
      int mth = now.month;
      int end = DateTime(y, mth + 1, 0).day;
      var cand = DateTime(y, mth, d.clamp(1, end), hh, mm);
      if (!cand.isBefore(now)) {
        return cand;
      }
      mth += 1;
      end = DateTime(y, mth + 1, 0).day;
      return DateTime(y, mth, d.clamp(1, end), hh, mm);
    }
    // Default daily frequency
    final today = DateTime(now.year, now.month, now.day, hh, mm);
    if (!today.isBefore(now)) {
      return today;
    }
    return today.add(const Duration(days: 1));
  }

  /// Read the next run time (milliseconds) directly from the database for the given task uid.
  /// Returns null if next_time is not present or cannot be parsed.  This helper is used
  /// when cancelling alarms to ensure we always use the latest persisted next_time rather
  /// than recomputing it or using a stale in-memory value.

  String _defaultCeModelForProvider(String provider) {
    if (provider == 'openai') {
      final m = _modelCtrl.text.trim();
      return m.isEmpty ? 'gpt-5' : m;
    }
    if (provider == 'openrouter') {
      return _globalAiModelRaw.trim().isEmpty ? 'openai/gpt-4.1-mini' : _globalAiModelRaw.trim();
    }
    if (provider == 'edenai') {
      return _globalAiModelRaw.trim().isEmpty ? GlobalAiSettings.edenAiDefaultModel : _globalAiModelRaw.trim();
    }
    if (provider == 'xgrok') {
      return _globalAiModelRaw.trim().isEmpty ? GlobalAiSettings.xGrokDefaultModel : _globalAiModelRaw.trim();
    }
    if (provider == 'gemini') {
      return _globalAiModelRaw.trim().isEmpty ? GlobalAiSettings.geminiDefaultModel : _globalAiModelRaw.trim();
    }
    if (provider == 'azure') {
      // Azure 没有内置默认模型：可用模型完全取决于用户在各资源里部署了什么。
      return _globalAiModelRaw.trim();
    }
    return 'deepseek-v4-pro';
  }

  String _defaultCeEndpointForProvider(String provider) {
    if (provider == 'openai') {
      final ep = _endpointCtrl.text.trim();
      return ep.isEmpty ? 'https://api.openai.com/v1/responses' : ep;
    }
    if (provider == 'openrouter') {
      return UnifiedAiService.openRouterEndpoint;
    }
    if (provider == 'edenai') {
      return UnifiedAiService.edenAiChatCompletionsEndpoint;
    }
    if (provider == 'xgrok') {
      return UnifiedAiService.xGrokChatCompletionsEndpoint;
    }
    if (provider == 'gemini') {
      return UnifiedAiService.geminiChatCompletionsEndpoint;
    }
    if (provider == 'azure') {
      return _azureChatEndpointPreview();
    }
    return 'https://api.deepseek.com/chat/completions';
  }

  /// Azure 的调用地址由“所选模型所属的资源 + 部署名”推导出来，这里只作展示。
  String _azureChatEndpointPreview() {
    final parts = AzureAiSettings.splitModel(_globalAiModelRaw.trim());
    if (parts.deployment.isEmpty) return '';
    final resource = _findAzureResourceByName(parts.resourceName);
    if (resource == null) return '';
    final candidates = resource.chatEndpointCandidates(parts.deployment);
    return candidates.isEmpty ? '' : candidates.first;
  }

  Widget _buildAzureResourceSection() {
    final usableCount = _azureResources.where((e) => e.enabled && e.isConfigured).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text('Azure / Microsoft Foundry 资源', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              onPressed: _editingConfig ? () => _openAzureResourceEditor() : null,
              icon: const Icon(Icons.add),
              label: const Text('添加资源'),
            ),
          ],
        ),
        const Text(
          '可以同时接入多个 Azure 资源/项目：例如一个项目部署 gpt-5.6 系列，另一个项目部署 Claude、Grok。'
          '每个资源单独填写 Microsoft Foundry 项目终结点（或 Azure OpenAI 终结点）、密钥、api-version。'
          '保存后在上方“全局 AI 提供方”里选择 Azure，再点刷新即可拉取所有资源中已部署的模型；'
          '模型以“资源名/部署名”展示，选中后全 app 的 AI 调用都会走到该模型上。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (_azureResources.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('尚未添加 Azure 资源。', style: TextStyle(color: Colors.grey)),
          )
        else
          ..._azureResources.asMap().entries.map((entry) => _buildAzureResourceTile(entry.key, entry.value)),
        const SizedBox(height: 4),
        Text(
          '当前可用资源：$usableCount 个（需同时填写终结点与密钥，且未停用）。',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAzureResourceTile(int index, AzureAiResource resource) {
    final subtitleLines = <String>[
      resource.endpoint.trim().isEmpty ? '终结点：未填写' : '终结点：${resource.endpoint.trim()}',
      '接入方式：${resource.kindLabel}｜api-version：${resource.resolvedApiVersion}',
      '密钥：${resource.apiKey.trim().isEmpty ? '未填写' : '已填写'}'
          '${resource.projectName.isEmpty ? '' : '｜项目：${resource.projectName}'}'
          '${resource.deployments.isEmpty ? '' : '｜手填部署：${resource.deployments.join('、')}'}',
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Row(
          children: <Widget>[
            Expanded(child: Text(resource.name.isEmpty ? '(未命名资源)' : resource.name)),
            if (!resource.enabled)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('已停用', style: TextStyle(fontSize: 12, color: Colors.orange)),
              )
            else if (!resource.isConfigured)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('待完善', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
          ],
        ),
        subtitle: Text(subtitleLines.join('\n'), style: const TextStyle(fontSize: 12)),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: '编辑',
              icon: const Icon(Icons.edit),
              onPressed: _editingConfig ? () => _openAzureResourceEditor(index: index) : null,
            ),
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _editingConfig
                  ? () {
                      setState(() => _azureResources = List<AzureAiResource>.from(_azureResources)..removeAt(index));
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAzureResourceEditor({int? index}) async {
    final existing = index == null ? null : _azureResources[index];
    final edited = await showDialog<AzureAiResource>(
      context: context,
      builder: (ctx) => _AzureResourceEditorDialog(resource: existing),
    );
    if (edited == null || !mounted) return;
    setState(() {
      final next = List<AzureAiResource>.from(_azureResources);
      if (index == null) {
        next.add(edited);
      } else {
        next[index] = edited;
      }
      _azureResources = next;
    });
  }

  AzureAiResource? _findAzureResourceByName(String name) {
    final usable = _azureResources.where((e) => e.enabled && e.isConfigured).toList();
    if (usable.isEmpty) return null;
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) return usable.first;
    for (final resource in usable) {
      if (resource.name.toLowerCase() == wanted || resource.id.toLowerCase() == wanted) return resource;
    }
    return usable.first;
  }

  Future<int?> _readNextMillisFromDbOrNull(String uid) async {
    try {
      final t = await _taskDao.getByUid(uid);
      final raw = (t?['next_time'] ?? '') as String?;
      if (raw != null && raw.isNotEmpty) {
        try {
          final dt = DateTime.parse(raw);
          return dt.millisecondsSinceEpoch;
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _normalizeProviderKey(String? provider) {
    final p = (provider ?? _ceProvider).trim().toLowerCase();
    if (p == 'openai') return 'openai';
    if (p == 'openrouter') return 'openrouter';
    if (p == 'edenai') return 'edenai';
    if (p == 'xgrok' || p == 'xai' || p == 'grok') return 'xgrok';
    if (p == 'gemini' || p == 'google' || p == 'googleai') return 'gemini';
    if (p == 'azure' || p == 'azureopenai' || p == 'azure_openai' || p == 'foundry' || p == 'msfoundry') {
      return 'azure';
    }
    return 'deepseek';
  }

  String _providerDisplayName(String? provider) {
    switch (_normalizeProviderKey(provider)) {
      case 'openai':
        return 'OpenAI';
      case 'openrouter':
        return 'OpenRouter';
      case 'edenai':
        return 'Eden AI';
      case 'xgrok':
        return 'xGrok';
      case 'gemini':
        return 'Gemini';
      case 'azure':
        return 'Azure';
      case 'deepseek':
      default:
        return 'DeepSeek';
    }
  }

  String _formatGlobalAiModelDisplay(String provider, String model) {
    final normalized = _normalizeProviderKey(provider);
    if (normalized == 'openrouter') return 'openrouter / $model';
    if (normalized == 'azure') return model.trim().isEmpty ? '' : 'azure / $model';
    return model;
  }

  String _cePromptKey(String base, [String? provider]) {
    final p = _normalizeProviderKey(provider);
    return 'ce_prompt_${base}_$p';
  }

  String _cePromptLastKey(String base, [String? provider]) {
    final p = _normalizeProviderKey(provider);
    return 'ce_prompt_${base}_${p}_last';
  }

  String _cePromptCurrentValue(String base) {
    switch (base) {
      case 'parse_template':
        return _cePromptParseCtrl.text;
      case 'scene_template':
        return _cePromptSceneCtrl.text;
      case 'turn_template':
        return _cePromptTurnCtrl.text;
      case 'replay_template':
        return _cePromptReplayCtrl.text;
      case 'behavior_chain_template':
        return _cePromptBehaviorChainCtrl.text;
      case 'extra':
        return _cePromptExtraCtrl.text;
      default:
        return '';
    }
  }

  void _cePromptSetCurrentValue(String base, String value) {
    switch (base) {
      case 'parse_template':
        _cePromptParseCtrl.text = value;
        break;
      case 'scene_template':
        _cePromptSceneCtrl.text = value;
        break;
      case 'turn_template':
        _cePromptTurnCtrl.text = value;
        break;
      case 'replay_template':
        _cePromptReplayCtrl.text = value;
        break;
      case 'behavior_chain_template':
        _cePromptBehaviorChainCtrl.text = value;
        break;
      case 'extra':
        _cePromptExtraCtrl.text = value;
        break;
    }
  }

  String _ceDefaultTemplate(String base) {
    switch (base) {
      case 'parse_template':
        return ConceptEngineService.defaultPromptTemplate('parse');
      case 'scene_template':
        return ConceptEngineService.defaultPromptTemplate('scene');
      case 'turn_template':
        return ConceptEngineService.defaultPromptTemplate('turn');
      case 'replay_template':
        return ConceptEngineService.defaultPromptTemplate('replay');
      case 'behavior_chain_template':
        return ConceptEngineService.defaultPromptTemplate('behavior_chain');
      case 'extra':
        return '';
      default:
        return '';
    }
  }

  Future<void> _showPromptVersionDialog(String base, String title) async {
    final current = _cePromptCurrentValue(base);
    final last = (await _kvDao.getString(_cePromptLastKey(base))) ?? '';
    final def = _ceDefaultTemplate(base);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title · 模板版本'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _templatePreviewCard('当前编辑中', current.isEmpty ? '（空，表示使用默认模板）' : current),
                const SizedBox(height: 12),
                _templatePreviewCard('上一版', last.isEmpty ? '（暂无上一版）' : last),
                const SizedBox(height: 12),
                _templatePreviewCard('内置默认', def.isEmpty ? '（无默认内容）' : def),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
          TextButton(
            onPressed: () {
              setState(() => _cePromptSetCurrentValue(base, last));
              Navigator.of(ctx).pop();
            },
            child: const Text('使用上一版'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _cePromptSetCurrentValue(base, def));
              Navigator.of(ctx).pop();
            },
            child: const Text('使用默认模板'),
          ),
        ],
      ),
    );
  }

  Widget _templatePreviewCard(String label, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(content, style: const TextStyle(fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }

  Future<void> _loadConceptEngineProviderConfig(String provider) async {
    final p = _normalizeProviderKey(provider);
    final legacyExtra = (await _kvDao.getString('ce_prompt_extra')) ?? '';
    final legacyParse = (await _kvDao.getString('ce_prompt_parse_template')) ?? '';
    final legacyScene = (await _kvDao.getString('ce_prompt_scene_template')) ?? '';
    final legacyTurn = (await _kvDao.getString('ce_prompt_turn_template')) ?? '';
    final legacyReplay = (await _kvDao.getString('ce_prompt_replay_template')) ?? '';
    final legacyBehaviorChain = (await _kvDao.getString('ce_prompt_behavior_chain_template')) ?? '';

    _cePromptExtraCtrl.text = (await _kvDao.getString(_cePromptKey('extra', p))) ?? legacyExtra;
    _cePromptParseCtrl.text = (await _kvDao.getString(_cePromptKey('parse_template', p))) ?? legacyParse;
    _cePromptSceneCtrl.text = (await _kvDao.getString(_cePromptKey('scene_template', p))) ?? legacyScene;
    _cePromptTurnCtrl.text = (await _kvDao.getString(_cePromptKey('turn_template', p))) ?? legacyTurn;
    _cePromptReplayCtrl.text = (await _kvDao.getString(_cePromptKey('replay_template', p))) ?? legacyReplay;
    _cePromptBehaviorChainCtrl.text = (await _kvDao.getString(_cePromptKey('behavior_chain_template', p))) ?? legacyBehaviorChain;
  }

  Future<void> _load() async {
    final cfg = await _configDao.getOne();
    _apiKeyCtrl.text = (cfg['api_key'] ?? '') as String;
    _modelCtrl.text = (cfg['model'] ?? 'gpt-5') as String;
    _endpointCtrl.text = (cfg['endpoint'] ?? '') as String;

    // load recent hours
    final rh = await _configDao.getRecentHours();
    _recentHoursCtrl.text = rh.toString();

    final ot = await _configDao.getOverviewThreshold();
    _overviewThresholdCtrl.text = ot.toString();

    // Load movie token; fall back to default inside DAO
    try {
      final mt = await _configDao.getMovieToken();
      _movieTokenCtrl.text = mt;
    } catch (_) {
      _movieTokenCtrl.text = '';
    }

    // Load DeepSeek API key and model. If not set, fall back to
    // sensible defaults. Fetch the available model list afterwards.
    try {
      final dsKey = await _configDao.getDeepseekKey();
      _deepseekKeyCtrl.text = dsKey;
    } catch (_) {
      _deepseekKeyCtrl.text = '';
    }
    try {
      _openRouterKeyCtrl.text = await _configDao.getOpenRouterKey();
    } catch (_) {
      _openRouterKeyCtrl.text = '';
    }
    try {
      _edenAiKeyCtrl.text = await _globalAiSettings.getEdenAiKey();
    } catch (_) {
      _edenAiKeyCtrl.text = '';
    }
    try {
      _xGrokKeyCtrl.text = await _globalAiSettings.getXGrokKey();
    } catch (_) {
      _xGrokKeyCtrl.text = '';
    }
    try {
      _geminiKeyCtrl.text = await _globalAiSettings.getGeminiKey();
    } catch (_) {
      _geminiKeyCtrl.text = '';
    }
    try {
      final saved = await _azureAiSettings.listResources();
      // 首次进入时给出与实际项目同名的两条模板（AzureOpenAI / modleapikey），
      // 用户只需要补上终结点和密钥即可，不必从零开始建表。
      _azureResources = saved.isEmpty ? AzureAiSettings.defaultTemplates() : saved;
    } catch (_) {
      _azureResources = AzureAiSettings.defaultTemplates();
    }
    try {
      final dsModel = await _configDao.getDeepseekModel();
      _selectedDeepseekModel = _normalizeDeepseekUiModel(dsModel);
    } catch (_) {
      _selectedDeepseekModel = 'deepseek-v4-pro';
    }

    try {
      _youtubeApiKeyCtrl.text = (await _kvDao.getString(YoutubeMusicService.apiKeyKvKey)) ?? '';
    } catch (_) {
      _youtubeApiKeyCtrl.text = '';
    }

    try {
      _jamendoClientIdCtrl.text = (await _kvDao.getString(OpenMusicService.jamendoClientIdKvKey)) ?? '';
    } catch (_) {
      _jamendoClientIdCtrl.text = '';
    }

    try {
      _kugouAppIdCtrl.text = (await _kvDao.getString('kugou_open_app_id')) ?? '';
      _kugouAppKeyCtrl.text = (await _kvDao.getString('kugou_open_app_key')) ?? '';
    } catch (_) {
      _kugouAppIdCtrl.text = '';
      _kugouAppKeyCtrl.text = '';
    }


    // 全局 AI 模型配置：供首页左侧菜单各模块统一复用。
    try {
      final globalAi = await _globalAiSettings.getState();
      _globalAiProvider = _normalizeProviderKey(globalAi['provider']);
      _globalAiModelRaw = (globalAi['model'] ?? '').trim();
      _globalAiModelCtrl.text = (globalAi['display_model'] ?? _globalAiModelRaw).trim();
      _goalSettingPromptCtrl.text = await _globalAiSettings.getGoalSettingUnderstandingPrompt();
      _goalSettingActionPromptCtrl.text = await _globalAiSettings.getGoalSettingActionPrompt();
      _goalSettingLoopPromptCtrl.text = await _globalAiSettings.getGoalSettingLoopPrompt();
    } catch (_) {
      _globalAiProvider = 'deepseek';
      _globalAiModelRaw = '';
      _globalAiModelCtrl.text = '';
      _goalSettingPromptCtrl.text = _globalAiSettings.defaultGoalSettingUnderstandingPrompt;
      _goalSettingActionPromptCtrl.text = _globalAiSettings.defaultGoalSettingActionPrompt;
      _goalSettingLoopPromptCtrl.text = _globalAiSettings.defaultGoalSettingLoopPrompt;
    }

    try {
      final requestCfg = await _globalAiRequestSettings.getConfig();
      _globalTimeoutCtrl.text = requestCfg.timeoutSeconds?.toString() ?? '';
      _globalMaxTokensCtrl.text = requestCfg.maxOutputTokens?.toString() ?? '';
      _globalTemperatureCtrl.text = requestCfg.temperature?.toString() ?? '';
      _globalTopPCtrl.text = requestCfg.topP?.toString() ?? '';
      _globalRetryCountCtrl.text = requestCfg.retryCount?.toString() ?? '';
      _globalRetryDelayMsCtrl.text = requestCfg.retryDelayMs?.toString() ?? '';
    } catch (_) {
      _globalTimeoutCtrl.text = '';
      _globalMaxTokensCtrl.text = '';
      _globalTemperatureCtrl.text = '';
      _globalTopPCtrl.text = '';
      _globalRetryCountCtrl.text = '';
      _globalRetryDelayMsCtrl.text = '';
    }

    // 概念实践引擎配置：支持在 DeepSeek / OpenAI / OpenRouter / Eden AI / xGrok / Gemini 之间切换，并继承上方对应服务商密钥。
    try {
      _ceProvider = _globalAiProvider;
      _ceModelCtrl.text = _globalAiModelRaw.isEmpty ? _defaultCeModelForProvider(_ceProvider) : _globalAiModelRaw;
      _ceEndpointCtrl.text = _defaultCeEndpointForProvider(_ceProvider);
      _ceTimeoutCtrl.text = (await _kvDao.getString('ce_timeout_seconds'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_timeout_seconds'))!.trim()
          : '60';
      if (_globalTimeoutCtrl.text.trim().isNotEmpty) {
        _ceTimeoutCtrl.text = _globalTimeoutCtrl.text.trim();
      }
      _ceSceneCountCtrl.text = (await _kvDao.getString('ce_scene_count'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_scene_count'))!.trim()
          : '3';
      _ceTurnTargetCtrl.text = (await _kvDao.getString('ce_turn_target'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_turn_target'))!.trim()
          : '6';
      _ceParseMinIntuitiveCtrl.text = (await _kvDao.getString('ce_parse_min_intuitive'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_parse_min_intuitive'))!.trim()
          : '10';
      _ceParseMinBehaviorsCtrl.text = (await _kvDao.getString('ce_parse_min_behaviors'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_parse_min_behaviors'))!.trim()
          : '10';
      _ceParseRetryCountCtrl.text = (await _kvDao.getString('ce_parse_retry_count'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_parse_retry_count'))!.trim()
          : '2';
      _ceBehaviorChainMinNodesCtrl.text = (await _kvDao.getString('ce_behavior_chain_min_nodes'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_behavior_chain_min_nodes'))!.trim()
          : '4';
      _ceBehaviorChainMaxNodesCtrl.text = (await _kvDao.getString('ce_behavior_chain_max_nodes'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_behavior_chain_max_nodes'))!.trim()
          : '8';
      _ceParseMaxTokensCtrl.text = (await _kvDao.getString('ce_parse_max_tokens'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_parse_max_tokens'))!.trim()
          : '3200';
      _ceSceneMaxTokensCtrl.text = (await _kvDao.getString('ce_scene_max_tokens'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_scene_max_tokens'))!.trim()
          : '4000';
      _ceTurnMaxTokensCtrl.text = (await _kvDao.getString('ce_turn_max_tokens'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_turn_max_tokens'))!.trim()
          : '2500';
      _ceReplayMaxTokensCtrl.text = (await _kvDao.getString('ce_replay_max_tokens'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_replay_max_tokens'))!.trim()
          : '3500';
      _ceBehaviorChainMaxTokensCtrl.text = (await _kvDao.getString('ce_behavior_chain_max_tokens'))?.trim().isNotEmpty == true
          ? (await _kvDao.getString('ce_behavior_chain_max_tokens'))!.trim()
          : '2200';
      _ceTransportMode = (((await _kvDao.getString('ce_transport_mode')) ?? ConceptEngineService.transportDirect).trim().toLowerCase() == ConceptEngineService.transportProxy)
          ? ConceptEngineService.transportProxy
          : ConceptEngineService.transportDirect;
      _ceProxyEndpointCtrl.text = (await _kvDao.getString('ce_proxy_endpoint')) ?? '';
      _ceProxyTokenCtrl.text = (await _kvDao.getString('ce_proxy_token')) ?? '';
      await _loadConceptEngineProviderConfig(_ceProvider);
    } catch (_) {
      _ceProvider = _globalAiProvider;
      _ceModelCtrl.text = _defaultCeModelForProvider(_ceProvider);
      _ceEndpointCtrl.text = _defaultCeEndpointForProvider(_ceProvider);
      _ceTimeoutCtrl.text = '60';
      _ceSceneCountCtrl.text = '3';
      _ceTurnTargetCtrl.text = '6';
      _ceParseMinIntuitiveCtrl.text = '10';
      _ceParseMinBehaviorsCtrl.text = '10';
      _ceParseRetryCountCtrl.text = '2';
      _ceBehaviorChainMinNodesCtrl.text = '4';
      _ceBehaviorChainMaxNodesCtrl.text = '8';
      _ceParseMaxTokensCtrl.text = '3200';
      _ceSceneMaxTokensCtrl.text = '4000';
      _ceTurnMaxTokensCtrl.text = '2500';
      _ceReplayMaxTokensCtrl.text = '3500';
      _ceBehaviorChainMaxTokensCtrl.text = '2200';
      _ceTransportMode = ConceptEngineService.transportDirect;
      _ceProxyEndpointCtrl.text = '';
      _ceProxyTokenCtrl.text = '';
      await _loadConceptEngineProviderConfig(_ceProvider);
    }

    // Fetch the list of DeepSeek models asynchronously. This will update
    // state when complete. It is invoked outside of setState to avoid
    // triggering redundant rebuilds.
    _fetchDeepseekModels();
    _fetchGlobalAiModels();

    _tasks = await _taskDao.all();
    // 读取量表自动报告开关状态
    try {
      final auto = await _configDao.getAutoReportEnabled();
      _autoReportEnabled = auto;
    } catch (_) {
      _autoReportEnabled = false;
    }
    // 读取 EMA / SSES 设置
    try {
      final ema = await _configDao.getEmaEnabled();
      final scale = await _configDao.getSelfEsteemScale();
      _emaEnabled = ema;
      _esteemScale = scale;
    } catch (_) {
      _emaEnabled = false;
      _esteemScale = 100;
    }

    // 读取首页侧栏 AI 主题开关（默认关闭）
    try {
      _drawerHeaderAiEnabled = await _globalAiSettings.isDrawerHeaderAiEnabled();
    } catch (_) {
      _drawerHeaderAiEnabled = false;
    }

    // 读取火种复问通知开关（缺省即关）
    try {
      _kindlingReaskNotifyEnabled = await KindlingHostReminder.isEnabled();
    } catch (_) {
      _kindlingReaskNotifyEnabled = false;
    }

    // 读取发现之旅“此时此刻心情卡片”设置
    try {
      _moodCardPopupEnabled = await _configDao.getMoodCardPopupEnabled();
      _moodCardDelayMsCtrl.text = (await _configDao.getMoodCardPopupDelayMs()).toString();
    } catch (_) {
      _moodCardPopupEnabled = true;
      _moodCardDelayMsCtrl.text = ConfigDao.defaultMoodCardDelayMs.toString();
    }

    // 读取运动设置
    try {
      _sportBgPath = await _configDao.getSportRunningBg();
      _sportSoundPath = await _configDao.getSportStartSound();
      _sportMusicList = await _configDao.getSportMusicPlaylist();
      _sportMusicMode = await _configDao.getSportMusicMode();
      _sportMusicBgBindings = await _configDao.getSportMusicBgBindings();
    } catch (_) {
      _sportBgPath = null;
      _sportSoundPath = null;
      _sportMusicList = <String>[];
      _sportMusicBgBindings = <String, List<String>>{};
      _sportMusicMode = 'order';
    }
    _loadingAutoReport = false;
    if (mounted) setState(() {});
  }


  Future<void> _backupConceptEnginePromptVersion() async {
    await _kvDao.setString(_cePromptLastKey('extra'), (await _kvDao.getString(_cePromptKey('extra'))) ?? '');
    await _kvDao.setString(_cePromptLastKey('parse_template'), (await _kvDao.getString(_cePromptKey('parse_template'))) ?? '');
    await _kvDao.setString(_cePromptLastKey('scene_template'), (await _kvDao.getString(_cePromptKey('scene_template'))) ?? '');
    await _kvDao.setString(_cePromptLastKey('turn_template'), (await _kvDao.getString(_cePromptKey('turn_template'))) ?? '');
    await _kvDao.setString(_cePromptLastKey('replay_template'), (await _kvDao.getString(_cePromptKey('replay_template'))) ?? '');
    await _kvDao.setString(_cePromptLastKey('behavior_chain_template'), (await _kvDao.getString(_cePromptKey('behavior_chain_template'))) ?? '');
    await _kvDao.setString('ce_prompt_version_last_at_${_ceProvider}', DateTime.now().toIso8601String());
  }

  Future<void> _rollbackConceptEnginePromptVersion() async {
    final lastExtra = (await _kvDao.getString(_cePromptLastKey('extra'))) ?? '';
    final lastParse = (await _kvDao.getString(_cePromptLastKey('parse_template'))) ?? '';
    final lastScene = (await _kvDao.getString(_cePromptLastKey('scene_template'))) ?? '';
    final lastTurn = (await _kvDao.getString(_cePromptLastKey('turn_template'))) ?? '';
    final lastReplay = (await _kvDao.getString(_cePromptLastKey('replay_template'))) ?? '';
    final lastBehaviorChain = (await _kvDao.getString(_cePromptLastKey('behavior_chain_template'))) ?? '';
    setState(() {
      _cePromptExtraCtrl.text = lastExtra;
      _cePromptParseCtrl.text = lastParse;
      _cePromptSceneCtrl.text = lastScene;
      _cePromptTurnCtrl.text = lastTurn;
      _cePromptReplayCtrl.text = lastReplay;
      _cePromptBehaviorChainCtrl.text = lastBehaviorChain;
    });
    showToast('已回滚到 ${_providerDisplayName(_ceProvider)} 上一版 Prompt，请记得保存配置');
  }

  Future<void> _saveConfig() async {
    await _configDao.save(apiKey: _apiKeyCtrl.text.trim(), model: _modelCtrl.text.trim(), endpoint: _endpointCtrl.text.trim());
    // also persist recent hours with the same save action
    final _rh = int.tryParse(_recentHoursCtrl.text.trim()) ?? 2;
    await _configDao.setRecentHours(_rh < 1 ? 1 : _rh);
    final _ot = int.tryParse(_overviewThresholdCtrl.text.trim()) ?? 500;
    await _configDao.setOverviewThreshold(_ot < 1 ? 1 : _ot);
    final moodDelayMs = int.tryParse(_moodCardDelayMsCtrl.text.trim()) ?? ConfigDao.defaultMoodCardDelayMs;
    final normalizedMoodDelayMs = moodDelayMs < 0 ? 0 : (moodDelayMs > 60000 ? 60000 : moodDelayMs);
    _moodCardDelayMsCtrl.text = normalizedMoodDelayMs.toString();
    await _configDao.setMoodCardPopupEnabled(_moodCardPopupEnabled);
    await _configDao.setMoodCardPopupDelayMs(normalizedMoodDelayMs);

    // Persist movie token
    await _configDao.setMovieToken(_movieTokenCtrl.text.trim());

    await _kvDao.setString(YoutubeMusicService.apiKeyKvKey, _youtubeApiKeyCtrl.text.trim());
    await _kvDao.setString(OpenMusicService.jamendoClientIdKvKey, _jamendoClientIdCtrl.text.trim());
    await _kvDao.setString('kugou_open_app_id', _kugouAppIdCtrl.text.trim());
    await _kvDao.setString('kugou_open_app_key', _kugouAppKeyCtrl.text.trim());


    // Persist DeepSeek API key and selected model. Even if no models were
    // fetched, persisting the key allows TranslationService to pick it up
    // immediately. Persisting the model ensures we store a valid value or
    // default 'deepseek-v4-pro'.
    await _configDao.setDeepseekKey(_deepseekKeyCtrl.text.trim());
    await _configDao.setDeepseekModel(_normalizeDeepseekUiModel(_selectedDeepseekModel));
    await _configDao.setOpenRouterKey(_openRouterKeyCtrl.text.trim());
    await _globalAiSettings.setEdenAiKey(_edenAiKeyCtrl.text.trim());
    await _globalAiSettings.setXGrokKey(_xGrokKeyCtrl.text.trim());
    await _globalAiSettings.setGeminiKey(_geminiKeyCtrl.text.trim());
    await _azureAiSettings.saveResources(_azureResources);
    _azureResources = await _azureAiSettings.listResources();
    // 保存资源表时资源名可能被去重改写（例如两个同名资源）。所选模型是
    // “资源名/部署名”的限定写法，这里按改写后的资源名重新限定一次，
    // 避免保存后模型指向一个已经不存在的资源名。
    if (_globalAiProvider == 'azure' && _globalAiModelRaw.trim().isNotEmpty) {
      final parts = AzureAiSettings.splitModel(_globalAiModelRaw.trim());
      final resource = _findAzureResourceByName(parts.resourceName);
      if (resource != null && parts.deployment.isNotEmpty) {
        _globalAiModelRaw = AzureAiSettings.qualifyModel(resource.name, parts.deployment);
        _globalAiModelCtrl.text = _formatGlobalAiModelDisplay('azure', _globalAiModelRaw);
      }
    }
    await _globalAiSettings.save(
      provider: _globalAiProvider,
      model: _globalAiModelRaw.trim().isEmpty ? _globalAiModelCtrl.text.trim() : _globalAiModelRaw.trim(),
    );
    await _globalAiRequestSettings.saveRaw(
      timeoutSeconds: _globalTimeoutCtrl.text,
      maxOutputTokens: _globalMaxTokensCtrl.text,
      temperature: _globalTemperatureCtrl.text,
      topP: _globalTopPCtrl.text,
      retryCount: _globalRetryCountCtrl.text,
      retryDelayMs: _globalRetryDelayMsCtrl.text,
    );
    await _globalAiSettings.saveGoalSettingUnderstandingPrompt(_goalSettingPromptCtrl.text.trim());
    await _globalAiSettings.saveGoalSettingActionPrompt(_goalSettingActionPromptCtrl.text.trim());
    await _globalAiSettings.saveGoalSettingLoopPrompt(_goalSettingLoopPromptCtrl.text.trim());
    await _backupConceptEnginePromptVersion();
    _ceProvider = _globalAiProvider;
    _ceModelCtrl.text = _globalAiModelRaw.trim().isEmpty ? _defaultCeModelForProvider(_ceProvider) : _globalAiModelRaw.trim();
    _ceEndpointCtrl.text = _defaultCeEndpointForProvider(_ceProvider);
    if (_globalTimeoutCtrl.text.trim().isNotEmpty) {
      _ceTimeoutCtrl.text = _globalTimeoutCtrl.text.trim();
    }
    await _kvDao.setString('ce_provider', _ceProvider);
    final ceModel = _ceModelCtrl.text.trim().isEmpty ? _defaultCeModelForProvider(_ceProvider) : _ceModelCtrl.text.trim();
    final ceEndpoint = _ceEndpointCtrl.text.trim().isEmpty ? _defaultCeEndpointForProvider(_ceProvider) : _ceEndpointCtrl.text.trim();
    await _kvDao.setString('ce_openai_model', ceModel);
    await _kvDao.setString('ce_openai_endpoint', ceEndpoint);
    await _kvDao.setString('ce_deepseek_model', ceModel);
    await _kvDao.setString('ce_deepseek_endpoint', ceEndpoint);
    await _kvDao.setString('ce_model', ceModel);
    await _kvDao.setString('ce_endpoint', ceEndpoint);
    await _kvDao.setString('ce_timeout_seconds', (_ceTimeoutCtrl.text.trim().isEmpty ? '60' : _ceTimeoutCtrl.text.trim()));
    await _kvDao.setString('ce_scene_count', (_ceSceneCountCtrl.text.trim().isEmpty ? '3' : _ceSceneCountCtrl.text.trim()));
    await _kvDao.setString('ce_turn_target', (_ceTurnTargetCtrl.text.trim().isEmpty ? '6' : _ceTurnTargetCtrl.text.trim()));
    await _kvDao.setString('ce_parse_min_intuitive', (_ceParseMinIntuitiveCtrl.text.trim().isEmpty ? '10' : _ceParseMinIntuitiveCtrl.text.trim()));
    await _kvDao.setString('ce_parse_min_behaviors', (_ceParseMinBehaviorsCtrl.text.trim().isEmpty ? '10' : _ceParseMinBehaviorsCtrl.text.trim()));
    await _kvDao.setString('ce_parse_retry_count', (_ceParseRetryCountCtrl.text.trim().isEmpty ? '2' : _ceParseRetryCountCtrl.text.trim()));
    await _kvDao.setString('ce_behavior_chain_min_nodes', (_ceBehaviorChainMinNodesCtrl.text.trim().isEmpty ? '4' : _ceBehaviorChainMinNodesCtrl.text.trim()));
    await _kvDao.setString('ce_behavior_chain_max_nodes', (_ceBehaviorChainMaxNodesCtrl.text.trim().isEmpty ? '8' : _ceBehaviorChainMaxNodesCtrl.text.trim()));
    await _kvDao.setString('ce_parse_max_tokens', (_ceParseMaxTokensCtrl.text.trim().isEmpty ? '3200' : _ceParseMaxTokensCtrl.text.trim()));
    await _kvDao.setString('ce_scene_max_tokens', (_ceSceneMaxTokensCtrl.text.trim().isEmpty ? '4000' : _ceSceneMaxTokensCtrl.text.trim()));
    await _kvDao.setString('ce_turn_max_tokens', (_ceTurnMaxTokensCtrl.text.trim().isEmpty ? '2500' : _ceTurnMaxTokensCtrl.text.trim()));
    await _kvDao.setString('ce_replay_max_tokens', (_ceReplayMaxTokensCtrl.text.trim().isEmpty ? '3500' : _ceReplayMaxTokensCtrl.text.trim()));
    await _kvDao.setString('ce_behavior_chain_max_tokens', (_ceBehaviorChainMaxTokensCtrl.text.trim().isEmpty ? '2200' : _ceBehaviorChainMaxTokensCtrl.text.trim()));
    await _kvDao.setString('ce_transport_mode', _ceTransportMode);
    await _kvDao.setString('ce_proxy_endpoint', _ceProxyEndpointCtrl.text.trim());
    await _kvDao.setString('ce_proxy_token', _ceProxyTokenCtrl.text.trim());
    await _kvDao.setString(_cePromptKey('extra'), _cePromptExtraCtrl.text);
    await _kvDao.setString(_cePromptKey('parse_template'), _cePromptParseCtrl.text);
    await _kvDao.setString(_cePromptKey('scene_template'), _cePromptSceneCtrl.text);
    await _kvDao.setString(_cePromptKey('turn_template'), _cePromptTurnCtrl.text);
    await _kvDao.setString(_cePromptKey('replay_template'), _cePromptReplayCtrl.text);
    await _kvDao.setString(_cePromptKey('behavior_chain_template'), _cePromptBehaviorChainCtrl.text);
    // 兼容旧版本通用键，保存当前生效值。
    await _kvDao.setString('ce_prompt_extra', _cePromptExtraCtrl.text);
    await _kvDao.setString('ce_prompt_parse_template', _cePromptParseCtrl.text);
    await _kvDao.setString('ce_prompt_scene_template', _cePromptSceneCtrl.text);
    await _kvDao.setString('ce_prompt_turn_template', _cePromptTurnCtrl.text);
    await _kvDao.setString('ce_prompt_replay_template', _cePromptReplayCtrl.text);
    await _kvDao.setString('ce_prompt_behavior_chain_template', _cePromptBehaviorChainCtrl.text);
    // Refresh available model lists after saving keys, so dropdowns show all
    // provider specific models immediately.
    _fetchDeepseekModels();
    _fetchGlobalAiModels();
    setState(() => _editingConfig = false);
    showToast('配置已保存');
    
  }

  
Future<String?> _saveAvatarTemp(File file) async {
  // 保留原始扩展名与尺寸，不裁剪
  final docs = await getApplicationDocumentsDirectory();
  final ext = p.extension(file.path);
  final base = p.basename(file.path);
  final safeName = 'avatar_${DateTime.now().millisecondsSinceEpoch}${ext.isNotEmpty ? ext : p.extension(base)}';
  final dst = File(p.join(docs.path, safeName));
  await dst.writeAsBytes(await file.readAsBytes());
  return dst.path;
}


  Future<void> _openTaskDialog({Map<String, dynamic>? task}) async {
    final isEdit = task != null;

    String name = isEdit ? (task['name'] ?? '') as String : '';
    String type = isEdit ? (task['type'] ?? 'manual') as String : 'manual'; // manual / auto / carousel / 批量导入任务
    String status = isEdit ? (task['status'] ?? 'on') as String : 'on';     // on / off
    String prompt = isEdit ? (task['prompt'] ?? '') as String : '';
    // Carousel order: desc (降序) | asc (升序) | random (随机)
    String carouselOrder = isEdit ? ((task?['carousel_order'] ?? 'desc') as String) : 'desc';
    String manualQuote = '';
    String theme = '';
    String authorName = '';
    String sourceFrom = '';
    String explanation = '';
    
    // Prepare avatarPath early; it may be overwritten for bulk-import tasks based on quote avatar
    String avatarPath = isEdit ? (task['avatar_path'] ?? '') as String : '';
    // 回显手动任务或批量导入任务的名言及其他字段
    if (isEdit && (task?['task_uid'] != null)) {
      final taskUid = task!['task_uid'] as String;
      if (type == 'manual') {
        final mq = await QuoteDao().latestForTask(taskUid);
        manualQuote = (mq?['content'] ?? '') as String;
        theme = (mq?['theme'] ?? '') as String;
        authorName = (mq?['author_name'] ?? '') as String;
        sourceFrom = (mq?['source_from'] ?? '') as String;
        explanation = (mq?['explanation'] ?? '') as String;
      } else if (type == '批量导入任务') {
        // Use cursor to select which quote to show.  Default to 0 if missing.
        final cursorVal = (task['cursor'] is int) ? task['cursor'] as int : int.tryParse((task['cursor'] ?? '0').toString()) ?? 0;
        final mq = await QuoteDao().findByTaskOffsetDesc(taskUid, cursorVal);
        if (mq != null) {
          manualQuote = (mq['content'] ?? '') as String;
          theme = (mq['theme'] ?? '') as String;
          authorName = (mq['author_name'] ?? '') as String;
          sourceFrom = (mq['source_from'] ?? '') as String;
          explanation = (mq['explanation'] ?? '') as String;
          // For bulk import tasks, use the quote's avatar for preview
          avatarPath = (mq['avatar'] ?? '') as String;
        }
      }
    }

    // freq
    String freqType = isEdit ? (task['freq_type'] ?? 'daily') as String : 'daily'; // daily/weekly/monthly/custom
    int? selectedWeekday = (task?['freq_weekday'] as int?);
    int? selectedMonthDay = (task?['freq_day_of_month'] as int?);
    TimeOfDay time = _parseTimeOfDay((task?['start_time'] ?? '') as String) ?? TimeOfDay.now();
    final formKey = GlobalKey<FormState>();

    // Auto-refresh "next trigger" preview
    Timer? ticker;
    void ensureTicker(StateSetter setStateDialog, BuildContext ctx) {
      ticker ??= Timer.periodic(const Duration(seconds: 30), (_){
        if (Navigator.of(ctx).mounted) setStateDialog((){});
      });
    }

    String two(int n)=> n.toString().padLeft(2,'0');
    String weekdayText(int w){
      const names = ['一','二','三','四','五','六','日'];
      return (w>=1 && w<=7)? names[w-1] : '一';
    }
    DateTime computeNext(DateTime now){
      if (freqType == 'weekly'){
        final wd = (selectedWeekday ?? 1);
        int delta = (wd - now.weekday) % 7;
        var cand = DateTime(now.year, now.month, now.day, time.hour, time.minute).add(Duration(days: delta));
        if (!cand.isAfter(now)) cand = cand.add(const Duration(days: 7));
        return cand;
      } else if (freqType == 'monthly'){
        final d = (selectedMonthDay ?? 1);
        int y = now.year, m = now.month;
        int end = DateTime(y, m + 1, 0).day;
        var cand = DateTime(y, m, d.clamp(1, end), time.hour, time.minute);
        if (!cand.isAfter(now)) {
          m += 1;
          end = DateTime(y, m + 1, 0).day;
          cand = DateTime(y, m, d.clamp(1, end), time.hour, time.minute);
        }
        return cand;
      } else {
        final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
        if (today.isAfter(now)) return today;
        return today.add(const Duration(days: 1));
      }
    }

    String _fmt(DateTime dt){ String two(int n)=> n.toString().padLeft(2,'0'); return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}'; }
    await showDialog(context: context, builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          ensureTicker(setStateDialog, ctx);
          final next = computeNext(DateTime.now());
          final nextStr = '${next.year}-${two(next.month)}-${two(next.day)} ${two(next.hour)}:${two(next.minute)}';

          return AlertDialog(
            title: Text(isEdit ? '编辑任务' : '新增任务'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('任务标题'),
                    TextFormField(
                      initialValue: name,
                      onChanged: (v)=> name = v,
                      validator: (v)=> (v==null || v.trim().isEmpty) ? '请输入任务标题' : null,
                    ),
                    const SizedBox(height: 8),
                    const Text('任务类型'),
                    DropdownButton<String>(
                      value: type,
                      onChanged: (v){ setStateDialog(()=> type = v ?? 'manual'); },
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('手动')),
                        DropdownMenuItem(value: 'auto', child: Text('自动')),
                        DropdownMenuItem(value: 'carousel', child: Text('轮播')),
                        DropdownMenuItem(value: '批量导入任务', child: Text('批量导入任务')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (type == 'auto') ...[
                      const Text('提示词'),
                      TextFormField(
                        initialValue: prompt,
                        onChanged: (v)=> prompt = v,
                        validator: (v)=> (type=='auto' && (v==null || v.trim().isEmpty)) ? '请输入提示词' : null,
                      ),
                    ],
                    if (type == 'manual' || type == '批量导入任务') ...[
                      const Text('名人名言'),
                      
TextFormField(
            initialValue: manualQuote,
                        onChanged: (v)=> manualQuote = v,
                        validator: (v)=> (type=='manual' && (v==null || v.trim().isEmpty)) ? '请输入名人名言' : null,
                        minLines: 3,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                      ),

  const SizedBox(height: 8),
  const Text('主题'),
  TextFormField(
    initialValue: theme,
    onChanged: (v) => theme = v,
  ),
  const SizedBox(height: 8),
  const Text('署名'),
  TextFormField(
    initialValue: authorName,
    onChanged: (v) => authorName = v,
  ),
  const SizedBox(height: 8),
  const Text('出处'),
  TextFormField(
    initialValue: sourceFrom,
    onChanged: (v) => sourceFrom = v,
  ),
  const SizedBox(height: 8),
  const Text('简明解释'),
  TextFormField(
    initialValue: explanation,
    onChanged: (v) => explanation = v,
    minLines: 3,
    maxLines: null,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
  ),
],
                    // When creating or editing a carousel task, allow the user to select the play order
                    if (type == 'carousel') ...[
                      const Text('轮播顺序'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioListTile<String>(
                            title: const Text('降序'),
                            value: 'desc',
                            groupValue: carouselOrder,
                            onChanged: (v) {
                              setStateDialog(() => carouselOrder = v ?? 'desc');
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('升序'),
                            value: 'asc',
                            groupValue: carouselOrder,
                            onChanged: (v) {
                              setStateDialog(() => carouselOrder = v ?? 'desc');
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('随机'),
                            value: 'random',
                            groupValue: carouselOrder,
                            onChanged: (v) {
                              setStateDialog(() => carouselOrder = v ?? 'desc');
                            },
                          ),
                        ],
                      ),
                    ],
const SizedBox(height: 8),
const Text('头像（用于通知图标）'),
                    Row(
                      children: [
                        // 显示文件名；若未选择则显示提示文字；不展示图片
                        Flexible(
                          child: Text(
                            avatarPath.isNotEmpty ? p.basename(avatarPath) : '未选择',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final x = await picker.pickImage(source: ImageSource.gallery);
                            if (x != null) {
                              final p = await _saveAvatarTemp(File(x.path));
                              setStateDialog(()=> avatarPath = p ?? '');
                            }
                          },
                          icon: const Icon(Icons.photo),
                          label: const Text('选择图片'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('状态'),
                    DropdownButton<String>(
                      value: status,
                      onChanged: (v){ setStateDialog(()=> status = v ?? 'on'); },
                      items: const [
                        DropdownMenuItem(value: 'on', child: Text('开启')),
                        DropdownMenuItem(value: 'off', child: Text('关闭')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('时间：'),
                    // frequency row
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: freqType,
                          onChanged: (v){ setStateDialog(()=> freqType = v ?? 'daily'); },
                          items: const [
                            DropdownMenuItem(value: 'daily', child: Text('每天')),
                            DropdownMenuItem(value: 'weekly', child: Text('每周')),
                            DropdownMenuItem(value: 'monthly', child: Text('每月')),
                          ],
                        ),
                        const SizedBox(width: 12),
                        if (freqType=='weekly')
                          DropdownButton<int>(
                            value: selectedWeekday ?? 1,
                            onChanged: (v){ setStateDialog(()=> selectedWeekday = v ?? 1); },
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('周一')),
                              DropdownMenuItem(value: 2, child: Text('周二')),
                              DropdownMenuItem(value: 3, child: Text('周三')),
                              DropdownMenuItem(value: 4, child: Text('周四')),
                              DropdownMenuItem(value: 5, child: Text('周五')),
                              DropdownMenuItem(value: 6, child: Text('周六')),
                              DropdownMenuItem(value: 7, child: Text('周日')),
                            ],
                          ),
                        if (freqType=='monthly')
                          DropdownButton<int>(
                            value: (selectedMonthDay ?? 1).clamp(1, 28),
                            onChanged: (v){ setStateDialog(()=> selectedMonthDay = (v ?? 1).clamp(1, 28)); },
                            items: [
                              for (int d=1; d<=28; d++)
                                DropdownMenuItem(value: d, child: Text('$d日')),
                            ],
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: ctx, initialTime: time);
                            if (t != null) setStateDialog(()=> time = t);
                          },
                          icon: const Icon(Icons.access_time),
                        ),
                        Text('${two(time.hour)}:${two(time.minute)}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      () {
                        final hhmm = '${two(time.hour)}:${two(time.minute)}';
                        if (freqType=='weekly') {
                          final w = selectedWeekday ?? 1;
                          return '每周${weekdayText(w)} $hhmm （下一次：$nextStr）';
                        } else if (freqType=='monthly') {
                          final d = selectedMonthDay ?? 1;
                          return '每月${d}日 $hhmm （下一次：$nextStr）';
                        } else {
                          return '每天 $hhmm （下一次：$nextStr）';
                        }
                      }(),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (isEdit)
                TextButton(
                  onPressed: () async {
                    final uid = task!['task_uid'] as String;
                    // Cancel AM/WM using the latest persisted next_time from DB rather than computing a value.
                    try {
                      final nextMillis = await _readNextMillisFromDbOrNull(uid);
                      if (await NativeGuard.isNativeWM()) {
                        await NativeWm.cancelWmByUidBoth(uid);
                      }
                      if (await NativeGuard.isNativeAM()) {
                        if (nextMillis != null) {
                          await NativeAm.cancelExactByNext(uid, nextMillis);
                        } else {
                          final _t = await _taskDao.getByUid(uid);
                          final rk = (_t?['scheduled_run_key'] ?? '') as String?;
                          await NativeAm.cancelExactById(uid, rk);
                        }
                      }
                    } catch (_) {}
                    await SchedulerService.cancelNextForTask(uid);
                    await _taskDao.delete(uid);
                    showToast('已删除任务');
                    await _load();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('删除'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() != true) return;

                  String? uidToSchedule;

                  // Compose freq_custom for potential future use (not required now)
                  final freqCustomJson = '';

                  if (isEdit) {
                    final patch = <String, dynamic>{
                      'name': name.trim(),
                      'type': type,
                      'prompt': type=='auto' ? prompt.trim() : '',
                      'avatar_path': avatarPath,
                      'status': status,
                      'freq_type': freqType,
                      'freq_weekday': selectedWeekday,
                      'freq_day_of_month': selectedMonthDay,
                      'start_time': _fmt(computeNext(DateTime.now())),
                      'freq_custom': freqCustomJson,
                    };
                    // Handle carousel order updates: persist and reset cursor when changed
                    if (type == 'carousel') {
                      patch['carousel_order'] = carouselOrder;
                      final oldOrder = (task?['carousel_order'] ?? 'desc').toString();
                      if (oldOrder != carouselOrder) {
                        // When order changes, reset cursor to 0
                        patch['cursor'] = 0;
                      }
                    }
                    await _taskDao.update(task!['task_uid'] as String, patch);
                    // Cancel existing alarms using the latest persisted next_time from DB rather than computing a value
                    try {
                      final uid = task['task_uid'] as String;
                      final nextMillis = await _readNextMillisFromDbOrNull(uid);
                      if (await NativeGuard.isNativeWM()) {
                        await NativeWm.cancelWmByUidBoth(uid);
                      }
                      if (await NativeGuard.isNativeAM()) {
                        if (nextMillis != null) {
                          await NativeAm.cancelExactByNext(uid, nextMillis);
                        } else {
                          final _t2 = await _taskDao.getByUid(uid);
                          final rk = (_t2?['scheduled_run_key'] ?? '') as String?;
                          await NativeAm.cancelExactById(uid, rk);
                        }
                      }
                    } catch (_) {}
                    await SchedulerService.cancelNextForTask(task['task_uid'] as String);
                    uidToSchedule = task['task_uid'] as String;
                    await _reloadTasksAfterSave();

                                          
                    if (type == 'manual') {
                      final content = manualQuote.trim();
                      if (content.isNotEmpty) {
                        final ok = await QuoteDao().updateLatestForTaskDetailed(
                          taskUid: task['task_uid'] as String,
                          content: content,
                          theme: theme,
                          authorName: authorName,
                          sourceFrom: sourceFrom,
                          explanation: explanation,
                          avatarPath: avatarPath,
                        );
                        if (!ok) {
                          // 按你的要求：编辑手动任务时不新增，只更新
                          showToast('未找到该任务的现有名言（未新增）');
                        }
                      }
                    }
                  } else {
                    final newUid = await _taskDao.create(
                      name: name.trim(),
                      type: type,
                      startTime: _fmt(computeNext(DateTime.now())),
                      prompt: type=='auto' ? prompt.trim() : '',
                      avatarPath: avatarPath,
                      status: status,
                      freqType: freqType,
                      freqWeekday: selectedWeekday,
                      freqDayOfMonth: selectedMonthDay,
                      freqCustom: freqCustomJson,
                      carouselOrder: carouselOrder,
                    );
                    uidToSchedule = newUid;
                    await _reloadTasksAfterSave();

                    if (type == 'manual') {
                      final content = manualQuote.trim();
                      if (content.isNotEmpty) {
                        final dup = await QuoteDao().existsSimilar(content);
                        if (dup) {
                          showToast('数据重复!请重新输入名人名言');
                          return;
                        }
                        final now = DateTime.now(); String two(int n)=> n<10? '0$n':'$n'; final nowStr='${now.year}-${two(now.month)}-${two(now.day)} ${now.hour}:${two(now.minute)}:${two(now.second)}';
                        await QuoteDao().insertIfUniqueDetailed(taskUid: newUid, content: content, theme: theme, authorName: authorName, sourceFrom: sourceFrom, explanation: explanation, avatarPath: avatarPath, taskName: name, taskType: type, insertedAt: nowStr);
                      }
                    }
                  }

                                    await _load();
                  if (uidToSchedule != null) {
                    await SchedulerService.scheduleNextForTask(uidToSchedule!);
                  }
                  showToast('已保存');
                  if (context.mounted) Navigator.pop(context);
                }
                  ,
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    });
    ticker?.cancel();
  }

  
  TimeOfDay? _parseTimeOfDay(String startTime){
    // supports 'HH:mm' or 'yyyy-MM-dd HH:mm'
    startTime = (startTime ?? '').trim();
    if (startTime.isEmpty) return null;
    String? hhmm;
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(startTime)) {
      hhmm = startTime;
    } else {
      final m = RegExp(r'\b(\d{2}:\d{2})\b').firstMatch(startTime);
      hhmm = m?.group(1);
    }
    if (hhmm == null) return null;
    final hm = hhmm.split(':');
    final h = int.tryParse(hm[0]); final m2 = int.tryParse(hm[1]);
    if (h == null || m2 == null) return null;
    return TimeOfDay(hour: h, minute: m2);
  }

  Future<void> _testConceptEngineGateway() async {
    setState(() {
      _checkingCeGateway = true;
      _ceGatewayCheckMessage = null;
      _ceGatewayCheckOk = null;
    });
    _ceProvider = _globalAiProvider;
    _ceModelCtrl.text = _globalAiModelRaw.trim().isEmpty ? _defaultCeModelForProvider(_ceProvider) : _globalAiModelRaw.trim();
    _ceEndpointCtrl.text = _defaultCeEndpointForProvider(_ceProvider);
    if (_globalTimeoutCtrl.text.trim().isNotEmpty) {
      _ceTimeoutCtrl.text = _globalTimeoutCtrl.text.trim();
    }
    await _kvDao.setString('ce_provider', _ceProvider.trim());
    await _kvDao.setString('ce_transport_mode', _ceTransportMode.trim());
    await _kvDao.setString('ce_proxy_endpoint', _ceProxyEndpointCtrl.text.trim());
    await _kvDao.setString('ce_proxy_token', _ceProxyTokenCtrl.text.trim());
    await _kvDao.setString('ce_timeout_seconds', _ceTimeoutCtrl.text.trim().isEmpty ? '60' : _ceTimeoutCtrl.text.trim());
    await _kvDao.setString('ce_openai_model', _ceModelCtrl.text.trim());
    await _kvDao.setString('ce_openai_endpoint', _ceEndpointCtrl.text.trim());
    await _kvDao.setString('ce_deepseek_model', _ceModelCtrl.text.trim());
    await _kvDao.setString('ce_deepseek_endpoint', _ceEndpointCtrl.text.trim());
    final result = await _conceptEngineService.testGatewayHealth();
    if (!mounted) return;
    setState(() {
      _checkingCeGateway = false;
      _ceGatewayCheckOk = result.ok;
      _ceGatewayCheckMessage = result.message + (result.endpoint.isEmpty ? '' : '\n${result.endpoint}');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfgFields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OpenAI 密钥', style: TextStyle(fontWeight: FontWeight.bold)),
        // Remove underline border for API key input
        TextField(
          controller: _apiKeyCtrl,
          enabled: _editingConfig,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        const SizedBox(height: 8),
        const Text('OpenAI 模型版本', style: TextStyle(fontWeight: FontWeight.bold)),
        // Remove underline border for model input
        TextField(
          controller: _modelCtrl,
          enabled: _editingConfig,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        const SizedBox(height: 8),
        const Text('OpenAI 接口地址', style: TextStyle(fontWeight: FontWeight.bold)),
        // Remove underline border for endpoint input
        TextField(
          controller: _endpointCtrl,
          enabled: _editingConfig,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        const SizedBox(height: 8),
        const Text('首页查询时间窗（小时）', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _recentHoursCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        const SizedBox(height: 8),
        const Text('长周期总览显示阈值（条）', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _overviewThresholdCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none),
        ),

        const SizedBox(height: 8),
        // DeepSeek API key input
        const Text('DeepSeek 密钥', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _deepseekKeyCtrl,
          enabled: _editingConfig,
          decoration: const InputDecoration(border: InputBorder.none),
        ),

        const SizedBox(height: 8),
        // DeepSeek model dropdown. When the models list is being loaded, show a
        // hint; otherwise provide a dropdown for selection. If editing is
        // disabled, the dropdown is disabled.
        const Text('DeepSeek 模型', style: TextStyle(fontWeight: FontWeight.bold)),
        _loadingDeepseek
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('正在加载模型列表...', style: TextStyle(color: Colors.grey)),
              )
            : DropdownButton<String>(
                isExpanded: true,
                value: _selectedDeepseekModel,
                onChanged: (_editingConfig && _deepseekModels.isNotEmpty)
                    ? (String? v) {
                        if (v == null) return;
                        setState(() {
                          _selectedDeepseekModel = v;
                        });
                        // Persist immediately when user selects; this ensures
                        // TranslationService picks up the new model without
                        // requiring a full save. Errors are ignored.
                        _configDao.setDeepseekModel(_normalizeDeepseekUiModel(v));
                      }
                    : null,
                items: (_deepseekModels.isNotEmpty
                        ? _deepseekModels
                        : <String>{..._officialDeepseekModels, _selectedDeepseekModel}.toList())
                    .map<DropdownMenuItem<String>>((String m) {
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Text(m),
                  );
                }).toList(),
              ),

        const SizedBox(height: 8),
        const Text('OpenRouter 密钥', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _openRouterKeyCtrl,
          enabled: _editingConfig,
          obscureText: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'sk-or-... ',
          ),
        ),

        const SizedBox(height: 8),
        const Text('Eden AI 密钥', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _edenAiKeyCtrl,
          enabled: _editingConfig,
          obscureText: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Eden AI API Key / Bearer Token',
          ),
        ),

        const SizedBox(height: 8),
        const Text('xGrok 密钥', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _xGrokKeyCtrl,
          enabled: _editingConfig,
          obscureText: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'xAI / Grok API Key',
          ),
        ),

        const SizedBox(height: 8),
        const Text('Gemini 密钥', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _geminiKeyCtrl,
          enabled: _editingConfig,
          obscureText: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Google AI Studio Gemini API Key',
          ),
        ),

        const SizedBox(height: 12),
        const Divider(),
        _buildAzureResourceSection(),
        const Divider(),

        const SizedBox(height: 8),
        const Text('YouTube Data API Key（全球音乐搜索）', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _youtubeApiKeyCtrl,
          enabled: _editingConfig,
          obscureText: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Google Cloud 中启用 YouTube Data API v3 后生成的 API Key',
          ),
        ),
        const Text(
          '用于发现之旅 > 听音乐：搜索 YouTube 音乐视频并使用官方嵌入播放器播放。建议在 Google Cloud 限制此 Key 只能调用 YouTube Data API v3。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const SizedBox(height: 8),
        const Text('Jamendo Client ID（开放音乐，可选）', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _jamendoClientIdCtrl,
          enabled: _editingConfig,
          obscureText: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '可选；填写后“开放音乐”会额外搜索 Jamendo 独立音乐',
          ),
        ),
        const Text(
          '不填写也可以使用 Internet Archive 开放音乐源；开放音乐源支持 App 切后台继续播放。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const SizedBox(height: 8),
        const Text('酷狗开放组件 AppId（预留）', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _kugouAppIdCtrl,
          enabled: _editingConfig,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '拿到酷狗官方 SDK / 商务授权后填写',
          ),
        ),
        const SizedBox(height: 8),
        const Text('酷狗开放组件 AppKey（预留）', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _kugouAppKeyCtrl,
          enabled: _editingConfig,
          obscureText: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '拿到酷狗官方 SDK / 商务授权后填写',
          ),
        ),
        const Text(
          '当前版本先完成 YouTube 官方搜索与嵌入播放；酷狗字段只做预留，不调用非官方接口。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const SizedBox(height: 8),
        const Text('统一 AI 模型（供模块复用）', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          '首页左侧菜单中的独立模块会统一读取这里的 AI 提供方与模型版本；模块内只展示，不单独配置。OpenAI 使用本页顶部 OpenAI 密钥，DeepSeek 使用本页 DeepSeek 密钥，OpenRouter 使用本页 OpenRouter 密钥，Eden AI 使用本页 Eden AI 密钥，xGrok 使用本页 xGrok 密钥，Gemini 使用本页 Gemini 密钥，Azure / Microsoft Foundry 使用本页“Azure / Microsoft Foundry 资源”里对应资源的终结点与密钥。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text('全局 AI 提供方', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          isExpanded: true,
          value: _globalAiProvider,
          onChanged: _editingConfig
              ? (String? v) async {
                  if (v == null) return;
                  final provider = _normalizeProviderKey(v);
                  final suggested = await _globalAiSettings.getModelForProvider(provider);
                  setState(() {
                    _globalAiProvider = provider;
                    _globalAiModelRaw = suggested;
                    _globalAiModelCtrl.text = _formatGlobalAiModelDisplay(provider, suggested);
                    _ceProvider = provider;
                    _ceModelCtrl.text = suggested;
                    _ceEndpointCtrl.text = _defaultCeEndpointForProvider(provider);
                  });
                  await _fetchGlobalAiModels();
                }
              : null,
          items: const [
            DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek')),
            DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
            DropdownMenuItem(value: 'openrouter', child: Text('OpenRouter')),
            DropdownMenuItem(value: 'edenai', child: Text('Eden AI')),
            DropdownMenuItem(value: 'xgrok', child: Text('xGrok')),
            DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
            DropdownMenuItem(value: 'azure', child: Text('Azure / Microsoft Foundry')),
          ],
        ),
        if (_globalAiProvider == 'azure') ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _azureResources.where((e) => e.enabled && e.isConfigured).isEmpty
                ? '尚未配置可用的 Azure 资源：请先在上方“Azure / Microsoft Foundry 资源”里填写项目终结点与密钥，再刷新模型列表。'
                : '当前调用地址：${_azureChatEndpointPreview().isEmpty ? '待选择模型' : _azureChatEndpointPreview()}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Text('全局 AI 模型版本', style: TextStyle(fontWeight: FontWeight.bold))),
            IconButton(
              onPressed: _editingConfig && !_loadingGlobalAiModels ? _fetchGlobalAiModels : null,
              icon: _loadingGlobalAiModels
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              tooltip: '刷新模型列表',
            ),
          ],
        ),
        TextField(
          controller: _globalAiModelCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '根据上方提供方自动显示当前模型版本',
          ),
        ),
        const SizedBox(height: 8),
        const Text('可用模型列表', style: TextStyle(fontWeight: FontWeight.bold)),
        _loadingGlobalAiModels
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('正在加载模型列表...', style: TextStyle(color: Colors.grey)),
              )
            : DropdownButton<String>(
                isExpanded: true,
                value: _globalAiModels.contains(_globalAiModelRaw) ? _globalAiModelRaw : (_globalAiModels.isNotEmpty ? _globalAiModels.first : null),
                onChanged: _editingConfig && _globalAiModels.isNotEmpty
                    ? (String? v) {
                        if (v == null) return;
                        setState(() {
                          _globalAiModelRaw = v;
                          _globalAiModelCtrl.text = _formatGlobalAiModelDisplay(_globalAiProvider, v);
                          _ceModelCtrl.text = v;
                          _ceEndpointCtrl.text = _defaultCeEndpointForProvider(_globalAiProvider);
                        });
                      }
                    : null,
                items: (_globalAiModels.isNotEmpty ? _globalAiModels : (_globalAiModelRaw.trim().isEmpty ? <String>[] : <String>[_globalAiModelRaw]))
                    .map<DropdownMenuItem<String>>((String m) => DropdownMenuItem<String>(value: m, child: Text(m)))
                    .toList(),
              ),
        if (_globalAiProvider == 'azure' && _azureModelDiagnostics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Azure 模型列举提示：\n${_azureModelDiagnostics.join('\n')}',
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
          const Text(
            '常见原因：终结点填成了别的地址、密钥不属于该资源、该资源下还没有部署模型。'
            '终结点可以直接粘贴门户里的资源终结点、Foundry 项目终结点或部署页的“目标 URI”，系统会自动裁成资源根地址。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text('全局 AI 请求关键参数', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          '以下参数会作为全 app 的统一请求覆盖项。留空表示沿用各模块原本默认值；填写后会优先作用到 OpenAI、DeepSeek、OpenRouter、Eden AI、xGrok、Gemini、Azure / Microsoft Foundry 及其通过统一路径触发的模型调用。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text('统一请求超时时间（秒）', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('含义：一次 AI 请求最多等待多久。留空则沿用模块默认；值越大越适合长回答和推理模型。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _globalTimeoutCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none, hintText: '例如 90；留空则使用模块默认'),
        ),
        const SizedBox(height: 8),
        const Text('统一最大输出 Tokens', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('含义：限制模型单次最多输出多少内容。留空则沿用模块默认；数值越小越省 token，但回答可能被截断。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _globalMaxTokensCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none, hintText: '例如 2400；留空则使用模块默认'),
        ),
        const SizedBox(height: 8),
        const Text('统一 Temperature', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('含义：控制回答随机性。越低越稳定、越高越发散。留空则沿用模块默认。常见范围 0.0 - 1.0。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _globalTemperatureCtrl,
          enabled: _editingConfig,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: InputBorder.none, hintText: '例如 0.3；留空则使用模块默认'),
        ),
        const SizedBox(height: 8),
        const Text('统一 Top P', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('含义：控制候选词采样范围。数值越低越保守。留空则沿用模块默认。常见范围 0.0 - 1.0。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _globalTopPCtrl,
          enabled: _editingConfig,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: InputBorder.none, hintText: '例如 0.9；留空则使用模块默认'),
        ),
        const SizedBox(height: 8),
        const Text('统一重试次数', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('含义：请求失败后，最多额外自动重试几次。留空或填 0 表示不自动重试；Eden AI 等按次扣费平台建议保持 0，避免异常时重复扣费。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _globalRetryCountCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none, hintText: '例如 1 或 2；留空/0 表示不重试'),
        ),
        const SizedBox(height: 8),
        const Text('统一重试间隔（毫秒）', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('含义：两次自动重试之间等待多久。只有重试次数大于 0 时才会生效。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          controller: _globalRetryDelayMsCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none, hintText: '例如 800；不重试时可留空'),
        ),
        const SizedBox(height: 8),
        _aiPromptCenterEntry(),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text('概念实践引擎（统一读取全局 AI 配置）', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          '该模块不再单独配置模型提供商、模型版本、接口地址与请求超时，而是统一读取上方“全局 AI 提供方 / 模型版本”。这里只保留传输模式、代理、Prompt 模板与 AI 参数。',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text('当前实践引擎来源', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          '${_providerDisplayName(_globalAiProvider)} · ${_globalAiModelCtrl.text.trim().isEmpty ? '未选择模型' : _globalAiModelCtrl.text.trim()}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text('传输模式', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          isExpanded: true,
          value: _ceTransportMode,
          onChanged: _editingConfig
              ? (v) {
                  if (v == null) return;
                  setState(() => _ceTransportMode = v);
                }
              : null,
          items: const [
            DropdownMenuItem(value: ConceptEngineService.transportDirect, child: Text('客户端直连模型提供商')),
            DropdownMenuItem(value: ConceptEngineService.transportProxy, child: Text('通过后端统一 AI 网关代理')),
          ],
        ),
        if (_ceTransportMode == ConceptEngineService.transportProxy) ...[
          const SizedBox(height: 8),
          const Text('AI 网关地址', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _ceProxyEndpointCtrl,
            enabled: _editingConfig,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '例如：https://your-domain.com/api/concept-engine/proxy',
            ),
          ),
          const SizedBox(height: 8),
          const Text('AI 网关令牌（可选）', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _ceProxyTokenCtrl,
            enabled: _editingConfig,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '如果后端代理需要鉴权，可在这里填写 Bearer Token',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '代理模式下，概念实践引擎优先请求你的后端 API，由后端再统一调用 DeepSeek / OpenAI / OpenRouter / Eden AI / xGrok / Gemini。这样更适合正式上线，便于保护密钥、统一日志与服务端规则控制。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _editingConfig && !_checkingCeGateway ? _testConceptEngineGateway : null,
                icon: _checkingCeGateway
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_checkingCeGateway ? '测试中…' : '测试 AI 网关'),
              ),
              const SizedBox(width: 12),
              if (_ceGatewayCheckMessage != null)
                Expanded(
                  child: Text(
                    _ceGatewayCheckMessage!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _ceGatewayCheckOk == true ? Colors.green : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Text('请求超时', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('已移除单独配置，统一使用模块内默认超时与全局 AI 路径。', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('场景候选数', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _ceSceneCountCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        const SizedBox(height: 8),
        const Text('建议互动轮次', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _ceTurnTargetCtrl,
          enabled: _editingConfig,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        const SizedBox(height: 8),
        const Text('Prompt 追加约束', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _cePromptExtraCtrl,
          enabled: _editingConfig,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '可填写模块特定的补充约束，例如输出风格、行业场景、评分偏好等。',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '当前正在编辑 ${_providerDisplayName(_ceProvider)} 的 Prompt 配置；它会跟随上方全局 AI 提供方同步切换。保存后，返回对应页面点击“重新解析 / 重新生成”才会按新配置再次调用 AI。',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '新手建议：先点“填入默认”，只改 1-2 条你最关心的规则；务必保留“请只输出 json”和 schema 结构。\n\n常用步骤：1）先保存设置；2）回到功能页点击重新解析/重新生成；3）若结果不理想，优先改数量要求、输出风格和约束；4）如果返回格式错乱，直接恢复默认模板。',
            style: TextStyle(fontSize: 12, color: Color(0xFF7C5A03), height: 1.55),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '模板状态：当前提供商 ${_providerDisplayName(_ceProvider)}；当前传输模式 ${_ceTransportMode == ConceptEngineService.transportProxy ? '后端网关代理' : '客户端直连'}；当前配置长度 - 解析 ${_cePromptParseCtrl.text.trim().length} / 场景 ${_cePromptSceneCtrl.text.trim().length} / 互动 ${_cePromptTurnCtrl.text.trim().length} / 复盘 ${_cePromptReplayCtrl.text.trim().length} / 行为行动链 ${_cePromptBehaviorChainCtrl.text.trim().length}。'
            '参数状态：解析最少直观语言 ${_ceParseMinIntuitiveCtrl.text.trim().isEmpty ? '10' : _ceParseMinIntuitiveCtrl.text.trim()} 条、行为表现 ${_ceParseMinBehaviorsCtrl.text.trim().isEmpty ? '10' : _ceParseMinBehaviorsCtrl.text.trim()} 条；行动链节点 ${_ceBehaviorChainMinNodesCtrl.text.trim().isEmpty ? '4' : _ceBehaviorChainMinNodesCtrl.text.trim()}-${_ceBehaviorChainMaxNodesCtrl.text.trim().isEmpty ? '8' : _ceBehaviorChainMaxNodesCtrl.text.trim()}。'
            '留空表示使用内置默认模板；“回滚上一版”会恢复上一次保存前的 ${_providerDisplayName(_ceProvider)} 模板内容；也可进入单个模板的版本面板查看默认 / 当前 / 上一版。',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('AI 参数配置（修改后下一次调用生效）', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text(
              '这些参数不再写死在代码中。建议先用默认值，只在你明确知道要增加数量、节点数或输出长度时再调整。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            children: [
              const SizedBox(height: 8),
              const Text('解析结果参数', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('最少直观语言条数', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceParseMinIntuitiveCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 10')),
              const SizedBox(height: 4),
              const Text('最少行为表现条数', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceParseMinBehaviorsCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 10')),
              const SizedBox(height: 4),
              const Text('解析重试次数', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceParseRetryCountCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 2')),
              const SizedBox(height: 8),
              const Text('行为行动链参数', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('行动链最少节点数', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceBehaviorChainMinNodesCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 4')),
              const SizedBox(height: 4),
              const Text('行动链最多节点数', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceBehaviorChainMaxNodesCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 8')),
              const SizedBox(height: 8),
              const Text('模型输出长度（max tokens）', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('概念解析 max tokens', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceParseMaxTokensCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 3200')),
              const SizedBox(height: 4),
              const Text('场景生成 max tokens', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceSceneMaxTokensCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 4000')),
              const SizedBox(height: 4),
              const Text('互动推进 max tokens', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceTurnMaxTokensCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 2500')),
              const SizedBox(height: 4),
              const Text('复盘 max tokens', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceReplayMaxTokensCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 3500')),
              const SizedBox(height: 4),
              const Text('行为行动链 max tokens', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _ceBehaviorChainMaxTokensCtrl, enabled: _editingConfig, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: '默认 2200')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Prompt 模板配置（留空使用默认模板）', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '当前编辑的是 ${_providerDisplayName(_ceProvider)} 独立 Prompt 模板。可使用 {{sceneCount}}、{{turnTarget}}、{{parseMinIntuitive}}、{{parseMinBehaviors}}、{{behaviorChainMinNodes}}、{{behaviorChainMaxNodes}}、{{promptExtra}}、{{promptExtraLine}}、{{provider}}、{{providerLabel}} 占位符。',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('概念解析 Prompt', style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => _showPromptVersionDialog('parse_template', '概念解析 Prompt'), child: const Text('版本面板')),
                  TextButton(onPressed: _editingConfig ? () => setState(() => _cePromptParseCtrl.text = _ceDefaultTemplate('parse_template')) : null, child: const Text('填入默认')),
                ],
              ),
              TextField(
                controller: _cePromptParseCtrl,
                enabled: _editingConfig,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '留空使用默认模板。建议保留“请只输出 json”和 schema 说明。',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('场景生成 Prompt', style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => _showPromptVersionDialog('scene_template', '场景生成 Prompt'), child: const Text('版本面板')),
                  TextButton(onPressed: _editingConfig ? () => setState(() => _cePromptSceneCtrl.text = _ceDefaultTemplate('scene_template')) : null, child: const Text('填入默认')),
                ],
              ),
              TextField(
                controller: _cePromptSceneCtrl,
                enabled: _editingConfig,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '留空使用默认模板。可用 {{sceneCount}}。',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('互动推进 Prompt', style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => _showPromptVersionDialog('turn_template', '互动推进 Prompt'), child: const Text('版本面板')),
                  TextButton(onPressed: _editingConfig ? () => setState(() => _cePromptTurnCtrl.text = _ceDefaultTemplate('turn_template')) : null, child: const Text('填入默认')),
                ],
              ),
              TextField(
                controller: _cePromptTurnCtrl,
                enabled: _editingConfig,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '留空使用默认模板。可用 {{turnTarget}}。',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('复盘 Prompt', style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => _showPromptVersionDialog('replay_template', '复盘 Prompt'), child: const Text('版本面板')),
                  TextButton(onPressed: _editingConfig ? () => setState(() => _cePromptReplayCtrl.text = _ceDefaultTemplate('replay_template')) : null, child: const Text('填入默认')),
                ],
              ),
              TextField(
                controller: _cePromptReplayCtrl,
                enabled: _editingConfig,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '留空使用默认模板。',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('行为行动链 Prompt', style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => _showPromptVersionDialog('behavior_chain_template', '行为行动链 Prompt'), child: const Text('版本面板')),
                  TextButton(onPressed: _editingConfig ? () => setState(() => _cePromptBehaviorChainCtrl.text = _ceDefaultTemplate('behavior_chain_template')) : null, child: const Text('填入默认')),
                ],
              ),
              TextField(
                controller: _cePromptBehaviorChainCtrl,
                enabled: _editingConfig,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '留空使用默认模板。可用 {{behaviorChainMinNodes}} / {{behaviorChainMaxNodes}}。',
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _editingConfig ? _rollbackConceptEnginePromptVersion : null,
                    icon: const Icon(Icons.history_toggle_off),
                    label: Text('回滚上一版（${_providerDisplayName(_ceProvider)}）'),
                  ),
                  TextButton.icon(
                    onPressed: _editingConfig
                        ? () {
                            setState(() {
                              _cePromptParseCtrl.clear();
                              _cePromptSceneCtrl.clear();
                              _cePromptTurnCtrl.clear();
                              _cePromptReplayCtrl.clear();
                              _cePromptBehaviorChainCtrl.clear();
                            });
                          }
                        : null,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('清空并恢复默认'),
                  ),
                ],
              ),
            ],
          ),
        ),

      ],
    );

    return Scaffold(backgroundColor: Colors.white,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // Remove the default bottom divider by specifying a zero-height bottom
        bottom: const PreferredSize(preferredSize: Size.fromHeight(0), child: SizedBox()),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Material(
            color: Colors.white,
            elevation: 6,
            shape: const CircleBorder(),
            child: IconButton(
              icon: Icon(_editingConfig ? Icons.save : Icons.edit, color: Colors.black87),
              onPressed: () async {
                if (_editingConfig) {
                  // 如果处于编辑状态，保存配置并退出编辑模式（保存函数内部已处理 _editingConfig=false）
                  await _saveConfig();
                } else {
                  // 当前非编辑状态，进入编辑模式
                  setState(() => _editingConfig = true);
                }
              },
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Material(
              color: Colors.white,
              elevation: 6,
              shape: const CircleBorder(),
              child: IconButton(onPressed: ()=> _openTaskDialog(), icon: const Icon(Icons.add, color: Colors.black87)),
            ),
          ),
        ],
      ),
      body: Padding(
        // Remove top and bottom padding; keep horizontal padding only
        padding: const EdgeInsets.only(left: 12.0, right: 12.0),
        child: ListView(children: [
          ListTile(title: const Text('日记设置'), trailing: const Icon(Icons.chevron_right), onTap: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=>const DiarySettingsPage())); },),
          ListTile(
            title: const Text('语义一致性精判配置'),
            subtitle: const Text('Embedding、LLM Judge、严格事实抽取、标题忠实性、Reranker 精排配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SemanticConsistencySettingsPage()));
              await _load();
            },
          ),
          ListTile(
            title: const Text('健康饮食配置'),
            subtitle: const Text('发现之旅 / 生理赋能 / 饮食：营养膳食、食物数据源、菜谱 API 与医学风险提示'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthDietSettingsPage()));
              await _load();
            },
          ),
          ListTile(
            title: const Text('电影角色实验室配置'),
            subtitle: const Text('OpenSubtitles / TMDb 密钥、字幕语言与后续模块配置入口'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieRoleLabSettingsPage()));
              await _load();
            },
          ),
          ListTile(
            title: const Text('语音与美好的祝福配置'),
            subtitle: const Text('ElevenLabs API Key、声音克隆、TTS 文件库、美好的祝福声音绑定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceLabHomePage()));
              await _load();
            },
          ),
          ListTile(
            title: const Text('电影分析提示词配置'),
            subtitle: const Text('配置“发现之旅/看电影”每部电影卡片上的 AI 深度分析默认提示词'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiPromptSettingsPage(
                    initialModuleId: 'movie_watch',
                    initialPromptId: 'movie_analysis',
                  ),
                ),
              );
              await _load();
            },
          ),
          SwitchListTile(
            title: const Text('首页侧栏 AI 主题开关'),
            subtitle: const Text('默认关闭；关闭时展开左侧菜单只使用本地随机主题，不会调用 AI。开启后才会调用 AI 生成侧栏标题与简介。'),
            value: _drawerHeaderAiEnabled,
            onChanged: (bool value) async {
              setState(() => _drawerHeaderAiEnabled = value);
              await _globalAiSettings.setDrawerHeaderAiEnabled(value);
              showToast(value ? '已开启首页侧栏 AI 主题' : '已关闭首页侧栏 AI 主题');
            },
          ),
          ListTile(
            title: const Text('首页侧栏 AI 标题提示词配置'),
            subtitle: const Text('配置开启“首页侧栏 AI 主题”后，每次展开左侧菜单时生成标题与简介的轻量提示词'),
            trailing: const Icon(Icons.chevron_right),
            enabled: _drawerHeaderAiEnabled,
            onTap: _drawerHeaderAiEnabled
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiPromptSettingsPage(
                          initialModuleId: 'app_shell',
                          initialPromptId: 'drawer_header',
                        ),
                      ),
                    );
                    await _load();
                  }
                : null,
          ),
          Divider(),
            
            // 配置字段
            cfgFields,
            const SizedBox(height: 16),
            // 量表自动报告开关与模板导入配置卡片
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 自动报告开关
                  SwitchListTile(
                    title: const Text('量表自动报告开关'),
                    subtitle: const Text('开启后，提交问卷时将调用大模型生成报告（暂未实现）'),
                    value: _autoReportEnabled,
                    onChanged: _loadingAutoReport
                        ? null
                        : (bool value) async {
                            // 即刻更新 UI
                            setState(() {
                              _autoReportEnabled = value;
                            });
                            await _configDao.setAutoReportEnabled(value);
                            showToast(value ? '已开启量表自动报告' : '已关闭量表自动报告');
                          },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('上传量表模板文件', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedFileName ?? '请选择 .xlsx 文件',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _pickExcelFile(),
                              child: const Text('选择文件'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _importExcel(),
                          child: const Text('导入'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 火种：复问通知开关
            Card(
              child: SwitchListTile(
                key: const ValueKey<String>('settings_kindling_reask_notify'),
                title: const Text('火种：「说不准」7 天后提醒一次'),
                subtitle: const Text('默认关闭。关闭时不发通知，下次打开火种仍会问一次'),
                value: _kindlingReaskNotifyEnabled,
                onChanged: (bool value) async {
                  setState(() {
                    _kindlingReaskNotifyEnabled = value;
                  });
                  await KindlingHostReminder.setEnabled(value);
                  if (value) {
                    await NotificationService.request();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            // 发现之旅“此时此刻心情卡片”配置卡片
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('发现之旅：自动弹出此时此刻心情卡片'),
                    subtitle: const Text('开启后，点击底部“发现之旅”会按下方延迟自动弹出心情记录卡片'),
                    value: _moodCardPopupEnabled,
                    onChanged: _editingConfig
                        ? (bool value) async {
                            setState(() {
                              _moodCardPopupEnabled = value;
                            });
                            await _configDao.setMoodCardPopupEnabled(value);
                            showToast(value ? '已开启心情卡片自动弹出' : '已关闭心情卡片自动弹出');
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _moodCardDelayMsCtrl,
                      enabled: _editingConfig && _moodCardPopupEnabled,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '心情卡片弹出延迟时间（毫秒）',
                        helperText: '0 表示立即弹出；建议 2000～8000；最大 60000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // EMA / SSES 配置卡片
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EMA 开关
                  SwitchListTile(
                    title: const Text('启用即时自尊问答（EMA/SSES）'),
                    subtitle: const Text('开启后记录情绪时会额外弹出自尊题目'),
                    value: _emaEnabled,
                    onChanged: (bool value) async {
                      // Persist the new setting first; if it fails, keep the old state
                      try {
                        await _configDao.setEmaEnabled(value);
                        // only update local state after persistence succeeds
                        if (!mounted) return;
                        setState(() {
                          _emaEnabled = value;
                        });
                        showToast(value ? '已开启自尊问答' : '已关闭自尊问答');
                      } catch (_) {
                        // ignore failures silently
                      }
                    },
                  ),
                  const Divider(height: 1),
                  // 自尊评分尺度选择
                  ListTile(
                    title: const Text('自尊评分尺度'),
                    subtitle: const Text('选择 100 分制或 30 分制'),
                    trailing: DropdownButton<int>(
                      value: _esteemScale,
                      items: const [
                        DropdownMenuItem<int>(value: 100, child: Text('100 分制')),
                        DropdownMenuItem<int>(value: 30, child: Text('30 分制')),
                      ],
                      onChanged: (int? val) async {
                        if (val == null) return;
                        try {
                          // Persist scale first
                          await _configDao.setSelfEsteemScale(val);
                          if (!mounted) return;
                          setState(() {
                            _esteemScale = val;
                          });
                          showToast('已设置自尊评分尺度为 $val');
                        } catch (_) {
                          // ignore errors
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 运动设置卡片（背景图 + 开始铃声）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('运动设置', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('运动进行时背景图片'),
                      subtitle: Text(
                        _sportMusicList.isEmpty
                            ? '请先设置运动进行时音乐'
                            : '已为 ${_sportMusicBgBindings.values.where((e) => e.isNotEmpty).length} 首音乐绑定背景图；未设置时运行页恢复默认背景色',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: _editingConfig ? _manageSportMusicBgBindings : null, child: const Text('设置')),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('运动开始铃声'),
                      subtitle: Text(_sportSoundPath == null || _sportSoundPath!.isEmpty ? '系统通知铃声（默认）' : p.basename(_sportSoundPath!)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: _editingConfig ? _pickSportStartSound : null, child: const Text('选择')),
                          if (_sportSoundPath != null && _sportSoundPath!.isNotEmpty)
                            TextButton(onPressed: _editingConfig ? _clearSportStartSound : null, child: const Text('清除')),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('运动进行时音乐播放清单'),
                      subtitle: Text(
                        _sportMusicList.isEmpty
                            ? '未设置'
                            : '${_sportMusicList.length} 首：' + _sportMusicList.take(3).map((e) => p.basename(e)).join('、') + (_sportMusicList.length > 3 ? '…' : ''),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: _editingConfig ? _pickSportMusicPlaylist : null, child: const Text('选择')),
                          if (_sportMusicList.isNotEmpty)
                            TextButton(onPressed: _editingConfig ? _manageSportMusicPlaylist : null, child: const Text('管理')),
                          if (_sportMusicList.isNotEmpty)
                            TextButton(onPressed: _editingConfig ? _clearSportMusicPlaylist : null, child: const Text('清除')),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 16),
                        const Text('播放模式', style: TextStyle(color: Colors.black87)),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: (_sportMusicMode == 'random') ? 'random' : 'order',
                          onChanged: _editingConfig
                              ? (v) {
                                  if (v != null) _setSportMusicMode(v);
                                }
                              : null,
                          items: const [
                            DropdownMenuItem(value: 'order', child: Text('顺序循环')),
                            DropdownMenuItem(value: 'random', child: Text('随机循环')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('说明：未设置铃声时，运动倒计时结束会播放系统通知铃声；播放清单只在运动正式开始后循环播放。每首运行时音乐可绑定 0~N 张背景图，多张背景图会在运行页按固定间隔自动轮播；未绑定背景图时恢复默认背景色。删除某个运行时音乐时，其绑定的背景图会一并移除。', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 解锁提醒冷却时间设置卡片
            const UnlockCooldownConfigWidget(),
            const SizedBox(height: 16),

            // 百度 AK 设置卡片（Web / Android）
            const BaiduWebAkConfigWidget(),
            const SizedBox(height: 12),
            const BaiduAndroidAkConfigWidget(),
            const SizedBox(height: 16),

            const Text('任务列表', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final t in _tasks)
              ListTile(
                title: InkWell(
                  onTap: () => _openTaskDialog(task: t),
                  child: Text((t['name'] ?? '') as String, style: const TextStyle(decoration: TextDecoration.underline)),
                ),
                subtitle: Text('时间: ${(t['start_time'] ?? '') as String}   下一次: ${((t['next_time'] ?? '') as String).toString().replaceFirst('T', ' ').split('.').first}   频率: ${(t['freq_type'] ?? '') as String}  状态: ${(t['status'] ?? '') as String}'),
              ),
          ],
        ),
      ),

    );
  }
}

class _SelfCheckConfigWidget extends StatefulWidget {
  const _SelfCheckConfigWidget({super.key});
  @override
  State<_SelfCheckConfigWidget> createState() => _SelfCheckConfigWidgetState();
}
class _SelfCheckConfigWidgetState extends State<_SelfCheckConfigWidget> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final minutes = await NotifyConfigDao().getSelfCheckMinutes();
    setState(() { _ctrl.text = minutes.toString(); _loading=false; });
  }
  Future<void> _save() async {
    final m = int.tryParse(_ctrl.text) ?? 15;
    await NotifyConfigDao().setSelfCheckMinutes(m);
    await SchedulerService.scheduleSelfCheck();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存（自检功能已禁用，不会注册周期任务）')));
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('自检频率（分钟）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '>=15')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _save, child: const Text('保存并生效')),
          ],
        ),
      ),
    );
  }
}



class RecentHoursWidget extends StatefulWidget {
  const RecentHoursWidget({super.key});
  @override
  State<RecentHoursWidget> createState() => _RecentHoursWidgetState();
}
class _RecentHoursWidgetState extends State<RecentHoursWidget> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final h = await ConfigDao().getRecentHours();
    setState(() { _ctrl.text = h.toString(); _loading = false; });
  }
  Future<void> _save() async {
    final h = int.tryParse(_ctrl.text.trim()) ?? 2;
    await ConfigDao().setRecentHours(h);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存最近小时数')));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('首页查询时间窗（小时）', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '默认 2（单位：小时）',
              ),
            ),
            const SizedBox(height: 8),
            const Text('说明：只查询“今日且最近 N 小时内”的通知记录（notified=1）。'),
            const SizedBox(height: 8),
            Row(children:[
              ElevatedButton(onPressed: _save, child: const Text('保存')),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 解锁提醒冷却时间配置控件。
/// 允许用户设置解锁触发愿景提醒的冷却间隔（分钟或天）。
class UnlockCooldownConfigWidget extends StatefulWidget {
  const UnlockCooldownConfigWidget({super.key});
  @override
  State<UnlockCooldownConfigWidget> createState() => _UnlockCooldownConfigWidgetState();
}

class _UnlockCooldownConfigWidgetState extends State<UnlockCooldownConfigWidget> {
  final _minutesCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final dao = NotifyConfigDao();
    final mins = await dao.getUnlockCooldownMinutes();
    final days = await dao.getUnlockCooldownDays();
    // 如果 days > 0，则优先显示 days；否则显示 mins
    if (days > 0) {
      _daysCtrl.text = days.toString();
      _minutesCtrl.text = '';
    } else {
      _minutesCtrl.text = mins.toString();
      _daysCtrl.text = '';
    }
    if (mounted) setState(() { _loading = false; });
  }
  @override
  void dispose() {
    _minutesCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }
  Future<void> _save() async {
    final dao = NotifyConfigDao();
    // 优先取天数
    final dStr = _daysCtrl.text.trim();
    if (dStr.isNotEmpty) {
      final d = double.tryParse(dStr);
      if (d != null && d > 0) {
        await dao.setUnlockCooldown(days: d);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存解锁冷却时间（天）')));
        return;
      }
    }
    final mStr = _minutesCtrl.text.trim();
    if (mStr.isNotEmpty) {
      final m = int.tryParse(mStr);
      if (m != null && m > 0) {
        await dao.setUnlockCooldown(minutes: m);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存解锁冷却时间（分钟）')));
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的冷却时间')));
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('解锁提醒冷却时间', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '分钟',
                      hintText: '默认 30',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _daysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '天',
                      hintText: '可选',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 百度 Web AK 配置控件（用于 Web API：逆地理/Place/IP 等）
class BaiduWebAkConfigWidget extends StatefulWidget {
  const BaiduWebAkConfigWidget({super.key});
  @override
  State<BaiduWebAkConfigWidget> createState() => _BaiduWebAkConfigWidgetState();
}

class _BaiduWebAkConfigWidgetState extends State<BaiduWebAkConfigWidget> {
  final _akCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ak = await ConfigDao().getBaiduAk();
    _akCtrl.text = ak;
    if (mounted) setState(() { _loading = false; });
  }

  @override
  void dispose() {
    _akCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ak = _akCtrl.text.trim();
    await ConfigDao().setBaiduAk(ak);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存百度 Web AK')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('百度 Web AK', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('用于：Web 逆地理、Place 周边检索、IP 定位等（不依赖包名/SHA1）。', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _akCtrl,
              decoration: const InputDecoration(
                hintText: '输入 Baidu Web API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [ElevatedButton(onPressed: _save, child: const Text('保存'))]),
          ],
        ),
      ),
    );
  }
}

/// 百度 Android AK 配置控件（用于 Baidu SDK：定位/搜索 SDK）
class BaiduAndroidAkConfigWidget extends StatefulWidget {
  const BaiduAndroidAkConfigWidget({super.key});
  @override
  State<BaiduAndroidAkConfigWidget> createState() => _BaiduAndroidAkConfigWidgetState();
}

class _BaiduAndroidAkConfigWidgetState extends State<BaiduAndroidAkConfigWidget> {
  final _akCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ak = await ConfigDao().getBaiduAndroidAk();
    _akCtrl.text = ak;
    if (mounted) setState(() { _loading = false; });
  }

  @override
  void dispose() {
    _akCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ak = _akCtrl.text.trim();
    await ConfigDao().setBaiduAndroidAk(ak);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存百度 Android AK（重启 App 后生效）')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('百度 Android AK', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('用于：Baidu Location/Map/Search SDK（必须在百度控制台绑定：包名 + SHA1）。', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _akCtrl,
              decoration: const InputDecoration(
                hintText: '输入 Baidu Android SDK Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [ElevatedButton(onPressed: _save, child: const Text('保存'))]),
          ],
        ),
      ),
    );
  }
}

/// Azure / Microsoft Foundry 单个资源的编辑弹窗。
///
/// 资源表在设置页里是动态列表，把每条记录的输入框放到独立弹窗里维护，
/// 可以避免为不定数量的资源在页面上持有一堆 TextEditingController。
class _AzureResourceEditorDialog extends StatefulWidget {
  const _AzureResourceEditorDialog({this.resource});

  final AzureAiResource? resource;

  @override
  State<_AzureResourceEditorDialog> createState() => _AzureResourceEditorDialogState();
}

class _AzureResourceEditorDialogState extends State<_AzureResourceEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _apiVersionCtrl;
  late final TextEditingController _deploymentsCtrl;
  late String _kind;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final resource = widget.resource;
    _nameCtrl = TextEditingController(text: resource?.name ?? '');
    _endpointCtrl = TextEditingController(text: resource?.endpoint ?? '');
    _apiKeyCtrl = TextEditingController(text: resource?.apiKey ?? '');
    _apiVersionCtrl = TextEditingController(text: resource?.apiVersion ?? '');
    _deploymentsCtrl = TextEditingController(text: (resource?.deployments ?? const <String>[]).join(', '));
    _kind = AzureAiSettings.normalizeKind(resource?.kind ?? AzureAiSettings.kindAuto);
    _enabled = resource?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _endpointCtrl.dispose();
    _apiKeyCtrl.dispose();
    _apiVersionCtrl.dispose();
    _deploymentsCtrl.dispose();
    super.dispose();
  }

  /// 实时预览归一化后的资源根地址与调用地址，方便用户确认终结点填对了。
  AzureAiResource get _preview => AzureAiResource(
        id: widget.resource?.id ?? '',
        name: _nameCtrl.text,
        endpoint: _endpointCtrl.text,
        apiKey: _apiKeyCtrl.text,
        apiVersion: _apiVersionCtrl.text,
        kind: _kind,
        deployments: AzureAiSettings.parseDeploymentInput(_deploymentsCtrl.text),
        enabled: _enabled,
      );

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final sampleDeployment = preview.deployments.isEmpty ? '<部署名>' : preview.deployments.first;
    final candidates = preview.chatEndpointCandidates(sampleDeployment);
    return AlertDialog(
      title: Text(widget.resource == null ? '添加 Azure 资源' : '编辑 Azure 资源'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('资源/项目名称', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '例如 AzureOpenAI、modleapikey'),
            ),
            const Text(
              '模型列表里会显示成“资源名/部署名”，用于区分不同项目里的同名部署。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text('Microsoft Foundry 项目终结点 / Azure OpenAI 终结点',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _endpointCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'https://xxx.services.ai.azure.com/api/projects/yyy',
              ),
            ),
            const Text(
              '两种写法都支持：Foundry 项目终结点（含 /api/projects/…）或 Azure OpenAI 终结点'
              '（https://xxx.openai.azure.com）。系统会自动归一化出资源根地址。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text('API 密钥', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '该资源的 Key（请求会以 api-key 头发送）'),
            ),
            const SizedBox(height: 12),
            const Text('接入方式', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: _kind,
              onChanged: (v) => setState(() => _kind = AzureAiSettings.normalizeKind(v ?? AzureAiSettings.kindAuto)),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: AzureAiSettings.kindAuto, child: Text('自动识别（按终结点判断）')),
                DropdownMenuItem(value: AzureAiSettings.kindAzureOpenAi, child: Text('Azure OpenAI 部署（gpt 系列）')),
                DropdownMenuItem(
                    value: AzureAiSettings.kindFoundryModels, child: Text('Foundry 模型推理（Claude / Grok 等）')),
              ],
            ),
            const Text(
              '只影响候选调用地址的先后顺序。实际调用时如果首选路径返回“路径/部署不存在”，会自动改用其它路径重试。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text('api-version（可留空）', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _apiVersionCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '留空则使用默认：Azure OpenAI ${AzureAiSettings.defaultAzureOpenAiApiVersion}，'
                    'Foundry ${AzureAiSettings.defaultFoundryApiVersion}',
              ),
            ),
            const SizedBox(height: 12),
            const Text('部署名（可留空，用逗号分隔）', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _deploymentsCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '例如 gpt-5.6-chat, claude-sonnet-4-5, grok-4'),
            ),
            const Text(
              '一般不用填：保存后点“刷新模型列表”会直接从该资源拉取已部署的模型。'
              '只有当订阅关闭了部署列举接口时，才需要在这里手工登记部署名作为兜底。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用该资源'),
              subtitle: const Text('停用后不参与模型列举与调用', style: TextStyle(fontSize: 12)),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const Divider(),
            const Text('解析结果预览', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '资源根地址：${preview.baseUrl.isEmpty ? '(终结点无法解析)' : preview.baseUrl}\n'
              '${preview.projectName.isEmpty ? '' : '项目名：${preview.projectName}\n'}'
              '接入方式：${preview.kindLabel}｜api-version：${preview.resolvedApiVersion}\n'
              '调用地址：${candidates.isEmpty ? '(待补全终结点)' : candidates.first}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        ElevatedButton(
          onPressed: _nameCtrl.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_preview),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

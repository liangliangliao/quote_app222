import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/exact_alarm_permission_coordinator.dart';
import '../services/health_diet_settings_service.dart';
import '../services/health_diet_daily_scheduler_service.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthDietSettingsPage extends StatefulWidget {
  const HealthDietSettingsPage({super.key});

  @override
  State<HealthDietSettingsPage> createState() => _HealthDietSettingsPageState();
}

class _HealthDietSettingsPageState extends State<HealthDietSettingsPage> {
  final _service = HealthDietSettingsService();
  final _usdaApiKeyCtrl = TextEditingController();
  final _openFoodFactsUserAgentCtrl = TextEditingController();
  final _booheeApiKeyCtrl = TextEditingController();
  final _juheBarcodeApiKeyCtrl = TextEditingController();
  final _tanshuBarcodeTokenCtrl = TextEditingController();
  final _tanshuBarcodeBasicUrlCtrl = TextEditingController();
  final _tanshuBarcodeNutritionUrlCtrl = TextEditingController();
  final _chinaBarcodeApiUrlTemplateCtrl = TextEditingController();
  final _chinaBarcodeApiKeyCtrl = TextEditingController();
  final _chinaBarcodeApiHeaderNameCtrl = TextEditingController();
  final _chinaBarcodeAppCodeCtrl = TextEditingController();
  final _edamamAppIdCtrl = TextEditingController();
  final _edamamAppKeyCtrl = TextEditingController();
  final _spoonacularApiKeyCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _aiAdviceEnabled = true;
  bool _externalApiAiTranslationEnabled = false;
  bool _medicalNoticeEnabled = true;
  bool _healthConnectEnabled = false;
  bool _agentAutopilotEnabled = true;
  bool _agentAutoAiEnabled = true;
  bool _agentAutoApiEnabled = true;
  bool _agentAutoHealthSyncEnabled = true;
  bool _agentDailyScheduleEnabled = true;
  bool _agentScheduleNotifyEnabled = true;
  bool _chinaBarcodeEnabled = true;
  bool _showSensitiveValues = false;
  String _defaultFoodSource = 'auto';
  String _defaultRecipeSource = 'auto';
  String _agentAutonomyLevel = 'L4';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usdaApiKeyCtrl.dispose();
    _openFoodFactsUserAgentCtrl.dispose();
    _booheeApiKeyCtrl.dispose();
    _juheBarcodeApiKeyCtrl.dispose();
    _tanshuBarcodeTokenCtrl.dispose();
    _tanshuBarcodeBasicUrlCtrl.dispose();
    _tanshuBarcodeNutritionUrlCtrl.dispose();
    _chinaBarcodeApiUrlTemplateCtrl.dispose();
    _chinaBarcodeApiKeyCtrl.dispose();
    _chinaBarcodeApiHeaderNameCtrl.dispose();
    _chinaBarcodeAppCodeCtrl.dispose();
    _edamamAppIdCtrl.dispose();
    _edamamAppKeyCtrl.dispose();
    _spoonacularApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await _service.load();
    if (!mounted) return;
    setState(() {
      _usdaApiKeyCtrl.text = values[HealthDietSettingsService.usdaApiKey] ?? '';
      _openFoodFactsUserAgentCtrl.text = values[HealthDietSettingsService.openFoodFactsUserAgent] ?? 'quote_app_health_diet/1.0';
      _booheeApiKeyCtrl.text = values[HealthDietSettingsService.booheeApiKey] ?? '';
      _juheBarcodeApiKeyCtrl.text = values[HealthDietSettingsService.juheBarcodeApiKey] ?? '';
      _tanshuBarcodeTokenCtrl.text = values[HealthDietSettingsService.tanshuBarcodeToken] ?? '';
      _tanshuBarcodeBasicUrlCtrl.text = values[HealthDietSettingsService.tanshuBarcodeBasicUrl] ?? 'https://www.tanshuapi.com/market/detail-77';
      _tanshuBarcodeNutritionUrlCtrl.text = values[HealthDietSettingsService.tanshuBarcodeNutritionUrl] ?? '';
      _chinaBarcodeApiUrlTemplateCtrl.text = values[HealthDietSettingsService.chinaBarcodeApiUrlTemplate] ?? '';
      _chinaBarcodeApiKeyCtrl.text = values[HealthDietSettingsService.chinaBarcodeApiKey] ?? '';
      _chinaBarcodeApiHeaderNameCtrl.text = values[HealthDietSettingsService.chinaBarcodeApiHeaderName] ?? 'X-APISpace-Token';
      _chinaBarcodeAppCodeCtrl.text = values[HealthDietSettingsService.chinaBarcodeAppCode] ?? '';
      _edamamAppIdCtrl.text = values[HealthDietSettingsService.edamamAppId] ?? '';
      _edamamAppKeyCtrl.text = values[HealthDietSettingsService.edamamAppKey] ?? '';
      _spoonacularApiKeyCtrl.text = values[HealthDietSettingsService.spoonacularApiKey] ?? '';
      _defaultFoodSource = values[HealthDietSettingsService.defaultFoodSource] ?? 'auto';
      _defaultRecipeSource = values[HealthDietSettingsService.defaultRecipeSource] ?? 'auto';
      _aiAdviceEnabled = _service.isEnabledValue(values[HealthDietSettingsService.aiAdviceEnabled]);
      _externalApiAiTranslationEnabled = _service.isEnabledValue(values[HealthDietSettingsService.externalApiAiTranslationEnabled]);
      _medicalNoticeEnabled = _service.isEnabledValue(values[HealthDietSettingsService.medicalNoticeEnabled]);
      _healthConnectEnabled = _service.isEnabledValue(values[HealthDietSettingsService.healthConnectEnabled]);
      _agentAutopilotEnabled = _service.isEnabledValue(values[HealthDietSettingsService.agentAutopilotEnabled]);
      _agentAutoAiEnabled = _service.isEnabledValue(values[HealthDietSettingsService.agentAutoAiEnabled]);
      _agentAutoApiEnabled = _service.isEnabledValue(values[HealthDietSettingsService.agentAutoApiEnabled]);
      _agentAutoHealthSyncEnabled = _service.isEnabledValue(values[HealthDietSettingsService.agentAutoHealthSyncEnabled]);
      _agentDailyScheduleEnabled = _service.isEnabledValue(values[HealthDietSettingsService.agentDailyScheduleEnabled]);
      _agentScheduleNotifyEnabled = _service.isEnabledValue(values[HealthDietSettingsService.agentScheduleNotifyEnabled]);
      _chinaBarcodeEnabled = _service.isEnabledValue(values[HealthDietSettingsService.chinaBarcodeEnabled]);
      _agentAutonomyLevel = values[HealthDietSettingsService.agentAutonomyLevel] ?? 'L4';
      _loading = false;
    });
  }


  Future<void> _pasteSecret(TextEditingController controller, String label) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('剪贴板没有可粘贴的 $label')),
      );
      return;
    }
    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已粘贴 $label')),
    );
  }

  Future<void> _save() async {
    if (_agentDailyScheduleEnabled && _agentScheduleNotifyEnabled) {
      final granted = await ExactAlarmPermissionCoordinator.ensureGranted(
        context,
        featureName: '健康饮食定时通知',
        explanation: '六个每日膳食时段会用精准闹钟发送本地提醒；完整巡检仍由后台任务执行。',
      );
      if (!granted || !mounted) return;
    }
    setState(() => _saving = true);
    await _service.save({
      HealthDietSettingsService.usdaApiKey: _usdaApiKeyCtrl.text,
      HealthDietSettingsService.openFoodFactsUserAgent: _openFoodFactsUserAgentCtrl.text,
      HealthDietSettingsService.booheeApiKey: _booheeApiKeyCtrl.text,
      HealthDietSettingsService.juheBarcodeApiKey: _juheBarcodeApiKeyCtrl.text,
      HealthDietSettingsService.tanshuBarcodeToken: _tanshuBarcodeTokenCtrl.text,
      HealthDietSettingsService.tanshuBarcodeBasicUrl: _tanshuBarcodeBasicUrlCtrl.text,
      HealthDietSettingsService.tanshuBarcodeNutritionUrl: _tanshuBarcodeNutritionUrlCtrl.text,
      HealthDietSettingsService.chinaBarcodeApiUrlTemplate: _chinaBarcodeApiUrlTemplateCtrl.text,
      HealthDietSettingsService.chinaBarcodeApiKey: _chinaBarcodeApiKeyCtrl.text,
      HealthDietSettingsService.chinaBarcodeApiHeaderName: _chinaBarcodeApiHeaderNameCtrl.text,
      HealthDietSettingsService.chinaBarcodeAppCode: _chinaBarcodeAppCodeCtrl.text,
      HealthDietSettingsService.chinaBarcodeEnabled: _chinaBarcodeEnabled ? '1' : '0',
      HealthDietSettingsService.edamamAppId: _edamamAppIdCtrl.text,
      HealthDietSettingsService.edamamAppKey: _edamamAppKeyCtrl.text,
      HealthDietSettingsService.spoonacularApiKey: _spoonacularApiKeyCtrl.text,
      HealthDietSettingsService.defaultFoodSource: _defaultFoodSource,
      HealthDietSettingsService.defaultRecipeSource: _defaultRecipeSource,
      HealthDietSettingsService.aiAdviceEnabled: _aiAdviceEnabled ? '1' : '0',
      HealthDietSettingsService.externalApiAiTranslationEnabled: _externalApiAiTranslationEnabled ? '1' : '0',
      HealthDietSettingsService.medicalNoticeEnabled: _medicalNoticeEnabled ? '1' : '0',
      HealthDietSettingsService.healthConnectEnabled: _healthConnectEnabled ? '1' : '0',
      HealthDietSettingsService.agentAutonomyLevel: _agentAutonomyLevel,
      HealthDietSettingsService.agentAutopilotEnabled: _agentAutopilotEnabled ? '1' : '0',
      HealthDietSettingsService.agentAutoAiEnabled: _agentAutoAiEnabled ? '1' : '0',
      HealthDietSettingsService.agentAutoApiEnabled: _agentAutoApiEnabled ? '1' : '0',
      HealthDietSettingsService.agentAutoHealthSyncEnabled: _agentAutoHealthSyncEnabled ? '1' : '0',
      HealthDietSettingsService.agentDailyScheduleEnabled: _agentDailyScheduleEnabled ? '1' : '0',
      HealthDietSettingsService.agentScheduleNotifyEnabled: _agentScheduleNotifyEnabled ? '1' : '0',
    });
    String? scheduleError;
    try {
      await HealthDietDailySchedulerService().syncSchedules();
    } catch (e) {
      scheduleError = e.toString();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(scheduleError == null ? '健康饮食配置已保存，定时计划已同步' : '配置已保存，但定时计划同步失败：$scheduleError')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康饮食配置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                HealthDietDataSourceBanner(
                  sources: const ['本地配置', '用户 API Key', '外部健康平台', '全局 AI Provider'],
                  updatedAt: DateTime.now(),
                  note: '本页显示的是用户配置和开关，不是营养判断结果；保存后才会被 Agent、扫码、菜谱、复盘页面读取。',
                ),
                _noticeCard(),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _showSensitiveValues,
                  onChanged: (v) => setState(() => _showSensitiveValues = v),
                  title: const Text('临时显示密钥内容'),
                  subtitle: const Text('默认隐藏所有 API Key / App ID / App Key，避免在截图、录屏或他人旁观时明文泄露。'),
                  secondary: Icon(_showSensitiveValues ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
                const SizedBox(height: 12),
                _sectionTitle('App 内置 Agent'),
                _localAgentCard(),
                const SizedBox(height: 12),
                _sectionTitle('食物数据源'),
                _secretField(_usdaApiKeyCtrl, 'USDA FoodData Central API Key', '基础食材营养数据库；为空时后续接口层可使用 DEMO_KEY 或禁用该源'),
                _textField(_openFoodFactsUserAgentCtrl, 'Open Food Facts User-Agent', '建议填写 App 名称/版本，便于开放数据库识别请求来源'),
                _secretField(_booheeApiKeyCtrl, '薄荷健康 API Key', '中文食物、中餐、条码、食物估重等数据源；正式商用以平台授权为准'),
                SwitchListTile(
                  value: _chinaBarcodeEnabled,
                  onChanged: (v) => setState(() => _chinaBarcodeEnabled = v),
                  title: const Text('启用国内条码候选源'),
                  subtitle: const Text('扫码时会在 Open Food Facts 之外，同时尝试聚合数据、探数数据和自定义国内条码接口；结果页按不同数据源分别展示。'),
                ),
                _secretField(_juheBarcodeApiKeyCtrl, '聚合数据条码查询 Key', '聚合数据条码查询接口；用于国内包装食品名称、品牌、规格等补充。'),
                _secretField(_tanshuBarcodeTokenCtrl, '探数数据 Bearer Token', '探数商品条码/成分接口 Token。若平台实际 URL 不同，可修改下面两个 URL。'),
                _textField(_tanshuBarcodeBasicUrlCtrl, '探数商品条码 URL', '默认按 POST JSON {barcode} 调用；请以平台后台实际接口地址为准。'),
                _textField(_tanshuBarcodeNutritionUrlCtrl, '探数商品成分 URL（可选）', '若平台提供单独营养成分接口，可填入；为空则只查商品基础信息。'),
                _textField(_chinaBarcodeApiUrlTemplateCtrl, '自定义国内条码接口 URL 模板', '例如：https://example.com/barcode?code={barcode}&key={key}；支持 {barcode} 和 {key} 占位。'),
                _secretField(_chinaBarcodeApiKeyCtrl, '自定义国内条码接口 Key / Token', '配合 URL 模板或 Header 使用。'),
                _textField(_chinaBarcodeApiHeaderNameCtrl, '自定义条码接口 Header 名', '例如 Authorization、X-APISpace-Token；为空时只使用 URL 模板。'),
                _secretField(_chinaBarcodeAppCodeCtrl, '阿里云市场/云市场 AppCode（可选）', '若接口要求 Authorization: APPCODE xxx，可填写；具体以购买接口文档为准。'),
                const SizedBox(height: 12),
                _sectionTitle('菜谱与膳食计划数据源'),
                _secretField(_edamamAppIdCtrl, 'Edamam App ID', '健康标签、营养分析、meal plan 相关能力'),
                _secretField(_edamamAppKeyCtrl, 'Edamam App Key', 'Edamam 密钥'),
                _secretField(_spoonacularApiKeyCtrl, 'Spoonacular API Key', '健康菜谱、制作步骤、营养与过敏原分析'),
                const SizedBox(height: 12),
                _sectionTitle('默认策略'),
                _dropdown(
                  label: '默认食物数据源',
                  value: _defaultFoodSource,
                  items: const {
                    'auto': '自动选择',
                    'boohee': '薄荷健康优先',
                    'usda': 'USDA 优先',
                    'open_food_facts': 'Open Food Facts 优先',
                    'china_barcode_first': '国内条码优先',
                  },
                  onChanged: (v) => setState(() => _defaultFoodSource = v ?? 'auto'),
                ),
                _dropdown(
                  label: '默认菜谱数据源',
                  value: _defaultRecipeSource,
                  items: const {
                    'auto': '自动选择',
                    'spoonacular': 'Spoonacular 优先',
                    'edamam': 'Edamam 优先',
                    'ai_only': '仅 AI 健康改造',
                  },
                  onChanged: (v) => setState(() => _defaultRecipeSource = v ?? 'auto'),
                ),
                SwitchListTile(
                  value: _aiAdviceEnabled,
                  onChanged: (v) => setState(() => _aiAdviceEnabled = v),
                  title: const Text('启用 AI 个性化饮食建议'),
                  subtitle: const Text('AI 参与文字/语音解析、图片识别、饮食复盘解释与菜谱健康改造；营养数值优先来自已配置 API/数据库。'),
                ),
                SwitchListTile(
                  value: _externalApiAiTranslationEnabled,
                  onChanged: (v) => setState(() => _externalApiAiTranslationEnabled = v),
                  title: const Text('外部平台英文结果用 AI 翻译'),
                  subtitle: const Text('仅建议少量手动查询时开启。自动托管/菜谱搜索会调用大量平台数据，开启后会连续消耗 token 并让日志快速刷新。默认关闭以避免卡顿。'),
                ),
                SwitchListTile(
                  value: _medicalNoticeEnabled,
                  onChanged: (v) => setState(() => _medicalNoticeEnabled = v),
                  title: const Text('显示医学风险提示'),
                  subtitle: const Text('涉及糖尿病、肾病、孕期、术后等情况时，强制提示咨询医生/营养师。'),
                ),
                SwitchListTile(
                  value: _healthConnectEnabled,
                  onChanged: (v) => setState(() => _healthConnectEnabled = v),
                  title: const Text('启用 Health Connect 身体状态联动'),
                  subtitle: const Text('第四阶段已支持读取用户授权后的步数、睡眠、运动、活动消耗和体重，并参与饮食复盘。'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('保存健康饮食配置'),
                ),
              ],
            ),
    );
  }


  Widget _localAgentCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.smart_toy_outlined, color: Colors.green),
            title: Text('启用 App 内置 Agent 编排层'),
            subtitle: Text('所有代码仍在手机 App 内运行；API Key 和模型选择仍保存在手机端，由本地 AgentService 统一读取健康档案、Health Connect、饮食分享、外部 API 和 AI 模型来生成方案。'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _agentAutonomyLevel,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Agent 主动等级'),
            items: const {
              'L1': 'L1 只分析，不主动安排',
              'L2': 'L2 主动建议，但不自动写任务',
              'L3': 'L3 自动调用 API/生成复盘/主动安排',
              'L4': 'L4 自动托管：同步/API/AI/复盘/记忆',
            }.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _agentAutonomyLevel = v ?? 'L4'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _agentAutopilotEnabled,
            onChanged: (v) => setState(() => _agentAutopilotEnabled = v),
            title: const Text('开启自动托管巡检'),
            subtitle: const Text('打开 AI 营养膳食专家页或每日定时任务到点时自动执行：同步身体数据、调用健康平台 API、生成复盘和方案。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _agentAutoApiEnabled,
            onChanged: (v) => setState(() => _agentAutoApiEnabled = v),
            title: const Text('自动调用营养/菜谱 API'),
            subtitle: const Text('自动尝试 USDA、Open Food Facts、Spoonacular、Edamam，并缓存到本地数据库。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _agentAutoAiEnabled,
            onChanged: (v) => setState(() => _agentAutoAiEnabled = v),
            title: const Text('自动调用 AI 完成专家分析'),
            subtitle: const Text('使用全局 AI Provider / 模型配置；会消耗用户选择模型的 token 或额度。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _agentAutoHealthSyncEnabled,
            onChanged: (v) => setState(() => _agentAutoHealthSyncEnabled = v),
            title: const Text('自动同步 Health Connect'),
            subtitle: const Text('仅在用户已手动授权后自动读取；不会在后台强行弹出权限请求。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _agentDailyScheduleEnabled,
            onChanged: (v) async {
              if (v && _agentScheduleNotifyEnabled) {
                final granted = await ExactAlarmPermissionCoordinator.ensureGranted(
                  context,
                  featureName: '健康饮食定时通知',
                  explanation: '开启每日托管后，六个膳食时段需要准时提醒。',
                );
                if (!granted || !mounted) return;
              }
              setState(() => _agentDailyScheduleEnabled = v);
            },
            title: const Text('开启每日定时膳食托管'),
            subtitle: const Text('按 08:00、10:30、12:00、15:30、18:00、21:30 自动巡检：安排饮食、检查记录、动态调整下一餐、生成晚间复盘。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _agentScheduleNotifyEnabled,
            onChanged: (v) async {
              if (v && _agentDailyScheduleEnabled) {
                final granted = await ExactAlarmPermissionCoordinator.ensureGranted(
                  context,
                  featureName: '健康饮食定时通知',
                  explanation: '到点通知采用精准闹钟，系统限制后台运行时仍能直接提醒。',
                );
                if (!granted || !mounted) return;
              }
              setState(() => _agentScheduleNotifyEnabled = v);
            },
            title: const Text('定时托管完成后发送通知'),
            subtitle: const Text('后台任务可用时发送本地通知；如果系统限制后台运行，打开健康饮食模块时会自动补跑到点任务。'),
          ),
          const SizedBox(height: 10),
          const Text(
            '提示：当前是手机 App 内置自动托管模式，不需要服务器地址。API Key 和模型选择仍保存在手机端；Agent 会在模块打开或每日定时任务到点时自动调用外部 AI / USDA / Open Food Facts / Spoonacular / Edamam 等能力。',
            style: TextStyle(fontSize: 13, height: 1.45, color: Colors.black54),
          ),
        ]),
      ),
    );
  }

  Widget _noticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Text(
        '健康饮食模块已改为 App 内置每日定时托管 Agent 模式：打开专家页或定时任务到点时会自动读取已授权的 Health Connect、自动补全营养/菜谱 API 数据、自动生成今日复盘，并在允许时自动调用全局 AI 生成专家分析。所有密钥输入框默认隐藏，支持长按粘贴和右侧粘贴按钮。',
        style: TextStyle(height: 1.5),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _secretField(TextEditingController controller, String label, String helper) {
    final hidden = !_showSensitiveValues;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: hidden,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: label,
          helperText: '$helper\n可长按输入框粘贴，也可点击右侧粘贴按钮直接写入剪贴板内容。',
          helperMaxLines: 4,
          border: const OutlineInputBorder(),
          suffixIconConstraints: const BoxConstraints(minWidth: 96, minHeight: 48),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '粘贴密钥',
                icon: const Icon(Icons.content_paste_outlined),
                onPressed: () => _pasteSecret(controller, label),
              ),
              IconButton(
                tooltip: hidden ? '显示密钥' : '隐藏密钥',
                icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _showSensitiveValues = !_showSensitiveValues),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label, String helper) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.containsKey(value) ? value : items.keys.first,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.entries
            .map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

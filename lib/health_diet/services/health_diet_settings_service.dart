import '../../data/kv_dao.dart';

class HealthDietSettingsService {
  HealthDietSettingsService({KeyValueDao? kvDao}) : _kvDao = kvDao ?? KeyValueDao();

  final KeyValueDao _kvDao;

  static const usdaApiKey = 'health_diet_usda_api_key';
  static const openFoodFactsUserAgent = 'health_diet_open_food_facts_user_agent';
  static const booheeApiKey = 'health_diet_boohee_api_key';
  static const juheBarcodeApiKey = 'health_diet_juhe_barcode_api_key';
  static const tanshuBarcodeToken = 'health_diet_tanshu_barcode_token';
  static const tanshuBarcodeBasicUrl = 'health_diet_tanshu_barcode_basic_url';
  static const tanshuBarcodeNutritionUrl = 'health_diet_tanshu_barcode_nutrition_url';
  static const chinaBarcodeApiUrlTemplate = 'health_diet_china_barcode_api_url_template';
  static const chinaBarcodeApiKey = 'health_diet_china_barcode_api_key';
  static const chinaBarcodeApiHeaderName = 'health_diet_china_barcode_api_header_name';
  static const chinaBarcodeAppCode = 'health_diet_china_barcode_app_code';
  static const chinaBarcodeEnabled = 'health_diet_china_barcode_enabled';
  static const edamamAppId = 'health_diet_edamam_app_id';
  static const edamamAppKey = 'health_diet_edamam_app_key';
  static const spoonacularApiKey = 'health_diet_spoonacular_api_key';
  static const defaultFoodSource = 'health_diet_default_food_source';
  static const defaultRecipeSource = 'health_diet_default_recipe_source';
  static const aiAdviceEnabled = 'health_diet_ai_advice_enabled';
  static const externalApiAiTranslationEnabled = 'health_diet_external_api_ai_translation_enabled';
  static const medicalNoticeEnabled = 'health_diet_medical_notice_enabled';
  static const healthConnectEnabled = 'health_diet_health_connect_enabled';
  static const agentAutonomyLevel = 'health_diet_agent_autonomy_level';
  static const agentAutopilotEnabled = 'health_diet_agent_autopilot_enabled';
  static const agentAutoAiEnabled = 'health_diet_agent_auto_ai_enabled';
  static const agentAutoApiEnabled = 'health_diet_agent_auto_api_enabled';
  static const agentAutoHealthSyncEnabled = 'health_diet_agent_auto_health_sync_enabled';
  static const agentDailyScheduleEnabled = 'health_diet_agent_daily_schedule_enabled';
  static const agentScheduleNotifyEnabled = 'health_diet_agent_schedule_notify_enabled';

  Future<Map<String, String>> load() async {
    return <String, String>{
      usdaApiKey: (await _kvDao.getString(usdaApiKey)) ?? '',
      openFoodFactsUserAgent: (await _kvDao.getString(openFoodFactsUserAgent)) ?? 'quote_app_health_diet/1.0',
      booheeApiKey: (await _kvDao.getString(booheeApiKey)) ?? '',
      juheBarcodeApiKey: (await _kvDao.getString(juheBarcodeApiKey)) ?? '',
      tanshuBarcodeToken: (await _kvDao.getString(tanshuBarcodeToken)) ?? '',
      tanshuBarcodeBasicUrl: (await _kvDao.getString(tanshuBarcodeBasicUrl)) ?? 'https://www.tanshuapi.com/market/detail-77',
      tanshuBarcodeNutritionUrl: (await _kvDao.getString(tanshuBarcodeNutritionUrl)) ?? '',
      chinaBarcodeApiUrlTemplate: (await _kvDao.getString(chinaBarcodeApiUrlTemplate)) ?? '',
      chinaBarcodeApiKey: (await _kvDao.getString(chinaBarcodeApiKey)) ?? '',
      chinaBarcodeApiHeaderName: (await _kvDao.getString(chinaBarcodeApiHeaderName)) ?? 'X-APISpace-Token',
      chinaBarcodeAppCode: (await _kvDao.getString(chinaBarcodeAppCode)) ?? '',
      chinaBarcodeEnabled: (await _kvDao.getString(chinaBarcodeEnabled)) ?? '1',
      edamamAppId: (await _kvDao.getString(edamamAppId)) ?? '',
      edamamAppKey: (await _kvDao.getString(edamamAppKey)) ?? '',
      spoonacularApiKey: (await _kvDao.getString(spoonacularApiKey)) ?? '',
      defaultFoodSource: (await _kvDao.getString(defaultFoodSource)) ?? 'auto',
      defaultRecipeSource: (await _kvDao.getString(defaultRecipeSource)) ?? 'auto',
      aiAdviceEnabled: (await _kvDao.getString(aiAdviceEnabled)) ?? '1',
      externalApiAiTranslationEnabled: (await _kvDao.getString(externalApiAiTranslationEnabled)) ?? '0',
      medicalNoticeEnabled: (await _kvDao.getString(medicalNoticeEnabled)) ?? '1',
      healthConnectEnabled: (await _kvDao.getString(healthConnectEnabled)) ?? '0',
      agentAutonomyLevel: (await _kvDao.getString(agentAutonomyLevel)) ?? 'L4',
      agentAutopilotEnabled: (await _kvDao.getString(agentAutopilotEnabled)) ?? '1',
      agentAutoAiEnabled: (await _kvDao.getString(agentAutoAiEnabled)) ?? '1',
      agentAutoApiEnabled: (await _kvDao.getString(agentAutoApiEnabled)) ?? '1',
      agentAutoHealthSyncEnabled: (await _kvDao.getString(agentAutoHealthSyncEnabled)) ?? '1',
      agentDailyScheduleEnabled: (await _kvDao.getString(agentDailyScheduleEnabled)) ?? '1',
      agentScheduleNotifyEnabled: (await _kvDao.getString(agentScheduleNotifyEnabled)) ?? '1',
    };
  }

  Future<void> save(Map<String, String> values) async {
    for (final entry in values.entries) {
      await _kvDao.setString(entry.key, entry.value.trim());
    }
  }

  bool isEnabledValue(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }
}

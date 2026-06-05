import '../models/health_diet_expert_plan.dart';
import '../repositories/health_profile_repository.dart';
import 'health_diet_expert_service.dart';
import 'health_diet_settings_service.dart';
import 'health_diet_autopilot_service.dart';

class HealthDietAppAgentStatus {
  const HealthDietAppAgentStatus({
    required this.modeLabel,
    required this.message,
    required this.autonomyLevel,
    required this.aiEnabled,
    required this.healthConnectEnabled,
  });

  final String modeLabel;
  final String message;
  final String autonomyLevel;
  final bool aiEnabled;
  final bool healthConnectEnabled;
}

/// App 内置健康饮食 Agent 编排入口。
///
/// 该服务不是服务器网关，不需要填写后端地址，也不会把用户 API Key
/// 发送给自有服务器。它在手机 App 内统一读取：健康目标、健康档案、
/// Health Connect、饮食分享、长期模式、外部营养/菜谱 API 和用户选择的
/// AI 模型，然后生成主动营养膳食方案。
class HealthDietAppAgentService {
  HealthDietAppAgentService({
    HealthDietExpertService? expertService,
    HealthDietSettingsService? settingsService,
    HealthDietAutopilotService? autopilotService,
  })  : _expert = expertService ?? HealthDietExpertService(),
        _settings = settingsService ?? HealthDietSettingsService(),
        _autopilot = autopilotService ?? HealthDietAutopilotService();

  final HealthDietExpertService _expert;
  final HealthDietSettingsService _settings;
  final HealthDietAutopilotService _autopilot;

  Future<HealthDietAppAgentStatus> status() async {
    final values = await _settings.load();
    final autonomy = values[HealthDietSettingsService.agentAutonomyLevel] ?? 'L4';
    final autopilotEnabled = _settings.isEnabledValue(values[HealthDietSettingsService.agentAutopilotEnabled]);
    final autoAi = _settings.isEnabledValue(values[HealthDietSettingsService.agentAutoAiEnabled]);
    final autoApi = _settings.isEnabledValue(values[HealthDietSettingsService.agentAutoApiEnabled]);
    final dailySchedule = _settings.isEnabledValue(values[HealthDietSettingsService.agentDailyScheduleEnabled]);
    final aiEnabled = _settings.isEnabledValue(values[HealthDietSettingsService.aiAdviceEnabled]);
    final hcEnabled = _settings.isEnabledValue(values[HealthDietSettingsService.healthConnectEnabled]);
    return HealthDietAppAgentStatus(
      modeLabel: 'App 内置 Agent 模式',
      autonomyLevel: autonomy,
      aiEnabled: aiEnabled,
      healthConnectEnabled: hcEnabled,
      message: '当前使用手机 App 内置自动托管 Agent：打开专家页或每日定时任务到点时，会按配置自动同步 Health Connect、自动调用营养/菜谱 API、自动生成复盘，并在允许时自动调用 AI。主动等级：$autonomy；自动托管：${autopilotEnabled ? '开启' : '关闭'}；每日定时：${dailySchedule ? '开启' : '关闭'}；自动API：${autoApi ? '开启' : '关闭'}；自动AI：${autoAi ? '开启' : '关闭'}。',
    );
  }

  Future<HealthDietExpertPlan> buildTodayPlan({String userId = HealthProfileRepository.defaultUserId}) {
    return _expert.buildTodayPlan(userId: userId);
  }

  Future<String> generateAiCoachNarrative(HealthDietExpertPlan plan) {
    return _expert.generateAiCoachNarrative(plan);
  }

  Future<HealthDietAutopilotResult> runAutopilot({
    String userId = HealthProfileRepository.defaultUserId,
    bool force = false,
    bool interactive = false,
  }) {
    return _autopilot.run(userId: userId, force: force, interactive: interactive);
  }
}


import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/kv_dao.dart';
import '../utils/deepseek_logger.dart';
import 'goal_setting_models.dart';

class GoalSettingRemoteSync {
  final KeyValueDao _kv = KeyValueDao();

  Future<bool> isEnabled() async {
    final mode = ((await _kv.getString('ce_transport_mode')) ?? '').trim().toLowerCase();
    final endpoint = ((await _kv.getString('ce_proxy_endpoint')) ?? '').trim();
    return mode == 'proxy' && endpoint.isNotEmpty;
  }

  Future<Map<String, String>?> fetchPrompts() async {
    final cfg = await _loadConfig();
    if (cfg == null) return null;
    final uri = Uri.parse('${cfg.baseUrl}/api/goal-setting/prompts');
    try {
      final res = await http.get(uri, headers: _headers(cfg.token)).timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return <String, String>{
        'understanding_prompt': '${decoded['understanding_prompt'] ?? ''}',
        'action_prompt': '${decoded['action_prompt'] ?? ''}',
        'loop_prompt': '${decoded['loop_prompt'] ?? ''}',
      };
    } catch (e, st) {
      await DeepSeekLogger.logError(provider: 'goal-sync', module: 'goal_setting.remote.prompts.fetch', endpoint: uri.toString(), error: e, stackTrace: st);
      return null;
    }
  }

  Future<bool> savePrompts(Map<String, String> prompts) async {
    final cfg = await _loadConfig();
    if (cfg == null) return false;
    final uri = Uri.parse('${cfg.baseUrl}/api/goal-setting/prompts');
    try {
      final res = await http.put(uri, headers: _headers(cfg.token), body: jsonEncode(prompts)).timeout(const Duration(seconds: 30));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e, st) {
      await DeepSeekLogger.logError(provider: 'goal-sync', module: 'goal_setting.remote.prompts.save', endpoint: uri.toString(), error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> upsertAction(GoalSettingAction action) async {
    final cfg = await _loadConfig();
    if (cfg == null) return;
    final uri = Uri.parse('${cfg.baseUrl}/api/goal-setting/actions/${Uri.encodeComponent(action.id)}');
    try {
      await http.put(uri, headers: _headers(cfg.token), body: jsonEncode(action.toJson())).timeout(const Duration(seconds: 30));
    } catch (e, st) {
      await DeepSeekLogger.logError(provider: 'goal-sync', module: 'goal_setting.remote.action.upsert', endpoint: uri.toString(), error: e, stackTrace: st);
    }
  }

  Future<void> appendFactRecord(GoalSettingFactRecord record) async {
    final cfg = await _loadConfig();
    if (cfg == null) return;
    final uri = Uri.parse('${cfg.baseUrl}/api/goal-setting/actions/${Uri.encodeComponent(record.actionId)}/fact-records');
    try {
      await http.post(uri, headers: _headers(cfg.token), body: jsonEncode(record.toJson())).timeout(const Duration(seconds: 30));
    } catch (e, st) {
      await DeepSeekLogger.logError(provider: 'goal-sync', module: 'goal_setting.remote.fact.append', endpoint: uri.toString(), error: e, stackTrace: st);
    }
  }

  Future<Map<String, dynamic>?> fetchLoopContext(String actionId) async {
    final cfg = await _loadConfig();
    if (cfg == null) return null;
    final uri = Uri.parse('${cfg.baseUrl}/api/goal-setting/actions/${Uri.encodeComponent(actionId)}/loop-context');
    try {
      final res = await http.get(uri, headers: _headers(cfg.token)).timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      await DeepSeekLogger.logError(provider: 'goal-sync', module: 'goal_setting.remote.loop_context.fetch', endpoint: uri.toString(), error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> saveLoopInsight(GoalSettingActionLoopInsight insight) async {
    final cfg = await _loadConfig();
    if (cfg == null) return;
    final uri = Uri.parse('${cfg.baseUrl}/api/goal-setting/actions/${Uri.encodeComponent(insight.actionId)}/loop-insight');
    try {
      await http.post(uri, headers: _headers(cfg.token), body: jsonEncode(insight.toJson())).timeout(const Duration(seconds: 30));
    } catch (e, st) {
      await DeepSeekLogger.logError(provider: 'goal-sync', module: 'goal_setting.remote.loop_insight.save', endpoint: uri.toString(), error: e, stackTrace: st);
    }
  }

  Map<String, String> _headers(String token) => <String, String>{
        'Content-Type': 'application/json',
        if (token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
      };

  Future<_GoalRemoteConfig?> _loadConfig() async {
    if (!await isEnabled()) return null;
    final endpoint = ((await _kv.getString('ce_proxy_endpoint')) ?? '').trim();
    if (endpoint.isEmpty) return null;
    final baseUrl = _deriveBaseUrl(endpoint);
    if (baseUrl.isEmpty) return null;
    final token = ((await _kv.getString('ce_proxy_token')) ?? '').trim();
    return _GoalRemoteConfig(baseUrl: baseUrl, token: token);
  }

  String _deriveBaseUrl(String proxyEndpoint) {
    final trimmed = proxyEndpoint.trim().replaceFirst(RegExp(r'/+$'), '');
    const marker = '/api/concept-engine/proxy';
    if (trimmed.endsWith(marker)) {
      return trimmed.substring(0, trimmed.length - marker.length);
    }
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
}

class _GoalRemoteConfig {
  final String baseUrl;
  final String token;

  const _GoalRemoteConfig({required this.baseUrl, required this.token});
}

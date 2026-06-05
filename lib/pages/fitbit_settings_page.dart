import 'package:flutter/material.dart';

import '../data/kv_dao.dart';

/// Fitbit integration settings.
///
/// Users need to provide a Fitbit Developer app Client ID/Secret.
/// These are stored locally (SQLite notify_config table) and used by
/// the OAuth PKCE flow.
class FitbitSettingsPage extends StatefulWidget {
  const FitbitSettingsPage({super.key});

  @override
  State<FitbitSettingsPage> createState() => _FitbitSettingsPageState();
}

class _FitbitSettingsPageState extends State<FitbitSettingsPage> {
  final _kv = KeyValueDao();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();

  bool _loading = true;

  static const _kClientId = 'fitbit_client_id';
  static const _kClientSecret = 'fitbit_client_secret';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await _kv.getString(_kClientId) ?? '';
    final sec = await _kv.getString(_kClientSecret) ?? '';
    _clientId.text = id;
    _clientSecret.text = sec;
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    await _kv.setString(_kClientId, _clientId.text.trim());
    await _kv.setString(_kClientSecret, _clientSecret.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存 Fitbit 配置')));
  }

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitbit 设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '要接入 Fitbit，你需要在 Fitbit Developer Portal 创建应用，并将 Redirect URI 设置为：\n\n  quoteappfitbit://auth\n',
                  style: TextStyle(height: 1.4),
                ),
                TextField(
                  controller: _clientId,
                  decoration: const InputDecoration(labelText: 'Client ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientSecret,
                  decoration: const InputDecoration(labelText: 'Client Secret'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
                const SizedBox(height: 24),
                const Text(
                  '提示：\n- 访问 intraday（分钟/秒级）心率等数据，Fitbit 对第三方应用可能要求额外审批。\n- Fitbit Web API 目前不提供 EDA/Stress 原始数据接口（即使设备有 EDA 传感器）。',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
              ],
            ),
    );
  }
}

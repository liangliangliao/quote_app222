import 'package:flutter/material.dart';

import 'movie_role_lab_config.dart';

class MovieRoleLabSettingsPage extends StatefulWidget {
  const MovieRoleLabSettingsPage({super.key});

  @override
  State<MovieRoleLabSettingsPage> createState() => _MovieRoleLabSettingsPageState();
}

class _MovieRoleLabSettingsPageState extends State<MovieRoleLabSettingsPage> {
  final MovieRoleLabConfigStore _store = MovieRoleLabConfigStore();
  final TextEditingController _tmdbTokenCtrl = TextEditingController();
  final TextEditingController _tmdbApiKeyCtrl = TextEditingController();
  final TextEditingController _openSubApiKeyCtrl = TextEditingController();
  final TextEditingController _openSubUsernameCtrl = TextEditingController();
  final TextEditingController _openSubPasswordCtrl = TextEditingController();
  final TextEditingController _openSubUserAgentCtrl = TextEditingController();
  final TextEditingController _languagesCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tmdbTokenCtrl.dispose();
    _tmdbApiKeyCtrl.dispose();
    _openSubApiKeyCtrl.dispose();
    _openSubUsernameCtrl.dispose();
    _openSubPasswordCtrl.dispose();
    _openSubUserAgentCtrl.dispose();
    _languagesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await _store.load();
    if (!mounted) return;
    setState(() {
      _tmdbTokenCtrl.text = cfg.tmdbReadToken;
      _tmdbApiKeyCtrl.text = cfg.tmdbApiKey;
      _openSubApiKeyCtrl.text = cfg.openSubtitlesApiKey;
      _openSubUsernameCtrl.text = cfg.openSubtitlesUsername;
      _openSubPasswordCtrl.text = cfg.openSubtitlesPassword;
      _openSubUserAgentCtrl.text = cfg.openSubtitlesUserAgent.isEmpty ? 'MovieRoleLab v1.0' : cfg.openSubtitlesUserAgent;
      _languagesCtrl.text = cfg.subtitleLanguages.isEmpty ? 'ze,zh-cn,en' : cfg.subtitleLanguages;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cfg = MovieRoleLabConfig(
      tmdbReadToken: _tmdbTokenCtrl.text,
      tmdbApiKey: _tmdbApiKeyCtrl.text,
      openSubtitlesApiKey: _openSubApiKeyCtrl.text,
      openSubtitlesUsername: _openSubUsernameCtrl.text,
      openSubtitlesPassword: _openSubPasswordCtrl.text,
      openSubtitlesUserAgent: _openSubUserAgentCtrl.text.trim().isEmpty ? 'MovieRoleLab v1.0' : _openSubUserAgentCtrl.text,
      subtitleLanguages: _languagesCtrl.text.trim().isEmpty ? 'ze,zh-cn,en' : _languagesCtrl.text,
    );
    await _store.save(cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('电影角色实验室配置已保存')),
    );
  }

  Widget _section({required String title, required String subtitle, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        minLines: 1,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('电影角色实验室配置')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    '升级后流程：TMDb 用于识别电影和获取 IMDb ID；OpenSubtitles 用于搜索/下载真实字幕。AI 只基于真实字幕片段分析，不再直接凭空生成所谓电影剧本。',
                    style: TextStyle(color: Color(0xFF92400E), height: 1.45),
                  ),
                ),
                _section(
                  title: 'TMDb 电影资料源',
                  subtitle: '优先填写 Read Access Token；如果只申请了 v3 API Key，也可以填 API Key。至少填写一个。',
                  children: [
                    _field('TMDb API Read Access Token / v4 auth', _tmdbTokenCtrl, hint: 'eyJhbGciOiJIUzI1NiJ9...'),
                    _field('TMDb API Key / v3 auth（可选）', _tmdbApiKeyCtrl, hint: '例如 372d...'),
                  ],
                ),
                _section(
                  title: 'OpenSubtitles 字幕源',
                  subtitle: '搜索字幕需要 API Key；下载字幕需要用户名和密码登录获取 token。User-Agent 建议使用“应用名 v版本”。',
                  children: [
                    _field('OpenSubtitles API Key', _openSubApiKeyCtrl),
                    _field('OpenSubtitles 用户名', _openSubUsernameCtrl),
                    _field(
                      'OpenSubtitles 密码',
                      _openSubPasswordCtrl,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    _field('User-Agent', _openSubUserAgentCtrl, hint: 'MovieRoleLab v1.0'),
                    _field('默认字幕语言优先级', _languagesCtrl, hint: 'ze,zh-cn,en'),
                    const Text(
                      '推荐：ze（中英双语）→ zh-cn（简体中文）→ en（英文）。多个语言用英文逗号分隔。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('保存配置'),
                ),
              ],
            ),
    );
  }
}

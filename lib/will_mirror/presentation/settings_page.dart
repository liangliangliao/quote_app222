import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../ai/protocol.dart';
import '../application/controller.dart';
import '../data/store.dart';
import '../domain/model.dart';
import '../integration/host_settings.dart';
import 'design.dart';
import 'sheets.dart';

class MirrorSettingsPage extends StatefulWidget {
  const MirrorSettingsPage({super.key, required this.controller});
  final MirrorController controller;
  @override
  State<MirrorSettingsPage> createState() => _MirrorSettingsPageState();
}

class _MirrorSettingsPageState extends State<MirrorSettingsPage> {
  MirrorController get c => widget.controller;
  Future<void> _change(Json changes) => runUiAction(
      context, () => c.savePreferences(c.preferences.change(changes)));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final p = c.preferences;
        return ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            children: [
              Text('按自己的节奏。', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              MirrorCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('画面与声音',
                        style: Theme.of(context).textTheme.titleMedium),
                    SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('轻微动画'),
                        subtitle: const Text('同时遵循系统的减少动态效果设置'),
                        value: p.animations,
                        onChanged: (v) => _change({'animations': v})),
                    SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('允许预演语音'),
                        subtitle: const Text('每次仍需主动点击播放，不自动朗读'),
                        value: p.sound,
                        onChanged: (v) => _change({'sound': v})),
                    SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('轻触反馈'),
                        value: p.haptics,
                        onChanged: (v) => _change({'haptics': v})),
                    DropdownButtonFormField<String>(
                        initialValue: p.darkMode,
                        decoration: const InputDecoration(labelText: '外观'),
                        items: const [
                          DropdownMenuItem(
                              value: 'system', child: Text('跟随系统')),
                          DropdownMenuItem(value: 'light', child: Text('浅色')),
                          DropdownMenuItem(value: 'dark', child: Text('深色'))
                        ],
                        onChanged: (v) {
                          if (v != null) _change({'darkMode': v});
                        }),
                  ])),
              const SizedBox(height: 16),
              MirrorCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('分析服务',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(c.providerLabel),
                    const Text(
                        '复用应用现有 AI 配置。每次分析单独选择资料；没有服务时可以继续记录、比较已有结果和等待真实反馈。'),
                    TextButton.icon(
                        onPressed: () async {
                          await openHostAiSettings(context);
                          c.providerLabel = await c.model.label();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('打开应用的 AI 设置')),
                    const Divider(),
                    SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Decisions 四维协同评分'),
                        subtitle:
                            const Text('可选。仅向你配置的受保护网关发送本次授权资料；不可用时显示规则排序。'),
                        value: p.remoteScoring,
                        onChanged: (v) async {
                          if (v && p.gatewayUrl.isEmpty) {
                            await _gateway();
                          } else {
                            await _change({'remoteScoring': v});
                          }
                        }),
                    TextButton(
                        onPressed: _gateway, child: const Text('配置评分网关')),
                  ])),
              const SizedBox(height: 16),
              MirrorCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('哪些经历可作为其他课题的参考',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                        '默认不跨课题使用。开启后，每次分析仍会请你选择具体记录。关闭会清除其他课题中依赖这些资料的派生内容，并取消相关提醒。'),
                    if (c.files.isEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('还没有可选择的课题。')),
                    for (final f in c.files)
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: p.crossCaseIds.contains(f.id),
                          title: Text(f.issue,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          onChanged: (v) {
                            final ids = p.crossCaseIds.toSet();
                            if (v == true) {
                              ids.add(f.id);
                            } else {
                              ids.remove(f.id);
                            }
                            _change({'crossCaseIds': ids.toList()});
                          }),
                  ])),
              const SizedBox(height: 16),
              MirrorCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('自己的资料',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('内容在本机加密保存。删除与撤回会处理历史快照和依赖它的内容。'),
                    OutlinedButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('导出我的记录')),
                    TextButton(
                        onPressed: _deleteAll, child: const Text('删除本模块全部课题')),
                  ])),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('理论来源与产品解释的边界'),
                children: [
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          '这些理论帮助提出可检验的问题，不会把动机强弱、人格或未来行为计算成确定结论。身体与环境条件分别保留；他人的自主和实际安全限制不能被积极想象抵消。')),
                  for (final card in theoryCards)
                    ListTile(
                        title: Text(card['title']?.toString() ??
                            card['author']?.toString() ??
                            '理论与产品解释'),
                        subtitle: Text(card.entries
                            .where((e) => e.key != 'id' && e.key != 'title')
                            .map((e) => e.value.toString())
                            .join('\n')))
                ],
              ),
              const SizedBox(height: 12),
              Text('意志之镜 · v2.8\n从事实出发，允许修订，也允许仍然未知。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ]);
      });
  Future<void> _gateway() async {
    final endpoint = TextEditingController(text: c.preferences.gatewayUrl),
        token = TextEditingController(text: c.preferences.gatewayAccessToken);
    final form = GlobalKey<FormState>();
    final value = await mirrorSheet<Json>(context,
        title: '可选的评分网关',
        child: Builder(
            builder: (sheet) => Form(
                key: form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          '填写自己的服务端地址和网关访问令牌。OpenAI 开发者密钥只保存在服务端，不在这里填写。'),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: endpoint,
                          decoration:
                              const InputDecoration(labelText: 'HTTPS 网关地址'),
                          keyboardType: TextInputType.url,
                          validator: (v) {
                            final uri = Uri.tryParse(v?.trim() ?? '');
                            return uri?.scheme == 'https' &&
                                    uri!.host.isNotEmpty &&
                                    uri.userInfo.isEmpty &&
                                    uri.query.isEmpty
                                ? null
                                : '请填写没有查询参数的 HTTPS 地址';
                          }),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: token,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration:
                              const InputDecoration(labelText: '网关访问令牌'),
                          validator: (v) => v == null || v.trim().length < 16
                              ? '请输入网关访问令牌'
                              : v.trim().startsWith('sk-')
                                  ? '这里填写网关令牌，不是模型服务密钥'
                                  : null),
                      const SizedBox(height: 18),
                      FilledButton(
                          onPressed: () {
                            if (form.currentState!.validate())
                              Navigator.pop(sheet, {
                                'gatewayUrl': endpoint.text.trim(),
                                'gatewayAccessToken': token.text.trim(),
                                'remoteScoring': true
                              });
                          },
                          child: const Text('保存并开启可选评分')),
                    ]))));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    endpoint.dispose();
    token.dispose();
    if (value != null && mounted) await _change(value);
  }

  Future<void> _export() async {
    final type = await chooseOption(context,
        title: '选择导出方式',
        options: {
          'plain': '可阅读 JSON（包含个人原文）',
          if (c.store is SqliteMirrorStore) 'encrypted': '本设备加密归档（其他设备不能解密）'
        },
        explanation: '导出文件由你选择保存位置。可阅读 JSON 不再受本应用的加密保护。');
    if (type == null || !mounted) return;
    await runUiAction(context, () async {
      final Uint8List bytes = type == 'encrypted'
          ? await (c.store as SqliteMirrorStore).encryptedBackup()
          : Uint8List.fromList(utf8.encode(await c.store.exportJson()));
      final saved = await FilePicker.platform.saveFile(
          dialogTitle: '保存意志之镜记录',
          fileName: type == 'encrypted'
              ? 'will-mirror-device-archive.wmvault'
              : 'will-mirror-records.json',
          bytes: bytes);
      if (saved != null && mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('记录已导出到你选择的位置')));
    });
  }

  Future<void> _deleteAll() async {
    if (c.files.isEmpty) return;
    final answer = await chooseOption(context,
        title: '删除全部 ${c.files.length} 个课题？',
        explanation: '本模块的原文、历史版本和衍生内容都会删除，相关提醒会取消。此操作无法撤销。',
        options: {'keep': '保留我的资料', 'delete': '确认删除本模块全部课题'});
    if (answer == 'delete' && mounted)
      await runUiAction(context, () async {
        for (final id in c.files.map((f) => f.id).toList()) {
          await c.deleteCase(id);
        }
      });
  }
}

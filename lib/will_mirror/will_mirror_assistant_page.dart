import 'dart:convert';

import 'package:flutter/material.dart';

import 'will_mirror_assistant_service.dart';
import 'will_mirror_capability_catalog.dart';
import 'will_mirror_knowledge_repository.dart';
import 'will_mirror_practice_models.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorAssistantPage extends StatefulWidget {
  const WillMirrorAssistantPage({
    super.key,
    required this.vault,
    required this.knowledge,
    this.plan,
    this.service,
  });

  static const Key inputKey = ValueKey<String>('wm_v5_assistant_input');
  static const Key sendKey = ValueKey<String>('wm_v5_assistant_send');

  final WillMirrorVault vault;
  final WillMirrorKnowledgeRepository knowledge;
  final WillMirrorActionPlan? plan;
  final WillMirrorAssistantService? service;

  @override
  State<WillMirrorAssistantPage> createState() =>
      _WillMirrorAssistantPageState();
}

class _WillMirrorAssistantPageState extends State<WillMirrorAssistantPage> {
  late final WillMirrorAssistantService _service =
      widget.service ?? WillMirrorAssistantService(knowledge: widget.knowledge);
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<WillMirrorAssistantMessage> _messages =
      <WillMirrorAssistantMessage>[];
  WillMirrorActionPlan? _plan;
  bool _sending = false;
  bool _allowAiOnce = false;

  static const List<String> _quickQuestions = <String>[
    '我不知道从哪里开始',
    '这个字段怎么填？',
    '为什么今天没做成？',
    'Why Tree 是干什么的？',
    '给我一个完整案例',
    '哪些内容会发送给 AI？',
  ];

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_plan == null) _plan = await widget.vault.activeActionPlan();
    final raw = await widget.vault.readSetting(
      WillMirrorVault.assistantHistoryKey,
    );
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _messages.addAll(
            decoded.whereType<Map>().map(
                  (item) => WillMirrorAssistantMessage.fromJson(
                    item.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  ),
                ),
          );
        }
      } catch (_) {
        // Corrupt history is ignored. It never blocks access to the assistant.
      }
    }
    if (_messages.isEmpty) {
      _messages.add(
        WillMirrorAssistantMessage(
          role: 'assistant',
          text: _plan == null
              ? '把你不知道怎么做的地方直接告诉我。我会说明这是什么、为什么、怎么填，并给你下一步。'
              : '我知道你正在处理“${_plan!.need}”。你可以问今天怎么做、为什么这样做、没做成怎么办，或任何模块如何使用。',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          steps: const <String>['直接描述卡点，不需要使用产品术语'],
          theoryIds: const <String>['SCH-B2-022-METAPHYSICAL-BOUNDARY'],
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _send([String? quick]) async {
    final question = (quick ?? _input.text).trim();
    if (question.isEmpty || _sending) return;
    final userMessage = WillMirrorAssistantMessage(
      role: 'user',
      text: question,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      _messages.add(userMessage);
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();
    final allowAi = _allowAiOnce;
    final answer = await _service.answer(
      question: question,
      plan: _plan,
      allowAi: allowAi,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(answer.toMessage());
      _sending = false;
      _allowAiOnce = false;
    });
    await _saveHistory();
    _scrollToEnd();
  }

  Future<void> _saveHistory() async {
    final retained = _messages.length <= 30
        ? _messages
        : _messages.sublist(_messages.length - 30);
    await widget.vault.writeSetting(
      WillMirrorVault.assistantHistoryKey,
      jsonEncode(retained.map((item) => item.toJson()).toList()),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text('随身助手'),
        backgroundColor: const Color(0xFFFAFBF9),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _plan == null ? '还没有进行中的实践' : '当前：${_plan!.need}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: WillMirrorPalette.muted),
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) => ActionChip(
                label: Text(_quickQuestions[index]),
                onPressed: _sending ? null : () => _send(_quickQuestions[index]),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: _quickQuestions.length,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  children: <Widget>[
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _allowAiOnce,
                      onChanged: _sending
                          ? null
                          : (value) =>
                              setState(() => _allowAiOnce = value ?? false),
                      title: const Text(
                        '仅本条允许发送给已配置 AI',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        '只发送这条问题、当前步骤摘要和 KB 摘要；不会发送整个 Vault。发送后自动关闭。',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: WillMirrorAssistantPage.inputKey,
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: '例如：我完全不知道第一步该做什么',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          key: WillMirrorAssistantPage.sendKey,
                          tooltip: '发送',
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final WillMirrorAssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isUser ? WillMirrorPalette.forest : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: WillMirrorPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: TextStyle(
                height: 1.45,
                color: isUser ? Colors.white : WillMirrorPalette.ink,
              ),
            ),
            if (!isUser && message.steps.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              for (var index = 0; index < message.steps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('${index + 1}. ${message.steps[index]}'),
                ),
            ],
            if (!isUser && message.caution.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message.caution,
                style: const TextStyle(fontSize: 12, color: WillMirrorPalette.muted),
              ),
            ],
            if (!isUser && message.theoryIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 9),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: message.theoryIds.map((id) {
                  return WillMirrorBadge(
                    label: WillMirrorTheoryCatalog.find(id)?.shortLabel ?? id,
                  );
                }).toList(growable: false),
              ),
            ],
            if (!isUser) ...<Widget>[
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  Icon(
                    message.provider == 'local'
                        ? Icons.phone_android
                        : message.provider == 'local-safety'
                            ? Icons.health_and_safety_outlined
                            : Icons.auto_awesome,
                    size: 14,
                    color: WillMirrorPalette.muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      message.provider == 'local'
                          ? message.aiRequested
                              ? 'AI 未完成 · 本地知识库已接管'
                              : '本地知识库回答'
                          : message.provider == 'local-safety'
                              ? '本地安全规则'
                              : 'AI 已参与 · ${message.provider}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: WillMirrorPalette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (message.fallbackReason.isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  message.fallbackReason,
                  style: const TextStyle(
                    fontSize: 10,
                    color: WillMirrorPalette.muted,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

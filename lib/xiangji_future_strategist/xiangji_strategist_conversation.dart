import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ai_assistant/ai_assistant_file_text_extractor.dart';
import '../data/kv_dao.dart';
import 'xiangji_campaign_action_pages.dart';
import 'xiangji_database.dart';
import 'xiangji_repository.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_sck_runtime.dart';
import 'xiangji_ui_support.dart';

class XiangjiStrategistConversationPanel extends StatefulWidget {
  const XiangjiStrategistConversationPanel({
    super.key,
    required this.repository,
    required this.dao,
    this.onDataChanged,
  });

  final XiangjiRepository repository;
  final XiangjiDao dao;
  final Future<void> Function()? onDataChanged;

  @override
  State<XiangjiStrategistConversationPanel> createState() =>
      _XiangjiStrategistConversationPanelState();
}

class _XiangjiStrategistConversationPanelState
    extends State<XiangjiStrategistConversationPanel> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final AiAssistantFileTextExtractor _attachmentExtractor =
      AiAssistantFileTextExtractor();
  List<PlatformFile> _attachments = const <PlatformFile>[];
  List<XiangjiDecisionDraftRecord> _history =
      const <XiangjiDecisionDraftRecord>[];
  XiangjiCouncilResult? _result;
  XiangjiOrchestrationState? _progress;
  String _pendingProblemId = '';
  bool _awaitingClarification = false;
  bool _working = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final values = await widget.repository.decisionDrafts(limit: 12);
      if (!mounted) return;
      setState(() => _history = values);
    } catch (_) {
      // The primary composer remains usable even when history cannot load.
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      xiangjiShowMessage(context, '请告诉军师你想要什么、发生了什么，或卡在哪里。');
      return;
    }
    setState(() {
      _working = true;
      _progress = XiangjiOrchestrationState.cognitiveModeling;
    });
    try {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      final attachmentText = await _extractAttachmentText(_attachments);
      final refs = _attachments
          .map((file) =>
              'local_attachment:${file.name}:${file.size}:${file.extension ?? ''}')
          .toList();
      final result = await widget.repository.consultStrategist(
        utterance: text,
        problemId: _awaitingClarification ? _pendingProblemId : '',
        authorizedSensitiveContext: authorized,
        attachmentRefs: refs,
        attachmentText: attachmentText,
        clarificationAnswer: _awaitingClarification,
        onProgress: (state) {
          if (mounted) setState(() => _progress = state);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _pendingProblemId = result.problemId;
        _awaitingClarification =
            result.outcome == XiangjiAskUserOutcome.askOne;
        _controller.clear();
        _attachments = const <PlatformFile>[];
      });
      await _loadHistory();
      await widget.onDataChanged?.call();
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _toggleVoice() async {
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (mounted && status == 'done') {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _listening = false);
          xiangjiShowMessage(context, '语音识别暂不可用：${error.errorMsg}');
        }
      },
    );
    if (!available) {
      if (mounted) xiangjiShowMessage(context, '当前设备没有可用的语音识别服务。');
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'zh_CN',
      onResult: (result) {
        if (!mounted) return;
        _controller.value = TextEditingValue(
          text: result.recognizedWords,
          selection: TextSelection.collapsed(
            offset: result.recognizedWords.length,
          ),
        );
      },
    );
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (!mounted || result == null) return;
      final accepted = result.files.where((file) => file.size <= 5 * 1024 * 1024);
      setState(() => _attachments = <PlatformFile>[
            ..._attachments,
            ...accepted,
          ].take(5).toList());
      if (result.files.any((file) => file.size > 5 * 1024 * 1024)) {
        xiangjiShowMessage(context, '单个附件需不超过 5 MB；大文件请先放入知识库。');
      }
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    }
  }

  Future<String> _extractAttachmentText(List<PlatformFile> files) async {
    const textExtensions = <String>{
      'txt', 'md', 'json', 'csv', 'tsv', 'yaml', 'yml', 'log',
    };
    final parts = <String>[];
    for (final file in files) {
      final extension = (file.extension ?? '').toLowerCase();
      String? extracted;
      final path = file.path ?? '';
      if (path.isNotEmpty) {
        extracted = await _attachmentExtractor.extract(
          File(path),
          file.name,
          sizeBytes: file.size,
        );
      }
      final bytes = file.bytes;
      if ((extracted == null || extracted.trim().isEmpty) &&
          textExtensions.contains(extension) &&
          bytes != null) {
        final clipped = bytes.length > 160000
            ? bytes.sublist(0, 160000)
            : bytes;
        extracted = utf8.decode(clipped, allowMalformed: true);
      }
      if (extracted == null || extracted.trim().isEmpty) continue;
      parts.add('【附件原文 ${file.name}】\n${extracted.trim()}');
      if (parts.join('\n\n').length >= 120000) break;
    }
    final combined = parts.join('\n\n');
    return combined.length <= 120000
        ? combined
        : combined.substring(0, 120000);
  }

  void _newTopic() {
    setState(() {
      _result = null;
      _pendingProblemId = '';
      _awaitingClarification = false;
      _controller.clear();
      _attachments = const <PlatformFile>[];
    });
  }

  Future<void> _respond(XiangjiDecisionDraftStatus status) async {
    final result = _result;
    if (result == null) return;
    try {
      await widget.repository.respondToDecisionDraft(
        decisionDraftId: result.decisionDraftId,
        status: status,
      );
      await _loadHistory();
      await widget.onDataChanged?.call();
      if (!mounted) return;
      if (status == XiangjiDecisionDraftStatus.adopted &&
          result.actionId.isNotEmpty) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => XiangjiActionModePage(
            actionId: result.actionId,
            repository: widget.repository,
            dao: widget.dao,
          ),
        ));
        await widget.onDataChanged?.call();
      } else {
        xiangjiShowMessage(
          context,
          status == XiangjiDecisionDraftStatus.deferred
              ? '已暂缓；模型与事前判断都保留下来。'
              : '已记录你的决定。',
        );
      }
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    }
  }

  Future<void> _modify() async {
    final result = _result;
    if (result == null) return;
    final recommendation =
        TextEditingController(text: result.draft.recommendation);
    final action = TextEditingController(text: result.draft.currentAction);
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改军师草案'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recommendation,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '我采用的建议版本',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: action,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '当前一步',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              <String>[recommendation.text, action.text],
            ),
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
    recommendation.dispose();
    action.dispose();
    if (values == null) return;
    setState(() {
      _working = true;
      _progress = XiangjiOrchestrationState.cognitiveModeling;
    });
    try {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      final next = await widget.repository.correctAndRecalculate(
        problemId: result.problemId,
        targetRef: 'decision_draft:${result.decisionDraftId}',
        oldValue:
            '建议：${result.draft.recommendation}\n当前一步：${result.draft.currentAction}',
        correctedValue: '建议：${values[0]}\n当前一步：${values[1]}',
        reason: '用户修改军师草案',
        authorizedSensitiveContext: authorized,
        onProgress: (state) {
          if (mounted) setState(() => _progress = state);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = next;
        _pendingProblemId = next.problemId;
        _awaitingClarification =
            next.outcome == XiangjiAskUserOutcome.askOne;
      });
      await _loadHistory();
      await widget.onDataChanged?.call();
      if (mounted) xiangjiShowMessage(context, '已保留原草案并按你的修改重算。');
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _oppose() async {
    final result = _result;
    if (result == null) return;
    final correction = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('告诉军师哪里理解错了'),
        content: TextField(
          controller: correction,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '只需说正确情况；旧派生结论会标记为过期并自动重算。',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(correction.text),
            child: const Text('纠正并重算'),
          ),
        ],
      ),
    );
    correction.dispose();
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      _working = true;
      _progress = XiangjiOrchestrationState.cognitiveModeling;
    });
    try {
      final authorized =
          await KeyValueDao().getString(
                'xiangji_sensitive_cloud_authorized_v1',
              ) ==
              '1';
      final next = await widget.repository.correctAndRecalculate(
        problemId: result.problemId,
        targetRef: 'decision_draft:${result.decisionDraftId}',
        oldValue: result.draft.judgment,
        correctedValue: value,
        authorizedSensitiveContext: authorized,
        onProgress: (state) {
          if (mounted) setState(() => _progress = state);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = next;
        _pendingProblemId = next.problemId;
        _awaitingClarification =
            next.outcome == XiangjiAskUserOutcome.askOne;
      });
      await _loadHistory();
      await widget.onDataChanged?.call();
    } catch (error) {
      if (mounted) xiangjiShowMessage(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _showWhy() async {
    final result = _result;
    if (result == null) return;
    final values = await Future.wait<Object?>(<Future<Object?>>[
      widget.dao.reasoningArtifacts(problemId: result.problemId),
      widget.dao.agentRuns(result.problemId),
    ]);
    if (!mounted) return;
    final artifacts = values[0] as List<Map<String, Object?>>;
    final runs = values[1] as List<Map<String, Object?>>;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.86,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '为什么这样判断',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              XiangjiLabeledValue(
                label: '当前认识根据',
                value: result.draft.groundingReason,
              ),
              XiangjiLabeledValue(
                label: '最脆弱前提 / 反方',
                value: result.draft.redTeam.join('\n'),
              ),
              XiangjiLabeledValue(
                label: '会改变建议的现实信号',
                value: result.draft.changeSignals,
              ),
              const Divider(height: 28),
              const Text(
                '可追溯 AI 工作台',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final artifact in artifacts)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(_artifactLabel((artifact['kind'] ?? '').toString())),
                  subtitle: Text('来源态势：${artifact['situation_model_id']}'),
                  children: [
                    SelectableText(
                      _prettyJson((artifact['json_payload'] ?? '{}').toString()),
                    ),
                  ],
                ),
              const Divider(height: 28),
              Text(
                'Agent 顺序：${runs.map((row) => row['agent_role']).join(' → ')}',
                style: const TextStyle(color: XiangjiPalette.muted),
              ),
              const SizedBox(height: 8),
              Text(
                'SCK：${XiangjiSckRuntime.rules.keys.join(' · ')}',
                style: const TextStyle(
                  color: XiangjiPalette.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '与军师对话',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _awaitingClarification
                          ? '军师只需要你补充一个会改变路线的信息。'
                          : '你负责讲真实处境；认识分层、求解、战略与红队由军师完成。',
                      style: const TextStyle(
                        color: XiangjiPalette.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _working ? null : _newTopic,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('新议题'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _composer(),
          if (_working) ...[
            const SizedBox(height: 14),
            XiangjiSectionCard(
              title: _progress?.label ?? '军师正在工作',
              subtitle: 'SCK 正在自动建模、判断、求解；若是重大问题还会自动进入战略与红队。',
              child: const LinearProgressIndicator(),
            ),
          ],
          if (_result != null && !_working) ...[
            const SizedBox(height: 14),
            _resultCard(_result!),
          ] else if (!_working && _history.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              '最近军议',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final draft in _history.take(4)) _historyCard(draft),
          ],
        ],
      ),
    );
  }

  Widget _composer() {
    return Semantics(
      textField: true,
      label: '告诉军师你的需要、现实或卡点',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: XiangjiPalette.line),
        ),
        child: Column(
          children: [
            TextField(
              key: const ValueKey<String>('xiangji_strategist_input'),
              controller: _controller,
              minLines: 3,
              maxLines: 8,
              enabled: !_working,
              decoration: InputDecoration(
                hintText: _awaitingClarification
                    ? _result?.clarificationQuestion
                    : '告诉我你想要什么、发生了什么，或者你现在卡在哪里。',
                border: InputBorder.none,
              ),
            ),
            if (_attachments.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var index = 0; index < _attachments.length; index++)
                      InputChip(
                        label: Text(_attachments[index].name),
                        onDeleted: _working
                            ? null
                            : () => setState(() {
                                  _attachments = <PlatformFile>[
                                    ..._attachments.take(index),
                                    ..._attachments.skip(index + 1),
                                  ];
                                }),
                      ),
                  ],
                ),
              ),
            const Divider(),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: _listening ? '停止语音输入' : '语音输入',
                  onPressed: _working ? null : _toggleVoice,
                  icon: Icon(
                    _listening ? Icons.mic : Icons.mic_none_outlined,
                    color: _listening ? Colors.red : null,
                  ),
                ),
                IconButton(
                  tooltip: '添加附件',
                  onPressed: _working ? null : _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                ),
                FilledButton.icon(
                  onPressed: _working ? null : _submit,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(_awaitingClarification ? '回答并继续' : '请军师分析'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(XiangjiCouncilResult result) {
    if (result.outcome == XiangjiAskUserOutcome.askOne) {
      return XiangjiSectionCard(
        title: '我还缺一个会改变战略的信息',
        subtitle: 'AskUserGuard 已确认：现有历史不可推断，且无法由低成本侦察替代。本轮只问这一项。',
        child: Text(
          result.clarificationQuestion,
          style: const TextStyle(fontSize: 18, height: 1.55),
        ),
      );
    }
    final draft = result.draft;
    return XiangjiSectionCard(
      title: '军师回复',
      subtitle: '这是可修订建议，不是客观事实；认识状态：${draft.epistemicStatus}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draft.trueProblem.trim().isNotEmpty)
            XiangjiLabeledValue(
              label: '我理解的真正问题',
              value: draft.trueProblem,
            ),
          XiangjiLabeledValue(label: '军师判断', value: draft.judgment),
          XiangjiLabeledValue(
            label: '我建议',
            value: result.executionFrozen
                ? '先冻结不可逆承诺，补证、降风险，并在需要时寻求专业复核。'
                : draft.recommendation,
          ),
          XiangjiLabeledValue(label: '为什么', value: draft.why),
          XiangjiLabeledValue(
            label: '当前一步',
            value: result.executionFrozen ? '' : draft.currentAction,
          ),
          XiangjiLabeledValue(
            label: '会改变建议的信号',
            value: draft.changeSignals,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!result.executionFrozen)
                FilledButton(
                  onPressed: () => _respond(XiangjiDecisionDraftStatus.adopted),
                  child: const Text('采用'),
                ),
              OutlinedButton(onPressed: _modify, child: const Text('修改')),
              OutlinedButton(onPressed: _oppose, child: const Text('不认同')),
              TextButton.icon(
                onPressed: _showWhy,
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('为什么？'),
              ),
              TextButton(
                onPressed: () => _respond(XiangjiDecisionDraftStatus.deferred),
                child: const Text('暂缓'),
              ),
            ],
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '部分云端角色未完成，已使用本地 SCK 草案保持闭环。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: XiangjiPalette.muted,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(XiangjiDecisionDraftRecord draft) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        title: Text(
          draft.recommendation,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${draft.epistemicStatus} · ${draft.status.wire}',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final problemId = draft.problemId;
          final artifacts = await widget.dao.reasoningArtifacts(
            problemId: problemId,
          );
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('军师草案'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      XiangjiLabeledValue(
                        label: '军师判断',
                        value: draft.judgment,
                      ),
                      XiangjiLabeledValue(
                        label: '建议',
                        value: draft.recommendation,
                      ),
                      XiangjiLabeledValue(
                        label: '当前一步',
                        value: draft.currentAction,
                      ),
                      Text('可追溯工件：${artifacts.length} 项'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _artifactLabel(String kind) => switch (kind) {
        'causal_map' => '竞争因果图',
        'judgment_map' => '判断力同异/边界',
        'grounding_chain' => '认识根据链',
        'problem_tree' => 'Problem / AND-OR / Operators',
        'strategy_matrix' => '战略矩阵',
        'red_team' => '红队清单',
        'war_game' => '兵棋场景',
        _ => kind,
      };

  String _prettyJson(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }
}

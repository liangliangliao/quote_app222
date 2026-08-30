import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ai_assistant/ai_assistant_file_text_extractor.dart';
import '../data/kv_dao.dart';
import '../pages/settings_page.dart';
import '../services/global_ai_settings.dart';
import 'xiangji_campaign_action_pages.dart';
import 'xiangji_database.dart';
import 'xiangji_experience_widgets.dart';
import 'xiangji_insight_pages.dart';
import 'xiangji_models.dart';
import 'xiangji_problem_pages.dart';
import 'xiangji_repository.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_rev4_models.dart';
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
  SpeechToText? _speech;
  final AiAssistantFileTextExtractor _attachmentExtractor =
      AiAssistantFileTextExtractor();
  List<PlatformFile> _attachments = const <PlatformFile>[];
  List<XiangjiDecisionDraftRecord> _history =
      const <XiangjiDecisionDraftRecord>[];
  XiangjiCouncilResult? _result;
  XiangjiSolverSnapshot? _solver;
  List<XiangjiMethodEvent> _methodEvents = const <XiangjiMethodEvent>[];
  XiangjiOrchestrationState? _progress;
  String _pendingProblemId = '';
  bool _awaitingClarification = false;
  bool _working = false;
  bool _listening = false;
  bool _forceNewOnNextSubmit = false;
  String _failedInput = '';
  String _failureMessage = '';
  Map<String, String> _aiState = const <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadHistory();
        _loadAiReadiness();
      }
    });
  }

  @override
  void dispose() {
    _speech?.stop();
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

  Future<void> _loadAiReadiness() async {
    try {
      final state = await GlobalAiSettings().getState();
      if (mounted) setState(() => _aiState = state);
    } catch (_) {
      // Readiness is advisory; the primary local composer stays available.
    }
  }

  Future<void> _openGlobalAiSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    await _loadAiReadiness();
  }

  Future<void> _reviewSensitiveConsent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => XiangjiSettingsPage(
          dao: widget.dao,
          repository: widget.repository,
        ),
      ),
    );
    await _loadAiReadiness();
  }

  Future<void> _refreshProblemContext(String problemId) async {
    if (problemId.isEmpty) return;
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.dao.solverSnapshot(problemId),
        widget.dao.latestMethodTurnEvents(
          problemId: problemId,
          userVisibleOnly: true,
          limit: 3,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _solver = values[0] as XiangjiSolverSnapshot?;
        _methodEvents = values[1] as List<XiangjiMethodEvent>;
      });
    } catch (_) {
      // The decision remains usable even if optional solver details fail.
    }
  }

  Future<void> _submit({bool userDoesNotKnow = false}) async {
    final text = userDoesNotKnow
        ? '我不知道这个答案，请用保守假设或低成本现实侦察继续。'
        : _controller.text.trim();
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
        problemId: _pendingProblemId,
        authorizedSensitiveContext: authorized,
        attachmentRefs: refs,
        attachmentText: attachmentText,
        clarificationAnswer: _awaitingClarification,
        forceNewProblem: _forceNewOnNextSubmit,
        userDoesNotKnow: userDoesNotKnow,
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
        _forceNewOnNextSubmit = false;
        _failedInput = '';
        _failureMessage = '';
      });
      await _refreshProblemContext(result.problemId);
      await _loadHistory();
      await widget.onDataChanged?.call();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failedInput = text;
          _failureMessage = error.toString();
        });
      }
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
    final speech = _speech ??= SpeechToText();
    if (speech.isListening) {
      await speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await speech.initialize(
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
    await speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'zh_CN'),
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
      _solver = null;
      _methodEvents = const <XiangjiMethodEvent>[];
      _pendingProblemId = '';
      _awaitingClarification = false;
      _controller.clear();
      _attachments = const <PlatformFile>[];
      _forceNewOnNextSubmit = true;
      _failedInput = '';
      _failureMessage = '';
    });
  }

  Future<void> _retryFailed() async {
    if (_failedInput.isEmpty || _working) return;
    _controller.text = _failedInput;
    await _submit();
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
      await _refreshProblemContext(next.problemId);
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
      await _refreshProblemContext(next.problemId);
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

  Future<void> _submitMethodExercise(
    XiangjiCognitiveExperienceDraft experience,
  ) async {
    final result = _result;
    if (result == null) return;
    final values = await showXiangjiFormDialog(
      context,
      title: '把练习结果交给军师',
      note: experience.transferPrompt,
      fields: const <XiangjiFormFieldSpec>[
        XiangjiFormFieldSpec(
          keyName: 'response',
          label: '你实际观察到了什么',
          hint: '写具体场景、变化或反例；不需要使用方法术语。',
          required: true,
          maxLines: 5,
        ),
      ],
      submitLabel: '让军师反馈并更新问题',
    );
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
      final next = await widget.repository.submitMethodExercise(
        problemId: result.problemId,
        cognitiveExperienceId: experience.id,
        response: values['response']!,
        authorizedSensitiveContext: authorized,
      );
      if (!mounted) return;
      setState(() {
        _result = next;
        _pendingProblemId = next.problemId;
        _awaitingClarification =
            next.outcome == XiangjiAskUserOutcome.askOne;
      });
      await _refreshProblemContext(next.problemId);
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
    final explanation = await widget.dao.latestExplanationCard(
      result.problemId,
    );
    final experiences = result.cognitiveExperiences.isNotEmpty
        ? result.cognitiveExperiences
        : await widget.dao.cognitiveExperiences(
            problemId: result.problemId,
            limit: 12,
          );
    final methodEvents = _methodEvents.isNotEmpty
        ? _methodEvents
        : await widget.dao.latestMethodTurnEvents(
            problemId: result.problemId,
            userVisibleOnly: true,
            limit: 3,
          );
    if (!mounted) return;
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
                '为什么军师这么判断？',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '这是基于当前材料形成的理解，不是关于你的最终事实；新现实可以修订它。',
                style: TextStyle(color: XiangjiPalette.muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              XiangjiLabeledValue(
                label: '已确认的事实 / 体验',
                value: _naturalList(explanation?['facts_json']),
              ),
              XiangjiLabeledValue(
                label: '军师怎样理解',
                value: (explanation?['interpretation'] ??
                        result.draft.judgment)
                    .toString(),
              ),
              XiangjiLabeledValue(
                label: '反例 / 不支持当前判断的材料',
                value: _naturalList(explanation?['counterevidence_json']),
              ),
              XiangjiLabeledValue(
                label: '最弱前提',
                value: (explanation?['weakest_premise'] ?? '').toString(),
              ),
              XiangjiLabeledValue(
                label: '现在仍不知道',
                value: (explanation?['uncertainty'] ?? '').toString(),
              ),
              XiangjiLabeledValue(
                label: '什么现实会改变判断',
                value: (explanation?['what_changes_it'] ??
                        result.draft.changeSignals)
                    .toString(),
              ),
              const Divider(height: 28),
              const Text('叔本华 L0 内核与求解方法怎样影响了这轮？',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                '只解释本轮真正改变或检查了解法的 0–3 项能力，并明确它们受哪些 L0 认识原则约束；理论不是装饰，也不会代替现实。',
                style: TextStyle(
                  color: XiangjiPalette.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              for (final event in methodEvents)
                XiangjiMethodEffectCard(event: event),
              if (experiences.isNotEmpty) ...[
                const Divider(height: 28),
                const Text(
                  '基于当前问题的可选练习',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
              for (final experience in experiences)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(experience.headline),
                  subtitle: Text(experience.userMessage),
                  children: [
                    for (final detail in experience.details.entries)
                      XiangjiLabeledValue(
                        label: detail.key,
                        value: detail.value,
                      ),
                    if (experience.methodText.trim().isNotEmpty)
                      XiangjiLabeledValue(
                        label: '这次使用了什么方法',
                        value: experience.methodText,
                      ),
                    if (experience.transferPrompt.trim().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          XiangjiLabeledValue(
                            label: '可选的小练习',
                            value: experience.transferPrompt,
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await Future<void>.delayed(Duration.zero);
                              if (mounted) {
                                await _submitMethodExercise(experience);
                              }
                            },
                            icon: const Icon(Icons.reply_outlined),
                            label: const Text('完成后让军师给反馈'),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiReadinessBanner() {
    final available = _aiState['available'] == '1';
    final label = (_aiState['label'] ?? '').trim();
    return Semantics(
      button: true,
      label: available ? 'AI 已就绪，$label' : 'AI 未配置，当前使用本地模式',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openGlobalAiSettings,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: available
                ? const Color(0xFFE9F1FF)
                : const Color(0xFFF3F1ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: available
                  ? const Color(0xFFB9CFF2)
                  : XiangjiPalette.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                available
                    ? Icons.auto_awesome_outlined
                    : Icons.memory_outlined,
                color: available
                    ? const Color(0xFF3468C0)
                    : XiangjiPalette.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      available
                          ? 'AI 已就绪 · ${label.isEmpty ? '已配置模型' : label}'
                          : 'AI 未配置 · 当前使用本地求解内核',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available
                          ? '普通问题会直接使用 AI；外发前自动隐藏手机号、邮箱等直接标识。'
                          : '点此配置 API Key 与模型；本地模式不会伪装成 AI 输出。',
                      style: const TextStyle(
                        color: XiangjiPalette.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: XiangjiPalette.muted),
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
          _aiReadinessBanner(),
          const SizedBox(height: 10),
          _composer(),
          if (_failureMessage.isNotEmpty && !_working) ...[
            const SizedBox(height: 14),
            _analysisFailureCard(),
          ],
          if (_working) ...[
            const SizedBox(height: 14),
            XiangjiSectionCard(
              title: _progress?.label ?? '军师正在工作',
              subtitle: '正在自动整理现实、比较原因并形成可修订的下一步；重大问题还会比较多条路线与失败条件。',
              child: const LinearProgressIndicator(),
            ),
          ],
          if (_result != null && !_working) ...[
            const SizedBox(height: 14),
            _resultCard(_result!),
            const SizedBox(height: 14),
            XiangjiAiContributionCard(
              summary: _result!.aiExecution,
              onConfigureAi: _openGlobalAiSettings,
              onReviewSensitiveConsent: _reviewSensitiveConsent,
            ),
            if (_methodEvents.isNotEmpty) ...[
              const SizedBox(height: 14),
              XiangjiSectionCard(
                title: '本轮 L0 认识原则与求解方法如何改变解法',
                subtitle: '只显示当前最影响决定的 0–3 项；完整 24 项叔本华核心概念与 14 项运行能力可在“我的知识库”查看。',
                child: Column(
                  children: [
                    for (final event in _methodEvents)
                      XiangjiMethodEffectCard(event: event),
                  ],
                ),
              ),
            ],
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

  Widget _analysisFailureCard() => XiangjiSectionCard(
        title: '原始记录已保存，分析未完成',
        subtitle: '你的输入没有丢失。可以重试，或检查并切换当前 AI 服务。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _friendlyFailureMessage(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: XiangjiPalette.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _retryFailed,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试分析'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('切换 AI 服务'),
                ),
              ],
            ),
          ],
        ),
      );

  String _friendlyFailureMessage() {
    final lower = _failureMessage.toLowerCase();
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return '当前网络或远程 AI 服务没有及时响应。本地原始记录仍然完整。';
    }
    if (lower.contains('key') ||
        lower.contains('auth') ||
        lower.contains('401') ||
        lower.contains('403')) {
      return '当前 AI 服务授权不可用。请检查全局 AI 服务设置后重试。';
    }
    return '军师没有完成这一轮分析，但你的原始输入已保存；重试不会重复创建问题。';
  }

  Widget _resultCard(XiangjiCouncilResult result) {
    if (result.outcome == XiangjiAskUserOutcome.askOne) {
      return XiangjiSectionCard(
        title: '有一个信息可能改变下一步',
        subtitle: '如果你知道，直接回答；不知道也没关系，军师会改用保守假设或现实侦察。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.clarificationQuestion,
              style: const TextStyle(fontSize: 18, height: 1.55),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _working
                  ? null
                  : () => _submit(userDoesNotKnow: true),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('我不知道，先帮我侦察'),
            ),
          ],
        ),
      );
    }
    final draft = result.draft;
    final progress = result.problemProgress;
    final solver = _solver;
    final hypotheses = (solver?.hypotheses ?? const <Map<String, Object?>>[])
        .map(
          (item) => (item['statement'] ?? item['claim'] ?? item['label'] ?? '')
              .toString()
              .trim(),
        )
        .where((item) => item.isNotEmpty)
        .take(3)
        .join('；');
    final currentState = solver?.currentStateSummary.isNotEmpty == true
        ? solver!.currentStateSummary
        : draft.summary;
    final goal = solver?.goalSummary.isNotEmpty == true
        ? solver!.goalSummary
        : draft.goal;
    final keyGap = solver?.keyGapSummary.isNotEmpty == true
        ? solver!.keyGapSummary
        : draft.targetGap;
    final subgoal = solver?.activeSubgoalSummary.isNotEmpty == true
        ? solver!.activeSubgoalSummary
        : (draft.subGoals.isEmpty ? '' : draft.subGoals.first);
    final action = result.executionFrozen
        ? ''
        : solver?.activeOperatorSummary.isNotEmpty == true
            ? solver!.activeOperatorSummary
            : draft.currentAction;
    final mechanism = (solver?.activeOperator['mechanism'] ?? '')
            .toString()
            .trim()
            .isNotEmpty
        ? (solver!.activeOperator['mechanism'] ?? '').toString()
        : draft.operatorMechanism;
    final prediction = solver?.predictionSummary.isNotEmpty == true
        ? solver!.predictionSummary
        : draft.prediction;

    return XiangjiSolverCockpitView(
      problem: draft.trueProblem,
      currentState: currentState,
      goal: goal,
      keyGap: keyGap,
      activeHypothesis: hypotheses,
      subgoal: subgoal,
      currentAction: action,
      mechanism: result.executionFrozen ? '' : mechanism,
      prediction: result.executionFrozen ? '' : prediction,
      originalNeed: draft.need,
      realityFacts: <String>[
        ...draft.observedFacts,
        ...draft.bodyExperiences,
      ].take(5).toList(),
      epistemicStatus: _epistemicLabel(draft.epistemicStatus),
      keyGapReason:
          (solver?.keyGap['selected_reason'] ?? '').toString(),
      actionBoundary: result.executionFrozen
          ? '当前已冻结不可逆承诺，补证并降低风险后再决定'
          : '预计 ${draft.expectedMinutes} 分钟；${draft.changeSignals}',
      progressLabel: progress?.state.label ?? '',
      currentFocus: progress?.currentFocus ?? '',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          XiangjiLabeledValue(label: '军师一句判断', value: draft.judgment),
          XiangjiLabeledValue(
            label: '军师首选',
            value: result.executionFrozen
                ? '先冻结不可逆承诺，补证、降风险，并在需要时寻求专业复核。'
                : draft.recommendation,
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
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('为什么 / 证据 / 方法'),
              ),
              TextButton(
                onPressed: () => _respond(XiangjiDecisionDraftStatus.deferred),
                child: const Text('暂缓'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => XiangjiProblemWorkspacePage(
                        problemId: result.problemId,
                        repository: widget.repository,
                        dao: widget.dao,
                      ),
                    ),
                  );
                  await _refreshProblemContext(result.problemId);
                  await widget.onDataChanged?.call();
                },
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('打开完整解题台'),
              ),
            ],
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: XiangjiPalette.sand.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '原始记录已保存；部分云端分析未完成，当前回复由本地规则保持连续。你可以继续使用，也可以稍后重试或切换 AI 服务。',
                style: TextStyle(height: 1.45),
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
            '${_epistemicLabel(draft.epistemicStatus)} · ${_decisionStatusLabel(draft.status)}',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
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
                      XiangjiLabeledValue(
                        label: '为什么',
                        value: draft.why,
                      ),
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

  String _naturalList(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        final values = decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        return values.isEmpty ? '当前没有已确认材料' : values.join('；');
      }
    } catch (_) {
      // Fall through to the user-facing empty state.
    }
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? '当前没有已确认材料' : value;
  }

  String _epistemicLabel(String value) => switch (value.toUpperCase()) {
        'SUPPORTED' => '当前有较强现实支持',
        'PROVISIONAL' => '当前材料暂时支持',
        'EPISTEMIC_DEBT' => '仍有会改变判断的关键未知',
        'UNRESOLVED' => '现实根据仍不足',
        _ => '当前理解仍可修订',
      };

  String _decisionStatusLabel(XiangjiDecisionDraftStatus value) =>
      switch (value) {
        XiangjiDecisionDraftStatus.proposed => '待你决定',
        XiangjiDecisionDraftStatus.adopted => '已采用',
        XiangjiDecisionDraftStatus.modified => '已按你修改',
        XiangjiDecisionDraftStatus.opposed => '你已反对',
        XiangjiDecisionDraftStatus.deferred => '已暂缓',
        XiangjiDecisionDraftStatus.stale => '已被新现实替代',
      };
}

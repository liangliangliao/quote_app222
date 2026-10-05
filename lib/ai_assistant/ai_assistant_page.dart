import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/unified_ai_service.dart';
import 'ai_assistant_dao.dart';
import 'ai_assistant_media_service.dart';
import 'ai_assistant_models.dart';
import 'ai_assistant_service.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key, this.initialConversationId});

  final int? initialConversationId;

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final AiAssistantDao _dao = AiAssistantDao();
  final AiAssistantService _assistantService = AiAssistantService();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();
  final AiAssistantMediaService _mediaService = AiAssistantMediaService();
  final AudioPlayer _speechPlayer = AudioPlayer();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<AiAssistantConversation> _conversations = <AiAssistantConversation>[];
  List<AiAssistantMessage> _messages = <AiAssistantMessage>[];
  Map<int, List<AiAssistantAttachment>> _attachmentsByMessageId = <int, List<AiAssistantAttachment>>{};
  List<AiAssistantPendingAttachment> _pendingAttachments = <AiAssistantPendingAttachment>[];
  int? _conversationId;
  String _modelLabel = 'AI';
  String _contextMode = AiAssistantContextMode.defaultMode;
  bool _loading = true;
  bool _sending = false;
  bool _capabilitiesLoading = true;
  AiAssistantMediaCapabilities _mediaCapabilities = const AiAssistantMediaCapabilities.unavailable();
  StreamSubscription<void>? _speechCompleteSubscription;
  List<String> _speechQueue = const [];
  int _speechQueueIndex = 0;
  int _speechRequestId = 0;
  int? _speakingMessageId;
  int? _speechLoadingMessageId;

  @override
  void initState() {
    super.initState();
    _speechCompleteSubscription = _speechPlayer.onPlayerComplete.listen((_) => _playNextSpeechChunk());
    _bootstrap();
  }

  @override
  void dispose() {
    _speechRequestId++;
    _speechCompleteSubscription?.cancel();
    _speechPlayer.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await _dao.ensureTables();
      await _loadModelLabel();
      final list = await _dao.listConversations();
      int? id = widget.initialConversationId;
      if (id == null || !list.any((c) => c.id == id)) {
        if (list.isNotEmpty) {
          id = list.first.id;
        } else {
          final cfg = await _unifiedAiService.resolveGlobalConfig();
          id = await _dao.createConversation(provider: cfg.provider, model: cfg.model);
        }
      }
      final messages = await _dao.listMessages(id);
      final attachments = await _loadAttachmentsMap(id);
      final selectedConversation = await _dao.getConversation(id);
      final refreshed = await _dao.listConversations();
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _messages = messages;
        _attachmentsByMessageId = attachments;
        _contextMode = selectedConversation?.contextMode ?? AiAssistantContextMode.defaultMode;
        _conversations = refreshed;
        _loading = false;
      });
      _scrollToBottom(delay: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('AI 助手初始化失败：$e');
    }
  }

  Future<void> _loadModelLabel() async {
    try {
      final cfg = await _unifiedAiService.resolveGlobalConfig();
      _modelLabel = cfg.label;
      final alreadyResolved = _mediaCapabilities.provider == cfg.provider && _mediaCapabilities.model == cfg.model;
      if (!alreadyResolved) {
        _capabilitiesLoading = true;
        unawaited(_refreshMediaCapabilities(cfg));
      }
    } catch (_) {
      _modelLabel = 'AI';
      _capabilitiesLoading = false;
      _mediaCapabilities = const AiAssistantMediaCapabilities.unavailable();
    }
  }

  Future<void> _refreshMediaCapabilities(UnifiedAiResolvedConfig cfg) async {
    AiAssistantMediaCapabilities capabilities;
    try {
      capabilities = await _mediaService.resolveCapabilities(cfg);
    } catch (e) {
      capabilities = AiAssistantMediaCapabilities.unavailable(
        provider: cfg.provider,
        model: cfg.model,
        speechReason: '能力检测失败：$e',
        imageReason: '能力检测失败：$e',
        videoReason: '能力检测失败：$e',
      );
    }
    if (!mounted) return;
    setState(() {
      _mediaCapabilities = capabilities;
      _capabilitiesLoading = false;
    });
  }

  Future<void> _reloadCurrent() async {
    final id = _conversationId;
    if (id == null) return;
    final messages = await _dao.listMessages(id);
    final attachments = await _loadAttachmentsMap(id);
    final selectedConversation = await _dao.getConversation(id);
    final conversations = await _dao.listConversations();
    await _loadModelLabel();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _attachmentsByMessageId = attachments;
      _contextMode = selectedConversation?.contextMode ?? _contextMode;
      _conversations = conversations;
    });
    _scrollToBottom(delay: true);
  }

  Future<void> _createConversation() async {
    try {
      final cfg = await _unifiedAiService.resolveGlobalConfig();
      final id = await _dao.createConversation(provider: cfg.provider, model: cfg.model);
      final conversations = await _dao.listConversations();
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _messages = <AiAssistantMessage>[];
        _attachmentsByMessageId = <int, List<AiAssistantAttachment>>{};
        _pendingAttachments = <AiAssistantPendingAttachment>[];
        _contextMode = AiAssistantContextMode.defaultMode;
        _conversations = conversations;
        _modelLabel = cfg.label;
      });
    } catch (e) {
      _showSnack('新建会话失败：$e');
    }
  }

  Future<void> _openConversation(int id) async {
    final messages = await _dao.listMessages(id);
    final attachments = await _loadAttachmentsMap(id);
    final conversation = await _dao.getConversation(id);
    final conversations = await _dao.listConversations();
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _messages = messages;
      _attachmentsByMessageId = attachments;
      _pendingAttachments = <AiAssistantPendingAttachment>[];
      _contextMode = conversation?.contextMode ?? AiAssistantContextMode.defaultMode;
      _conversations = conversations;
    });
    Navigator.of(context).maybePop();
    _scrollToBottom(delay: true);
  }

  Future<void> _deleteCurrentConversation() async {
    final id = _conversationId;
    if (id == null) return;
    final ok = await _confirm('删除当前会话？', '删除后该会话将不会再出现在历史列表中。');
    if (ok != true) return;
    await _dao.deleteConversation(id);
    final list = await _dao.listConversations();
    int? nextId;
    if (list.isNotEmpty) {
      nextId = list.first.id;
    } else {
      final cfg = await _unifiedAiService.resolveGlobalConfig();
      nextId = await _dao.createConversation(provider: cfg.provider, model: cfg.model);
    }
    final messages = await _dao.listMessages(nextId);
    final attachments = await _loadAttachmentsMap(nextId);
    final refreshed = await _dao.listConversations();
    if (!mounted) return;
    setState(() {
      _conversationId = nextId;
      _messages = messages;
      _attachmentsByMessageId = attachments;
      _pendingAttachments = <AiAssistantPendingAttachment>[];
      _contextMode = refreshed.firstWhere((c) => c.id == nextId, orElse: () => refreshed.first).contextMode;
      _conversations = refreshed;
    });
  }

  Future<void> _deleteAllConversations() async {
    final ok = await _confirm('删除全部历史聊天？', '所有 AI 助手会话都会从历史列表中移除。');
    if (ok != true) return;
    await _dao.deleteAllConversations();
    final cfg = await _unifiedAiService.resolveGlobalConfig();
    final id = await _dao.createConversation(provider: cfg.provider, model: cfg.model);
    final refreshed = await _dao.listConversations();
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _messages = <AiAssistantMessage>[];
      _attachmentsByMessageId = <int, List<AiAssistantAttachment>>{};
      _pendingAttachments = <AiAssistantPendingAttachment>[];
      _contextMode = AiAssistantContextMode.defaultMode;
      _conversations = refreshed;
      _modelLabel = cfg.label;
    });
  }

  Future<bool?> _confirm(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final id = _conversationId;
    final text = _inputCtrl.text.trim();
    if (id == null || (text.isEmpty && _pendingAttachments.isEmpty) || _sending) return;
    final attachments = List<AiAssistantPendingAttachment>.from(_pendingAttachments);
    _inputCtrl.clear();
    setState(() {
      _pendingAttachments = <AiAssistantPendingAttachment>[];
      _sending = true;
    });
    try {
      await _assistantService.sendMessage(
        conversationId: id,
        content: text,
        contextMode: _contextMode,
        attachments: attachments,
      );
      await _reloadCurrent();
    } catch (e) {
      _showSnack('发送失败：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _readMessage(AiAssistantMessage message) async {
    if (!_mediaCapabilities.speech || message.content.trim().isEmpty) return;
    if (_speakingMessageId == message.id || _speechLoadingMessageId == message.id) {
      await _stopSpeech();
      return;
    }
    final requestId = ++_speechRequestId;
    await _speechPlayer.stop();
    if (!mounted) return;
    setState(() {
      _speechLoadingMessageId = message.id;
      _speakingMessageId = null;
      _speechQueue = const [];
      _speechQueueIndex = 0;
    });
    try {
      final files = await _mediaService.synthesizeSpeech(message.content);
      if (!mounted || requestId != _speechRequestId) return;
      setState(() {
        _speechLoadingMessageId = null;
        _speakingMessageId = message.id;
        _speechQueue = files;
        _speechQueueIndex = 0;
      });
      if (files.isNotEmpty) await _speechPlayer.play(DeviceFileSource(files.first));
    } catch (e) {
      if (!mounted || requestId != _speechRequestId) return;
      setState(() {
        _speechLoadingMessageId = null;
        _speakingMessageId = null;
      });
      _showSnack(_friendlyError('朗读失败', e));
    }
  }

  Future<void> _playNextSpeechChunk() async {
    if (!mounted || _speakingMessageId == null) return;
    final next = _speechQueueIndex + 1;
    if (next >= _speechQueue.length) {
      setState(() {
        _speakingMessageId = null;
        _speechQueue = const [];
        _speechQueueIndex = 0;
      });
      return;
    }
    setState(() => _speechQueueIndex = next);
    await _speechPlayer.play(DeviceFileSource(_speechQueue[next]));
  }

  Future<void> _stopSpeech() async {
    _speechRequestId++;
    await _speechPlayer.stop();
    if (!mounted) return;
    setState(() {
      _speechLoadingMessageId = null;
      _speakingMessageId = null;
      _speechQueue = const [];
      _speechQueueIndex = 0;
    });
  }

  Future<void> _generateMedia({required bool video}) async {
    final id = _conversationId;
    final prompt = _inputCtrl.text.trim();
    final supported = video ? _mediaCapabilities.video : _mediaCapabilities.image;
    if (id == null || _sending || !supported) return;
    if (prompt.isEmpty) {
      _showSnack('请先输入${video ? '视频' : '图片'}生成提示词');
      return;
    }
    _inputCtrl.clear();
    setState(() => _sending = true);
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    try {
      final cfg = await _unifiedAiService.resolveGlobalConfig();
      await _dao.insertMessage(
        conversationId: id,
        role: 'user',
        content: prompt,
        provider: cfg.provider,
        model: cfg.model,
      );
      await _dao.touchConversation(
        id,
        provider: cfg.provider,
        model: cfg.model,
        title: prompt.length <= 32 ? prompt : '${prompt.substring(0, 32)}…',
      );
      final media = video ? await _mediaService.generateVideo(prompt) : await _mediaService.generateImage(prompt);
      final assistantMessageId = await _dao.insertMessage(
        conversationId: id,
        role: 'assistant',
        content: '已通过 ${media.provider} · ${media.model} 生成${video ? '视频' : '图片'}。',
        provider: media.provider,
        model: media.model,
        latencyMs: DateTime.now().millisecondsSinceEpoch - startedAt,
      );
      final file = File(media.path);
      await _dao.insertAttachments(
        conversationId: id,
        messageId: assistantMessageId,
        attachments: [
          AiAssistantAttachment(
            id: 0,
            conversationId: id,
            messageId: assistantMessageId,
            attachmentType: video ? AiAssistantAttachmentType.video : AiAssistantAttachmentType.image,
            name: media.name,
            path: media.path,
            mimeType: media.mimeType,
            sizeBytes: await file.length(),
            provider: media.provider,
            providerFileId: media.remoteUrl,
            providerUploadedAtMs: DateTime.now().millisecondsSinceEpoch,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
      await _reloadCurrent();
    } catch (e) {
      try {
        await _dao.insertMessage(
          conversationId: id,
          role: 'assistant',
          content: _friendlyError('${video ? '视频' : '图片'}生成失败', e),
          error: e.toString(),
        );
        await _reloadCurrent();
      } catch (_) {}
      _showSnack(_friendlyError('${video ? '视频' : '图片'}生成失败', e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendlyError(String prefix, Object error) {
    final raw = error.toString();
    final clean = raw.startsWith('Bad state: ') ? raw.substring('Bad state: '.length) : raw;
    return '$prefix：$clean';
  }



  Future<Map<int, List<AiAssistantAttachment>>> _loadAttachmentsMap(int conversationId) async {
    final attachments = await _dao.listAttachmentsForConversation(conversationId);
    final map = <int, List<AiAssistantAttachment>>{};
    for (final attachment in attachments) {
      map.putIfAbsent(attachment.messageId, () => <AiAssistantAttachment>[]).add(attachment);
    }
    return map;
  }

  Future<void> _pickAttachment({required bool imagesOnly}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: imagesOnly ? FileType.custom : FileType.any,
        allowedExtensions: imagesOnly ? const <String>['jpg', 'jpeg', 'png', 'webp', 'gif'] : null,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      final attachmentDir = Directory(p.join(dir.path, 'ai_assistant_attachments'));
      if (!await attachmentDir.exists()) await attachmentDir.create(recursive: true);
      final next = <AiAssistantPendingAttachment>[..._pendingAttachments];
      for (final item in result.files) {
        final srcPath = item.path;
        if (srcPath == null || srcPath.trim().isEmpty) continue;
        final src = File(srcPath);
        if (!await src.exists()) continue;
        final safeName = item.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final targetName = '${DateTime.now().millisecondsSinceEpoch}_${safeName}';
        final targetPath = p.join(attachmentDir.path, targetName);
        await src.copy(targetPath);
        final type = _isImageName(item.name) ? AiAssistantAttachmentType.image : AiAssistantAttachmentType.file;
        next.add(AiAssistantPendingAttachment(
          attachmentType: type,
          name: item.name,
          path: targetPath,
          mimeType: _guessMimeType(item.name),
          sizeBytes: item.size,
        ));
      }
      if (!mounted) return;
      setState(() => _pendingAttachments = next.take(8).toList());
    } catch (e) {
      _showSnack('选择附件失败：$e');
    }
  }

  bool _isImageName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  String _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.md')) return 'text/markdown';
    return 'text/plain';
  }

  void _showAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('上传图片'),
              subtitle: const Text('支持 jpg、png、webp、gif；OpenRouter/OpenAI 视觉模型可直接看图'),
              onTap: () {
                Navigator.pop(context);
                _pickAttachment(imagesOnly: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('上传文件'),
              subtitle: const Text('文本/Markdown/CSV/JSON/代码文件会自动读取内容'),
              onTap: () {
                Navigator.pop(context);
                _pickAttachment(imagesOnly: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyMessage(AiAssistantMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    _showSnack('已复制');
  }

  Future<void> _editUserMessage(AiAssistantMessage message) async {
    final id = _conversationId;
    if (id == null || message.role != 'user' || _sending) return;
    final ctrl = TextEditingController(text: message.content == '（已上传附件）' ? '' : message.content);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑消息并重新发送'),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 8,
          decoration: const InputDecoration(hintText: '输入新的消息内容'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('重新发送')),
        ],
      ),
    );
    ctrl.dispose();
    if (edited == null) return;
    final attachments = (_attachmentsByMessageId[message.id] ?? const <AiAssistantAttachment>[])
        .map(AiAssistantPendingAttachment.fromAttachment)
        .toList();
    await _dao.deleteMessagesFrom(id, message.id);
    setState(() => _sending = true);
    try {
      await _assistantService.sendMessage(
        conversationId: id,
        content: edited,
        contextMode: _contextMode,
        attachments: attachments,
      );
      await _reloadCurrent();
    } catch (e) {
      _showSnack('重新发送失败：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retryAssistantMessage(AiAssistantMessage message) async {
    final id = _conversationId;
    if (id == null || message.role != 'assistant' || _sending) return;
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index <= 0) return;
    AiAssistantMessage? userMessage;
    for (var i = index - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        userMessage = _messages[i];
        break;
      }
    }
    if (userMessage == null) return;
    final attachments = (_attachmentsByMessageId[userMessage.id] ?? const <AiAssistantAttachment>[])
        .map(AiAssistantPendingAttachment.fromAttachment)
        .toList();
    await _dao.deleteMessagesFrom(id, userMessage.id);
    setState(() => _sending = true);
    try {
      await _assistantService.sendMessage(
        conversationId: id,
        content: userMessage.content == '（已上传附件）' ? '' : userMessage.content,
        contextMode: _contextMode,
        attachments: attachments,
      );
      await _reloadCurrent();
    } catch (e) {
      _showSnack('重试失败：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setMessageFeedback(
    AiAssistantMessage message,
    int rating, {
    String? reason,
    String? comment,
  }) async {
    final id = _conversationId;
    if (id == null || message.role != 'assistant') return;
    try {
      final nextRating = message.feedbackRating == rating && rating > 0 ? 0 : rating;
      await _dao.setMessageFeedback(
        conversationId: id,
        messageId: message.id,
        rating: nextRating,
        reason: nextRating < 0 ? reason : null,
        comment: nextRating < 0 ? comment : null,
      );
      await _reloadCurrent();
      if (nextRating > 0) _showSnack('已记录：这条回复有帮助');
      if (nextRating == 0) _showSnack('已取消反馈');
    } catch (e) {
      _showSnack('保存反馈失败：$e');
    }
  }

  Future<void> _showNegativeFeedback(AiAssistantMessage message) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final items = <String>[
          AiAssistantFeedbackReason.misunderstoodContext,
          AiAssistantFeedbackReason.irrelevantHistory,
          AiAssistantFeedbackReason.ignoredRelevantHistory,
          AiAssistantFeedbackReason.inaccurate,
          AiAssistantFeedbackReason.tooLong,
          AiAssistantFeedbackReason.tooShort,
          AiAssistantFeedbackReason.other,
        ];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Text('这条回复哪里不好？', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              for (final item in items)
                ListTile(
                  title: Text(AiAssistantFeedbackReason.label(item)),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        );
      },
    );
    if (reason == null) return;
    String? comment;
    if (reason == AiAssistantFeedbackReason.other) {
      comment = await _askFeedbackComment();
    }
    await _setMessageFeedback(message, -1, reason: reason, comment: comment);
  }

  Future<String?> _askFeedbackComment() async {
    final ctrl = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('补充反馈'),
          content: TextField(
            controller: ctrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '可选：说明哪里需要改进'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('跳过')),
            FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('保存')),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  void _scrollToBottom({bool delay = false}) {
    void jump() {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    if (delay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    } else {
      jump();
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI 助手'),
            Text(
              _modelLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '新建会话',
            onPressed: _sending ? null : _createConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete_current') _deleteCurrentConversation();
              if (v == 'delete_all') _deleteAllConversations();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete_current', child: Text('删除当前会话')),
              PopupMenuItem(value: 'delete_all', child: Text('删除全部历史')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildContextModeBar(),
                Expanded(child: _buildMessageList()),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('历史会话', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                  IconButton(
                    tooltip: '新建',
                    onPressed: _createConversation,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _conversations.isEmpty
                  ? const Center(child: Text('暂无历史会话'))
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final item = _conversations[index];
                        final selected = item.id == _conversationId;
                        return ListTile(
                          selected: selected,
                          leading: Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline),
                          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${item.messageCount} 条消息 · ${AiAssistantContextMode.label(item.contextMode)} · ${_formatTime(item.updatedAtMs)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openConversation(item.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextModeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_outlined, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          const Text('上下文模式', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: AiAssistantContextMode.normalize(_contextMode),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: AiAssistantContextMode.fullHistory,
                    child: Text('拼接全部历史'),
                  ),
                  DropdownMenuItem(
                    value: AiAssistantContextMode.edenAiEmbedding,
                    child: Text('Eden AI 语义上下文检索'),
                  ),
                ],
                onChanged: _sending
                    ? null
                    : (value) async {
                        final id = _conversationId;
                        final mode = AiAssistantContextMode.normalize(value);
                        if (id == null) return;
                        setState(() => _contextMode = mode);
                        await _dao.updateContextMode(id, mode);
                        final conversations = await _dao.listConversations();
                        if (!mounted) return;
                        setState(() => _conversations = conversations);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 18),
              const Text('开始新的 AI 对话', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                '当前模型：$_modelLabel\n上下文模式：${AiAssistantContextMode.label(_contextMode)}\n聊天历史会保存在本地数据库。',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (_sending && index == _messages.length) {
          return const _AssistantTypingBubble();
        }
        final message = _messages[index];
        return _MessageBubble(
          message: message,
          attachments: _attachmentsByMessageId[message.id] ?? const <AiAssistantAttachment>[],
          onCopy: () => _copyMessage(message),
          onEdit: message.role == 'user' ? () => _editUserMessage(message) : null,
          onRetry: message.role == 'assistant' ? () => _retryAssistantMessage(message) : null,
          onRead: message.role == 'assistant' && _mediaCapabilities.speech ? () => _readMessage(message) : null,
          readDisabledReason: _capabilitiesLoading ? '正在检测当前模型的朗读能力' : _mediaCapabilities.speechReason,
          isReading: _speakingMessageId == message.id,
          isReadLoading: _speechLoadingMessageId == message.id,
          onPositiveFeedback: () => _setMessageFeedback(message, 1),
          onNegativeFeedback: () => _showNegativeFeedback(message),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MediaCapabilityButton(
                      icon: Icons.image_outlined,
                      label: '生成图片',
                      enabled: !_capabilitiesLoading && _mediaCapabilities.image && !_sending,
                      tooltip: _capabilitiesLoading ? '正在检测当前模型能力' : _mediaCapabilities.imageReason,
                      onPressed: () => _generateMedia(video: false),
                    ),
                    const SizedBox(width: 8),
                    _MediaCapabilityButton(
                      icon: Icons.movie_creation_outlined,
                      label: '生成视频',
                      enabled: !_capabilitiesLoading && _mediaCapabilities.video && !_sending,
                      tooltip: _capabilitiesLoading ? '正在检测当前模型能力' : _mediaCapabilities.videoReason,
                      onPressed: () => _generateMedia(video: true),
                    ),
                    const SizedBox(width: 8),
                    _CapabilityStatusChip(
                      loading: _capabilitiesLoading,
                      speech: _mediaCapabilities.speech,
                      image: _mediaCapabilities.image,
                      video: _mediaCapabilities.video,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            if (_pendingAttachments.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _pendingAttachments.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: _PendingAttachmentChip(
                            attachment: _pendingAttachments[i],
                            onRemove: () {
                              setState(() {
                                _pendingAttachments = [..._pendingAttachments]..removeAt(i);
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '上传图片或文件',
                  onPressed: _sending ? null : _showAttachmentMenu,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _pendingAttachments.isEmpty ? '输入消息...' : '补充描述或问题...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  width: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder()),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${two(dt.hour)}:${two(dt.minute)}';
    }
    return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _MediaCapabilityButton extends StatelessWidget {
  const _MediaCapabilityButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: enabled ? Theme.of(context).colorScheme.primary : const Color(0xFFB6BBC4)),
        label: Text(label),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _CapabilityStatusChip extends StatelessWidget {
  const _CapabilityStatusChip({required this.loading, required this.speech, required this.image, required this.video});

  final bool loading;
  final bool speech;
  final bool image;
  final bool video;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Chip(
        avatar: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        label: Text('检测能力'),
      );
    }
    final enabledCount = [speech, image, video].where((value) => value).length;
    return Chip(
      avatar: Icon(enabledCount > 0 ? Icons.check_circle_outline : Icons.block_outlined, size: 17),
      label: Text('朗${speech ? '✓' : '—'} 图${image ? '✓' : '—'} 影${video ? '✓' : '—'}'),
    );
  }
}


class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.attachments,
    required this.onCopy,
    required this.onPositiveFeedback,
    required this.onNegativeFeedback,
    required this.readDisabledReason,
    required this.isReading,
    required this.isReadLoading,
    this.onEdit,
    this.onRetry,
    this.onRead,
  });

  final AiAssistantMessage message;
  final List<AiAssistantAttachment> attachments;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRetry;
  final VoidCallback? onRead;
  final String readDisabledReason;
  final bool isReading;
  final bool isReadLoading;
  final VoidCallback onPositiveFeedback;
  final VoidCallback onNegativeFeedback;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bg = isUser ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6);
    final fg = isUser ? Colors.white : const Color(0xFF111827);
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachments.isNotEmpty) ...[
            _AttachmentPreviewList(attachments: attachments, isUser: isUser),
            if (message.content.trim().isNotEmpty && message.content.trim() != '（已上传附件）') const SizedBox(height: 8),
          ],
          if (message.content.trim().isNotEmpty && message.content.trim() != '（已上传附件）')
            _AiMessageContent(text: message.content, color: fg),
        ],
      ),
    );

    final column = Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubble,
        _MessageActionBar(
          message: message,
          onCopy: onCopy,
          onEdit: onEdit,
          onRetry: onRetry,
          onRead: onRead,
          readDisabledReason: readDisabledReason,
          isReading: isReading,
          isReadLoading: isReadLoading,
          onPositive: onPositiveFeedback,
          onNegative: onNegativeFeedback,
        ),
      ],
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: column,
    );
  }
}

class _MessageActionBar extends StatelessWidget {
  const _MessageActionBar({
    required this.message,
    required this.onCopy,
    required this.onPositive,
    required this.onNegative,
    this.onEdit,
    this.onRetry,
    this.onRead,
    this.readDisabledReason = '',
    this.isReading = false,
    this.isReadLoading = false,
  });

  final AiAssistantMessage message;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRetry;
  final VoidCallback? onRead;
  final String readDisabledReason;
  final bool isReading;
  final bool isReadLoading;
  final VoidCallback onPositive;
  final VoidCallback onNegative;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == 'assistant';
    final positive = message.feedbackRating > 0;
    final negative = message.feedbackRating < 0;
    final reasonLabel = AiAssistantFeedbackReason.label(message.feedbackReason);
    return Padding(
      padding: EdgeInsets.only(left: isAssistant ? 4 : 0, right: isAssistant ? 0 : 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '复制',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF6B7280)),
          ),
          if (!isAssistant && onEdit != null)
            IconButton(
              tooltip: '编辑并重新发送',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF6B7280)),
            ),
          if (isAssistant && onRetry != null)
            IconButton(
              tooltip: '重试',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280)),
            ),
          if (isAssistant)
            Tooltip(
              message: onRead == null ? readDisabledReason : (isReading || isReadLoading ? '停止朗读' : '朗读回复'),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: onRead,
                icon: isReadLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        isReading ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                        color: onRead == null ? const Color(0xFFB6BBC4) : (isReading ? const Color(0xFFDC2626) : const Color(0xFF6B7280)),
                      ),
              ),
            ),
          if (isAssistant) ...[
            IconButton(
              tooltip: positive ? '已标记有帮助，点击取消' : '有帮助',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onPositive,
              icon: Icon(
                positive ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                color: positive ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
              ),
            ),
            IconButton(
              tooltip: negative ? '已标记没帮助' : '没帮助 / 反馈',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: onNegative,
              icon: Icon(
                negative ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined,
                color: negative ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
              ),
            ),
            if (reasonLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(reasonLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentPreviewList extends StatelessWidget {
  const _AttachmentPreviewList({required this.attachments, required this.isUser});

  final List<AiAssistantAttachment> attachments;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final fg = isUser ? Colors.white : const Color(0xFF374151);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((attachment) {
        final borderColor = isUser ? Colors.white.withOpacity(0.45) : const Color(0xFFD1D5DB);
        final card = Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: isUser ? Colors.white.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attachment.isImage && File(attachment.path).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(attachment.path),
                    height: 120,
                    width: 210,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (attachment.isImage && File(attachment.path).existsSync()) const SizedBox(height: 6),
              if (attachment.isVideo)
                Container(
                  height: 112,
                  width: 210,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 42),
                      SizedBox(height: 6),
                      Text('点击播放生成视频', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              if (attachment.isVideo) const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    attachment.isImage
                        ? Icons.image_outlined
                        : (attachment.isVideo ? Icons.movie_outlined : Icons.insert_drive_file_outlined),
                    size: 18,
                    color: fg,
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text(attachment.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 12))),
                ],
              ),
            ],
          ),
        );
        if (!attachment.isVideo) return card;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openVideo(context, attachment),
          child: card,
        );
      }).toList(),
    );
  }

  Future<void> _openVideo(BuildContext context, AiAssistantAttachment attachment) async {
    final remote = (attachment.providerFileId ?? '').trim();
    final uri = remote.startsWith('http://') || remote.startsWith('https://') ? Uri.parse(remote) : Uri.file(attachment.path);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('视频已保存在：${attachment.path}')));
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({required this.attachment, required this.onRemove});

  final AiAssistantPendingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachment.isImage && File(attachment.path).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(File(attachment.path), width: 28, height: 28, fit: BoxFit.cover),
            )
          else
            Icon(attachment.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 18, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Flexible(child: Text(attachment.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _AiMessageContent extends StatelessWidget {
  const _AiMessageContent({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          if (block.isTable)
            _MarkdownTable(block.lines, textColor: color)
          else
            SelectableText(block.lines.join('\n'), style: TextStyle(color: color, fontSize: 15, height: 1.45)),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  List<_ContentBlock> _parseBlocks(String value) {
    final lines = value.split('\n');
    final blocks = <_ContentBlock>[];
    var current = <String>[];
    var currentIsTable = false;

    bool isTableLine(String line) {
      final trimmed = line.trim();
      if (!trimmed.contains('|')) return false;
      return trimmed.split('|').where((p) => p.trim().isNotEmpty).length >= 2;
    }

    void flush() {
      if (current.isEmpty) return;
      blocks.add(_ContentBlock(List<String>.from(current), currentIsTable));
      current = <String>[];
    }

    for (final line in lines) {
      final table = isTableLine(line);
      if (current.isNotEmpty && table != currentIsTable) flush();
      currentIsTable = table;
      current.add(line);
    }
    flush();
    return blocks;
  }
}

class _ContentBlock {
  final List<String> lines;
  final bool isTable;
  const _ContentBlock(this.lines, this.isTable);
}

class _MarkdownTable extends StatelessWidget {
  const _MarkdownTable(this.lines, {required this.textColor});

  final List<String> lines;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[];
    for (final raw in lines) {
      final trimmed = raw.trim();
      if (RegExp(r'^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)+\|?$').hasMatch(trimmed)) continue;
      final cells = trimmed.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (cells.length >= 2) rows.add(cells);
    }
    if (rows.isEmpty) return SelectableText(lines.join('\n'), style: TextStyle(color: textColor, fontSize: 15, height: 1.45));
    final maxCols = rows.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: const Color(0xFFD1D5DB)),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: BoxDecoration(color: r == 0 ? const Color(0xFFE5E7EB).withOpacity(0.55) : Colors.white.withOpacity(0.55)),
              children: [
                for (var c = 0; c < maxCols; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: SelectableText(
                      c < rows[r].length ? rows[r][c] : '',
                      style: TextStyle(color: const Color(0xFF111827), fontWeight: r == 0 ? FontWeight.w700 : FontWeight.w400, fontSize: 13),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AssistantTypingBubble extends StatelessWidget {
  const _AssistantTypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('正在思考...', style: TextStyle(color: Color(0xFF6B7280))),
      ),
    );
  }
}

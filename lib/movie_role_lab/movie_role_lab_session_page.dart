import 'package:flutter/material.dart';

import 'movie_role_lab_models.dart';
import 'movie_role_lab_service.dart';

class MovieRoleLabSessionPage extends StatefulWidget {
  final MovieRoleLabMovie movie;
  final MovieRoleLabCharacter character;
  final List<MovieRoleLabCharacter> ensemble;
  final MovieRoleLabEntryBrief brief;
  final MovieRoleLabEpisode? episode;

  const MovieRoleLabSessionPage({
    super.key,
    required this.movie,
    required this.character,
    required this.ensemble,
    required this.brief,
    this.episode,
  });

  @override
  State<MovieRoleLabSessionPage> createState() => _MovieRoleLabSessionPageState();
}

class _MovieRoleLabSessionPageState extends State<MovieRoleLabSessionPage> {
  final MovieRoleLabService _service = MovieRoleLabService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = false;
  String _innerState = '';
  String _mode = 'exact_script';
  String _selectedEmoji = '';
  int _lineCursor = 0;
  final List<_ChatItem> _items = <_ChatItem>[];

  List<Map<String, String>> get _history => _items
      .where((e) => e.kind == 'user' || e.kind == 'cast')
      .map((e) => {
            'role': e.kind == 'user' ? 'user' : 'assistant',
            'content': e.text,
          })
      .toList();

  @override
  void initState() {
    super.initState();
    _innerState = widget.brief.whatYouFear;
    if (widget.episode == null) {
      _mode = 'free_creative';
    }
    _resetPerformance();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _resetPerformance() {
    setState(() {
      _items.clear();
      _lineCursor = 0;
      _selectedEmoji = '';
      _inputCtrl.clear();
      _items.add(_ChatItem(kind: 'director', text: _modeIntro()));
      _items.add(_ChatItem(kind: 'meta', text: widget.brief.subtitleEvidence.status));
      if (widget.episode == null) {
        _items.add(_ChatItem(kind: 'cast', text: widget.brief.openingLine));
      } else if (_mode == 'exact_script' || _mode == 'semantic_script') {
        _advanceAiUntilUser();
      } else {
        _items.add(_ChatItem(kind: 'meta', text: '自由创造模式：请在《${widget.movie.title}》背景和“${widget.episode!.title}”片段前提下扮演，不要跳出电影处境。'));
      }
    });
    _scrollToBottom();
  }

  String _modeIntro() {
    switch (_mode) {
      case 'exact_script':
        return '模式一：双方按剧本逐字表演。你只能从下方属于 ${widget.character.name} 的台词列表中选择台词，可附加表情；若台词或顺序不一致，会提示“你已经出戏了”。';
      case 'semantic_script':
        return '模式二：AI 角色严格按剧本台词推进；你可以自由输入，但语义必须与当前顺序下 ${widget.character.name} 的剧本台词高度一致，可附加表情。';
      case 'free_creative':
      default:
        return '模式三：双方可在电影背景与当前片段剧本前提下自由创造；如果明显超出前提，表演会暂停并说明原因。';
    }
  }

  bool _isUserLine(MovieRoleLabScriptLine line) => line.belongsTo(widget.character);

  MovieRoleLabScriptLine? _expectedUserLine() {
    final lines = widget.episode?.lines ?? const <MovieRoleLabScriptLine>[];
    if (_lineCursor >= lines.length) return null;
    final line = lines[_lineCursor];
    return _isUserLine(line) ? line : null;
  }

  List<MovieRoleLabScriptLine> _remainingUserLines() {
    final lines = widget.episode?.lines ?? const <MovieRoleLabScriptLine>[];
    return lines.skip(_lineCursor).where(_isUserLine).toList();
  }

  void _advanceAiUntilUser() {
    final episode = widget.episode;
    if (episode == null) return;
    while (_lineCursor < episode.lines.length) {
      final line = episode.lines[_lineCursor];
      if (_isUserLine(line)) break;
      _items.add(_ChatItem(kind: 'cast', text: '${line.displaySpeaker}：${line.text}'));
      _lineCursor++;
    }
    if (_lineCursor >= episode.lines.length) {
      _items.add(const _ChatItem(kind: 'meta', text: '这一集剧本已表演完毕。你可以点击“重新开始”再次练习。'));
    }
  }

  String _norm(String value) => value
      .replaceAll(RegExp(r'''[\s，。！？、,.!?;；:：“”"‘’'（）()\[\]【】]+'''), '')
      .toLowerCase()
      .trim();

  String _withEmoji(String text) => _selectedEmoji.trim().isEmpty ? text : '$text ${_selectedEmoji.trim()}';

  void _sendExact(MovieRoleLabScriptLine selectedLine) {
    if (_loading) return;
    final expected = _expectedUserLine();
    if (expected == null) {
      setState(() => _items.add(const _ChatItem(kind: 'director', text: '当前没有轮到你的台词；请等待对手戏台词推进，或重新开始。')));
      _scrollToBottom();
      return;
    }
    if (selectedLine.lineIndex != expected.lineIndex || _norm(selectedLine.text) != _norm(expected.text)) {
      setState(() {
        _items.add(_ChatItem(kind: 'director', text: '哈哈，你已经出戏了：现在应该接第 ${expected.lineIndex} 句“${expected.text}”，不能跳台词或倒回去。'));
      });
      _scrollToBottom();
      return;
    }
    setState(() {
      _items.add(_ChatItem(kind: 'user', text: _withEmoji(expected.text)));
      _lineCursor++;
      _selectedEmoji = '';
      _advanceAiUntilUser();
    });
    _scrollToBottom();
  }

  Future<void> _sendSemanticOrFree([String? preset]) async {
    final raw = (preset ?? _inputCtrl.text).trim();
    final text = _withEmoji(raw);
    if (raw.isEmpty || _loading) return;

    final expected = (_mode == 'semantic_script') ? _expectedUserLine() : null;
    if (_mode == 'semantic_script' && expected == null) {
      setState(() => _items.add(const _ChatItem(kind: 'director', text: '当前没有轮到你的台词；请等待对手戏推进，或重新开始。')));
      _scrollToBottom();
      return;
    }

    setState(() {
      _items.add(_ChatItem(kind: 'user', text: text));
      _loading = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();

    try {
      final result = await _service.playTurn(
        movie: widget.movie,
        character: widget.character,
        ensemble: widget.ensemble,
        history: _history,
        userInput: raw,
        subtitleEvidence: widget.brief.subtitleEvidence,
        episode: widget.episode,
        dialogueMode: _mode,
        expectedLine: expected,
        dialogueCursor: _lineCursor,
      );
      if (!mounted) return;
      setState(() {
        if (!result.accepted) {
          _items.add(_ChatItem(
            kind: 'director',
            text: result.directorFeedback.trim().isNotEmpty
                ? result.directorFeedback.trim()
                : (_mode == 'semantic_script' ? '你的台词语义还不符合剧本要求，请重新对齐当前台词。' : '这句超出了当前电影背景或片段前提，请重新调整。'),
          ));
          _items.add(_ChatItem(kind: 'meta', text: result.stopReason.trim().isEmpty ? '表演已暂停，等待你重新进入角色。' : result.stopReason.trim()));
        } else {
          if (result.directorFeedback.trim().isNotEmpty) {
            _items.add(_ChatItem(kind: 'director', text: result.directorFeedback.trim()));
          }
          if (_mode == 'semantic_script' && expected != null) {
            _lineCursor++;
            _advanceAiUntilUser();
          } else {
            for (final line in result.castLines) {
              _items.add(_ChatItem(kind: 'cast', text: line));
            }
          }
          if (result.sceneProgress.trim().isNotEmpty) {
            _items.add(_ChatItem(kind: 'meta', text: result.sceneProgress.trim()));
          }
          _innerState = result.innerState.trim().isEmpty ? _innerState : result.innerState.trim();
        }
        _selectedEmoji = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.add(_ChatItem(kind: 'meta', text: '生成失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _bubble(_ChatItem item) {
    final isUser = item.kind == 'user';
    final bg = item.kind == 'director'
        ? const Color(0xFF111827)
        : item.kind == 'meta'
            ? const Color(0xFFF3F4F6)
            : isUser
                ? const Color(0xFFDBEAFE)
                : Colors.white;
    final fg = item.kind == 'director' ? Colors.white : const Color(0xFF111827);
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final label = item.kind == 'director'
        ? '导演'
        : item.kind == 'meta'
            ? '局势'
            : isUser
                ? widget.character.name
                : '对手戏';
    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: item.kind == 'cast' ? const [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: fg.withOpacity(0.78), fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(item.text, style: TextStyle(color: fg, height: 1.55)),
          ],
        ),
      ),
    );
  }

  Widget _modeSelector() {
    final modes = <String, String>{
      'exact_script': '逐字按剧本',
      'semantic_script': '语义按剧本',
      'free_creative': '自由创造',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.entries.map((entry) {
        final selected = _mode == entry.key;
        return ChoiceChip(
          selected: selected,
          label: Text(entry.value),
          onSelected: _loading
              ? null
              : (_) {
                  setState(() => _mode = entry.key);
                  _resetPerformance();
                },
        );
      }).toList(),
    );
  }

  Widget _emojiSelector() {
    const emojis = ['🙂', '😔', '😠', '😅', '💪', '🙏', '🤫', '🔥'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...emojis.map((e) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: _selectedEmoji == e,
                  label: Text(e),
                  onSelected: _loading ? null : (_) => setState(() => _selectedEmoji = _selectedEmoji == e ? '' : e),
                ),
              )),
        ],
      ),
    );
  }

  Widget _exactLinePicker() {
    final lines = _remainingUserLines();
    final expected = _expectedUserLine();
    if (lines.isEmpty) {
      return const Text('这一集里暂时没有识别到属于该角色的剩余台词。', style: TextStyle(color: Color(0xFF6B7280)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expected != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('当前应接：${expected.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: lines
                .map(
                  (line) => Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text('第${line.lineIndex}句：${line.text}', maxLines: 3, overflow: TextOverflow.ellipsis),
                      onPressed: _loading ? null : () => _sendExact(line),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _referenceLinePicker() {
    final lines = _remainingUserLines();
    final expected = _expectedUserLine();
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    final title = _mode == 'semantic_script'
        ? '剧本语义参考：可点击直接发送，也可在下方用自己的话表达。'
        : '本角色剧本台词参考：可点击作为当前回应，也可自由创作。';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        if (expected != null && _mode == 'semantic_script')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('当前顺序应表达：${expected.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
        const SizedBox(height: 6),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: lines
                .map(
                  (line) => Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text('第${line.lineIndex}句：${line.text}', maxLines: 3, overflow: TextOverflow.ellipsis),
                      onPressed: _loading ? null : () => _sendSemanticOrFree(line.text),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final exactMode = _mode == 'exact_script';
    return Scaffold(
      appBar: AppBar(
        title: Text('扮演 ${widget.character.name}'),
        actions: [
          IconButton(
            tooltip: '重新开始',
            onPressed: _loading ? null : _resetPerformance,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前内心状态', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
                const SizedBox(height: 6),
                Text(_innerState, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                if (widget.episode != null) ...[
                  const SizedBox(height: 8),
                  Text('当前片段：第${widget.episode!.episodeIndex}集 · ${widget.episode!.title}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft, child: _modeSelector()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _items.map(_bubble).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, -2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _emojiSelector(),
                const SizedBox(height: 8),
                if (exactMode)
                  _exactLinePicker()
                else ...[
                  _referenceLinePicker(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: _mode == 'semantic_script'
                                ? '用自己的话说出当前剧本台词的同等语义…'
                                : '以角色身份自由回应，但不要超出电影背景和片段前提…',
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _loading ? null : _sendSemanticOrFree,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('发送'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatItem {
  final String kind; // director / cast / user / meta
  final String text;

  const _ChatItem({required this.kind, required this.text});
}

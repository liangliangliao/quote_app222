import 'package:flutter/material.dart';

import 'will_mirror_capability_catalog.dart';
import 'will_mirror_guide_page.dart';
import 'will_mirror_practice_coordinator.dart';
import 'will_mirror_practice_engine.dart';
import 'will_mirror_practice_models.dart';
import 'will_mirror_vault.dart';
import 'will_mirror_widgets.dart';

class WillMirrorPracticePage extends StatefulWidget {
  const WillMirrorPracticePage({
    super.key,
    required this.vault,
    this.initialText = '',
    this.initialType = WillMirrorNeedType.goal,
    this.engine = const WillMirrorPracticeEngine(),
  });

  static const Key needFieldKey = ValueKey<String>('wm_v5_need_field');
  static const Key outcomeFieldKey = ValueKey<String>('wm_v5_outcome_field');
  static const Key obstacleFieldKey = ValueKey<String>('wm_v5_obstacle_field');
  static const Key nextButtonKey = ValueKey<String>('wm_v5_next');
  static const Key saveButtonKey = ValueKey<String>('wm_v5_save_plan');

  final WillMirrorVault vault;
  final String initialText;
  final WillMirrorNeedType initialType;
  final WillMirrorPracticeEngine engine;

  @override
  State<WillMirrorPracticePage> createState() => _WillMirrorPracticePageState();
}

class _WillMirrorPracticePageState extends State<WillMirrorPracticePage> {
  late final TextEditingController _need =
      TextEditingController(text: widget.initialText);
  final TextEditingController _outcome = TextEditingController();
  final TextEditingController _obstacle = TextEditingController();
  late WillMirrorNeedType _needType = widget.initialType;
  WillMirrorSupportStyle _style = WillMirrorSupportStyle.practical;
  WillMirrorInterest _interest = WillMirrorInterest.create;
  int _minutes = 2;
  int _step = 0;
  List<WillMirrorActionRoute> _routes = const <WillMirrorActionRoute>[];
  WillMirrorActionRoute? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restoreProfile();
  }

  @override
  void dispose() {
    _need.dispose();
    _outcome.dispose();
    _obstacle.dispose();
    super.dispose();
  }

  Future<void> _restoreProfile() async {
    final profile = await widget.vault.practiceProfile();
    if (profile == null || !mounted) return;
    setState(() {
      _style = profile.style;
      _interest = profile.interest;
      _minutes = profile.energyMinutes;
    });
  }

  WillMirrorPracticeProfile get _profile => WillMirrorPracticeProfile(
        style: _style,
        interest: _interest,
        energyMinutes: _minutes,
      );

  void _next() {
    if (_step == 0) {
      if (_need.text.trim().isEmpty) {
        _show('先用一句话写下你想实现或解决的事');
        return;
      }
      if (_outcome.text.trim().isEmpty) {
        _show('请写下七天后能看见的一个小变化');
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      final routes = widget.engine.buildRoutes(
        needType: _needType,
        need: _need.text,
        desiredOutcome: _outcome.text,
        obstacle: _obstacle.text,
        profile: _profile,
      );
      setState(() {
        _routes = routes;
        _selected = routes.first;
        _step = 2;
      });
    }
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null || _saving) return;
    setState(() => _saving = true);
    try {
      final coordinator = WillMirrorPracticeCoordinator(
        vault: widget.vault,
        engine: widget.engine,
      );
      await coordinator.start(
        needType: _needType,
        need: _need.text,
        desiredOutcome: _outcome.text,
        obstacle: _obstacle.text,
        profile: _profile,
        route: selected,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _show('安全保存失败：$error');
      setState(() => _saving = false);
    }
  }

  Future<void> _useExample() async {
    final example = await Navigator.of(context).push<WillMirrorExampleCase>(
      MaterialPageRoute<WillMirrorExampleCase>(
        builder: (_) => const WillMirrorExamplesPage(selectable: true),
      ),
    );
    if (example == null || !mounted) return;
    _need.text = example.need;
    _outcome.text = example.desiredOutcome;
    _obstacle.text = example.obstacle;
    final generatedRoutes = widget.engine.buildRoutes(
      needType: example.needType,
      need: example.need,
      desiredOutcome: example.desiredOutcome,
      obstacle: example.obstacle,
      profile: example.profile,
    );
    final routes = generatedRoutes.map((route) {
      if (route.type != example.selectedRoute) return route;
      return route.copyWith(
        action: example.generatedAction,
        successSignal: example.successSignal,
        theoryIds: example.theoryIds,
      );
    }).toList(growable: false);
    setState(() {
      _needType = example.needType;
      _style = example.profile.style;
      _interest = example.profile.interest;
      _minutes = example.profile.energyMinutes;
      _routes = routes;
      _selected = routes.firstWhere(
        (item) => item.type == example.selectedRoute,
        orElse: () => routes.first,
      );
      _step = 2;
    });
  }

  void _show(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: Text('把想法变成行动 · ${_step + 1}/3'),
        backgroundColor: const Color(0xFFFAFBF9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 0) {
              Navigator.pop(context);
            } else {
              setState(() => _step -= 1);
            }
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          LinearProgressIndicator(
            value: (_step + 1) / 3,
            minHeight: 3,
            color: WillMirrorPalette.forest,
            backgroundColor: WillMirrorPalette.line,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: ListView(
                key: ValueKey<int>(_step),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: <Widget>[
                  if (_step == 0) _needStep(),
                  if (_step == 1) _profileStep(),
                  if (_step == 2) _routeStep(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          key: _step == 2
              ? WillMirrorPracticePage.saveButtonKey
              : WillMirrorPracticePage.nextButtonKey,
          onPressed: _step == 2 ? (_saving ? null : _save) : _next,
          icon: Icon(_step == 2 ? Icons.play_arrow_rounded : Icons.arrow_forward),
          label: Text(
            _step == 0
                ? '下一步：选适合我的方式'
                : _step == 1
                    ? '生成三个现实方案'
                    : _saving
                        ? '正在安全保存…'
                        : '采用这个方案，开始今天第一步',
          ),
        ),
      ),
    );
  }

  Widget _needStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '你今天最想改变什么？',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          '不需要写得漂亮。越具体，越容易生成真正能做的第一步。',
          style: TextStyle(color: WillMirrorPalette.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WillMirrorNeedType.values.map((type) {
            return ChoiceChip(
              label: Text(type.label),
              selected: _needType == type,
              onSelected: (_) => setState(() => _needType = type),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 16),
        TextField(
          key: WillMirrorPracticePage.needFieldKey,
          controller: _need,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: _needType == WillMirrorNeedType.goal
                ? '我想实现……'
                : '我想解决……',
            hintText: _needType == WillMirrorNeedType.goal
                ? '例如：我想在一个月内完成作品集初稿'
                : '例如：我总是拖到最后才开始，想改变这个问题',
            helperText: '填写什么：一件具体的事，不要写“变得更好”这类大词',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: WillMirrorPracticePage.outcomeFieldKey,
          controller: _outcome,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '七天后，好一点是什么样？',
            hintText: '例如：有两页能给朋友看的草稿',
            helperText: '为什么填：把抽象愿望变成可观察的变化',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: WillMirrorPracticePage.obstacleFieldKey,
          controller: _obstacle,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '最卡住你的是什么？（可不填）',
            hintText: '例如：怕做不好、没时间、不知道第一步',
            helperText: '为什么填：系统会把动作缩小或改成先看清一个阻碍',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        _TheoryNote(
          title: '为什么不直接替你解释？',
          body: '目标只是表象入口。系统先标出已知和未知，再用行动与生活事实检验，不宣布你的“真正本质”。',
          theoryIds: const <String>[
            'SCH-B2-018-INNER-NATURE',
            'SCH-B2-022-METAPHYSICAL-BOUNDARY',
          ],
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _useExample,
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('还是不会填？照着完整案例开始'),
        ),
      ],
    );
  }

  Widget _profileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '选今天最适合你的方式',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          '这不是人格测验，没有高低分。只用于让今天的行动更有兴趣、更省力。',
          style: TextStyle(color: WillMirrorPalette.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        const Text('什么最容易吸引你？', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WillMirrorInterest.values.map((interest) {
            return ChoiceChip(
              label: Text(interest.label),
              selected: _interest == interest,
              onSelected: (_) => setState(() => _interest = interest),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 18),
        const Text('你希望怎样被带着做？', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final style in WillMirrorSupportStyle.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WillMirrorSectionCard(
              color: _style == style ? WillMirrorPalette.sage : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => setState(() => _style = style),
              child: Row(
                children: <Widget>[
                  Icon(
                    _style == style
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: WillMirrorPalette.forest,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          style.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          style.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: WillMirrorPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        const Text('今天真实能给多少精力？', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <int>[2, 5, 15].map((minutes) {
            return ChoiceChip(
              label: Text('$minutes 分钟'),
              selected: _minutes == minutes,
              onSelected: (_) => setState(() => _minutes = minutes),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 16),
        _TheoryNote(
          title: '为什么按兴趣和精力生成？',
          body: '兴趣、优势和“最像自己”的体验只用来生成候选；真正是否适合，仍由七天行动、能量和持续性验证。',
          theoryIds: const <String>[
            'TAL-L13-REAL-ME',
            'TAL-L22-MPS',
            'VIA-CHARACTER-STRENGTHS-BOUNDARY',
          ],
        ),
      ],
    );
  }

  Widget _routeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '三个都能产出，选最想试的',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          '没有“最佳答案”。选错也没关系，现实反馈会帮助你调整。',
          style: TextStyle(color: WillMirrorPalette.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        for (final route in _routes) ...<Widget>[
          _RouteCard(
            route: route,
            selected: identical(route, _selected),
            onTap: () => setState(() => _selected = route),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        const WillMirrorGuardrail(compact: true),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final WillMirrorActionRoute route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? WillMirrorPalette.sage : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? WillMirrorPalette.forest : WillMirrorPalette.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('wm_route_${route.type.value}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      route.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: WillMirrorPalette.forest,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(route.promise, style: const TextStyle(color: WillMirrorPalette.muted)),
              const SizedBox(height: 12),
              _RouteLine(label: '今天做', body: route.action),
              _RouteLine(label: '做到哪算完成', body: route.successSignal),
              _RouteLine(label: '会得到', body: route.output),
              _RouteLine(label: '为什么有效', body: route.whyItWorks),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: route.theoryIds.map((id) {
                  return WillMirrorBadge(
                    label: WillMirrorTheoryCatalog.find(id)?.shortLabel ?? id,
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(height: 1.45, color: WillMirrorPalette.ink),
          children: <InlineSpan>[
            TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}

class _TheoryNote extends StatelessWidget {
  const _TheoryNote({
    required this.title,
    required this.body,
    required this.theoryIds,
  });

  final String title;
  final String body;
  final List<String> theoryIds;

  @override
  Widget build(BuildContext context) {
    return WillMirrorSectionCard(
      color: WillMirrorPalette.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(body, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: theoryIds.map((id) {
              return WillMirrorBadge(
                label: WillMirrorTheoryCatalog.find(id)?.shortLabel ?? id,
                icon: Icons.menu_book_outlined,
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

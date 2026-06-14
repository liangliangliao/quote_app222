import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../platform/intimacy_wallpaper_bridge.dart';
import '../services/unified_ai_service.dart';

class TouchMystifyWallpaperPage extends StatefulWidget {
  const TouchMystifyWallpaperPage({super.key});

  @override
  State<TouchMystifyWallpaperPage> createState() => _TouchMystifyWallpaperPageState();
}

class _TouchMystifyWallpaperPageState extends State<TouchMystifyWallpaperPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  int _style = 0;
  String _wallpaperMode = 'mystify';
  String _calligraphyStyle = 'kaishu';
  double _calligraphySpeed = 0.55;
  bool _generatingCalligraphy = false;
  final TextEditingController _calligraphyController = TextEditingController(
    text: '行到水穷处，坐看云起时。',
  );
  double _intimacy = 0.72;
  double _randomness = 0.66;
  double _ribbonWidth = 0.62;
  double _trail = 0.90;
  double _fullScreenCoverage = 0.96;
  double _strokeDensity = 0.24;
  bool _previewAccelerated = false;
  double _previewCycleMinutes = 3.0;
  bool _debugLoopEnabled = false;
  double _debugCycleMinutes = 3.0;
  bool _bubbles = true;
  bool _powerSave = false;
  bool _randomCycle = true;
  double _cycleMinDays = 1.0;
  double _cycleMaxDays = 365.0;
  double _fixedCycleDays = 30.0;
  double _ratioSeparation = 0.46;
  double _ratioAttraction = 0.22;
  double _ratioSync = 0.22;
  double _ratioCritical = 0.06;
  double _ratioRelease = 0.02;
  double _ratioAfterglow = 0.02;
  double _criticalMinSec = 30.0;
  double _criticalMaxSec = 180.0;
  double _releaseMinSec = 8.0;
  double _releaseMaxSec = 24.0;
  double _afterglowMinSec = 20.0;
  double _afterglowMaxSec = 90.0;
  int _previewSeed = 7;
  double _calligraphyPreviewStartedAt = 0;
  bool _waitingForSystemApply = false;
  Timer? _configSyncDebounce;

  final List<String> _styles = const ['可见硬震屏释放', '深海蓝绿光体', '紫粉花冠羽翼', '银白晶体折片', '金橙生命洪流'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
    })..start();
    _loadSavedWallpaperChoice();
  }

  Future<void> _loadSavedWallpaperChoice() async {
    final config = await IntimacyWallpaperBridge.getConfig();
    if (!mounted || config.isEmpty) return;
    final savedMode = config['wallpaperMode'] as String?;
    final savedText = config['calligraphyText'] as String?;
    final savedStyle = config['calligraphyStyle'] as String?;
    final savedSpeed = (config['calligraphySpeed'] as num?)?.toDouble();
    setState(() {
      if (savedMode == 'mystify' || savedMode == 'calligraphy') {
        _wallpaperMode = savedMode!;
      }
      if (savedText != null && savedText.trim().isNotEmpty) {
        _calligraphyController.text = savedText;
      }
      if (savedStyle == 'kaishu' || savedStyle == 'xingshu' || savedStyle == 'caoshu') {
        _calligraphyStyle = savedStyle!;
      }
      if (savedSpeed != null) {
        _calligraphySpeed = savedSpeed.clamp(0.15, 1.0).toDouble();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _configSyncDebounce?.cancel();
    _calligraphyController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSystemApply) {
      _waitingForSystemApply = false;
      Future<void>.delayed(const Duration(milliseconds: 500), _checkWallpaperAppliedAfterReturn);
    }
  }

  Future<void> _checkWallpaperAppliedAfterReturn() async {
    final applied = await IntimacyWallpaperBridge.isLiveWallpaperApplied();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(applied
            ? '动态壁纸已成功应用。'
            : '动态壁纸尚未应用：必须在系统预览页点击“设置壁纸/应用”，仅返回本页不会生效。'),
      ),
    );
  }


  Future<void> _showWallpaperDiagnostic() async {
    final data = await IntimacyWallpaperBridge.getLiveWallpaperDiagnostic();
    if (!mounted) return;
    final lines = <String>[
      '动态壁纸服务注册：${data['registeredInLiveWallpaperList'] == true ? '已识别' : '未识别'}',
      '当前是否已应用：${data['applied'] == true ? '是' : '否'}',
      '启用状态：${data['enableState'] ?? '-'}',
      if (data['needsEnableGuide'] == true) '启用引导：${data['enableGuide'] ?? ''}',
      '系统动态壁纸服务数：${data['availableLiveWallpaperServices'] ?? '-'}',
      '指定预览入口目标数：${data['previewIntentTargets'] ?? '-'}',
      '动态壁纸列表入口目标数：${data['chooserIntentTargets'] ?? '-'}',
      '当前壁纸包：${data['currentWallpaperPackage'] ?? ''}',
      '当前壁纸服务：${data['currentWallpaperService'] ?? ''}',
      if (data['error'] != null) '错误：${data['error']}',
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('动态壁纸诊断'),
        content: SingleChildScrollView(child: SelectableText(lines.join('\n'))),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
        ],
      ),
    );
  }


  void _updateConfigPreview(VoidCallback update) {
    setState(update);
    _scheduleConfigSync();
  }

  void _scheduleConfigSync() {
    _configSyncDebounce?.cancel();
    _configSyncDebounce = Timer(const Duration(milliseconds: 650), () {
      _saveCurrentConfig(resetSeed: false, showSnack: false);
    });
  }

  Future<bool> _saveCurrentConfig({required bool resetSeed, bool showSnack = false}) async {
    final ok = await IntimacyWallpaperBridge.saveConfig(
      style: _style,
      wallpaperMode: _wallpaperMode,
      calligraphyText: _calligraphyController.text.trim().isEmpty
          ? '行到水穷处，坐看云起时。'
          : _calligraphyController.text.trim(),
      calligraphyStyle: _calligraphyStyle,
      calligraphySpeed: _calligraphySpeed,
      intimacy: _intimacy,
      randomness: _randomness,
      ribbonWidth: _ribbonWidth,
      trail: _trail,
      fullScreenCoverage: _fullScreenCoverage,
      strokeDensity: _strokeDensity,
      previewAccelerated: _previewAccelerated,
      previewCycleMinutes: _previewCycleMinutes,
      debugLoopEnabled: _debugLoopEnabled,
      debugCycleMinutes: _debugCycleMinutes,
      bubbles: _bubbles,
      powerSave: _powerSave,
      randomCycle: _randomCycle,
      cycleMinDays: _cycleMinDays,
      cycleMaxDays: _cycleMaxDays,
      fixedCycleDays: _fixedCycleDays,
      ratioSeparation: _ratioSeparation,
      ratioAttraction: _ratioAttraction,
      ratioSync: _ratioSync,
      ratioCritical: _ratioCritical,
      ratioRelease: _ratioRelease,
      ratioAfterglow: _ratioAfterglow,
      criticalMinSec: _criticalMinSec,
      criticalMaxSec: _criticalMaxSec,
      releaseMinSec: _releaseMinSec,
      releaseMaxSec: _releaseMaxSec,
      afterglowMinSec: _afterglowMinSec,
      afterglowMaxSec: _afterglowMaxSec,
      resetSeed: resetSeed,
    );
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已保存壁纸参数，已安装的动态壁纸会自动读取新设置' : '当前平台不支持 Android 动态壁纸')),
      );
    }
    return ok;
  }

  Future<void> _saveAndOpen() async {
    final ok = await _saveCurrentConfig(resetSeed: true);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前平台不支持 Android 动态壁纸设置')),
      );
      return;
    }
    final diag = await IntimacyWallpaperBridge.getLiveWallpaperDiagnostic();
    if (!mounted) return;
    if (diag['registeredInLiveWallpaperList'] == false) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要开启/识别动态壁纸服务'),
          content: Text((diag['enableGuide'] as String?) ?? '系统尚未识别潮汐之间动态壁纸服务。请进入动态壁纸应用助手按步骤检查。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('继续打开助手')),
          ],
        ),
      );
      if (!mounted) return;
    }
    // Android 第三方应用不能稳定、静默地直接替换“动态壁纸”。
    // 正确且兼容的流程是打开系统 Live Wallpaper 预览页，由用户在系统页点击“设置壁纸/应用”。
    final opened = await IntimacyWallpaperBridge.openLiveWallpaper();
    if (!mounted) return;
    if (opened) {
      _waitingForSystemApply = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已打开动态壁纸应用助手；若系统未自动跳转，请在助手页选择入口。')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能打开动态壁纸应用助手，请从手机系统“壁纸/动态壁纸”中选择“潮汐之间”。')),
      );
    }
  }

  Future<void> _saveOnly() async {
    await _saveCurrentConfig(resetSeed: true, showSnack: true);
  }

  Future<void> _generateClassicText() async {
    if (_generatingCalligraphy) return;
    setState(() => _generatingCalligraphy = true);
    try {
      final result = await UnifiedAiService().generateText(
        prompt: '请随机选择一句适合动态壁纸书写的中国经典名言、名句或诗词。要求：正文不超过28个汉字；有出处时在下一行用“——作者《作品》”标注；不要解释，不要使用引号或Markdown。',
        purpose: 'touch_wallpaper.calligraphy_classic',
        systemPrompt: '你是中国古典文学与名言选句助手，只返回准确、凝练、适合书法展示的经典原文及简短出处。不要杜撰。',
        maxTokens: 120,
        temperature: 0.9,
      );
      if (!mounted) return;
      final cleaned = result
          .replaceAll(RegExp(r'^```(?:text)?\s*|\s*```$'), '')
          .replaceAll(RegExp(r'^[“"]|[”"]$'), '')
          .trim();
      if (cleaned.isEmpty) {
        throw Exception('未获取到内容，请先在全局 AI 设置中配置可用模型。');
      }
      setState(() {
        _calligraphyController.text = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
        _calligraphyController.selection = TextSelection.collapsed(offset: _calligraphyController.text.length);
      });
      _scheduleConfigSync();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI 获取失败：$error')));
    } finally {
      if (mounted) setState(() => _generatingCalligraphy = false);
    }
  }

  void _refreshPreview() {
    setState(() {
      if (_wallpaperMode == 'calligraphy') {
        _calligraphyPreviewStartedAt = _elapsed.inMilliseconds / 1000.0;
      } else {
        _previewSeed = math.Random().nextInt(999999);
        _randomness = (0.42 + math.Random().nextDouble() * 0.48).clamp(0.0, 1.0).toDouble();
      }
    });
    _saveCurrentConfig(resetSeed: true);
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _elapsed.inMilliseconds / 1000.0;
    return Scaffold(
      backgroundColor: const Color(0xFF050714),
      appBar: AppBar(
        title: const Text('触摸 · 动态艺术壁纸'),
        backgroundColor: const Color(0xFF050714),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            child: _wallpaperMode == 'calligraphy'
                ? _CalligraphyPreview(
                    key: const ValueKey('calligraphy'),
                    seconds: math.max(0.0, seconds - _calligraphyPreviewStartedAt).toDouble(),
                    text: _calligraphyController.text,
                    style: _calligraphyStyle,
                    speed: _calligraphySpeed,
                  )
                : _HeroPreview(
                    key: const ValueKey('mystify'),
                    seconds: seconds,
                    style: _style,
                    intimacy: _intimacy,
                    randomness: _randomness,
                    ribbonWidth: _ribbonWidth,
                    trail: _trail,
                    fullScreenCoverage: _fullScreenCoverage,
                    bubbles: _bubbles,
                    ratioSeparation: _ratioSeparation,
                    ratioAttraction: _ratioAttraction,
                    ratioSync: _ratioSync,
                    ratioCritical: _ratioCritical,
                    ratioRelease: _ratioRelease,
                    ratioAfterglow: _ratioAfterglow,
                    criticalMinSec: _criticalMinSec,
                    criticalMaxSec: _criticalMaxSec,
                    releaseMinSec: _releaseMinSec,
                    releaseMaxSec: _releaseMaxSec,
                    afterglowMinSec: _afterglowMinSec,
                    afterglowMaxSec: _afterglowMaxSec,
                    seed: _previewSeed,
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '选择真正应用的动态壁纸',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mystify', icon: Icon(Icons.auto_awesome), label: Text('潮汐光迹')),
                    ButtonSegment(value: 'calligraphy', icon: Icon(Icons.gesture), label: Text('书法书写')),
                  ],
                  selected: {_wallpaperMode},
                  onSelectionChanged: (value) => _updateConfigPreview(() => _wallpaperMode = value.first),
                ),
                const SizedBox(height: 10),
                Text(
                  _wallpaperMode == 'mystify'
                      ? '保留当前已经实现的动画壁纸，所有效果和参数均保持不变。'
                      : '书法模式会在黑色宣纸氛围中逐字落墨；保存后，系统中的同一个动态壁纸服务会即时切换。',
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
              ],
            ),
          ),
          if (_wallpaperMode == 'calligraphy') ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: '书写内容与笔体',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _calligraphyController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 80,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '自定义书写内容',
                      hintText: '输入名言、诗句或你想每天看见的话',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _scheduleConfigSync();
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _generatingCalligraphy ? null : _generateClassicText,
                      icon: _generatingCalligraphy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_generatingCalligraphy ? 'AI 正在选句…' : 'AI 获取经典名言 / 诗词'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: const [
                      ('kaishu', '楷书'), ('xingshu', '行书'), ('caoshu', '草书'),
                    ].map((item) => ChoiceChip(
                      label: Text(item.$2),
                      selected: _calligraphyStyle == item.$1,
                      onSelected: (_) => _updateConfigPreview(() => _calligraphyStyle = item.$1),
                    )).toList(),
                  ),
                  _SliderRow(
                    label: '落笔速度',
                    value: _calligraphySpeed,
                    description: '控制文字逐笔显现与停顿节奏。',
                    onChanged: (value) => _updateConfigPreview(() => _calligraphySpeed = value),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _IntroCard(),
          const SizedBox(height: 16),
          _SectionCard(
            title: '视觉风格',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _styles.length; i++)
                  ChoiceChip(
                    label: Text(_styles[i]),
                    selected: _style == i,
                    onSelected: (_) => _updateConfigPreview(() => _style = i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '表达参数',
            child: Column(
              children: [
                _SliderRow(
                  label: '亲密张力',
                  value: _intimacy,
                  description: '控制两条生命轨迹从吸引、同步、缠绕到释放的戏剧强度。',
                  onChanged: (v) => _updateConfigPreview(() => _intimacy = v),
                ),
                _SliderRow(
                  label: 'Mystify 随机性',
                  value: _randomness,
                  description: '控制轨迹变化莫测程度；越高越容易出现折叠、扇形光网、点线喷洒，但仍保持黑场留白。',
                  onChanged: (v) => _updateConfigPreview(() => _randomness = v),
                ),
                _SliderRow(
                  label: '光带宽度',
                  value: _ribbonWidth,
                  description: '控制主丝带的柔光厚度和高级感。',
                  onChanged: (v) => _updateConfigPreview(() => _ribbonWidth = v),
                ),
                _SliderRow(
                  label: '残影长度',
                  value: _trail,
                  description: '控制已画痕迹渐隐速度；越高越像一支光笔落笔作画、停笔呼吸、余痕淡出，再画出下一组千变万化的艺术形体。',
                  onChanged: (v) => _updateConfigPreview(() => _trail = v),
                ),
                _SliderRow(
                  label: '全屏活动范围',
                  value: _fullScreenCoverage,
                  description: '控制随机运动点是否覆盖手机可见屏幕任意位置。默认接近全屏，避免线条只在中心或小区域活动。',
                  onChanged: (v) => _updateConfigPreview(() => _fullScreenCoverage = v),
                ),
                _SliderRow(
                  label: '线条出现密度',
                  value: _strokeDensity,
                  description: '控制随机即时线条发生器的出生频率。过低更像黑场留白，过高更容易杂乱。',
                  onChanged: (v) => _updateConfigPreview(() => _strokeDensity = v),
                ),
                SwitchListTile(
                  value: _bubbles,
                  onChanged: (v) => _updateConfigPreview(() => _bubbles = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('可见硬震屏释放', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('释放后气泡从中心快速向四周散开；去除大色块圆盘和旧小残泡，只保留透明彩膜边缘、白色高光与细薄水光。', style: TextStyle(color: Colors.white60)),
                ),
                SwitchListTile(
                  value: _powerSave,
                  onChanged: (v) => _updateConfigPreview(() => _powerSave = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('省电模式', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('降低动态壁纸帧率，适合长期作为主屏/锁屏使用。', style: TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '完整周期（以天为单位）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: _randomCycle,
                  onChanged: (v) => _updateConfigPreview(() => _randomCycle = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('每轮随机生成周期', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _randomCycle
                        ? '当前范围：${_cycleMinDays.round()}～${_cycleMaxDays.round()} 天。每完成一轮后，会重新随机生成下一轮周期。'
                        : '关闭后使用固定周期：${_fixedCycleDays.round()} 天。',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
                SwitchListTile(
                  value: _previewAccelerated,
                  onChanged: (v) => _updateConfigPreview(() => _previewAccelerated = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('壁纸单次加速演示模式', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _previewAccelerated
                        ? '已开启：仅系统预览页会把一个完整周期压缩到约 ${_previewCycleMinutes.toStringAsFixed(1)} 分钟；真正应用到桌面/锁屏后仍按真实 1～365 天周期运行。'
                        : '关闭后按真实天数推进完整周期。若你想快速检查一次完整过程，可以临时开启。',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
                if (_previewAccelerated)
                  _MinuteSliderRow(
                    label: '单次演示周期',
                    value: _previewCycleMinutes,
                    min: 0.5,
                    max: 60.0,
                    onChanged: (v) => _updateConfigPreview(() => _previewCycleMinutes = v),
                  ),
                const Divider(color: Colors.white12, height: 24),
                SwitchListTile(
                  value: _debugLoopEnabled,
                  onChanged: (v) => _updateConfigPreview(() => _debugLoopEnabled = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('性交完整过程调试循环模式', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _debugLoopEnabled
                        ? '已开启：App 预览和真实桌面/锁屏动态壁纸都会按 ${_debugCycleMinutes.toStringAsFixed(1)} 分钟无限循环完整过程，用于快速调试阶段比例和短阶段持续时间。正式使用请关闭。'
                        : '关闭后，真实壁纸按 1～365 天周期运行；开启后会覆盖真实周期，并同步到已应用的动态壁纸。',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
                if (_debugLoopEnabled)
                  _MinuteSliderRow(
                    label: '调试循环周期',
                    value: _debugCycleMinutes,
                    min: 1.0,
                    max: 60.0,
                    onChanged: (v) => _updateConfigPreview(() => _debugCycleMinutes = v),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('随机范围：${_cycleMinDays.round()}～${_cycleMaxDays.round()} 天', style: const TextStyle(color: Colors.white70))),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(_cycleMinDays, _cycleMaxDays),
                  min: 1.0,
                  max: 365.0,
                  divisions: 364,
                  labels: RangeLabels('${_cycleMinDays.round()}天', '${_cycleMaxDays.round()}天'),
                  onChanged: (values) {
                    _updateConfigPreview(() {
                      _cycleMinDays = values.start.clamp(1.0, 365.0).toDouble();
                      _cycleMaxDays = values.end.clamp(_cycleMinDays, 365.0).toDouble();
                      _fixedCycleDays = _fixedCycleDays.clamp(_cycleMinDays, _cycleMaxDays).toDouble();
                    });
                  },
                ),
                if (!_randomCycle)
                  _DaySliderRow(
                    label: '固定周期',
                    value: _fixedCycleDays,
                    min: _cycleMinDays,
                    max: _cycleMaxDays,
                    onChanged: (v) => _updateConfigPreview(() => _fixedCycleDays = v),
                  ),
                const Text(
                  '实际动态壁纸按真实天数推进；本页预览是单次周期演示，不会在几分钟内重复释放/余韵；真实壁纸仍以原生 OpenGL 渲染为准。',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '阶段出现频率',
            child: Column(
              children: [
                _RatioSliderRow(label: '分离', value: _ratioSeparation, description: '默认最大比例：黑场、留白、低频单线，表达两个生命仍处于分离状态。', onChanged: (v) => _updateConfigPreview(() => _ratioSeparation = v)),
                _RatioSliderRow(label: '吸引', value: _ratioAttraction, description: '主要比例：线条从任意位置出现，彼此被牵引但尚未合一。', onChanged: (v) => _updateConfigPreview(() => _ratioAttraction = v)),
                _RatioSliderRow(label: '同步', value: _ratioSync, description: '主要比例：两条轨迹节奏趋同，张力持续升高。', onChanged: (v) => _updateConfigPreview(() => _ratioSync = v)),
                _RatioSliderRow(label: '临界', value: _ratioCritical, description: '小比例：短暂缠绕、压缩、接近峰值。', onChanged: (v) => _updateConfigPreview(() => _ratioCritical = v)),
                _RatioSliderRow(label: '释放', value: _ratioRelease, description: '最小比例：短促柔光脉冲，避免变成烟花式爆炸。', onChanged: (v) => _updateConfigPreview(() => _ratioRelease = v)),
                _RatioSliderRow(label: '余韵', value: _ratioAfterglow, description: '最小比例：残影、少量光尘、快速回到黑场。', onChanged: (v) => _updateConfigPreview(() => _ratioAfterglow = v)),
                _PhaseRatioSummary(
                  separation: _ratioSeparation,
                  attraction: _ratioAttraction,
                  sync: _ratioSync,
                  critical: _ratioCritical,
                  release: _ratioRelease,
                  afterglow: _ratioAfterglow,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '短阶段持续时间（秒）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SecondRangeRow(
                  label: '临界持续时间',
                  values: RangeValues(_criticalMinSec, _criticalMaxSec),
                  min: 5,
                  max: 7200,
                  description: '临界来自同步，位于释放之前；默认短暂出现，避免长时间停在峰值。',
                  onChanged: (v) => _updateConfigPreview(() {
                    _criticalMinSec = v.start;
                    _criticalMaxSec = math.max(v.end, _criticalMinSec);
                  }),
                ),
                _SecondRangeRow(
                  label: '释放持续时间',
                  values: RangeValues(_releaseMinSec, _releaseMaxSec),
                  min: 2,
                  max: 1200,
                  description: '每个完整周期内只出现一次释放；具体持续时长会在该范围内随机生成。',
                  onChanged: (v) => _updateConfigPreview(() {
                    _releaseMinSec = v.start;
                    _releaseMaxSec = math.max(v.end, _releaseMinSec);
                  }),
                ),
                _SecondRangeRow(
                  label: '余韵持续时间',
                  values: RangeValues(_afterglowMinSec, _afterglowMaxSec),
                  min: 3,
                  max: 3600,
                  description: '余韵必须紧跟释放，每周期只出现一次；具体持续时长也会随机生成。',
                  onChanged: (v) => _updateConfigPreview(() {
                    _afterglowMinSec = v.start;
                    _afterglowMaxSec = math.max(v.end, _afterglowMinSec);
                  }),
                ),
                const Text(
                  '新算法：先随机生成本轮周期天数，再随机确定本轮释放时刻；释放与余韵只出现一次，临界紧贴释放之前，分离/吸引/同步按占比填充前置过程，余韵结束后回到分离直到下一轮。',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.38),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _refreshPreview,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_wallpaperMode == 'calligraphy' ? '重新落墨' : '随机新构图'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveOnly,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('保存参数'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showWallpaperDiagnostic,
              icon: const Icon(Icons.medical_information_outlined),
              label: const Text('诊断动态壁纸入口/注册状态'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saveAndOpen,
              icon: const Icon(Icons.wallpaper),
              label: const Text('检查权限并打开动态壁纸助手'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '说明：先检查系统是否识别并启用潮汐之间动态壁纸服务；若尚未启用，请在应用助手中进入系统动态壁纸页，选择“潮汐之间”，再点击“设置壁纸/应用”。',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CalligraphyPreview extends StatelessWidget {
  const _CalligraphyPreview({
    super.key,
    required this.seconds,
    required this.text,
    required this.style,
    required this.speed,
  });

  final double seconds;
  final String text;
  final String style;
  final double speed;

  @override
  Widget build(BuildContext context) {
    final content = text.trim().isEmpty ? '行到水穷处，坐看云起时。' : text.trim();
    final runeCount = content.runes.length;
    final cycleSeconds = math.max(7.0, runeCount * (0.48 - speed * 0.27) + 4.0).toDouble();
    final progress = (seconds % cycleSeconds) / cycleSeconds;
    final label = switch (style) {
      'caoshu' => '草书',
      'xingshu' => '行书',
      _ => '楷书',
    };

    return AspectRatio(
      aspectRatio: 9 / 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.25, -0.4),
              radius: 1.25,
              colors: [Color(0xFF18201E), Color(0xFF080B0C), Colors.black],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _RicePaperPainter(seconds))),
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB73535).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$label · 动态落墨', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(38, 62, 38, 44),
                  child: CustomPaint(
                    painter: _CalligraphyWritingPainter(
                      text: content,
                      style: style,
                      progress: (progress / 0.78).clamp(0.0, 1.0).toDouble(),
                      opacity: progress > 0.92
                          ? ((1 - progress) / 0.08).clamp(0.0, 1.0).toDouble()
                          : 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalligraphyWritingPainter extends CustomPainter {
  const _CalligraphyWritingPainter({
    required this.text,
    required this.style,
    required this.progress,
    required this.opacity,
  });

  final String text;
  final String style;
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final runes = text.runes.where((rune) => !String.fromCharCode(rune).trim().isEmpty).take(40).toList();
    if (runes.isEmpty) return;
    final maxRows = math.min(10, math.max(1, (runes.length / 3).ceil()));
    final columns = math.max(1, (runes.length / maxRows).ceil());
    final cellWidth = math.min(58.0, size.width / math.max(1, columns)).toDouble();
    final cellHeight = math.min(58.0, size.height / math.max(1, maxRows)).toDouble();
    final fontSize = math.min(cellWidth * 0.76, cellHeight * 0.78).toDouble();
    final firstX = size.width * 0.5 + (columns - 1) * cellWidth * 0.5;
    final firstY = math.max(12.0, (size.height - maxRows * cellHeight) * 0.5).toDouble();
    final characterProgress = progress * runes.length;

    for (var index = 0; index < runes.length; index++) {
      final local = (characterProgress - index).clamp(0.0, 1.0).toDouble();
      if (local <= 0) continue;
      final row = index % maxRows;
      final column = index ~/ maxRows;
      final center = Offset(firstX - column * cellWidth, firstY + row * cellHeight + cellHeight * 0.5);
      _paintGlyph(canvas, String.fromCharCode(runes[index]), runes[index], center, fontSize, local);
      if (index > 0 && row > 0 && style != 'kaishu') {
        _paintLigature(canvas, center.translate(0, -cellHeight), center, runes[index], local);
      }
    }
  }

  void _paintGlyph(Canvas canvas, String glyph, int codePoint, Offset center, double fontSize, double progress) {
    final bounds = Rect.fromCenter(center: center, width: fontSize * 1.35, height: fontSize * 1.35);
    final textPainter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: Color.fromRGBO(242, 232, 210, opacity),
          fontFamily: style == 'kaishu' ? 'serif' : 'sans-serif',
          fontStyle: style == 'caoshu' ? FontStyle.italic : FontStyle.normal,
          fontWeight: style == 'kaishu' ? FontWeight.w700 : FontWeight.w400,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (progress >= 0.995) {
      _paintStyledText(canvas, textPainter, codePoint, center);
      return;
    }
    canvas.saveLayer(bounds, Paint());
    final strokeCount = style == 'kaishu' ? 9 : (style == 'xingshu' ? 7 : 5);
    final scaled = progress * strokeCount;
    for (var stroke = 0; stroke < strokeCount; stroke++) {
      final strokeProgress = (scaled - stroke).clamp(0.0, 1.0).toDouble();
      if (strokeProgress <= 0) continue;
      _paintRevealStroke(canvas, bounds, codePoint, stroke, strokeCount, strokeProgress);
    }

    final glyphLayer = Paint()..blendMode = BlendMode.srcIn;
    canvas.saveLayer(bounds, glyphLayer);
    _paintStyledText(canvas, textPainter, codePoint, center);
    canvas.restore();
    canvas.restore();
    _paintBrushTip(canvas, bounds, codePoint, progress);
  }

  void _paintStyledText(Canvas canvas, TextPainter textPainter, int codePoint, Offset center) {
    canvas.save();
    if (style == 'xingshu') {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(((codePoint % 7) - 3) * 0.012);
      canvas.translate(-center.dx, -center.dy);
    } else if (style == 'caoshu') {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.09 + (codePoint % 9) * 0.018);
      canvas.scale(0.82, 1.08);
      canvas.translate(-center.dx, -center.dy);
    }
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
    canvas.restore();
  }

  void _paintRevealStroke(
    Canvas canvas,
    Rect box,
    int codePoint,
    int stroke,
    int strokeCount,
    double progress,
  ) {
    final pattern = (codePoint * 31 + stroke * 17) % 6;
    final lane = (stroke + 0.55) / strokeCount;
    final endpoints = _strokeEndpoints(box, pattern, lane);
    final curve = box.width * (style == 'caoshu' ? 0.22 : (style == 'xingshu' ? 0.12 : 0.035));
    final control = Offset(
      (endpoints.$1.dx + endpoints.$2.dx) * 0.5 + math.sin(codePoint * 0.13 + stroke) * curve,
      (endpoints.$1.dy + endpoints.$2.dy) * 0.5 + math.cos(codePoint * 0.11 + stroke) * curve,
    );
    final t = _smooth(progress);
    final target = Offset(
      _quadratic(endpoints.$1.dx, control.dx, endpoints.$2.dx, t),
      _quadratic(endpoints.$1.dy, control.dy, endpoints.$2.dy, t),
    );
    final path = Path()
      ..moveTo(endpoints.$1.dx, endpoints.$1.dy)
      ..quadraticBezierTo(
        _lerp(endpoints.$1.dx, control.dx, t),
        _lerp(endpoints.$1.dy, control.dy, t),
        target.dx,
        target.dy,
      );
    final width = box.width * (style == 'kaishu' ? 0.24 : (style == 'xingshu' ? 0.20 : 0.17));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = style == 'kaishu' ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * (0.82 + 0.25 * math.sin(stroke * 2.1 + codePoint)),
    );
  }

  (Offset, Offset) _strokeEndpoints(Rect box, int pattern, double lane) {
    final left = box.left + box.width * 0.08;
    final right = box.right - box.width * 0.08;
    final top = box.top + box.height * 0.08;
    final bottom = box.bottom - box.height * 0.10;
    return switch (pattern) {
      0 => (Offset(left, _lerp(top, bottom, lane)), Offset(right, _lerp(top, bottom, lane) + box.height * 0.04)),
      1 => (
          Offset(_lerp(left, right, lane), top),
          Offset(_lerp(left, right, lane) - box.width * 0.04, bottom),
        ),
      2 => (Offset(left, top + box.height * lane * 0.55), Offset(right, bottom - box.height * (1 - lane) * 0.35)),
      3 => (Offset(right, top + box.height * lane * 0.45), Offset(left, bottom - box.height * (1 - lane) * 0.50)),
      4 => (Offset(box.center.dx, top), Offset(_lerp(left, right, lane), bottom)),
      _ => (
          Offset(_lerp(left, right, lane), box.center.dy),
          Offset(lane < 0.5 ? left : right, lane < 0.5 ? top : bottom),
        ),
    };
  }

  void _paintBrushTip(Canvas canvas, Rect box, int codePoint, double progress) {
    final strokeCount = style == 'kaishu' ? 9 : (style == 'xingshu' ? 7 : 5);
    final scaled = progress * strokeCount;
    final stroke = math.min(strokeCount - 1, math.max(0, scaled.floor()));
    final local = (scaled - stroke).clamp(0.0, 1.0).toDouble();
    final endpoints = _strokeEndpoints(box, (codePoint * 31 + stroke * 17) % 6, (stroke + 0.55) / strokeCount);
    final curve = box.width * (style == 'caoshu' ? 0.22 : (style == 'xingshu' ? 0.12 : 0.035));
    final control = Offset(
      (endpoints.$1.dx + endpoints.$2.dx) * 0.5 + math.sin(codePoint * 0.13 + stroke) * curve,
      (endpoints.$1.dy + endpoints.$2.dy) * 0.5 + math.cos(codePoint * 0.11 + stroke) * curve,
    );
    final t = _smooth(local);
    final point = Offset(
      _quadratic(endpoints.$1.dx, control.dx, endpoints.$2.dx, t),
      _quadratic(endpoints.$1.dy, control.dy, endpoints.$2.dy, t),
    );
    final radius = box.width * (style == 'kaishu' ? 0.055 : 0.042);
    canvas.drawOval(
      Rect.fromCenter(center: point, width: radius * 1.24, height: radius * 2),
      Paint()..color = Color.fromRGBO(246, 238, 218, opacity * 0.92),
    );
  }

  void _paintLigature(Canvas canvas, Offset from, Offset to, int codePoint, double progress) {
    final start = from.translate((codePoint & 1) == 0 ? 5 : -4, (to.dy - from.dy) * 0.22);
    final end = Offset(to.dx, _lerp(start.dy, to.dy - 16, _smooth(progress)));
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx + 12, _lerp(start.dy, end.dy, 0.30), end.dx - 12, _lerp(start.dy, end.dy, 0.70), end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromRGBO(223, 216, 198, opacity * (style == 'caoshu' ? 0.52 : 0.32))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = style == 'caoshu' ? 2.6 : 1.6,
    );
  }

  double _smooth(double value) => value * value * (3 - 2 * value);
  double _quadratic(double a, double b, double c, double t) {
    final u = 1 - t;
    return u * u * a + 2 * u * t * b + t * t * c;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _CalligraphyWritingPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity;
  }
}

class _RicePaperPainter extends CustomPainter {
  const _RicePaperPainter(this.seconds);
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 0.6;
    for (var i = 0; i < 26; i++) {
      final y = (i * 47.0 + math.sin(seconds * 0.12 + i) * 8) % size.height;
      paint.color = Color.fromRGBO(190, 205, 194, 0.025 + (i % 3) * 0.008);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + math.sin(i * 1.7) * 18), paint);
    }
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x2234D399), Colors.transparent],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * (0.5 + math.sin(seconds * 0.18) * 0.18), size.height * 0.52),
        radius: size.width * 0.55,
      ));
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant _RicePaperPainter oldDelegate) => oldDelegate.seconds != seconds;
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: const Text(
        '现在可在“潮汐光迹”和“书法书写”两种动态壁纸之间自由切换。原有 Mystify 动画、阶段节奏和参数完整保留；书法模式支持自定义内容、AI 经典选句、楷书/行书/草书与落笔速度。保存后，当前系统动态壁纸会读取新选择并即时更新。',
        style: TextStyle(color: Colors.white70, height: 1.55),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.description, required this.onChanged});
  final String label;
  final double value;
  final String description;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.white60)),
            ],
          ),
          Slider(value: value, onChanged: onChanged),
          Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}

class _DaySliderRow extends StatelessWidget {
  const _DaySliderRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeMax = math.max(min, max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              Text('${value.round()} 天', style: const TextStyle(color: Colors.white60)),
            ],
          ),
          Slider(
            value: value.clamp(min, safeMax).toDouble(),
            min: min,
            max: safeMax,
            divisions: math.max(1, (safeMax - min).round()),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}


class _MinuteSliderRow extends StatelessWidget {
  const _MinuteSliderRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              Text('${value.toStringAsFixed(1)} 分钟', style: const TextStyle(color: Colors.white60)),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: 119,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SecondRangeRow extends StatelessWidget {
  const _SecondRangeRow({required this.label, required this.values, required this.min, required this.max, required this.description, required this.onChanged});
  final String label;
  final RangeValues values;
  final double min;
  final double max;
  final String description;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    String fmt(double v) {
      if (v >= 3600) return '${(v / 3600).toStringAsFixed(1)}小时';
      if (v >= 60) return '${(v / 60).toStringAsFixed(1)}分';
      return '${v.round()}秒';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              Text('${fmt(values.start)}～${fmt(values.end)}', style: const TextStyle(color: Colors.white60)),
            ],
          ),
          RangeSlider(
            values: RangeValues(values.start.clamp(min, max).toDouble(), values.end.clamp(min, max).toDouble()),
            min: min,
            max: max,
            divisions: 200,
            labels: RangeLabels(fmt(values.start), fmt(values.end)),
            onChanged: onChanged,
          ),
          Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}

class _RatioSliderRow extends StatelessWidget {
  const _RatioSliderRow({required this.label, required this.value, required this.description, required this.onChanged});
  final String label;
  final double value;
  final String description;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              Text(value.toStringAsFixed(3), style: const TextStyle(color: Colors.white60)),
            ],
          ),
          Slider(value: value.clamp(0.002, 0.70).toDouble(), min: 0.002, max: 0.70, onChanged: onChanged),
          Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}

class _PhaseRatioSummary extends StatelessWidget {
  const _PhaseRatioSummary({required this.separation, required this.attraction, required this.sync, required this.critical, required this.release, required this.afterglow});
  final double separation;
  final double attraction;
  final double sync;
  final double critical;
  final double release;
  final double afterglow;

  @override
  Widget build(BuildContext context) {
    final total = math.max(0.001, separation + attraction + sync + critical + release + afterglow);
    String pct(double v) => '${(v / total * 100).toStringAsFixed(1)}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        '归一化后：分离 ${pct(separation)} · 吸引 ${pct(attraction)} · 同步 ${pct(sync)} · 临界 ${pct(critical)} · 释放 ${pct(release)} · 余韵 ${pct(afterglow)}',
        style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45),
      ),
    );
  }
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview({
    super.key,
    required this.seconds,
    required this.style,
    required this.intimacy,
    required this.randomness,
    required this.ribbonWidth,
    required this.trail,
    required this.fullScreenCoverage,
    required this.bubbles,
    required this.ratioSeparation,
    required this.ratioAttraction,
    required this.ratioSync,
    required this.ratioCritical,
    required this.ratioRelease,
    required this.ratioAfterglow,
    required this.criticalMinSec,
    required this.criticalMaxSec,
    required this.releaseMinSec,
    required this.releaseMaxSec,
    required this.afterglowMinSec,
    required this.afterglowMaxSec,
    required this.seed,
  });

  final double seconds;
  final int style;
  final double intimacy;
  final double randomness;
  final double ribbonWidth;
  final double trail;
  final double fullScreenCoverage;
  final bool bubbles;
  final double ratioSeparation;
  final double ratioAttraction;
  final double ratioSync;
  final double ratioCritical;
  final double ratioRelease;
  final double ratioAfterglow;
  final double criticalMinSec;
  final double criticalMaxSec;
  final double releaseMinSec;
  final double releaseMaxSec;
  final double afterglowMinSec;
  final double afterglowMaxSec;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final useNativePreview = !kIsWeb && Platform.isAndroid;
    final preview = useNativePreview
        ? const AndroidView(
            viewType: 'com.example.quote_app/intimacy_mystify_preview',
            creationParams: <String, dynamic>{},
            creationParamsCodec: StandardMessageCodec(),
          )
        : CustomPaint(
            painter: _MystifyPreviewPainter(
              seconds: seconds,
              style: style,
              intimacy: intimacy,
              randomness: randomness,
              ribbonWidth: ribbonWidth,
              trail: trail,
              fullScreenCoverage: fullScreenCoverage,
              bubbles: bubbles,
              ratioSeparation: ratioSeparation,
              ratioAttraction: ratioAttraction,
              ratioSync: ratioSync,
              ratioCritical: ratioCritical,
              ratioRelease: ratioRelease,
              ratioAfterglow: ratioAfterglow,
              criticalMinSec: criticalMinSec,
              criticalMaxSec: criticalMaxSec,
              releaseMinSec: releaseMinSec,
              releaseMaxSec: releaseMaxSec,
              afterglowMinSec: afterglowMinSec,
              afterglowMaxSec: afterglowMaxSec,
              seed: seed,
            ),
          );

    final screen = MediaQuery.sizeOf(context);
    // V87：设置页预览也按真实手机屏幕比例显示，避免 9:13 预览把主体压扁或误判为未全屏适配。
    final previewAspect = (screen.shortestSide / math.max(1.0, screen.longestSide)).clamp(9 / 21, 9 / 14).toDouble();

    return AspectRatio(
      aspectRatio: previewAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            preview,
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      useNativePreview
                          ? '原生预览：与真实壁纸共用同一渲染器'
                          : '单次周期预览：光笔作画、自然停顿、旧痕迹渐隐',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _MystifyPreviewPainter extends CustomPainter {
  _MystifyPreviewPainter({
    required this.seconds,
    required this.style,
    required this.intimacy,
    required this.randomness,
    required this.ribbonWidth,
    required this.trail,
    required this.fullScreenCoverage,
    required this.bubbles,
    required this.ratioSeparation,
    required this.ratioAttraction,
    required this.ratioSync,
    required this.ratioCritical,
    required this.ratioRelease,
    required this.ratioAfterglow,
    required this.criticalMinSec,
    required this.criticalMaxSec,
    required this.releaseMinSec,
    required this.releaseMaxSec,
    required this.afterglowMinSec,
    required this.afterglowMaxSec,
    required this.seed,
  });

  final double seconds;
  final int style;
  final double intimacy;
  final double randomness;
  final double ribbonWidth;
  final double trail;
  final double fullScreenCoverage;
  final bool bubbles;
  final double ratioSeparation;
  final double ratioAttraction;
  final double ratioSync;
  final double ratioCritical;
  final double ratioRelease;
  final double ratioAfterglow;
  final double criticalMinSec;
  final double criticalMaxSec;
  final double releaseMinSec;
  final double releaseMaxSec;
  final double afterglowMinSec;
  final double afterglowMaxSec;
  final int seed;

  static const List<List<Color>> palettes = [
    [Color(0xFF7DD3FC), Color(0xFFC4B5FD), Color(0xFFF472B6), Color(0xFFFDE68A), Color(0xFF030712)],
    [Color(0xFF67E8F9), Color(0xFF93C5FD), Color(0xFFC4B5FD), Color(0xFFFDE68A), Color(0xFF020617)],
    [Color(0xFFA78BFA), Color(0xFFD8B4FE), Color(0xFFF9A8D4), Color(0xFFFFF7ED), Color(0xFF050316)],
    [Color(0xFFE5E7EB), Color(0xFFFFFFFF), Color(0xFF93C5FD), Color(0xFFD1D5DB), Color(0xFF000000)],
    [Color(0xFFFDE68A), Color(0xFFFFF7ED), Color(0xFFFB7185), Color(0xFFFACC15), Color(0xFF06030A)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final palette = palettes[style % palettes.length];
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = palette[4]);

    // V14：设置页预览也不再用 seconds % cycle 循环。
    // 一个预览周期内只出现一次释放和余韵，之后停留在分离，避免几分钟内反复出现完整过程。
    final cycle = 360.0;
    final sec = math.min(seconds, cycle - 0.001);
    final plan = _previewPlan(cycle);
    final phase = _phaseAt(sec, cycle, plan);
    final rawLocal = ((sec - phase.start) / math.max(0.001, phase.end - phase.start)).clamp(0.0, 1.0).toDouble();
    final local = _smooth(rawLocal);
    final release = phase.name == '释放' ? math.sin(local * math.pi) : 0.0;
    final after = phase.name == '余韵' ? local : 0.0;
    final intensity = (phase.intensity * (0.76 + intimacy * 0.52)).clamp(0.0, 1.25).toDouble();
    final tension = (phase.tension * (0.74 + intimacy * 0.56)).clamp(0.0, 1.25).toDouble();

    // 这版预览不再画“两个固定曲线对象”。它模拟真实 Mystify：
    // 多个 StrokeEvent 从全屏任意位置出生，每帧即时画当前线段，旧事件只以残影形式短暂存在。
    final coverage = fullScreenCoverage.clamp(0.35, 1.0).toDouble();
    final safe = Rect.fromLTWH(
      size.width * (1 - coverage) * 0.5,
      size.height * (1 - coverage) * 0.5,
      size.width * coverage,
      size.height * coverage,
    );

    // 保持 Windows Mystify 式黑场和少量高质量线条：不要把屏幕填满。
    final densityByPhase = switch (phase.name) {
      '分离' => 0.18,
      '吸引' => 0.38,
      '同步' => 0.52,
      '临界' => 0.72,
      '释放' => 0.42,
      _ => 0.20,
    };
    final basePeriod = lerpDouble(14.0, 5.2, (randomness * 0.24 + densityByPhase * 0.48 + 0.12).clamp(0.0, 1.0))!;
    // V17：预览模拟真实 FBO 反馈。保留更多旧笔触层，形成“头部继续写出、尾部同步慢慢退场”。
    final activeBack = phase.name == '余韵' && bubbles ? 2 : 7 + (trail * 12).round();
    final currentIndex = (seconds / basePeriod).floor();

    // Sparse soft field only, not decorative clutter.
    // V32：余韵气泡阶段不再绘制大色块背景，避免变成几个巨大的蓝/黄圆盘。
    if ((intensity > 0.15 || release > 0.0) && after <= 0.0) {
      final fieldCenter = _eventPoint(currentIndex - 1, 91, safe, size);
      final field = Paint()
        ..shader = RadialGradient(
          colors: [
            palette[1].withOpacity(0.05 + intensity * 0.06 + release * 0.15),
            palette[2].withOpacity(0.025 + intensity * 0.035),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: fieldCenter, radius: size.shortestSide * (0.25 + intensity * 0.20 + release * 0.24)));
      canvas.drawCircle(fieldCenter, size.shortestSide * (0.25 + intensity * 0.20 + release * 0.24), field);
    }

    if (!(phase.name == '余韵' && bubbles) && !(phase.name == '释放' && local > 0.16)) {
    for (int event = currentIndex - activeBack; event <= currentIndex + 1; event++) {
      final start = event * basePeriod + _hash01(event, 19) * basePeriod * 0.35;
      final life = basePeriod * (0.95 + _hash01(event, 23) * 1.15 + trail * 0.78);
      final age = seconds - start;
      if (age < 0 || age > life) continue;
      final progress = (age / life).clamp(0.0, 1.0).toDouble();
      // V168：Mystify 式渐隐——旧内容按自身年龄独立渐隐，先画先消失，而不是等全部画完再一起消失。
      // 核心改变：alphaBase 乘以 (1 - progress)^0.6 让越老的笔触越透明；
      // trailSteps 改为按 progress 动态增减，早期笔触少层（画面干净），后期多层（尾迹丰富）。
      final born = _smooth((progress / 0.08).clamp(0.0, 1.0).toDouble());
      final eventPhase = _phaseForEvent(phase.name, event);
      // V168：旧笔触按年龄衰减，越老越透明（Mystify 式逐帧历史消除）。
      final ageDecay = math.pow(1.0 - progress, 0.55).toDouble();
      final alphaBase = (0.090 + born * (0.22 + intensity * 0.34)) * (eventPhase == '分离' ? 0.55 : 0.90) * (0.32 + 0.68 * ageDecay);
      final trailSteps = 12 + (trail * 22).round();
      for (int step = trailSteps; step >= 0; step--) {
        final lag = step * 0.032 * (0.72 + trail * 0.55);
        final localAge = (age - lag).clamp(0.0, life).toDouble();
        final localProgress = (localAge / life).clamp(0.0, 1.0).toDouble();
        final tail = step / (trailSteps + 1);
        final afterStroke = phase.name == '余韵' && bubbles ? (0.12 * (1.0 - after * 0.42)) : (phase.name == '余韵' ? (1.0 - after * 0.46) : 1.0);
        // V168：旧尾迹层衰减更陡（指数从 2.25 → 2.8），让更旧的残影更快消失。
        final lagAlpha = alphaBase * math.pow(1.0 - tail, 2.80) * (step == 0 ? 1.10 : 0.42) * afterStroke;
        _drawStrokeEvent(
          canvas,
          size,
          safe,
          palette,
          event,
          localProgress,
          seconds - lag,
          lagAlpha,
          intensity,
          tension,
          release,
          eventPhase,
        );
      }
    }
    }

    if (phase.name == '释放') {
      _drawReleaseEruption(canvas, size, safe, palette, currentIndex, seconds, rawLocal, release, intensity);
    }

    if (bubbles && after > 0.02) {
      _drawAfterglowBubbleAquarium(canvas, size, safe, palette, currentIndex, seconds, after);
    }

    final textPaint = TextPainter(
      text: TextSpan(text: phase.name, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPaint.paint(canvas, Offset(size.width - textPaint.width - 18, 18));
  }


  void _drawReleaseEruption(
    Canvas canvas,
    Size size,
    Rect safe,
    List<Color> palette,
    int currentIndex,
    double seconds,
    double local,
    double release,
    double intensity,
  ) {
    final baseCenter = _eventPoint(currentIndex, 777, safe, size);
    final minDim = size.shortestSide;
    final t = local.clamp(0.0, 1.0).toDouble();

    // V37：预览端把释放开头做成肉眼能看出来的“硬震屏错位”：
    // 大幅跳变偏移 + 全屏白闪 + 斜向撕裂光带 + 多重错帧光心。
    final quakeRise = _smooth((t / 0.018).clamp(0.0, 1.0).toDouble());
    final quakeDrop = 1.0 - _smooth(((t - 0.24) / 0.18).clamp(0.0, 1.0).toDouble());
    final preQuake = quakeRise * quakeDrop;
    final strobe = (((t * 90.0 + seed % 11).floor() & 1) == 0) ? 1.0 : 0.18;
    final snapSign = (((t * 67.0 + seed % 7).floor() & 1) == 0) ? 1.0 : -1.0;
    final impactFlash = _smooth((t / 0.055).clamp(0.0, 1.0).toDouble()) *
        (1.0 - _smooth(((t - 0.42) / 0.20).clamp(0.0, 1.0).toDouble()));
    final beamSurge = math.max(
      _smooth(((t - 0.055) / 0.145).clamp(0.0, 1.0).toDouble()) *
          (1.0 - _smooth(((t - 0.72) / 0.28).clamp(0.0, 1.0).toDouble())),
      _smooth(((t - 0.11) / 0.14).clamp(0.0, 1.0).toDouble()) *
          (1.0 - _smooth(((t - 0.58) / 0.24).clamp(0.0, 1.0).toDouble())),
    );
    final floodSurge = _smooth(((t - 0.15) / 0.18).clamp(0.0, 1.0).toDouble()) *
        (1.0 - _smooth(((t - 0.88) / 0.12).clamp(0.0, 1.0).toDouble()));
    final finalClean = 1.0 - _smooth(((t - 0.84) / 0.16).clamp(0.0, 1.0).toDouble());
    final visibleRelease = math.max(release, (preQuake * 0.62 + impactFlash * 0.86).clamp(0.0, 1.0));
    final a = ((visibleRelease * 0.82 + impactFlash * 0.55 + preQuake * 0.26) * (0.90 + intimacy * 0.38)).clamp(0.0, 1.60).toDouble();

    final tremor = preQuake * (0.42 + 0.58 * math.sin(t * 410.0 + seed * 0.0017).abs());
    final snap = preQuake * (0.55 + 0.45 * strobe);
    final jitter = Offset(
      minDim * (0.026 + 0.108 * tremor) * math.sin(t * 300.0 + seed * 0.0023) + minDim * 0.075 * snap * snapSign,
      minDim * (0.024 + 0.102 * tremor) * math.cos(t * 360.0 + seed * 0.0031) - minDim * 0.058 * snap * ((((t * 83).floor() & 1) == 0) ? 1.0 : -1.0),
    );
    final center = baseCenter + jitter;

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withOpacity((a * preQuake * (0.100 + 0.070 * strobe)).clamp(0.0, 0.28)));
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF3600).withOpacity((a * preQuake * (0.050 + 0.032 * (1.0 - strobe)) * finalClean).clamp(0.0, 0.18)));
    _drawQuakeTearBands(canvas, size, baseCenter, minDim, currentIndex, t, preQuake, strobe, a);

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF6B8).withOpacity((a * (0.088 * impactFlash + 0.060 * snap)).clamp(0.0, 0.26)));
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF6505).withOpacity((a * (0.036 * beamSurge + 0.030 * snap) * finalClean).clamp(0.0, 0.16)));
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF9F1239).withOpacity((a * (0.058 * preQuake + 0.020 * floodSurge) * finalClean).clamp(0.0, 0.16)));

    final coreR = minDim * (0.055 + 0.210 * beamSurge + 0.185 * impactFlash + 0.060 * visibleRelease);

    if (preQuake > 0.01) {
      for (var q = 0; q < 7; q++) {
        final key = seed * 991 + currentIndex * 733 + q * 761;
        final h0 = _hash01(key, 3901);
        final h1 = _hash01(key, 3903);
        final ang = h0 * math.pi * 2.0 + t * (120.0 + q * 18.0);
        final amp = minDim * (0.040 + 0.092 * h1) * preQuake * (0.55 + 0.45 * strobe);
        final ghost = baseCenter + Offset(math.cos(ang), math.sin(ang)) * amp + Offset(q.isEven ? jitter.dx * 0.45 : -jitter.dx * 0.36, q.isEven ? jitter.dy * 0.45 : -jitter.dy * 0.36);
        canvas.drawCircle(ghost, coreR * (0.58 + 0.20 * q), Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withOpacity((a * preQuake * (0.16 - q * 0.012)).clamp(0.0, 0.30)),
            const Color(0xFFFFD166).withOpacity((a * preQuake * (0.080 - q * 0.006)).clamp(0.0, 0.18)),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: ghost, radius: coreR * (0.58 + 0.20 * q))));
      }
    }

    for (var g = 0; g < 5; g++) {
      final gh = _hash01(seed * 97 + currentIndex * 53 + g, 3951);
      final gc = center + Offset((gh - 0.5) * minDim * 0.130 * preQuake, (_hash01(seed * 101 + currentIndex * 59 + g, 3957) - 0.5) * minDim * 0.130 * preQuake);
      canvas.drawCircle(gc, coreR * (2.90 + g * 0.42), Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFF7A18).withOpacity((a * math.max(0.010, 0.084 - g * 0.009) * finalClean).clamp(0.0, 0.16)),
          const Color(0xFFFFD166).withOpacity((a * math.max(0.006, 0.040 - g * 0.004) * finalClean).clamp(0.0, 0.10)),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: gc, radius: coreR * (2.90 + g * 0.42))));
      canvas.drawCircle(gc, coreR * (1.75 + g * 0.18), Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withOpacity((a * math.max(0.018, 0.165 - g * 0.018) * finalClean).clamp(0.0, 0.28)),
          const Color(0xFFFFD166).withOpacity((a * math.max(0.010, 0.100 - g * 0.012) * finalClean).clamp(0.0, 0.18)),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: gc, radius: coreR * (1.75 + g * 0.18))));
    }
    canvas.drawCircle(center, coreR * 0.88, Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withOpacity((a * 0.48 * finalClean).clamp(0.0, 0.78)),
        const Color(0xFFFFF7C0).withOpacity((a * 0.21 * finalClean).clamp(0.0, 0.36)),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: center, radius: coreR * 0.88)));

    for (var w = 0; w < 13; w++) {
      final key = seed * 1009 + currentIndex * 607 + w * 137;
      final h0 = _hash01(key, 4001);
      final h1 = _hash01(key, 4003);
      final ang = h0 * math.pi * 2.0 + 0.18 * math.sin(t * 28.0 + h1 * math.pi * 2.0) + preQuake * snapSign * 0.20;
      final sweep = 0.20 + h1 * 0.30;
      final len = minDim * (0.52 + h1 * 0.90) * (0.52 + beamSurge * 0.80 + preQuake * 0.22);
      final inner = minDim * (0.018 + h1 * 0.020);
      final p = Path()
        ..moveTo(center.dx + math.cos(ang - sweep) * inner, center.dy + math.sin(ang - sweep) * inner)
        ..lineTo(center.dx + math.cos(ang - sweep * 0.72) * len, center.dy + math.sin(ang - sweep * 0.72) * len)
        ..lineTo(center.dx + math.cos(ang + sweep * 0.72) * len * (0.92 + h0 * 0.18), center.dy + math.sin(ang + sweep * 0.72) * len * (0.92 + h0 * 0.18))
        ..lineTo(center.dx + math.cos(ang + sweep) * inner, center.dy + math.sin(ang + sweep) * inner)
        ..close();
      final wa = (a * math.max(beamSurge, preQuake * 0.72) * (0.035 + h0 * 0.030) * finalClean).clamp(0.0, 0.16).toDouble();
      canvas.drawPath(p, Paint()..color = const Color(0xFFFF7A18).withOpacity(wa * 0.58));
      canvas.drawPath(p, Paint()..color = const Color(0xFFFFF08A).withOpacity(wa * 0.22));
    }

    const beamCount = 32;
    for (var i = 0; i < beamCount; i++) {
      final key = seed * 1009 + currentIndex * 811 + i * 193;
      final h0 = _hash01(key, 4101);
      final h1 = _hash01(key, 4103);
      final h2 = _hash01(key, 4107);
      final h3 = _hash01(key, 4111);
      final ang = h0 * math.pi * 2.0 + preQuake * (h2 - 0.5) * 1.10 + 0.28 * math.sin(t * 10.0 + h1 * math.pi * 2.0);
      final dir = Offset(math.cos(ang), math.sin(ang));
      final tan = Offset(-dir.dy, dir.dx);
      final len = minDim * (0.70 + h1 * 1.18) * (0.34 + beamSurge * 0.98 + preQuake * 0.20);
      final start = center + dir * (minDim * (0.012 + h2 * 0.030));
      final end = center + dir * len;
      final bend = minDim * (h2 - 0.5) * 0.24 * (0.35 + beamSurge + preQuake * 0.30);
      final pts = <Offset>[
        start,
        Offset.lerp(start, end, 0.25)! + tan * bend * 0.22,
        Offset.lerp(start, end, 0.67)! + tan * bend,
        end,
      ];
      final beamAlpha = (a * (0.046 + h2 * 0.048) * math.max(beamSurge, preQuake * 0.52) * finalClean).clamp(0.0, 0.20).toDouble();
      final beamWidth = minDim * (0.024 + h3 * 0.070) * (0.72 + 1.12 * visibleRelease + 0.86 * impactFlash + 0.75 * snap);
      _drawTaperedRibbon(canvas, pts, beamWidth * 5.40, Paint()..color = const Color(0xFFFF3B00).withOpacity(beamAlpha * 0.36)..maskFilter = MaskFilter.blur(BlurStyle.normal, beamWidth));
      _drawTaperedRibbon(canvas, pts, beamWidth * 2.45, Paint()..color = const Color(0xFFFFD166).withOpacity(beamAlpha * 0.78)..maskFilter = MaskFilter.blur(BlurStyle.normal, beamWidth * 0.42));
      _drawTaperedRibbon(canvas, pts, math.max(1.10, beamWidth * 0.25), Paint()..color = Colors.white.withOpacity(beamAlpha * 1.45));
    }

    for (var sIdx = 0; sIdx < 7; sIdx++) {
      final key = seed * 601 + currentIndex * 733 + sIdx * 313;
      final h0 = _hash01(key, 4161);
      final angle = -0.54 + h0 * 1.08 + 0.24 * math.sin(t * 9.0 + sIdx) + preQuake * snapSign * 0.16;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-dir.dy, dir.dx);
      final off = minDim * (-0.40 + sIdx * 0.14 + (_hash01(key, 4167) - 0.5) * 0.30 + snapSign * preQuake * 0.18);
      final pts = <Offset>[
        center - dir * size.width * 1.35 + normal * off,
        center - dir * size.width * 0.45 + normal * (off + minDim * 0.03),
        center + dir * size.width * 0.45 + normal * (off - minDim * 0.02),
        center + dir * size.width * 1.35 + normal * off,
      ];
      final sw = minDim * (0.032 + 0.022 * _hash01(key, 4171)) * (0.8 + 1.2 * beamSurge + 0.44 * preQuake);
      final sur = math.max(beamSurge, preQuake * 0.65);
      _drawTaperedRibbon(canvas, pts, sw * 3.3, Paint()..color = const Color(0xFFFF4A00).withOpacity((a * sur * 0.028 * finalClean).clamp(0.0, 0.12))..maskFilter = MaskFilter.blur(BlurStyle.normal, sw));
      _drawTaperedRibbon(canvas, pts, sw * 1.05, Paint()..color = const Color(0xFFFFF08A).withOpacity((a * sur * 0.090 * finalClean).clamp(0.0, 0.20))..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 0.35));
      _drawTaperedRibbon(canvas, pts, math.max(0.8, sw * 0.15), Paint()..color = Colors.white.withOpacity((a * sur * 0.140 * finalClean).clamp(0.0, 0.28)));
    }

    for (var j = 0; j < 8; j++) {
      final key = seed * 577 + currentIndex * 421 + j * 271;
      final h = _hash01(key, 4201);
      final r = minDim * (0.08 + 0.105 * j + beamSurge * (0.18 + h * 0.20));
      final start = h * math.pi * 2.0 + t * 2.5 + tremor * 0.3;
      final sweep = math.pi * (0.26 + _hash01(key, 4207) * 0.74);
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1.0, minDim * (0.0060 + j * 0.0009))
          ..color = const Color(0xFFFFC857).withOpacity((a * (0.078 - j * 0.006) * beamSurge * finalClean).clamp(0.0, 0.16))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, minDim * 0.004),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 1.018),
        start + 0.07,
        sweep * 0.58,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.65, minDim * 0.0016)
          ..color = Colors.white.withOpacity((a * (0.061 - j * 0.005) * beamSurge * finalClean).clamp(0.0, 0.15)),
      );
    }

    _drawReleaseParticleFlood(canvas, center, minDim, currentIndex, t, visibleRelease, a, preQuake, floodSurge);
  }

  void _drawQuakeTearBands(
    Canvas canvas,
    Size size,
    Offset center,
    double minDim,
    int currentIndex,
    double t,
    double quake,
    double strobe,
    double alpha,
  ) {
    if (quake <= 0.005 || alpha <= 0.0) return;
    for (var i = 0; i < 9; i++) {
      final key = seed * 1777 + currentIndex * 919 + i * 881;
      final h0 = _hash01(key, 3841);
      final h1 = _hash01(key, 3847);
      final angle = -0.42 + h0 * 0.84 + quake * (i.isEven ? 0.16 : -0.16);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-dir.dy, dir.dx);
      final gate = (((t * (90.0 + i * 4.0) + h1 * 9.0).floor() & 1) == 0) ? 1.0 : -1.0;
      final off = minDim * (-0.46 + i * 0.12 + (h1 - 0.5) * 0.16 + gate * quake * 0.20);
      final widthPx = minDim * (0.010 + h0 * 0.024) * (1.0 + quake * 1.6);
      final pts = <Offset>[
        center - dir * size.width * 1.35 + normal * off,
        center - dir * size.width * 0.40 + normal * (off + gate * minDim * 0.045),
        center + dir * size.width * 0.52 + normal * (off - gate * minDim * 0.035),
        center + dir * size.width * 1.35 + normal * off,
      ];
      final a = (alpha * quake * (0.048 + h1 * 0.054) * (0.55 + 0.45 * strobe)).clamp(0.0, 0.22).toDouble();
      _drawTaperedRibbon(canvas, pts, widthPx * 5.2, Paint()..color = const Color(0xFFFF2E00).withOpacity(a * 0.30)..maskFilter = MaskFilter.blur(BlurStyle.normal, widthPx));
      _drawTaperedRibbon(canvas, pts, widthPx * 1.8, Paint()..color = const Color(0xFFFFE66D).withOpacity(a * 0.66)..maskFilter = MaskFilter.blur(BlurStyle.normal, widthPx * 0.40));
      _drawTaperedRibbon(canvas, pts, math.max(0.9, widthPx * 0.28), Paint()..color = Colors.white.withOpacity(a));
    }
  }

  void _drawReleaseParticleFlood(
    Canvas canvas,
    Offset center,
    double minDim,
    int currentIndex,
    double local,
    double release,
    double alpha,
    double quake,
    double floodSurge,
  ) {
    const count = 230;
    for (var i = 0; i < count; i++) {
      final key = seed * 1601 + currentIndex * 997 + i * 307;
      final h0 = _hash01(key, 4301);
      final h1 = _hash01(key, 4303);
      final h2 = _hash01(key, 4307);
      final h3 = _hash01(key, 4311);
      final h4 = _hash01(key, 4319);
      final born = h0 * 0.22;
      final life = 0.46 + h1 * 0.46;
      final u = ((local - born) / life).clamp(0.0, 1.0).toDouble();
      final live = _smooth((u / 0.045).clamp(0.0, 1.0).toDouble()) *
          (1.0 - _smooth(((u - 0.78) / 0.22).clamp(0.0, 1.0).toDouble())) * release * (0.55 + 0.85 * floodSurge);
      if (live <= 0.002) continue;
      final ang = h2 * math.pi * 2.0 + 0.18 * math.sin(u * 9.0 + h3 * math.pi * 2.0) + quake * (h4 - 0.5) * 0.92;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final tan = Offset(-dir.dy, dir.dx);
      final dist = (minDim * (0.030 + (0.35 + h3 * 1.30) * math.pow(u, 0.50))).toDouble();
      final drift = minDim * (h4 - 0.5) * 0.18 * u * u;
      final p = center + dir * dist + tan * drift;
      final sz = minDim * (0.0030 + h4 * 0.0125) * (1.12 - u * 0.46) * (0.90 + floodSurge * 0.32);
      final rot = ang + h0 * 2.8 + local * (1.2 + h1 * 2.0);
      final opacity = (alpha * live * (0.22 + h1 * 0.34)).clamp(0.0, 0.38).toDouble();
      if (i % 4 == 0) {
        final path = Path();
        final co = math.cos(rot), si = math.sin(rot);
        final rx = sz * (1.6 + h3 * 2.4);
        final ry = sz * (0.38 + h2 * 0.60);
        path.moveTo(p.dx + co * rx, p.dy + si * rx);
        path.lineTo(p.dx - si * ry, p.dy + co * ry);
        path.lineTo(p.dx - co * rx * 0.68, p.dy - si * rx * 0.68);
        path.lineTo(p.dx + si * ry, p.dy - co * ry);
        path.close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFFFB020).withOpacity(opacity * 0.72));
        canvas.drawCircle(p, math.max(0.6, sz * 0.30), Paint()..color = Colors.white.withOpacity(opacity * 0.78));
      } else if (i % 4 == 1) {
        _drawRotatedOval(canvas, p, sz * (1.8 + h2 * 1.8), sz * (0.28 + h1 * 0.34), rot, Paint()..color = const Color(0xFFFF5A00).withOpacity(opacity * 0.98));
        _drawRotatedOval(canvas, p, sz * 0.80, math.max(0.35, sz * 0.11), rot, Paint()..color = Colors.white.withOpacity(opacity * 0.76));
      } else if (i % 4 == 2) {
        final tail = sz * (3.6 + h1 * 5.0);
        final comet = <Offset>[p - dir * tail, p - dir * tail * 0.42 + tan * sz * 0.35, p];
        _drawTaperedRibbon(canvas, comet, math.max(0.55, sz * (0.65 + h2)), Paint()..color = const Color(0xFFFFE58A).withOpacity(opacity * 0.54));
        canvas.drawCircle(p, math.max(0.5, sz * 0.34), Paint()..color = Colors.white.withOpacity(opacity * 0.56));
      } else {
        canvas.drawCircle(p, sz * (0.40 + h2 * 0.55), Paint()..color = const Color(0xFFFFE58A).withOpacity(opacity * 0.42));
        _drawRotatedOval(canvas, p + tan * sz * 0.20, sz * (0.72 + h1), sz * 0.16, rot, Paint()..color = Colors.white.withOpacity(opacity * 0.66));
      }
    }
  }

  void _drawAfterglowBubbleAquarium(
    Canvas canvas,
    Size size,
    Rect safe,
    List<Color> palette,
    int currentIndex,
    double seconds,
    double after,
  ) {
    final appear = _smooth((after / 0.070).clamp(0.0, 1.0).toDouble());
    final fadeOut = 1.0 - _smooth(((after - 0.90) / 0.10).clamp(0.0, 1.0).toDouble());
    final aBase = (appear * fadeOut).clamp(0.0, 1.0).toDouble();
    if (aBase <= 0.002) return;
    final minDim = size.shortestSide;
    final pulse = _eventPoint(currentIndex, 777, safe, size);

    // V37：预览也模拟真实壁纸的“逐帧清绘气泡”：气泡移动靠坐标变化，不靠拖尾残影。
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF03142F).withOpacity(0.17 * aBase),
            const Color(0xFF062A55).withOpacity(0.14 * aBase),
            const Color(0xFF020713).withOpacity(0.12 * aBase),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0EA5E9).withOpacity(0.045 * aBase),
    );

    // 视频里左下角斜向青绿光束：保持细、透明、有纵深，避免变成白色大斜面。
    for (var k = 0; k < 5; k++) {
      final off = minDim * (-0.16 + k * 0.055 + math.sin(seconds * 0.045 + k * 1.9) * 0.024);
      final y0 = size.height * (1.02 + k * 0.010) + off;
      final y1 = size.height * (0.36 + k * 0.036) + off * 0.14;
      final pts = <Offset>[
        Offset(-size.width * 0.22, y0),
        Offset(size.width * 0.18, lerpDouble(y0, y1, 0.33)!),
        Offset(size.width * 0.64, lerpDouble(y0, y1, 0.72)!),
        Offset(size.width * 1.14, y1),
      ];
      _drawTaperedRibbon(
        canvas,
        pts,
        minDim * (0.014 + k * 0.0022),
        Paint()
          ..color = const Color(0xFF38BDF8).withOpacity((0.010 - k * 0.0009) * aBase)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, minDim * 0.004),
      );
      _drawTaperedRibbon(
        canvas,
        pts,
        math.max(0.55, minDim * (0.0017 + k * 0.00045)),
        Paint()..color = const Color(0xFFCFFAFE).withOpacity((0.040 - k * 0.004) * aBase),
      );
    }

    // 每一轮由 seed/currentIndex 决定，位置、大小、颜色、高光全部不同；从释放中心迅速朝四周散开。
    const count = 30;
    for (var i = 0; i < count; i++) {
      final key = seed * 1009 + currentIndex * 173 + i * 131;
      final h0 = _hash01(key, 3301);
      final h1 = _hash01(key, 3303);
      final h2 = _hash01(key, 3307);
      final h3 = _hash01(key, 3313);
      final h4 = _hash01(key, 3319);
      final born = h0 * 0.11;
      final life = 0.92 + h1 * 0.46;
      final u = ((after - born) / life).clamp(0.0, 1.0).toDouble();
      final live = _smooth((u / 0.060).clamp(0.0, 1.0).toDouble()) *
          (1.0 - _smooth(((u - 0.86) / 0.14).clamp(0.0, 1.0).toDouble()));
      if (live <= 0.002) continue;

      final ang = h2 * math.pi * 2.0 + 0.16 * math.sin(seconds * 0.10 + i * 0.7);
      final burst = _smooth((u / 0.18).clamp(0.0, 1.0).toDouble());
      final far = minDim * (0.30 + h3 * 0.78);
      final drift = minDim * (0.060 + h1 * 0.145) * u;
      final normal = Offset(math.cos(ang), math.sin(ang));
      final tangent = Offset(-normal.dy, normal.dx);
      final swirl = minDim * (0.012 + h0 * 0.036) * math.sin(u * math.pi * 1.9 + i * 1.3);
      final center = pulse + normal * (minDim * 0.012 + far * burst + drift) + tangent * swirl +
          Offset(minDim * (0.018 + h4 * 0.080) * u, -minDim * (0.060 + h1 * 0.150) * u);
      var radius = minDim * (0.024 + h4 * 0.050) * (0.90 + 0.18 * math.sin(math.pi * u));
      if (i % 9 == 0) radius *= 1.18;
      radius = math.min(radius, minDim * 0.088);
      _drawIridescentBubble(canvas, center, radius, seconds, key, aBase * live);
    }
  }

  void _drawIridescentBubble(Canvas canvas, Offset center, double radius, double seconds, int index, double alpha) {
    if (alpha <= 0.002 || radius <= 0.5) return;

    final bubbleRect = Rect.fromCircle(center: center, radius: radius);
    // 透明水晶内部：只给一点蓝色折射，不填成实心圆。
    canvas.drawCircle(
      center,
      radius * 0.98,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.22, -0.28),
          colors: [
            const Color(0xFF38BDF8).withOpacity(0.042 * alpha),
            const Color(0xFF0F3B73).withOpacity(0.018 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.56, 1.0],
        ).createShader(bubbleRect),
    );

    final spin = seconds * (0.10 + (index & 15) * 0.003) + index * 0.0137;
    final colors = const [
      Color(0xFFF472B6),
      Color(0xFF67E8F9),
      Color(0xFF86EFAC),
      Color(0xFFFDE68A),
      Color(0xFFA78BFA),
    ];
    canvas.drawCircle(
      center,
      radius * 1.010,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.40, radius * 0.015)
        ..color = Colors.white.withOpacity(0.28 * alpha),
    );
    canvas.drawCircle(
      center,
      radius * 0.935,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.28, radius * 0.007)
        ..color = const Color(0xFF7DD3FC).withOpacity(0.065 * alpha),
    );
    for (var k = 0; k < colors.length; k++) {
      final start = spin + k * 1.17;
      final sweep = math.pi * (0.36 + 0.08 * ((index + k) % 3));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (1.005 + k * 0.002)),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.55, radius * (0.024 + k * 0.002))
          ..color = colors[k].withOpacity((0.24 - k * 0.022) * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.004),
      );
    }

    final hiAng = -0.98 + 0.16 * math.sin(spin * 0.8);
    final hi = center + Offset(math.cos(hiAng), math.sin(hiAng)) * radius * 0.44;
    _drawRotatedOval(
      canvas,
      hi,
      radius * 0.155,
      radius * 0.052,
      hiAng + 0.54,
      Paint()
        ..color = Colors.white.withOpacity(0.58 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.008),
    );
    _drawRotatedOval(
      canvas,
      center + Offset(-radius * 0.26, -radius * 0.18),
      radius * 0.40,
      radius * 0.014,
      hiAng + 0.16,
      Paint()..color = const Color(0xFFCFFAFE).withOpacity(0.12 * alpha),
    );
    _drawRotatedOval(
      canvas,
      center + Offset(radius * 0.30, radius * 0.23),
      radius * 0.34,
      radius * 0.010,
      hiAng + 0.12,
      Paint()..color = const Color(0xFFF0ABFC).withOpacity(0.060 * alpha),
    );
  }

  String _phaseForEvent(String mainPhase, int event) {
    if (mainPhase == '分离') {
      return _hash01(event, 401) < 0.78 ? '分离' : '吸引';
    }
    if (mainPhase == '吸引') {
      return _hash01(event, 402) < 0.66 ? '吸引' : '分离';
    }
    if (mainPhase == '同步') {
      return _hash01(event, 403) < 0.70 ? '同步' : '吸引';
    }
    if (mainPhase == '临界') {
      return _hash01(event, 404) < 0.68 ? '临界' : '同步';
    }
    if (mainPhase == '释放') return '释放';
    return _hash01(event, 405) < 0.72 ? '余韵' : '分离';
  }


  int _chooseArtMode(int event, String phaseName) {
    // 0 长弧, 1 纵向纱面, 2 对角线, 3 任意长线, 4 角落薄刃,
    // 5 本地弧, 6 花瓣钩弧, 7 电子扇, 8 银白折刃, 9 菱形框片,
    // 10 水母触须, 11 星云涡旋, 12 折纸光片, 13 星座碎链,
    // 14 液态光泡, 15 发光羽翼, 16 花冠, 17 丝绸幕, 18 能量环, 19 晶体光片。
    // V168：预览端开放全部20种形体，让观察者看到丰富的多形体轮换。
    // 主体阶段（分离/吸引/同步/临界）：加大"网状/扇骨/螺旋/丝带/钩形"等形体的权重，
    // 确保屏保风格的多样性和突变感，不再锁定在翼面/丝绸幕。
    final weights = switch (phaseName) {
      '分离' => <double>[0.80, 0.60, 1.10, 0.70, 0.90, 0.80, 1.20, 0.30, 0.60, 0.80, 0.50, 0.40, 1.30, 0.90, 0.50, 0.80, 0.60, 0.80, 0.60, 0.50],
      '吸引' => <double>[0.60, 0.80, 1.20, 0.80, 1.00, 0.70, 1.00, 0.40, 0.70, 0.70, 0.60, 0.50, 1.10, 1.00, 0.60, 0.90, 0.70, 0.90, 0.70, 0.60],
      '同步' => <double>[0.50, 0.70, 1.10, 0.90, 1.10, 0.60, 0.80, 0.50, 0.80, 0.60, 0.70, 0.60, 0.90, 1.10, 0.70, 1.00, 0.80, 1.00, 0.80, 0.70],
      '临界' => <double>[0.40, 0.60, 0.90, 1.00, 1.20, 0.50, 0.60, 0.60, 0.90, 0.50, 0.80, 0.70, 0.70, 1.20, 0.80, 1.10, 0.90, 1.10, 0.90, 0.80],
      '释放' => <double>[0.22, 0.38, 0.30, 0.22, 0.60, 0.18, 0.28, 0.14, 1.10, 0.42, 0.22, 0.50, 0.74, 0.14, 1.46, 1.08, 0.82, 0.94, 1.76, 1.48],
      _ => <double>[0.82, 0.60, 0.62, 0.52, 0.62, 0.26, 0.28, 0.04, 0.58, 0.22, 0.36, 0.26, 0.32, 0.10, 0.92, 0.74, 0.72, 0.86, 0.78, 0.66],
    };
    final last1 = (_hash01(event - 1, 3) * weights.length).floor().clamp(0, weights.length - 1).toInt();
    final last2 = (_hash01(event - 2, 3) * weights.length).floor().clamp(0, weights.length - 1).toInt();
    var total = 0.0;
    final adjusted = <double>[];
    for (var i = 0; i < weights.length; i++) {
      var w = weights[i];
      if (i == last1) w *= _isSculpturalMode(i) ? 0.12 : 0.18;
      if (i == last2) w *= _isSculpturalMode(i) ? 0.34 : 0.42;
      // V31：非周期“天气”继续推动大形体；余韵则交给水域气泡层，避免继续变成点线网。
      final weather = 0.62 + 0.76 * _hash01(event * 31 + i * 17, 711);
      w *= weather;
      if (i == 7 || i == 13) w *= 0.42;
      adjusted.add(w);
      total += w;
    }
    var r = ((_hash01(event, 1701) + event * 0.61803398875) % 1.0) * total;
    for (var i = 0; i < adjusted.length; i++) {
      r -= adjusted[i];
      if (r <= 0) return i;
    }
    return adjusted.length - 1;
  }

  bool _isSculpturalMode(int mode) => mode >= 14 && mode <= 19;

  void _drawStrokeEvent(
    Canvas canvas,
    Size size,
    Rect safe,
    List<Color> palette,
    int event,
    double progress,
    double t,
    double alpha,
    double intensity,
    double tension,
    double release,
    String eventPhase,
  ) {
    if (alpha <= 0.002) return;
    final mode = _chooseArtMode(event, eventPhase);
    final sculptural = _isSculpturalMode(mode);
    final points = <Offset>[];
    final controlCount = _controlCountForMode(event, mode);
    for (int i = 0; i < controlCount; i++) {
      final base = _basePointForMode(event, i, mode, safe, size, eventPhase);
      final amp = size.shortestSide * (0.010 + randomness * 0.020 + tension * 0.018);
      final vx = math.sin(t * (0.42 + _hash01(event, 30 + i) * 0.72) + event * 0.37 + i * 1.9) * amp;
      final vy = math.cos(t * (0.36 + _hash01(event, 70 + i) * 0.66) + event * 0.29 + i * 1.4) * amp;
      var p = Offset(base.dx + vx, base.dy + vy);

      if (eventPhase == '吸引' || eventPhase == '同步' || eventPhase == '临界') {
        final attract = _eventPoint(event, 818, safe, size);
        final pull = eventPhase == '吸引' ? 0.05 : eventPhase == '同步' ? 0.10 : 0.16;
        p = Offset.lerp(p, attract, pull * intensity)!;
      }
      if (eventPhase == '释放') {
        final center = _eventPoint(event, 919, safe, size);
        p = Offset.lerp(p, center, release * 0.58)!;
      }
      points.add(p);
    }
    if (points.length < 2) return;

    // Mystify / Ribbons 的高级感来自“线条正在喷洒/飞掠”，不是一整条虫子懒洋洋地停在屏幕上。
    final sampled = _sampleCurve(points, 72);
    // V15：可见窗口沿曲线滑行：头部显现的同时，尾部正在逐渐离场。
    // 已离场的尾迹不由当前对象继续绘制，而由预览残影层和真实壁纸 FBO 慢慢淡去。
    // V18：不再允许出现短小残缺片段。可见窗口必须是一段完整光迹。
    final window = (0.30 + _hash01(event, 661) * 0.24).clamp(0.24, 0.58).toDouble();
    final lead = 0.06 + _hash01(event, 667) * 0.13;
    final eased = _smooth(progress);
    final head = lerpDouble(-lead, 1.0 + window + lead, eased)!;
    final tail = head - window;
    if (tail >= 1.0 || head <= 0.0) return;
    final startIndex = (sampled.length * tail.clamp(0.0, 1.0)).floor().clamp(0, sampled.length - 2);
    final endIndex = (sampled.length * head.clamp(0.0, 1.0)).ceil().clamp(startIndex + 2, sampled.length);
    final visiblePts = sampled.sublist(startIndex, endIndex);
    if (visiblePts.length < 2) return;
    if (_polylineLength(visiblePts) < size.shortestSide * 0.20) return;
    final path = Path()..moveTo(visiblePts.first.dx, visiblePts.first.dy);
    for (int i = 1; i < visiblePts.length; i++) {
      path.lineTo(visiblePts[i].dx, visiblePts[i].dy);
    }

    final colorA = palette[(event + 1) % 4];
    final colorB = palette[(event + 2) % 4];
    final baseWidth = (0.9 + ribbonWidth * 3.6) * (0.64 + intensity * 0.58 + release * 0.24);
    final shader = LinearGradient(colors: [colorA.withOpacity(0.90), colorB.withOpacity(0.90)]).createShader(Offset.zero & size);

    // V30：雕塑形态以完整的“面/体/片/环”为主；细纤维只保留给非雕塑轨迹。
    if (!sculptural) {
      _drawFiberVeil(canvas, visiblePts, palette, event, baseWidth, alpha, intensity, tension, release);
      _drawFanLattice(canvas, visiblePts, palette, event, baseWidth, alpha * 0.75, intensity, tension, release, eventPhase, mode);
    }
    _drawArtMotifAccents(canvas, size, visiblePts, palette, event, mode, baseWidth, alpha, intensity, tension, release, eventPhase);

    final videoSubject = mode == 15 || mode == 17 || mode == 19;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = shader
      ..strokeWidth = baseWidth * (videoSubject ? 0.16 : (sculptural ? 3.2 : (eventPhase == '分离' ? 1.35 : 2.05)))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * (videoSubject ? 0.08 : (sculptural ? 1.45 : 0.80)))
      ..color = Colors.white.withOpacity(alpha * (videoSubject ? 0.012 : 0.42));
    canvas.drawPath(path, glow);

    _drawTaperedRibbon(
      canvas,
      visiblePts,
      baseWidth * (videoSubject ? 0.018 : (sculptural ? 0.58 : (eventPhase == '分离' ? 0.50 : 0.76))),
      Paint()
        ..shader = shader
        ..color = (videoSubject ? const Color(0xFFBFFFE6) : Colors.white).withOpacity(alpha * (videoSubject ? 0.025 : 0.86)),
    );

    // V30：点线喷洒不再作为主视觉；雕塑、扇面、星座链跳过，避免网状/散点占据画面。
    if (!sculptural && mode != 7 && mode != 13) {
      _drawPointLineSpray(canvas, visiblePts, palette, event, baseWidth, alpha * 0.52, intensity, tension, release, eventPhase);
    }

    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(0.30, baseWidth * (videoSubject ? 0.008 : (sculptural ? 0.070 : 0.105)))
      ..color = (videoSubject ? const Color(0xFFC8FFE8) : Colors.white)
          .withOpacity((alpha * (videoSubject ? 0.020 : (sculptural ? 0.82 : 1.08))).clamp(0.0, videoSubject ? 0.05 : (sculptural ? 0.48 : 0.72)));
    canvas.drawPath(path, core);
  }


  double _polylineLength(List<Offset> pts) {
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  void _drawFanLattice(
    Canvas canvas,
    List<Offset> pts,
    List<Color> palette,
    int event,
    double baseWidth,
    double alpha,
    double intensity,
    double tension,
    double release,
    String eventPhase,
    int mode,
  ) {
    if (pts.length < 5 || alpha <= 0.003) return;
    final motifFan = mode == 7;
    final phaseAllows = motifFan || (eventPhase == '临界' && tension > 0.62);
    final chance = motifFan ? 0.78 : 0.06 + randomness * 0.08 + tension * 0.10;
    if (!phaseAllows) return;
    if (_hash01(event, 883) > chance) return;

    final first = pts.first;
    final last = pts.last;
    final d = last - first;
    final len = d.distance == 0 ? 1.0 : d.distance;
    final tangent = Offset(d.dx / len, d.dy / len);
    final normal = Offset(-tangent.dy, tangent.dx);
    final colorA = palette[(event + 1) % 4];
    final colorB = palette[(event + 2) % 4];
    final ribs = (4 + randomness * 4 + tension * 3 + (eventPhase == '临界' ? 2 : 0)).round().clamp(3, 10).toInt();
    final spread = baseWidth * (4.2 + randomness * 2.4 + tension * 3.4 + release * 2.6);
    final growFromStart = _hash01(event, 885) < 0.5;

    for (var j = 0; j < ribs; j++) {
      final jj = ribs == 1 ? 0.0 : j / (ribs - 1);
      final centered = (jj - 0.5) * 2.0;
      final h = _hash01(event * 113 + j, 887);
      final h2 = _hash01(event * 113 + j, 889);
      final off = centered * spread * (0.55 + h * 0.55);
      final phaseShift = (h2 - 0.5) * baseWidth * (1.15 + tension);
      final rib = <Offset>[];
      for (var i = 0; i < pts.length; i++) {
        final u = i / math.max(1, pts.length - 1);
        final fanGrow = growFromStart ? _smooth(u) : _smooth(1.0 - u);
        final feather = math.sin(math.pi * u.clamp(0.0, 1.0));
        final shimmer = math.sin(u * math.pi * 2.0 + event * 0.37 + j * 0.41) * baseWidth * (0.35 + tension * 0.25) * feather;
        rib.add(pts[i] + normal * (off * fanGrow + shimmer) + tangent * phaseShift * feather);
      }
      final c = Color.lerp(colorA, colorB, h)!;
      _drawTaperedRibbon(
        canvas,
        rib,
        math.max(0.20, baseWidth * (0.035 + _hash01(event * 113 + j, 891) * 0.060)),
        Paint()..color = c.withOpacity((alpha * (0.018 + intensity * 0.028 + release * 0.030) * (0.55 + h * 0.72)).clamp(0.0, 0.20)),
      );
    }

    final cross = math.min(2, math.max(0, ribs ~/ 5)).toInt();
    for (var k = 1; k <= cross; k++) {
      final u = k / (cross + 1);
      final idx = (u * (pts.length - 1)).round().clamp(1, pts.length - 2).toInt();
      final p = pts[idx];
      final fanGrow = growFromStart ? _smooth(u) : _smooth(1.0 - u);
      final span = spread * (0.20 + 0.52 * fanGrow);
      final c = Color.lerp(colorA, colorB, u)!;
      _drawTaperedRibbon(
        canvas,
        [p - normal * span, p + normal * span],
        math.max(0.18, baseWidth * 0.026),
        Paint()..color = c.withOpacity((alpha * (0.007 + intensity * 0.014 + release * 0.012)).clamp(0.0, 0.12)),
      );
    }
  }


  void _drawAsymmetricRibbon(Canvas canvas, List<Offset> pts, double leftMax, double rightMax, Paint paint, {double power = 0.82}) {
    if (pts.length < 2 || leftMax <= 0 || rightMax <= 0) return;
    final left = <Offset>[];
    final right = <Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final prev = pts[(i - 1).clamp(0, pts.length - 1).toInt()];
      final next = pts[(i + 1).clamp(0, pts.length - 1).toInt()];
      final d = next - prev;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final n = Offset(-d.dy / len, d.dx / len);
      final u = i / math.max(1, pts.length - 1);
      final profile = math.pow(math.sin(math.pi * u).clamp(0.0, 1.0), power).toDouble();
      left.add(pts[i] + n * leftMax * profile);
      right.add(pts[i] - n * rightMax * profile);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) { path.lineTo(p.dx, p.dy); }
    for (final p in right.reversed) { path.lineTo(p.dx, p.dy); }
    path.close();
    canvas.drawPath(path, paint);
  }


  void _drawRuledSurface(Canvas canvas, List<Offset> inner, List<Offset> outer, Paint paint) {
    if (inner.length < 2 || outer.length < 2) return;
    final n = math.min(inner.length, outer.length);
    final path = Path()..moveTo(inner.first.dx, inner.first.dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(inner[i].dx, inner[i].dy);
    }
    for (var i = n - 1; i >= 0; i--) {
      path.lineTo(outer[i].dx, outer[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawRotatedOval(Canvas canvas, Offset center, double rx, double ry, double rotation, Paint paint) {
    if (rx <= 0 || ry <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), paint);
    canvas.restore();
  }

  void _drawArcBand(Canvas canvas, Offset center, double radius, double width, double start, double sweep, Paint paint) {
    if (radius <= 0 || width <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..shader = paint.shader
      ..color = paint.color
      ..maskFilter = paint.maskFilter;
    canvas.drawArc(rect, start, sweep, false, p);
  }

  void _drawVideoSubjectPreview(
    Canvas canvas,
    Size size,
    List<Offset> pts,
    Color colorA,
    Color colorB,
    int event,
    double baseWidth,
    double alpha,
    double intensity,
    double tension,
    double release,
    String eventPhase,
  ) {
    if (pts.length < 4 || alpha <= 0.003) return;
    final side = _hash01(event, 1907) < 0.5 ? -1.0 : 1.0;
    final subjectPhase = eventPhase != '释放' && eventPhase != '余韵';
    final minDim = size.shortestSide;
    final phaseWide = eventPhase == '分离'
        ? 0.56
        : eventPhase == '吸引'
            ? 0.70
            : eventPhase == '同步'
                ? 0.92
                : eventPhase == '临界'
                    ? 1.08
                    : 0.82;
    late final Color main;
    late final Color accent;
    if (eventPhase == '同步') {
      main = const Color(0xFF7C2CFF);
      accent = const Color(0xFF29F27A);
    } else if (eventPhase == '临界') {
      main = const Color(0xFF18F04F);
      accent = const Color(0xFF20F0D0);
    } else if (eventPhase == '吸引') {
      main = const Color(0xFF1DDD62);
      accent = const Color(0xFFA020F0);
    } else if (eventPhase == '分离') {
      main = const Color(0xFF1ACC5A);
      accent = const Color(0xFFE64B6A);
    } else {
      main = colorA;
      accent = colorB;
    }

    final sail = minDim * (0.048 + 0.046 * phaseWide);
    final fold = math.max(0.22, baseWidth * 0.10);
    final layerScale = subjectPhase ? 1.0 : 0.24;
    final ridge = <Offset>[];
    final inner = <Offset>[];
    final outer = <Offset>[];
    final outerSoft = <Offset>[];
    final caustic = <Offset>[];

    for (var i = 0; i < pts.length; i++) {
      final u = i / math.max(1, pts.length - 1);
      final prev = pts[(i - 1).clamp(0, pts.length - 1).toInt()];
      final next = pts[(i + 1).clamp(0, pts.length - 1).toInt()];
      final d = next - prev;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final tangent = Offset(d.dx / len, d.dy / len);
      final normal = Offset(-tangent.dy, tangent.dx);
      final open = _smooth((u / 0.12).clamp(0.0, 1.0));
      final body = math.pow(math.sin(math.pi * u).clamp(0.0, 1.0), 0.58).toDouble();
      final tipClose = 1.0 - _smooth(((u - 0.74) / 0.26).clamp(0.0, 1.0)) * 0.985;
      final shoulderBias = 0.62 + 0.38 * math.pow(math.max(0.0, 1.0 - u), 0.55).toDouble();
      final profile = (open * body * tipClose * shoulderBias).clamp(0.0, 1.0).toDouble();
      final notch = math.sin(event * 0.031 + u * math.pi * 2.15) * sail * 0.012 * profile;
      final shear = sail * profile * (0.10 * math.pow(1.0 - u, 2).toDouble() - 0.045 * u * (1.0 - u));
      final p = pts[i];
      ridge.add(p - normal * side * fold * (0.10 + 0.18 * profile) + tangent * notch * 0.10);
      inner.add(p + normal * side * sail * profile * 0.32 + tangent * (shear * 0.38 + notch * 0.32));
      outer.add(p + normal * side * sail * profile + tangent * (shear + notch));
      outerSoft.add(p + normal * side * sail * profile * 1.12 + tangent * (shear * 1.10 + notch * 1.18));
      caustic.add(p + normal * side * sail * profile * (0.055 + 0.040 * math.sin(u * math.pi)) + tangent * notch * 0.18);
    }

    _drawRuledSurface(
      canvas,
      ridge,
      outerSoft,
      Paint()
        ..color = main.withOpacity((alpha * layerScale * (subjectPhase ? 0.0045 : 0.009)).clamp(0.0, 0.08))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.18),
    );
    _drawRuledSurface(
      canvas,
      ridge,
      outer,
      Paint()
        ..color = main.withOpacity((alpha * layerScale * (subjectPhase ? 0.014 : 0.026)).clamp(0.0, 0.11))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.10),
    );
    _drawRuledSurface(
      canvas,
      ridge,
      inner,
      Paint()..color = accent.withOpacity((alpha * layerScale * (subjectPhase ? 0.0045 : 0.008)).clamp(0.0, 0.06)),
    );

    final ribs = eventPhase == '临界' ? 44 : eventPhase == '同步' ? 34 : 24;
    for (var j = 1; j <= ribs; j++) {
      final u = j / (ribs + 1);
      if (u < 0.10 || u > 0.88) continue;
      final pos = u * (pts.length - 1);
      final i0 = pos.floor().clamp(0, pts.length - 1).toInt();
      final i1 = (i0 + 1).clamp(0, pts.length - 1).toInt();
      final f = pos - i0;
      final a = Offset.lerp(outerSoft[i0], outerSoft[i1], f)!;
      final cpt = Offset.lerp(caustic[i0], caustic[i1], f)!;
      final lpt = Offset.lerp(ridge[i0], ridge[i1], f)!;
      final rib = <Offset>[a, Offset.lerp(a, cpt, 0.52)!, lpt];
      final ribAlpha = alpha * (subjectPhase ? 0.0055 : 0.010) * (0.72 + 0.28 * math.sin(u * math.pi));
      _drawTaperedRibbon(
        canvas,
        rib,
        math.max(0.045, baseWidth * 0.004),
        Paint()..color = main.withOpacity(ribAlpha.clamp(0.0, 0.06)),
      );
    }

    _drawTaperedRibbon(
      canvas,
      outer,
      math.max(0.055, baseWidth * 0.010),
      Paint()
        ..color = main.withOpacity((alpha * (subjectPhase ? 0.020 : 0.044)).clamp(0.0, 0.10))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.06),
    );
    _drawTaperedRibbon(
      canvas,
      ridge,
      math.max(0.055, baseWidth * 0.008),
      Paint()..color = accent.withOpacity((alpha * (subjectPhase ? 0.022 : 0.048)).clamp(0.0, 0.12)),
    );
    _drawTaperedRibbon(
      canvas,
      caustic,
      math.max(0.045, baseWidth * 0.006),
      Paint()..color = const Color(0xFF94FFC8).withOpacity((alpha * (subjectPhase ? 0.014 : 0.032)).clamp(0.0, 0.08)),
    );

    final start = (pts.length * 0.82).floor().clamp(0, pts.length - 1).toInt();
    final tipRidge = ridge.sublist(start);
    _drawTaperedRibbon(
      canvas,
      tipRidge,
      math.max(0.05, baseWidth * 0.010),
      Paint()..color = const Color(0xFFA8FFE0).withOpacity((alpha * (subjectPhase ? 0.040 : 0.070)).clamp(0.0, 0.14)),
    );
  }


  void _drawArtMotifAccents(
    Canvas canvas,
    Size size,
    List<Offset> pts,
    List<Color> palette,
    int event,
    int mode,
    double baseWidth,
    double alpha,
    double intensity,
    double tension,
    double release,
    String eventPhase,
  ) {
    if (pts.length < 3 || alpha <= 0.003) return;
    final first = pts.first;
    final last = pts.last;
    final d = last - first;
    final len = d.distance == 0 ? 1.0 : d.distance;
    final tangent = Offset(d.dx / len, d.dy / len);
    final normal = Offset(-tangent.dy, tangent.dx);
    final colorA = palette[(event + 1) % 4];
    final colorB = palette[(event + 2) % 4];

    if (mode == 14) {
      // 液态光泡：完整椭圆体 + 内部柔光，不再由点线组成。
      final mid = pts[pts.length ~/ 2];
      final rot = math.atan2(d.dy, d.dx);
      final rx = baseWidth * (8.4 + tension * 3.2);
      final ry = baseWidth * (4.6 + release * 2.2);
      _drawRotatedOval(canvas, mid, rx, ry, rot, Paint()..color = colorA.withOpacity((alpha * (0.070 + intensity * 0.040)).clamp(0.0, 0.22))..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.9));
      _drawRotatedOval(canvas, mid + normal * rx * 0.08, rx * 0.55, ry * 0.48, rot + 0.25, Paint()..color = Colors.white.withOpacity((alpha * 0.040).clamp(0.0, 0.12))..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.55));
      _drawArcBand(canvas, mid, rx * 0.86, math.max(0.5, baseWidth * 0.13), rot + 0.2, math.pi * 1.55, Paint()..color = colorB.withOpacity((alpha * 0.075).clamp(0.0, 0.20)));
      return;
    } else if (mode == 15) {
      // V41 视频主体：单侧扇形薄膜/折叠光幕，去掉沿中心线加宽的粗白脊线。
      _drawVideoSubjectPreview(canvas, size, pts, colorA, colorB, event, baseWidth, alpha, intensity, tension, release, eventPhase);
      return;
    } else if (mode == 16) {
      // 花冠：几片可辨认的花瓣围绕中心展开。
      final mid = pts[pts.length ~/ 2];
      final rot = math.atan2(d.dy, d.dx);
      for (int k = 0; k < 5; k++) {
        final a = rot + (k - 2) * 0.56;
        final c = mid + Offset(math.cos(a), math.sin(a)) * baseWidth * (2.7 + k * 0.12);
        _drawRotatedOval(canvas, c, baseWidth * (4.8 + tension * 1.8), baseWidth * (1.8 + intensity), a, Paint()..color = Color.lerp(colorA, colorB, k / 4)!.withOpacity((alpha * (0.047 + intensity * 0.030)).clamp(0.0, 0.18))..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.35));
      }
      canvas.drawCircle(mid, baseWidth * (1.3 + release), Paint()..color = Colors.white.withOpacity((alpha * 0.075).clamp(0.0, 0.16))..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.4));
      return;
    } else if (mode == 17) {
      // V41 视频主体：宽端展开、尖端收束的彩色膜面，不再铺成大灰白布带。
      _drawVideoSubjectPreview(canvas, size, pts, colorA, colorB, event + 17, baseWidth * 0.96, alpha, intensity, tension, release, eventPhase);
      return;
    } else if (mode == 18) {
      // 能量环：弯月/环形而不是线网。
      final mid = pts[pts.length ~/ 2];
      final r = baseWidth * (8.0 + tension * 3.0 + release * 2.0);
      final start = math.atan2(first.dy - mid.dy, first.dx - mid.dx) + _hash01(event, 1801) * 1.2;
      _drawArcBand(canvas, mid, r, math.max(1.0, baseWidth * 0.70), start, math.pi * (1.22 + _hash01(event, 1802) * 0.70), Paint()..color = colorA.withOpacity((alpha * (0.16 + intensity * 0.06)).clamp(0.0, 0.34))..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.25));
      _drawArcBand(canvas, mid, r * 0.66, math.max(0.5, baseWidth * 0.12), start + 1.1, math.pi * 1.7, Paint()..color = colorB.withOpacity((alpha * 0.055).clamp(0.0, 0.16)));
      return;
    } else if (mode == 19) {
      // V41 晶体薄尖：只作为视频主体边缘折尖，不再生成白色多边形刀片。
      _drawVideoSubjectPreview(canvas, size, pts, colorA, colorB, event + 19, baseWidth * 0.82, alpha, intensity, tension, release, eventPhase);
      return;
    }

    if (mode == 6 || mode == 5) {
      // 花瓣/藤蔓：在主线侧边追加一片柔软卷边，避免只是一根普通线。
      final side = _hash01(event, 930) < 0.5 ? -1.0 : 1.0;
      for (int layer = 0; layer < 3; layer++) {
        final petal = <Offset>[];
        for (int i = 0; i < pts.length; i++) {
          final u = i / math.max(1, pts.length - 1);
          final feather = math.sin(math.pi * u).clamp(0.0, 1.0).toDouble();
          final curl = math.sin(u * math.pi * 1.5 + layer * 0.52 + event * 0.11) * baseWidth * (0.9 + tension);
          petal.add(pts[i] + normal * side * baseWidth * (1.8 + layer * 0.86) * feather + tangent * curl * feather);
        }
        _drawTaperedRibbon(
          canvas,
          petal,
          baseWidth * (0.18 + layer * 0.10),
          Paint()..color = Color.lerp(colorA, colorB, layer / 2.0)!.withOpacity((alpha * (0.025 + intensity * 0.050 + release * 0.030)).clamp(0.0, 0.18)),
        );
      }
    } else if (mode == 8) {
      // 银白折刃：加一条非常锋利的亮边和一片极淡三角面。
      final mid = pts[pts.length ~/ 2];
      final bladePts = [first, mid + normal * baseWidth * (2.2 + tension * 2.0), last];
      _drawTaperedRibbon(
        canvas,
        bladePts,
        baseWidth * (2.6 + release * 1.8),
        Paint()..color = Colors.white.withOpacity((alpha * (0.030 + release * 0.050)).clamp(0.0, 0.22)),
      );
      _drawTaperedRibbon(
        canvas,
        [first, last],
        math.max(0.35, baseWidth * 0.10),
        Paint()..color = Colors.white.withOpacity((alpha * (0.50 + intensity * 0.22)).clamp(0.0, 0.82)),
      );
    } else if (mode == 9) {
      // 菱形框片：偏移复写，形成视频里短暂出现的倾斜透明几何纸片。
      for (int k = -2; k <= 2; k++) {
        if (k == 0) continue;
        final off = normal * (baseWidth * k * 1.15);
        _drawTaperedRibbon(
          canvas,
          pts.map((p) => p + off).toList(),
          math.max(0.22, baseWidth * 0.055),
          Paint()..color = Color.lerp(colorA, colorB, (k + 2) / 4.0)!.withOpacity((alpha * (0.018 + intensity * 0.028)).clamp(0.0, 0.13)),
        );
      }
    } else if (mode == 10) {
      // 水母触须：主线边缘垂下几根短促、有方向的有机光丝。
      for (int h = 0; h < 5; h++) {
        final u = (0.42 + _hash01(event * 19 + h, 960) * 0.48).clamp(0.0, 1.0).toDouble();
        final idx = (u * (pts.length - 1)).round().clamp(1, pts.length - 2).toInt();
        final p = pts[idx];
        final side = _hash01(event * 19 + h, 961) < 0.5 ? -1.0 : 1.0;
        final hair = [
          p,
          p + normal * side * baseWidth * (2.1 + h * 0.55),
          p + normal * side * baseWidth * (2.8 + h * 0.62) + tangent * baseWidth * (1.1 + h * 0.15),
        ];
        _drawTaperedRibbon(
          canvas,
          hair,
          math.max(0.20, baseWidth * 0.052),
          Paint()..color = Color.lerp(colorA, colorB, h / 4.0)!.withOpacity((alpha * (0.020 + intensity * 0.020)).clamp(0.0, 0.14)),
        );
      }
    } else if (mode == 11) {
      // 星云涡旋：在主弧两侧生成螺旋回声，让同类曲线也有不同呼吸。
      for (int k = 1; k <= 3; k++) {
        final echo = <Offset>[];
        final sign = k.isEven ? -1.0 : 1.0;
        for (int i = 0; i < pts.length; i++) {
          final u = i / math.max(1, pts.length - 1);
          final feather = math.sin(math.pi * u).clamp(0.0, 1.0).toDouble();
          final swirl = math.sin(u * math.pi * (1.0 + k * 0.34) + event * 0.37) * baseWidth * (1.4 + k * 0.58) * feather;
          echo.add(pts[i] + normal * sign * swirl);
        }
        _drawTaperedRibbon(
          canvas,
          echo,
          math.max(0.20, baseWidth * (0.070 - k * 0.010)),
          Paint()..color = Color.lerp(colorA, colorB, k / 3.0)!.withOpacity((alpha * (0.018 + intensity * 0.025) * (1 - k * 0.16)).clamp(0.0, 0.13)),
        );
      }
    } else if (mode == 12) {
      // 折纸光片：一条亮折痕 + 一条暗折痕，像薄薄发光纸片翻身。
      for (final pair in const [1.0, -0.78]) {
        final fold = <Offset>[];
        for (int i = 0; i < pts.length; i++) {
          final u = i / math.max(1, pts.length - 1);
          final feather = math.sin(math.pi * u).clamp(0.0, 1.0).toDouble();
          fold.add(pts[i] + normal * baseWidth * pair * 2.0 * feather);
        }
        _drawTaperedRibbon(
          canvas,
          fold,
          math.max(0.20, baseWidth * (pair > 0 ? 0.060 : 0.045)),
          Paint()..color = (pair > 0 ? Colors.white : colorB).withOpacity((alpha * (pair > 0 ? 0.12 : 0.045)).clamp(0.0, 0.18)),
        );
      }
    } else if (mode == 13) {
      // 星座碎链：节点依附在线上，避免像随机灰尘散开。
      for (int k = 1; k <= 5; k++) {
        final idx = (k / 6 * (pts.length - 1)).round().clamp(1, pts.length - 2).toInt();
        final p = pts[idx];
        canvas.drawCircle(
          p,
          baseWidth * (0.32 + _hash01(event * 23 + k, 981) * 0.34),
          Paint()
            ..color = Color.lerp(colorA, colorB, k / 5)!.withOpacity((alpha * (0.08 + intensity * 0.04)).clamp(0.0, 0.20))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 0.16),
        );
      }
    } else if (mode == 7) {
      // 扇面焦点：让扇形更像从隐形铰链处展开，而不是散乱线束。
      final pivot = _hash01(event, 934) < 0.5 ? first : last;
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [colorA.withOpacity((alpha * 0.20).clamp(0.0, 0.18)), Colors.transparent],
        ).createShader(Rect.fromCircle(center: pivot, radius: baseWidth * (12.0 + tension * 8.0)));
      canvas.drawCircle(pivot, baseWidth * (12.0 + tension * 8.0), glow);
    }
  }

  void _drawFiberVeil(
    Canvas canvas,
    List<Offset> pts,
    List<Color> palette,
    int event,
    double baseWidth,
    double alpha,
    double intensity,
    double tension,
    double release,
  ) {
    if (pts.length < 4 || alpha <= 0.003) return;
    final first = pts.first;
    final last = pts.last;
    final d = last - first;
    final len = d.distance == 0 ? 1.0 : d.distance;
    final tangent = Offset(d.dx / len, d.dy / len);
    final normal = Offset(-tangent.dy, tangent.dx);
    final colorA = palette[(event + 1) % 4];
    final colorB = palette[(event + 2) % 4];
    final strands = 3 + (randomness * 3 + intensity * 2).round();
    final spread = baseWidth * (1.15 + tension * 1.75 + release * 1.60);
    for (var j = 0; j < strands; j++) {
      final h = _hash01(event * 97 + j, 701);
      final h2 = _hash01(event * 97 + j, 709);
      final side = (j - (strands - 1) * 0.5) / math.max(1, strands - 1);
      final off = side * spread * (0.55 + h * 0.90);
      final along = (h2 - 0.5) * baseWidth * (1.0 + tension);
      final strand = <Offset>[];
      for (var i = 0; i < pts.length; i++) {
        final u = i / math.max(1, pts.length - 1);
        final feather = math.sin(math.pi * u.clamp(0.0, 1.0));
        final wave = math.sin(u * math.pi * 2.0 + event * 0.71 + j * 0.77) * baseWidth * 0.28 * feather;
        strand.add(pts[i] + normal * (off + wave) + tangent * along * feather);
      }
      final c = Color.lerp(colorA, colorB, h)!;
      _drawTaperedRibbon(
        canvas,
        strand,
        math.max(0.25, baseWidth * (0.035 + _hash01(event * 97 + j, 719) * 0.075)),
        Paint()..color = c.withOpacity((alpha * (0.030 + intensity * 0.045 + release * 0.040) * (0.45 + h * 0.70)).clamp(0.0, 0.18)),
      );
    }
  }

  void _drawPointLineSpray(
    Canvas canvas,
    List<Offset> pts,
    List<Color> palette,
    int event,
    double baseWidth,
    double alpha,
    double intensity,
    double tension,
    double release,
    String eventPhase,
  ) {
    if (pts.length < 3 || alpha <= 0.002) return;
    final rndCount = eventPhase == '分离'
        ? 3
        : eventPhase == '吸引'
            ? 5
            : eventPhase == '同步'
                ? 6
                : eventPhase == '临界'
                    ? 8
                    : 5;
    final grains = (rndCount + randomness * 4 + release * 4).round();
    final colorA = palette[(event + 1) % 4];
    final colorB = palette[(event + 2) % 4];
    final spray = baseWidth * (1.35 + tension * 1.55);
    for (int i = 0; i < grains; i++) {
      final h1 = _hash01(event * 101 + i, 611);
      final h2 = _hash01(event * 101 + i, 617);
      final h3 = _hash01(event * 101 + i, 623);
      var u = h1 < 0.68 ? lerpDouble(0.55, 1.0, h2)! : h2;
      u = u.clamp(0.0, 1.0).toDouble();
      final idx = (u * (pts.length - 1)).round().clamp(1, pts.length - 2).toInt();
      final p = pts[idx];
      final prev = pts[idx - 1];
      final next = pts[idx + 1];
      final d = next - prev;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final t = Offset(d.dx / len, d.dy / len);
      final n = Offset(-t.dy, t.dx);
      final along = (_hash01(event * 101 + i, 631) - 0.5) * spray * 0.9;
      final normal = (_hash01(event * 101 + i, 637) - 0.5) * spray * (eventPhase == '临界' ? 2.2 : eventPhase == '释放' ? 2.6 : 1.5);
      final q = p + t * along + n * normal;
      final radius = (0.28 + baseWidth * (0.026 + _hash01(event * 101 + i, 641) * 0.080)).clamp(0.22, 2.4).toDouble();
      final c = Color.lerp(colorA, colorB, _hash01(event * 101 + i, 643))!;
      final dotPaint = Paint()
        ..color = c.withOpacity((alpha * (0.018 + intensity * 0.070 + release * 0.055) * (0.40 + h3 * 0.55)).clamp(0.0, 0.32))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35);
      canvas.drawCircle(q, radius, dotPaint);

      if (_hash01(event * 101 + i, 647) < 0.22 + intensity * 0.10) {
        final seg = radius * (5.0 + _hash01(event * 101 + i, 653) * 9.0);
        final path = Path()
          ..moveTo(q.dx - t.dx * seg * 0.45, q.dy - t.dy * seg * 0.45)
          ..lineTo(q.dx + t.dx * seg * 0.55, q.dy + t.dy * seg * 0.55);
        final linePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.22, radius * 0.34)
          ..color = c.withOpacity((alpha * 0.070).clamp(0.0, 0.18));
        canvas.drawPath(path, linePaint);
      }
    }
  }

  void _drawTaperedRibbon(Canvas canvas, List<Offset> pts, double maxWidth, Paint paint) {
    if (pts.length < 2 || maxWidth <= 0) return;
    final left = <Offset>[];
    final right = <Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final prev = pts[(i - 1).clamp(0, pts.length - 1).toInt()];
      final next = pts[(i + 1).clamp(0, pts.length - 1).toInt()];
      final d = next - prev;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final n = Offset(-d.dy / len, d.dx / len);
      final u = i / math.max(1, pts.length - 1);
      final profile = math.pow(math.sin(math.pi * u).clamp(0.0, 1.0), 1.25).toDouble();
      final w = maxWidth * (0.004 + 0.996 * profile) * 0.5;
      left.add(pts[i] + n * w);
      right.add(pts[i] - n * w);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  List<Offset> _sampleCurve(List<Offset> controls, int samples) {
    final pts = <Offset>[];
    if (controls.length == 2) return [controls[0], controls[1]];
    for (int s = 0; s < samples; s++) {
      final u = s / (samples - 1);
      final scaled = u * (controls.length - 1);
      final i = scaled.floor().clamp(0, controls.length - 2);
      final local = scaled - i;
      final p0 = controls[(i - 1).clamp(0, controls.length - 1).toInt()];
      final p1 = controls[i];
      final p2 = controls[(i + 1).clamp(0, controls.length - 1).toInt()];
      final p3 = controls[(i + 2).clamp(0, controls.length - 1).toInt()];
      pts.add(_catmull(p0, p1, p2, p3, local));
    }
    return pts;
  }

  Offset _catmull(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return Offset(
      0.5 * ((2 * p1.dx) + (-p0.dx + p2.dx) * t + (2*p0.dx - 5*p1.dx + 4*p2.dx - p3.dx) * t2 + (-p0.dx + 3*p1.dx - 3*p2.dx + p3.dx) * t3),
      0.5 * ((2 * p1.dy) + (-p0.dy + p2.dy) * t + (2*p0.dy - 5*p1.dy + 4*p2.dy - p3.dy) * t2 + (-p0.dy + 3*p1.dy - 3*p2.dy + p3.dy) * t3),
    );
  }


  int _controlCountForMode(int event, int mode) {
    switch (mode) {
      case 6: // petal hook / curled flower
        return 5 + (_hash01(event, 506) * 2).floor();
      case 7: // shell fan / electronic veil
        return 5 + (_hash01(event, 507) * 3).floor();
      case 8: // blade shard
        return 3 + (_hash01(event, 508) * 2).floor();
      case 9: // prism polygon / tilted frame
        return 5;
      case 10: // jellyfish tendril
        return 6 + (_hash01(event, 510) * 3).floor();
      case 11: // nebula coil
        return 6 + (_hash01(event, 511) * 3).floor();
      case 12: // origami sheet
        return 5 + (_hash01(event, 512) * 2).floor();
      case 13: // constellation chain
        return 4 + (_hash01(event, 513) * 4).floor();
      case 14: // liquid pod
        return 5 + (_hash01(event, 514) * 3).floor();
      case 15: // luminous wing
        return 5 + (_hash01(event, 515) * 3).floor();
      case 16: // blossom crown
        return 6 + (_hash01(event, 516) * 3).floor();
      case 17: // silk banner
        return 5 + (_hash01(event, 517) * 3).floor();
      case 18: // orbit halo
        return 5 + (_hash01(event, 518) * 3).floor();
      case 19: // crystal shard
        return 4 + (_hash01(event, 519) * 3).floor();
      default:
        return 4 + (_hash01(event, 5) * 3).floor();
    }
  }

  Offset _basePointForMode(int event, int index, int mode, Rect safe, Size size, String eventPhase) {
    final a = _hash01(event * 17 + index, 101);
    final b = _hash01(event * 17 + index, 102);
    switch (mode) {
      case 0: // long left/right sweep, like a magenta bridge or green comet
        return Offset(index == 0 ? safe.left : index == 1 ? safe.right : lerpDouble(safe.left, safe.right, a)!, lerpDouble(safe.top, safe.bottom, b)!);
      case 1: // top/bottom sheet sweep
        return Offset(lerpDouble(safe.left, safe.right, a)!, index == 0 ? safe.top : index == 1 ? safe.bottom : lerpDouble(safe.top, safe.bottom, b)!);
      case 2: // diagonal full-screen trace
        final reverse = _hash01(event, 120) < 0.5;
        final s = (index / 4.0).clamp(0.0, 1.0);
        final x = reverse ? lerpDouble(safe.right, safe.left, s)! : lerpDouble(safe.left, safe.right, s)!;
        final y = _hash01(event, 121) < 0.5 ? lerpDouble(safe.top, safe.bottom, s)! : lerpDouble(safe.bottom, safe.top, s)!;
        return Offset(x, y);
      case 3: // arbitrary long line with independent bend
        return _eventPoint(event + index * 37, 133, safe, size);
      case 4: // corner cut-in, like a white blade entering from darkness
        final corner = (_hash01(event, 140) * 4).floor();
        final cornerP = [safe.topLeft, safe.topRight, safe.bottomRight, safe.bottomLeft][corner];
        return Offset.lerp(cornerP, _eventPoint(event + index * 13, 141, safe, size), (index / 3.0).clamp(0.0, 1.0))!;
      case 5: // local arc but still anywhere on screen
        final center5 = _eventPoint(event, 150, safe, size);
        final radius = math.min(safe.width, safe.height) * (0.10 + _hash01(event, 151) * 0.18);
        final angle = _hash01(event, 152) * math.pi * 2 + index * 0.75;
        return Offset(center5.dx + math.cos(angle) * radius, center5.dy + math.sin(angle) * radius * 0.72);
      case 6: // petal hook: a vertical stem rolling into pink/yellow curved petal
        final center6 = _eventPoint(event, 260, safe, size);
        final count6 = _controlCountForMode(event, mode);
        final u6 = index / math.max(1, count6 - 1);
        final baseAngle = _hash01(event, 261) * math.pi * 2;
        final sweep = (1.15 + _hash01(event, 262) * 1.55) * (_hash01(event, 263) < 0.5 ? -1.0 : 1.0);
        final r = (size.shortestSide * (0.055 + 0.18 * math.pow(u6, 0.72))).toDouble();
        final curl = baseAngle + sweep * (u6 * u6);
        final stem = Offset(math.cos(baseAngle + math.pi / 2), math.sin(baseAngle + math.pi / 2)) * size.shortestSide * (0.12 * (0.5 - u6));
        return center6 + stem + Offset(math.cos(curl) * r, math.sin(curl) * r * (0.58 + _hash01(event, 264) * 0.34));
      case 7: // fan shell: ribs share a hidden pivot, then unfold like electronic gauze
        final pivot7 = _eventPoint(event, 270, safe, size);
        final count7 = _controlCountForMode(event, mode);
        final u7 = index / math.max(1, count7 - 1);
        final baseAngle = _hash01(event, 271) * math.pi * 2;
        final sweep = (0.65 + _hash01(event, 272) * 1.15) * (_hash01(event, 273) < 0.5 ? -1.0 : 1.0);
        final r = size.shortestSide * (0.035 + 0.34 * _smooth(u7));
        final a2 = baseAngle + sweep * _smooth(u7);
        return pivot7 + Offset(math.cos(a2) * r, math.sin(a2) * r * (0.72 + _hash01(event, 274) * 0.26));
      case 8: // silver prism blade: straight energy with one sharp crease
        final p08 = _eventPoint(event, 280, safe, size);
        final p18 = _eventPoint(event, 281, safe, size);
        final count8 = _controlCountForMode(event, mode);
        final u8 = index / math.max(1, count8 - 1);
        final midBias8 = math.sin(math.pi * u8);
        final d8 = p18 - p08;
        final len8 = d8.distance == 0 ? 1.0 : d8.distance;
        final n8 = Offset(-d8.dy / len8, d8.dx / len8);
        final crease = (_hash01(event, 282) - 0.5) * size.shortestSide * 0.26;
        return Offset.lerp(p08, p18, u8)! + n8 * crease * midBias8;
      case 9: // tilted diamond / polygon frame
        final center9 = _eventPoint(event, 290, safe, size);
        final radius = size.shortestSide * (0.11 + _hash01(event, 291) * 0.20);
        final rot = _hash01(event, 292) * math.pi * 2;
        final count9 = _controlCountForMode(event, mode);
        final u9 = index / math.max(1, count9 - 1);
        final corners = [
          Offset(math.cos(rot) * radius, math.sin(rot) * radius * 0.72),
          Offset(math.cos(rot + math.pi / 2) * radius * 0.72, math.sin(rot + math.pi / 2) * radius),
          Offset(math.cos(rot + math.pi) * radius, math.sin(rot + math.pi) * radius * 0.72),
          Offset(math.cos(rot + math.pi * 1.5) * radius * 0.72, math.sin(rot + math.pi * 1.5) * radius),
          Offset(math.cos(rot) * radius, math.sin(rot) * radius * 0.72),
        ];
        final seg = (u9 * 4).floor().clamp(0, 3).toInt();
        final local = u9 * 4 - seg;
        return center9 + Offset.lerp(corners[seg], corners[seg + 1], local)!;
      case 10: // jellyfish tendril / water grass
        final center10 = _eventPoint(event, 300, safe, size);
        final count10 = _controlCountForMode(event, mode);
        final u10 = index / math.max(1, count10 - 1);
        final base10 = _hash01(event, 301) * math.pi * 2;
        final len10 = size.shortestSide * (0.20 + _hash01(event, 302) * 0.30);
        final droop10 = len10 * (u10 - 0.5);
        final wave10 = math.sin(u10 * math.pi * 1.7 + event * 0.17) * size.shortestSide * (0.045 + _hash01(event, 303) * 0.035);
        return center10 + Offset(math.cos(base10) * droop10 + math.cos(base10 + math.pi / 2) * wave10, math.sin(base10) * droop10 + math.sin(base10 + math.pi / 2) * wave10);
      case 11: // open nebula coil
        final center11 = _eventPoint(event, 310, safe, size);
        final count11 = _controlCountForMode(event, mode);
        final u11 = index / math.max(1, count11 - 1);
        final base11 = _hash01(event, 311) * math.pi * 2;
        final handed11 = _hash01(event, 312) < 0.5 ? -1.0 : 1.0;
        final r11 = size.shortestSide * (0.035 + 0.31 * _smooth(u11));
        final a11 = base11 + handed11 * (0.75 + 2.10 * u11 + math.sin(u11 * math.pi) * 0.30);
        return center11 + Offset(math.cos(a11) * r11, math.sin(a11) * r11 * (0.62 + _hash01(event, 313) * 0.18));
      case 12: // origami light sheet
        final p012 = _eventPoint(event, 320, safe, size);
        final p112 = _eventPoint(event, 321, safe, size);
        final count12 = _controlCountForMode(event, mode);
        final u12 = index / math.max(1, count12 - 1);
        final d12 = p112 - p012;
        final len12 = d12.distance == 0 ? 1.0 : d12.distance;
        final n12 = Offset(-d12.dy / len12, d12.dx / len12);
        final fold12 = size.shortestSide * (0.055 + _hash01(event, 322) * 0.15) * (_hash01(event, 323) < 0.5 ? -1.0 : 1.0);
        final zig12 = (index.isEven ? -0.45 : 0.45) * fold12 * (0.25 + 0.75 * math.sin(math.pi * u12));
        final kink12 = u12 < 0.48 ? u12 / 0.48 : (1 - u12) / 0.52;
        return Offset.lerp(p012, p112, u12)! + n12 * (fold12 * kink12 + zig12);
      case 13: // constellation chain
        final p013 = _eventPoint(event, 330, safe, size);
        final p113 = _eventPoint(event, 331, safe, size);
        final count13 = _controlCountForMode(event, mode);
        final u13 = index / math.max(1, count13 - 1);
        final d13 = p113 - p013;
        final len13 = d13.distance == 0 ? 1.0 : d13.distance;
        final n13 = Offset(-d13.dy / len13, d13.dx / len13);
        final jitter13 = (_hash01(event * 17 + index, 332) - 0.5) * size.shortestSide * (0.075 + randomness * 0.055);
        return Offset.lerp(p013, p113, u13)! + n13 * jitter13;
      case 14: // liquid pod
        final c14 = _eventPoint(event, 340, safe, size);
        final count14 = _controlCountForMode(event, mode);
        final u14 = index / math.max(1, count14 - 1);
        final base14 = _hash01(event, 341) * math.pi * 2;
        final rx14 = size.shortestSide * (0.10 + _hash01(event, 342) * 0.18);
        final ry14 = rx14 * (0.52 + _hash01(event, 343) * 0.34);
        final a14 = base14 + (u14 - 0.5) * (1.45 + _hash01(event, 344) * 1.05);
        return c14 + Offset(math.cos(a14) * rx14, math.sin(a14) * ry14);
      case 15: // V41 video wing: single-sided folded membrane
        return _videoSubjectBasePoint(event, index, mode, safe, size, eventPhase, 350, 1.00);
      case 16: // blossom crown
        final c16 = _eventPoint(event, 360, safe, size);
        final count16 = _controlCountForMode(event, mode);
        final u16 = index / math.max(1, count16 - 1);
        final base16 = _hash01(event, 361) * math.pi * 2;
        final petal16 = 3.0 + (_hash01(event, 362) * 4).floor();
        final r16 = size.shortestSide * (0.075 + _hash01(event, 363) * 0.14) * (0.66 + 0.34 * math.sin((base16 + u16 * math.pi * 1.65) * petal16));
        final a16 = base16 + u16 * math.pi * 1.65;
        return c16 + Offset(math.cos(a16) * r16, math.sin(a16) * r16 * 0.74);
      case 17: // V41 silk banner: cropped wide end, curled cusp
        return _videoSubjectBasePoint(event, index, mode, safe, size, eventPhase, 370, 1.08);
      case 18: // orbit halo
        final c18 = _eventPoint(event, 380, safe, size);
        final count18 = _controlCountForMode(event, mode);
        final u18 = index / math.max(1, count18 - 1);
        final base18 = _hash01(event, 381) * math.pi * 2;
        final sweep18 = (1.55 + _hash01(event, 382) * 1.25) * (_hash01(event, 383) < 0.5 ? -1.0 : 1.0);
        final rx18 = size.shortestSide * (0.13 + _hash01(event, 384) * 0.20);
        final ry18 = rx18 * (0.48 + _hash01(event, 385) * 0.38);
        final a18 = base18 + sweep18 * u18;
        return c18 + Offset(math.cos(a18) * rx18, math.sin(a18) * ry18);
      case 19: // V41 crystal cusp: thin curled edge
        return _videoSubjectBasePoint(event, index, mode, safe, size, eventPhase, 390, 0.82);
      default:
        return _eventPoint(event + index * 37, 333, safe, size);
    }
  }

  Offset _videoSubjectBasePoint(int event, int index, int mode, Rect safe, Size size, String eventPhase, int salt, double scale) {
    final count = _controlCountForMode(event, mode);
    final u = index / math.max(1, count - 1);
    final su = _smooth(u);
    final minDim = size.shortestSide;
    final spanBase = eventPhase == '分离'
        ? 0.30
        : eventPhase == '吸引'
            ? 0.34
            : eventPhase == '同步'
                ? 0.40
                : eventPhase == '临界'
                    ? 0.46
                    : 0.36;
    final span = minDim * (spanBase + 0.12 * _hash01(event, salt + 1)) * scale;
    final pose = (_hash01(event, salt + 2) * 7).floor();
    final jitter = (_hash01(event, salt + 3) - 0.5) * 0.50;
    late final double angle;
    if (eventPhase == '分离') {
      angle = (pose.isEven ? 0.04 : math.pi - 0.04) + jitter * 0.62;
    } else if (eventPhase == '吸引') {
      angle = (pose % 3 == 0 ? 0.22 : pose % 3 == 1 ? -0.22 : 2.70) + jitter * 0.70;
    } else if (eventPhase == '同步') {
      angle = (pose.isEven ? -0.86 : 2.28) + jitter * 0.58;
    } else if (eventPhase == '临界') {
      angle = (pose.isEven ? -1.18 : 2.04) + jitter * 0.52;
    } else {
      angle = (pose < 3 ? 0.18 : pose < 5 ? -0.92 : 2.20) + jitter;
    }
    final tangent = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-tangent.dy, tangent.dx);
    final side = _hash01(event, salt + 11) < 0.5 ? -1.0 : 1.0;
    final cx = lerpDouble(safe.left + safe.width * 0.14, safe.right - safe.width * 0.14, _hash01(event, salt + 5))!;
    final cy = lerpDouble(safe.top + safe.height * 0.18, safe.bottom - safe.height * 0.18, _hash01(event, salt + 6))!;
    var tail = Offset(cx, cy) - tangent * span * 0.56 - normal * side * span * 0.10;
    var tip = Offset(cx, cy) + tangent * span * 0.44 + normal * side * span * 0.05;
    final croppedShoulder = _hash01(event, salt + 4) < (eventPhase == '临界' ? 0.42 : 0.26);
    if (croppedShoulder) {
      final edgePad = minDim * (0.03 + 0.07 * _hash01(event, salt + 7));
      if (tangent.dx.abs() > tangent.dy.abs()) {
        tail = Offset(tangent.dx > 0 ? safe.left - edgePad : safe.right + edgePad, tail.dy);
      } else {
        tail = Offset(tail.dx, tangent.dy > 0 ? safe.top - edgePad : safe.bottom + edgePad);
      }
      tip = tail + tangent * span;
    }
    final curveAmp = minDim * (0.060 + 0.092 * _hash01(event, salt + 12)) * side * (eventPhase == '分离' ? 0.74 : eventPhase == '临界' ? 1.10 : 1.0);
    final counter = minDim * (0.018 + 0.040 * _hash01(event, salt + 13)) * -side;
    final hookAmp = minDim * (0.050 + 0.068 * _hash01(event, salt + 14)) * -side;
    final along = Offset.lerp(tail, tip, su)!;
    final mainBend = math.sin(su * math.pi) * curveAmp;
    final sBend = math.sin(su * math.pi * 2.0 + event * 0.037) * counter * (0.25 + 0.75 * math.sin(su * math.pi));
    final hook = math.pow(((su - 0.70) / 0.30).clamp(0.0, 1.0), 1.45).toDouble() * hookAmp;
    final shoulderFold = math.pow(1.0 - su, 2.35).toDouble() * curveAmp * 0.15;
    return along + normal * (mainBend + sBend + hook - shoulderFold);
  }


  Offset _eventPoint(int event, int salt, Rect safe, Size size) {
    return Offset(
      lerpDouble(safe.left, safe.right, _hash01(event, salt))!,
      lerpDouble(safe.top, safe.bottom, _hash01(event, salt + 1))!,
    );
  }

  double _hash01(int n, int salt) {
    var x = (n + seed * 1009 + salt * 9176) & 0x7fffffff;
    x = (x ^ 61) ^ (x >> 16);
    x = x + (x << 3);
    x = x ^ (x >> 4);
    x = x * 0x27d4eb2d;
    x = x ^ (x >> 15);
    return ((x & 0x7fffffff) / 0x7fffffff).clamp(0.0, 1.0).toDouble();
  }

  _PreviewPlan _previewPlan(double cycle) {
    double randBetween(double a, double b, int salt) => a + (b - a) * _hash01(seed, salt);
    final releaseRaw = randBetween(releaseMinSec, releaseMaxSec, 501) / 10.0;
    final afterRaw = randBetween(afterglowMinSec, afterglowMaxSec, 502) / 10.0;
    final criticalRaw = randBetween(criticalMinSec, criticalMaxSec, 503) / 10.0;
    final releaseDur = releaseRaw.clamp(0.8, math.max(0.9, cycle * 0.065)).toDouble();
    final afterDur = afterRaw.clamp(1.2, math.max(1.3, cycle * 0.110)).toDouble();
    final criticalDur = criticalRaw.clamp(1.8, math.max(1.9, cycle * 0.155)).toDouble();
    final latest = math.max(2.0, cycle - releaseDur - afterDur - 1.0);
    final earliest = math.min(latest, cycle * 0.32);
    final releaseStart = earliest + (latest - earliest) * _hash01(seed, 504);
    return _PreviewPlan(
      releaseStart: releaseStart,
      releaseEnd: releaseStart + releaseDur,
      afterEnd: releaseStart + releaseDur + afterDur,
      criticalStart: math.max(0.0, releaseStart - criticalDur),
    );
  }

  _Phase _phaseAt(double sec, double cycle, _PreviewPlan plan) {
    if (sec >= plan.releaseStart && sec < plan.releaseEnd) {
      return _Phase('释放', plan.releaseStart, plan.releaseEnd, 1.00, 1.00, 0.46);
    }
    if (sec >= plan.releaseEnd && sec < plan.afterEnd) {
      return _Phase('余韵', plan.releaseEnd, plan.afterEnd, 0.22, 0.54, 0.08);
    }
    if (sec >= plan.criticalStart && sec < plan.releaseStart) {
      return _Phase('临界', plan.criticalStart, plan.releaseStart, 0.98, 0.92, 1.00);
    }
    if (sec >= plan.afterEnd) {
      return _Phase('分离', plan.afterEnd, cycle, 0.06, 0.00, 0.04);
    }
    final total = math.max(0.001, ratioSeparation + ratioAttraction + ratioSync);
    final pre = math.max(0.001, plan.criticalStart);
    final sepEnd = pre * (ratioSeparation / total);
    final attrEnd = sepEnd + pre * (ratioAttraction / total);
    if (sec < sepEnd) return _Phase('分离', 0.0, sepEnd, 0.06, 0.00, 0.04);
    if (sec < attrEnd) return _Phase('吸引', sepEnd, attrEnd, 0.24, 0.16, 0.16);
    return _Phase('同步', attrEnd, plan.criticalStart, 0.58, 0.58, 0.52);
  }

  double _smooth(double x) {
    x = x.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  @override
  bool shouldRepaint(covariant _MystifyPreviewPainter oldDelegate) => true;
}

class _PreviewPlan {
  const _PreviewPlan({required this.releaseStart, required this.releaseEnd, required this.afterEnd, required this.criticalStart});
  final double releaseStart;
  final double releaseEnd;
  final double afterEnd;
  final double criticalStart;
}

class _Phase {
  const _Phase(this.name, this.start, this.end, this.intensity, this.closeness, this.tension);
  final String name;
  final double start;
  final double end;
  final double intensity;
  final double closeness;
  final double tension;
}

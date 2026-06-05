import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import '../platform/bg_guard_helper.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/emotions.dart';
import '../ai_assistant/ai_assistant_bubble.dart';
// 引入生理赋能详情页
import 'physical_enhancement_page.dart';
import '../data/dao.dart';
import '../data/sses_dao.dart';
import '../data/sses_items.dart';
import 'mood_history_detail_page.dart';
import '../utils/simple_bus.dart';
import '../services/vision_trigger_service.dart';
import '../utils/debug_logger.dart';
import 'vision_hook_history_page.dart';
import 'vision_thought_history_page.dart';
import 'vision_reflection_history_page.dart';
import '../widgets/thought_record_dialog.dart';
import '../widgets/thought_taxonomy_mindmap.dart';
// 引入心理量表测评中心页面
import 'scale_center_page.dart';
// 引入电影榜单页面
import 'movie_ranking_page.dart';
import 'space_explorer_page.dart';
import 'global_music_page.dart';
import 'change_self_help_page.dart';

/// 心情与自尊分析：集中展示当下心情、自尊分析、情绪分布与愉悦度趋势。
class MoodInsightsPage extends StatefulWidget {
  const MoodInsightsPage({super.key});

  @override
  State<MoodInsightsPage> createState() => _MoodInsightsPageState();
}

class _EsteemPoint {
  final DateTime time;
  final double score;
  const _EsteemPoint({required this.time, required this.score});
}

class _ValencePoint {
  final DateTime time;
  final double valence;
  final String? emotionName;
  const _ValencePoint({required this.time, required this.valence, this.emotionName});
}

class _EmotionLegendEntry {
  final String name;
  final double percent;
  final Color color;

  const _EmotionLegendEntry({
    required this.name,
    required this.percent,
    required this.color,
  });
}

class _MoodInsightsPageState extends State<MoodInsightsPage> with SingleTickerProviderStateMixin {
  bool _geoEnabled = false;

  Map<String, dynamic>? _latestToday;
  List<Map<String, dynamic>> _todayList = [];
  bool _loading = false;

  final _configDao = ConfigDao();
  int _overviewThreshold = 500;

  // 自尊分析相关状态
  String _esteemRangeKey = 'today'; // 时间范围：today / 7d / 30d / 3mo / 6mo / 1y
  String _esteemGranularityKey = 'record'; // record / hour / day / month
  List<Map<String, dynamic>> _esteemList = [];

  // 独立的情绪分布与愉悦度筛选，避免互相影响
  String _emotionRangeKey = 'today';
  List<Map<String, dynamic>> _emotionList = [];

  String _valenceRangeKey = 'today';
  String _valenceGranularityKey = 'record';
  List<Map<String, dynamic>> _valenceList = [];

  // 长周期数据时的渲染点数上限与视窗控制（Overview + Detail）
  static const int _maxChartPoints = 500;

  double _esteemViewStart = 0.0;
  double _esteemViewEnd = 1.0;

  double _valenceViewStart = 0.0;
  double _valenceViewEnd = 1.0;




  // 心情分享卡片相关状态（迁移自首页）
  static bool _moodCardShownThisSession = false;
  bool _moodCardVisible = false;
  bool _moodCardMounted = false;
  late final AnimationController _moodCardController;
  final TextEditingController _behaviorController = TextEditingController();
  final TextEditingController _triggerController = TextEditingController();
  final TextEditingController _thoughtController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  EmojiItem? _selectedEmotion;
  bool _showEmojiPicker = false;
  Timer? _moodCardTimer;
  bool _moodCardPopupEnabled = true;
  int _moodCardDelayMs = ConfigDao.defaultMoodCardDelayMs;

  // ====== EMA / SSES 状态 ======
  // 是否启用 EMA 自尊评估；由设置页控制
  bool _emaEnabled = false;
  // 自尊评分尺度：100 或 30（默认 100）
  int _esteemScale = 100;
  // 当前轮换到的 SSES 题目索引（0-5）。
  int _ssesIndex = 0;

  @override
  void initState() {
    super.initState();
    // 读取地点规则开关状态
    () async { final cfg = ConfigDao(); final e = await cfg.isGeoRulesEnabled(); setState((){ _geoEnabled = e; }); }();

    _moodCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _moodCardMounted = true;
    _load();
    // 加载 EMA/SSES 配置，包括是否启用、当前自尊评分尺度和轮换索引
    _loadConfig();
  }

  /// 异步加载配置：EMA 开启状态、自尊评分尺度与 SSES 轮换索引。
  Future<void> _loadConfig() async {
    try {
      final ema = await _configDao.getEmaEnabled();
      final scale = await _configDao.getSelfEsteemScale();
      final ssesIdx = await _configDao.getSsesIndex();
      final moodEnabled = await _configDao.getMoodCardPopupEnabled();
      final moodDelay = await _configDao.getMoodCardPopupDelayMs();
      if (!mounted) return;
      setState(() {
        _emaEnabled = ema;
        _esteemScale = scale;
        _ssesIndex = ssesIdx % 6;
        _moodCardPopupEnabled = moodEnabled;
        _moodCardDelayMs = moodDelay;
      });
    } catch (_) {
      // ignore
    }
  }

  /// 根据 100 分制的自尊值转换为当前配置的分制（100 或 30）。
  double _convertScore(double score100) {
    if (_esteemScale == 30) {
      // 映射 0~100 到 0~30，保持线性比例
      final v = (score100 / 100.0) * 30.0;
      // 四舍五入到一位小数以避免太多小数
      return double.parse(v.toStringAsFixed(1));
    }
    // 默认返回原值（0~100）
    return score100;
  }

  /// 弹出 SSES 问卷题目，让用户在 1~7 的量表上作答，或者选择跳过。
  Future<void> _askSsesQuestion() async {
    // 仅当开启 EMA 时才提示
    if (!_emaEnabled) return;
    // 题库不足 1 条直接返回
    if (ssesItems.isEmpty) return;
    final currentIndex = _ssesIndex % ssesItems.length;
    final item = ssesItems[currentIndex];

    // 弹出对话框收集评分
    final int? selected = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('自尊问答'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.text),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List<Widget>.generate(7, (index) {
                  final score = index + 1;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(score);
                    },
                    child: Text('$score'),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                child: const Text('跳过'),
              ),
            ],
          ),
        );
      },
    );

    // 无论是否回答，都将索引推进到下一题目
    final nextIndex = (currentIndex + 1) % ssesItems.length;
    _ssesIndex = nextIndex;
    await _configDao.setSsesIndex(nextIndex);

    // 如果用户选择了具体分数，则保存到数据库
    if (selected != null) {
      try {
        final dao = SsesDao();
        await dao.insert(itemId: item.id, dimension: item.dimension, score: selected);
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final dao = EmotionDao();
      _overviewThreshold = await _configDao.getOverviewThreshold();
      final latest = await dao.latestToday();
      final list = await dao.listTodayOrdered();

      // 默认用“今天 + 单次记录粒度”作为自尊分析的初始数据
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final esteemRows = await dao.listByRange(start, now);

      if (!mounted) return;
      setState(() {
        _latestToday = latest;
        _todayList = list;
        _esteemList = esteemRows;
          _emotionList = esteemRows;
          _valenceList = esteemRows;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 根据当前选择的时间范围重新加载自尊分析数据
  Future<void> _reloadEsteemByFilter() async {
    final dao = EmotionDao();
    final now = DateTime.now();
    DateTime start;
    switch (_esteemRangeKey) {
      case '7d':
        start = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        // 当月：从本月第一天开始
        start = DateTime(now.year, now.month, 1);
        break;
      case '3mo':
        start = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6mo':
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1y':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      case '3y':
        start = DateTime(now.year - 3, now.month, now.day);
        break;
      case '5y':
        start = DateTime(now.year - 5, now.month, now.day);
        break;
      case '10y':
        start = DateTime(now.year - 10, now.month, now.day);
        break;
      case 'all':
        start = DateTime(1970, 1, 1);
        break;
      case 'today':
      default:
        start = DateTime(now.year, now.month, now.day);
        break;
    }

    final rows = await dao.listByRange(start, now);
    if (!mounted) return;
    setState(() {
      _esteemList = rows;
    });
  }

  /// 根据当前选择的时间范围重新加载愉悦度趋势数据（独立于自尊）
  Future<void> _reloadValenceByFilter() async {
    final dao = EmotionDao();
    final now = DateTime.now();
    DateTime start;
    switch (_valenceRangeKey) {
      case '7d':
        start = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        // 当月：从本月第一天开始
        start = DateTime(now.year, now.month, 1);
        break;
      case '3mo':
        case '3m':
        start = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6mo':
        case '6m':
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1y':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      case '3y':
        start = DateTime(now.year - 3, now.month, now.day);
        break;
      case '5y':
        start = DateTime(now.year - 5, now.month, now.day);
        break;
      case '10y':
        start = DateTime(now.year - 10, now.month, now.day);
        break;
      case 'all':
        start = DateTime(1970, 1, 1);
        break;
      case 'today':
      default:
        start = DateTime(now.year, now.month, now.day);
        break;
    }

    final rows = await dao.listByRange(start, now);
    if (!mounted) return;
    setState(() {
      _valenceList = rows;
    });
  }

  /// 根据当前选择的时间范围重新加载情绪分布数据（独立于自尊）
  Future<void> _reloadEmotionByFilter() async {
    final dao = EmotionDao();
    final now = DateTime.now();
    DateTime start;
    switch (_emotionRangeKey) {
      case '7d':
        start = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        // 当月：从本月第一天开始
        start = DateTime(now.year, now.month, 1);
        break;
      case '3mo':
        case '3m':
        start = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6mo':
        case '6m':
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1y':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      case '3y':
        start = DateTime(now.year - 3, now.month, now.day);
        break;
      case '5y':
        start = DateTime(now.year - 5, now.month, now.day);
        break;
      case '10y':
        start = DateTime(now.year - 10, now.month, now.day);
        break;
      case 'all':
        start = DateTime(1970, 1, 1);
        break;
      case 'today':
      default:
        start = DateTime(now.year, now.month, now.day);
        break;
    }

    final rows = await dao.listByRange(start, now);
    if (!mounted) return;
    setState(() {
      _emotionList = rows;
    });
  }





  List<double> _rawEsteemScores() {
    if (_esteemList.isEmpty) return const <double>[];
    return _esteemList.map<double>((row) {
      final name = (row['emoji_name'] ?? '').toString();
      // 先计算 0~100 的自尊得分，然后映射到当前分制
      final double s100 = estimateSelfEsteemScore(name);
      return _convertScore(s100);
    }).toList();
  }

  Map<String, List<int>> _computeEsteemStats(List<double> scores) {
    // 统计每一个“整数自尊值”在当前时间范围内出现的频率，
    // 然后按照占比区间划分到 50% / 60% / 70% / 80% / 90% 档位。
    final Map<String, List<int>> result = <String, List<int>>{
      '50': <int>[],
      '60': <int>[],
      '70': <int>[],
      '80': <int>[],
      '90': <int>[],
    };

    if (scores.isEmpty) {
      return result;
    }

    // 先统计每一个整数自尊得分出现的次数，范围依据当前分制
    final Map<int, int> countByScore = <int, int>{};
    final int maxScale = _esteemScale;
    for (final s in scores) {
      final int v = s.round();
      if (v < 0 || v > maxScale) continue;
      countByScore[v] = (countByScore[v] ?? 0) + 1;
    }

    final int total = scores.length;
    if (total == 0) {
      return result;
    }

    // 将每个分数按照它在全部记录中所占的百分比分配到对应档位
    countByScore.forEach((int score, int count) {
      final double p = (count * 100.0) / total;

      // 小于 50% 的自尊水平不统计
      if (p < 50.0) {
        return;
      } else if (p >= 50.0 && p < 60.0) {
        result['50']!.add(score);
      } else if (p >= 60.0 && p < 70.0) {
        result['60']!.add(score);
      } else if (p >= 70.0 && p < 80.0) {
        result['70']!.add(score);
      } else if (p >= 80.0 && p < 90.0) {
        result['80']!.add(score);
      } else if (p >= 90.0 && p <= 100.0) {
        // 大于等于 90% 且小于等于 100%
        result['90']!.add(score);
      }
    });

    // 为了展示稳定一些，对每个档位里的自尊分数做一次排序。
    for (final key in result.keys) {
      result[key]!.sort();
    }

    return result;
  }

  
  Map<String, double> _computeBasicEsteemStats(List<double> scores) {
    if (scores.isEmpty) {
      return <String, double>{
        'min': double.nan,
        'max': double.nan,
        'avg': double.nan,
        'mid': double.nan,
      };
    }

    // 将自尊得分统一映射为 0~100 的整数，并排序，便于统计最小值 / 最大值 / 中间值 / 平均值。
    // 根据当前分制将得分映射到整数并裁剪到范围 [0, maxScale]
    final int maxScale = _esteemScale;
    final List<int> intScores = scores
        .map((s) {
          int v = s.round();
          if (v < 0) v = 0;
          if (v > maxScale) v = maxScale;
          return v;
        })
        .toList()
      ..sort();

    final int minScore = intScores.first;
    final int maxScore = intScores.last;

    final int sum = intScores.fold<int>(0, (a, b) => a + b);
    final double avgScore = sum / intScores.length;

    double midScore;
    if (intScores.length.isOdd) {
      midScore = intScores[intScores.length ~/ 2].toDouble();
    } else {
      final int left = intScores[intScores.length ~/ 2 - 1];
      final int right = intScores[intScores.length ~/ 2];
      midScore = (left + right) / 2.0;
    }

    return <String, double>{
      'min': minScore.toDouble(),
      'max': maxScore.toDouble(),
      'avg': avgScore,
      'mid': midScore,
    };
  }


  static const int _discoverTabIndex = -1;

  void _onNavIndexChanged() {
    try {
      final idx = SimpleBus.navIndex.value;
      if (idx == _discoverTabIndex) {
        _scheduleMoodCard();
      } else {
        _cancelMoodCardTimer();
        if (_moodCardVisible) {
          _hideMoodCard();
        }
      }
    } catch (_) {}
  }

  Future<void> _scheduleMoodCard() async {
    if (_moodCardShownThisSession) return;
    _moodCardTimer?.cancel();

    try {
      final enabled = await _configDao.getMoodCardPopupEnabled();
      final delayMs = await _configDao.getMoodCardPopupDelayMs();
      if (!mounted) return;
      _moodCardPopupEnabled = enabled;
      _moodCardDelayMs = delayMs;
      if (!enabled) return;
      if (SimpleBus.navIndex.value != _discoverTabIndex) return;
    } catch (_) {
      if (!mounted) return;
    }

    _moodCardTimer = Timer(Duration(milliseconds: _moodCardDelayMs), () {
      if (!mounted || !_moodCardPopupEnabled) return;
      try {
        final idx = SimpleBus.navIndex.value;
        if (idx != _discoverTabIndex) return;
      } catch (_) {
        return;
      }
      _moodCardShownThisSession = true;
      _showMoodCard();
    });
  }

  void _cancelMoodCardTimer() {
    _moodCardTimer?.cancel();
    _moodCardTimer = null;
  }

  void _showMoodCard() {
    if (_moodCardVisible || !_moodCardMounted) {
      if (!_moodCardMounted) {
        setState(() {
          _moodCardMounted = true;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _moodCardController.forward(from: 0);
          setState(() {
            _moodCardVisible = true;
          });
        } catch (_) {}
      });
    } else {
      try {
        _moodCardController.forward(from: 0);
      } catch (_) {}
      setState(() {
        _moodCardVisible = true;
      });
    }
  }

  Future<void> _hideMoodCard() async {
    try {
      await _moodCardController.reverse();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _moodCardVisible = false;
      _showEmojiPicker = false;
    });
  }

  Future<void> _onShareMood() async {
    final emoji = _selectedEmotion;
    if (emoji == null) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择情绪状态')),
        );
      } catch (_) {}
      return;
    }
    String limit500(String s) => s.length > 500 ? s.substring(0, 500) : s;
    final behavior = limit500(_behaviorController.text.trim());
    final trigger = limit500(_triggerController.text.trim());
    final thought = limit500(_thoughtController.text.trim());
    final type = limit500(_typeController.text.trim());
    try {
      await EmotionDao().insert(
        emojiChar: emoji.char,
        emojiName: emoji.name,
        emojiTags: emoji.tags,
        behavior: behavior,
        triggerEvent: trigger,
        thought: thought,
        type: type,
      );
    } catch (_) {}
    await _hideMoodCard();
    _behaviorController.clear();
    _triggerController.clear();
    _thoughtController.clear();
    _typeController.clear();
    setState(() {
      _selectedEmotion = null;
    });

    // 记录心情后，如果启用了 EMA/SSES，则弹出自尊题目
    try {
      await _askSsesQuestion();
    } catch (_) {}
  }

  Widget _buildMoodCardOverlay() {
    if (!_moodCardMounted) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_moodCardVisible,
        child: AnimatedBuilder(
          animation: _moodCardController,
          builder: (context, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _moodCardController,
                curve: Curves.easeOutBack, // smoother springy entrance
                reverseCurve: Curves.easeInCubic,
              ),
            );
            final fade = CurvedAnimation(
              parent: _moodCardController,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            );
            // 当卡片标记为不可见且动画回到起点时，整个遮罩层也不再渲染，避免顶部残留边框
            final bool fullyHidden = !_moodCardVisible &&
                !_showEmojiPicker &&
                (_moodCardController.value <= 0.0);
            if (fullyHidden) {
              return const SizedBox.shrink();
            }
            return Stack(

              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _hideMoodCard,
                  child: Container(color: Colors.transparent),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: SlideTransition(
                    position: slide,
                    child: FadeTransition(
                      opacity: fade,
                      child: Padding(
                      padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
                      child: _buildMoodCard(),
                    ),
                  ),
                  ),
                ),
                if (_showEmojiPicker)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                      child: _buildEmojiPicker(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMoodCard() {
    final emoji = _selectedEmotion;
    final String emojiSummary = emoji == null
        ? ''
        : '${emoji.char}  ${emoji.name}  ${emoji.tags.join(' ')}';
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_showEmojiPicker) {
              setState(() {
                _showEmojiPicker = false;
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '分享此时此刻的心情',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                    onPressed: _hideMoodCard,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmojiPicker = true;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('情绪'),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.black54, width: 1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: Text(
                                  emojiSummary,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.expand_more, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildTextRow(
                label: '行为',
                controller: _behaviorController,
                hint: '例如：我选择了拖延、争吵或积极面对...',
              ),
              const SizedBox(height: 8),
              _buildTextRow(
                label: '事件',
                controller: _triggerController,
                hint: '例如：上司的批评、工作任务堆积、人际冲突...',
              ),
              const SizedBox(height: 8),
              _buildTextRow(
                label: '信念',
                controller: _thoughtController,
                hint: '例如：我认为自己不够好、别人都在否定我...（这是你的“信念”）',
              ),
              const SizedBox(height: 8),
              _buildTextRow(
                label: '类型',
                controller: _typeController,
                hint: '例如：可能来自生活、工作、他人、自我...',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onShareMood,
                  child: const Text('分享'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextRow({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: TextField(
              controller: controller,
              maxLines: null,
              maxLength: 500,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                border: const UnderlineInputBorder(),
                hintText: hint,
                filled: false,
                fillColor: null,
                hintStyle: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    // 构建所有可供选择的情绪项：遍历 kEmotionSelfEsteemMeta 的键，
    // 若在 unicornEmotions 中找到相同名称或包含该名称的标签，则复用其表情符号；
    // 否则根据 valence 值选择一个简单的默认 emoji。
    List<EmojiItem> pickerItems() {
      final List<EmojiItem> items = [];
      for (final name in kEmotionSelfEsteemMeta.keys) {
        EmojiItem? match;
        // 先尝试精确匹配名称
        for (final e in unicornEmotions) {
          if (e.name == name) {
            match = e;
            break;
          }
        }
        // 再根据 tags 查找包含该名称的条目
        match ??= unicornEmotions.cast<EmojiItem?>().firstWhere(
          (e) => e != null && e.tags.contains(name),
          orElse: () => null,
        );
        // 根据匹配结果决定使用的字符
        String char;
        if (match != null) {
          char = match.char;
        } else {
          // 根据 valence 选择简单的默认表情：正向🙂，负向🙁，中性😐
          final meta = kEmotionSelfEsteemMeta[name];
          if (meta != null) {
            if (meta.valence > 0) {
              char = '🙂';
            } else if (meta.valence < 0) {
              char = '🙁';
            } else {
              char = '😐';
            }
          } else {
            char = '😐';
          }
        }
        items.add(EmojiItem(char: char, name: name, tags: [name]));
      }
      // 按名称排序，使显示顺序稳定
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    }

    final items = pickerItems();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: 230,
          child: GridView.count(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            crossAxisCount: 6,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            childAspectRatio: 0.9,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final item in items)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedEmotion = item;
                      _showEmojiPicker = false;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.char,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

DateTime? _parseInsertedAt(String? insertedAt) {
    if (insertedAt == null || insertedAt.isEmpty) return null;
    try {
      return DateTime.parse(insertedAt);
    } catch (_) {
      return null;
    }
  }


  // 视窗截取：根据当前 viewStart/viewEnd 取区间内的点
  List<T> _applyViewport<T>(List<T> points, double startFrac, double endFrac) {
    if (points.isEmpty) return points;
    final startIdx = (points.length * startFrac).floor().clamp(0, points.length - 1);
    final endIdx = (points.length * endFrac).ceil().clamp(startIdx + 1, points.length);
    return points.sublist(startIdx, endIdx);
  }

  // 下采样：当点数过多时按桶平均聚合，保证趋势可视且不卡顿
  List<_EsteemPoint> _downsampleEsteemPoints(List<_EsteemPoint> points) {
    if (points.length <= _maxChartPoints) return points;
    final bucketSize = (points.length / _maxChartPoints).ceil();
    final List<_EsteemPoint> result = [];
    for (int i = 0; i < points.length; i += bucketSize) {
      final end = math.min(i + bucketSize, points.length);
      final chunk = points.sublist(i, end);
      if (chunk.isEmpty) continue;
      final avg = chunk.map((e) => e.score).reduce((a, b) => a + b) / chunk.length;
      final midTime = chunk[chunk.length ~/ 2].time;
      result.add(_EsteemPoint(time: midTime, score: avg));
    }
    return result;
  }

  List<_ValencePoint> _downsampleValencePoints(List<_ValencePoint> points) {
    if (points.length <= _maxChartPoints) return points;
    final bucketSize = (points.length / _maxChartPoints).ceil();
    final List<_ValencePoint> result = [];
    for (int i = 0; i < points.length; i += bucketSize) {
      final end = math.min(i + bucketSize, points.length);
      final chunk = points.sublist(i, end);
      if (chunk.isEmpty) continue;
      final avg = chunk.map((e) => e.valence).reduce((a, b) => a + b) / chunk.length;
      final mid = chunk.length ~/ 2;
      result.add(_ValencePoint(
        time: chunk[mid].time,
        valence: avg,
        emotionName: chunk[mid].emotionName,
      ));
    }
    return result;
  }

  // mini overview 图：带可拖动的视窗选择
    // mini overview 图：带可拖动的视窗选择
  Widget _buildOverviewSelector({
    required List<FlSpot> allSpots,
    required List<DateTime> allTimes,
    required double viewStart,
    required double viewEnd,
    required ValueChanged<double> onStartChanged,
    required bool isValence,
  }) {
    if (allSpots.length < 2) return const SizedBox.shrink();
    final window = (viewEnd - viewStart).clamp(0.05, 1.0);

    // 固定范围 & 基准
    final fixedMinY = isValence ? -2.0 : 0.0;
    final fixedMaxY = isValence ? 2.0 : 100.0;
    final baselineY = isValence ? 0.0 : 50.0;

    // 均值（总览用全量）
    final meanY = allSpots.map((e) => e.y).reduce((a, b) => a + b) / allSpots.length;

    // 均值显示在纵轴的“槽位”
    final meanSlotY = isValence
        ? meanY.roundToDouble().clamp(fixedMinY, fixedMaxY)
        : ((meanY / 10).round() * 10.0).clamp(fixedMinY, fixedMaxY);

    bool _isFixedTick(double v) {
      if (isValence) {
        return (v - 2).abs() < 1e-3 || v.abs() < 1e-3 || (v + 2).abs() < 1e-3;
      } else {
        return (v - 100).abs() < 1e-3 || (v - 50).abs() < 1e-3 || v.abs() < 1e-3;
      }
    }

    String _fmtBottom(DateTime t) {
      final yyyy = t.year.toString().padLeft(4, '0');
      final mm = t.month.toString().padLeft(2, '0');
      final dd = t.day.toString().padLeft(2, '0');
      final hh = t.hour.toString().padLeft(2, '0');
      final mi = t.minute.toString().padLeft(2, '0');
      return '$hh:$mi\n$yyyy-$mm-$dd';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // 纵轴宽度根据最大数值长度动态计算，避免数值换行显示（如 100 被挤成 10/0 两行）。
        final maxLabelLen = <String>[
          fixedMinY.toStringAsFixed(isValence ? 1 : 0),
          fixedMaxY.toStringAsFixed(isValence ? 1 : 0),
          meanY.toStringAsFixed(isValence ? 1 : 0),
        ].map((s) => s.length).reduce((a, b) => a > b ? a : b);
        final double leftPad = (maxLabelLen * 7.0 + 10).clamp(22.0, 48.0); // px

        final wPlot = (w - leftPad).clamp(1.0, w);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10), // 4) 上下外边距
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              final fracDelta = d.delta.dx / wPlot;
              final newStart = (viewStart + fracDelta).clamp(0.0, 1.0 - window);
              onStartChanged(newStart);
            },
            onTapDown: (d) {
              final tapFrac = ((d.localPosition.dx - leftPad) / wPlot).clamp(0.0, 1.0);
              final newStart = (tapFrac - window / 2).clamp(0.0, 1.0 - window);
              onStartChanged(newStart);
            },
            child: Column(
              children: [
                SizedBox(
                  height: 136, // 7) 总览图加高 40dp
                  child: Padding(
                    padding: EdgeInsets.only(left: leftPad),
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(enabled: false),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: true),

                        minY: fixedMinY,
                        maxY: fixedMaxY,

                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: leftPad,
                              interval: isValence ? 1 : 10,
                              getTitlesWidget: (value, meta) {
                                final isMeanSlot = (value - meanSlotY).abs() < 1e-3;
                                final isFixed = _isFixedTick(value);
                                if (!isFixed && !isMeanSlot) return const SizedBox.shrink();

                                final text = isMeanSlot
                                    ? meanY.toStringAsFixed(isValence ? 1 : 0)
                                    : value.toStringAsFixed(0);
                                final color = isMeanSlot ? Colors.green : Colors.black54;

                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 0,
                                  child: Text(
                                    text,
                                    style: TextStyle(fontSize: 10, color: color),
                                    textAlign: TextAlign.right,
                                    softWrap: false,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),

                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: baselineY,
                              color: Colors.amber,
                              strokeWidth: 2.0,
                            ),
                            HorizontalLine(
                              y: meanSlotY,
                              color: Colors.green,
                              strokeWidth: 2.0,
                            ),
                          ],
                        ),

                        minX: 0,
                        maxX: (allSpots.length - 1).toDouble(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: allSpots,
                            isCurved: true,
                            barWidth: 1.5,
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 1) start / mid / end
                if (allTimes.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: leftPad, top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtBottom(allTimes.first),
                            style: const TextStyle(fontSize: 8, color: Colors.black54),
                            textAlign: TextAlign.center),
                        Text(_fmtBottom(allTimes[allTimes.length ~/ 2]),
                            style: const TextStyle(fontSize: 8, color: Colors.black54),
                            textAlign: TextAlign.center),
                        Text(_fmtBottom(allTimes.last),
                            style: const TextStyle(fontSize: 8, color: Colors.black54),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                SizedBox(
                  height: 14,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(color: Colors.black.withOpacity(0.06)),
                      ),
                      Positioned(
                        left: leftPad + wPlot * viewStart,
                        width: wPlot * window,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.06),
                            border: Border.all(color: Colors.black26, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  /// 根据当前选择的粒度构建自尊曲线数据点。
  List<_EsteemPoint> _buildEsteemPoints() {
    if (_esteemList.isEmpty) return const <_EsteemPoint>[];

    // 逐条记录：直接按照每条记录的情绪计算自尊指数
    if (_esteemGranularityKey == 'record') {
      final List<_EsteemPoint> points = [];
      for (final row in _esteemList) {
        final dt = _parseInsertedAt(row['inserted_at']?.toString()) ?? DateTime.now();
        final name = (row['emoji_name'] ?? '').toString();
        // 单条记录自尊：先算 0~100 再转换
        final double s100 = estimateSelfEsteemScore(name);
        final double score = _convertScore(s100);
        points.add(_EsteemPoint(time: dt, score: score));
      }
      points.sort((a, b) => a.time.compareTo(b.time));
      return points;
    }

    // 按小时 / 按天聚合：在时间窗内收集所有情绪名称，用 computeSelfEsteemIndexFromEmotions 算出该时间窗的自尊指数
    final Map<String, List<String>> bucketNames = {};
    final Map<String, DateTime> bucketTime = {};

    for (final row in _esteemList) {
      final dt = _parseInsertedAt(row['inserted_at']?.toString());
      if (dt == null) continue;

      DateTime bucket;
      if (_esteemGranularityKey == 'day') {
        bucket = DateTime(dt.year, dt.month, dt.day);
      } else if (_esteemGranularityKey == 'month') {
        bucket = DateTime(dt.year, dt.month);
      } else {
        bucket = DateTime(dt.year, dt.month, dt.day, dt.hour);
      }
      final key = bucket.toIso8601String();
      final name = (row['emoji_name'] ?? '').toString();
      if (name.isEmpty) continue;

      bucketNames.putIfAbsent(key, () => <String>[]).add(name);
      bucketTime[key] = bucket;
    }

    final keys = bucketNames.keys.toList()
      ..sort((a, b) => bucketTime[a]!.compareTo(bucketTime[b]!));

    final List<_EsteemPoint> points = [];
    for (final key in keys) {
      final names = bucketNames[key]!;
      if (names.isEmpty) continue;
      // 聚合计算：先得到 0~100 自尊得分，再映射
      final double s100 = computeSelfEsteemIndexFromEmotions(names);
      final double score = _convertScore(s100);
      points.add(_EsteemPoint(time: bucketTime[key]!, score: score));
    }

    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  String _formatTime(String? insertedAt) {
    if (insertedAt == null || insertedAt.isEmpty) return '';
    // 期望格式：YYYY-MM-DD HH:mm:ss
    final parts = insertedAt.split(' ');
    if (parts.length < 2) return insertedAt;
    return parts[1];
  }

  List<List<Map<String, dynamic>>> _chunkEmotions(List<Map<String, dynamic>> src, int size) {
    if (src.isEmpty) return <List<Map<String, dynamic>>>[];
    final List<List<Map<String, dynamic>>> rows = [];
    for (var i = 0; i < src.length; i += size) {
      final end = (i + size < src.length) ? i + size : src.length;
      rows.add(src.sublist(i, end));
    }
    return rows;
  }

  Widget _buildTimelineRow(List<Map<String, dynamic>> rowItems) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 时间轴横线 + 表情在上方
          SizedBox(
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 1,
                      color: Colors.black26,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final item in rowItems)
                      GestureDetector(
                        onTap: () => _showEmotionDetailCard(item),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                (item['emoji_char'] ?? '').toString(),
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 时间显示在横线下方
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final item in rowItems)
                Text(
                  _formatTime(item['inserted_at']?.toString()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Text(
        '今天还没有记录心情，回到首页试试分享你的此时此刻吧～',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      );
    }
    final rows = _chunkEmotions(items, 4);
    // 计算是否需要垂直滚动：超过 3 行时开启
    final bool needScroll = rows.length > 3;

    final timelineColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows) _buildTimelineRow(r),
      ],
    );

    if (!needScroll) {
      return timelineColumn;
    } else {
      return SizedBox(
        // 每行高度约 56 左右，3 行 + 边距
        height: 56.0 * 3,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: timelineColumn,
        ),
      );
    }
  }
  /// 显示某条心情记录的详情卡片（事件、信念、行为、类型、时间在同一行展示）。
  void _showEmotionDetailCard(Map<String, dynamic> item) {
    final String behavior = (item['behavior'] ?? '').toString();
    final String event = (item['trigger_event'] ?? '').toString();
    final String thought = (item['thought'] ?? '').toString(); // 信念
    final String type = (item['type'] ?? '').toString();
    final String time = _formatTime(item['inserted_at']?.toString());
    final String line = '事件：' + event + '    信念：' + thought + '    行为：' + behavior + '    类型：' + type + '    时间：' + time;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 14),
                  softWrap: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }




  
    Widget _buildEsteemFilterBar() {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            value: _esteemRangeKey,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'today', child: Text('今天')),
              DropdownMenuItem(value: '7d', child: Text('近7天')),
              DropdownMenuItem(value: '30d', child: Text('当月')),
              DropdownMenuItem(value: '3mo', child: Text('近3个月')),
              DropdownMenuItem(value: '6mo', child: Text('近半年')),
              DropdownMenuItem(value: '1y', child: Text('近一年')),
              DropdownMenuItem(value: '3y', child: Text('近3年')),
              DropdownMenuItem(value: '5y', child: Text('近5年')),
              DropdownMenuItem(value: '10y', child: Text('近10年')),
              DropdownMenuItem(value: 'all', child: Text('全部')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _esteemRangeKey = value;
                // 当范围过短时不支持按月粒度，自动回退
                if ((_esteemRangeKey == 'today' || _esteemRangeKey == '7d') && _esteemGranularityKey == 'month') {
                  _esteemGranularityKey = _esteemRangeKey == 'today' ? 'hour' : 'day';
                }
                _esteemViewStart = 0.0;
                _esteemViewEnd = 1.0;
              });
              _reloadEsteemByFilter();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<String>(
            value: _esteemGranularityKey,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: 'record', child: Text('逐条记录')),
              const DropdownMenuItem(value: 'hour', child: Text('按小时')),
              const DropdownMenuItem(value: 'day', child: Text('按天')),
              if (!(_esteemRangeKey == 'today' || _esteemRangeKey == '7d'))
                const DropdownMenuItem(value: 'month', child: Text('按月')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _esteemGranularityKey = value;
                _esteemViewStart = 0.0;
                _esteemViewEnd = 1.0;
              });
              _reloadEsteemByFilter();
            },
          ),
        ),
      ],
    );
  }


  
  /// 根据当前选择的粒度构建愉悦度(valence)曲线数据点。
  List<_ValencePoint> _buildValencePoints() {
    if (_valenceList.isEmpty) return const <_ValencePoint>[];

    if (_valenceGranularityKey == 'record') {
      final List<_ValencePoint> points = [];
      // 在逐条粒度下直接使用 _valenceList，而非 _emotionList
      for (final row in _valenceList) {
        final dt = _parseInsertedAt(row['inserted_at']?.toString()) ?? DateTime.now();
        final name = (row['emoji_name'] ?? '').toString();
        final v = estimateValenceScore(name);
        points.add(_ValencePoint(time: dt, valence: v, emotionName: name));
      }
      points.sort((a, b) => a.time.compareTo(b.time));
      return points;
    }

    final Map<String, List<double>> bucketVals = {};
    final Map<String, DateTime> bucketTime = {};

    for (final row in _valenceList) {
      final dt = _parseInsertedAt(row['inserted_at']?.toString()) ?? DateTime.now();
      DateTime bucket;
      if (_valenceGranularityKey == 'day') {
        bucket = DateTime(dt.year, dt.month, dt.day);
      } else if (_valenceGranularityKey == 'month') {
        bucket = DateTime(dt.year, dt.month);
      } else {
        bucket = DateTime(dt.year, dt.month, dt.day, dt.hour);
      }
      final key = bucket.toIso8601String();
      final name = (row['emoji_name'] ?? '').toString();
      if (name.isEmpty) continue;
      final v = estimateValenceScore(name);
      bucketVals.putIfAbsent(key, () => <double>[]).add(v);
      bucketTime[key] = bucket;
    }

    final keys = bucketVals.keys.toList()
      ..sort((a, b) => bucketTime[a]!.compareTo(bucketTime[b]!));

    final List<_ValencePoint> points = [];
    for (final key in keys) {
      final vals = bucketVals[key]!;
      final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
      points.add(_ValencePoint(time: bucketTime[key]!, valence: avg));
    }
    return points;
  }

    Widget _buildEsteemLineChart({List<_EsteemPoint>? allPointsOverride}) {
    final allPoints = allPointsOverride ?? _buildEsteemPoints();
    if (allPoints.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '当前时间范围内还没有情绪记录',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }
    final windowed = _applyViewport(allPoints, _esteemViewStart, _esteemViewEnd);
    final points = _downsampleEsteemPoints(windowed);

    // 当前视窗的均值（用于参考线）
    final double meanScore = windowed.isEmpty
        ? 50.0
        : windowed.map((e) => e.score).reduce((a, b) => a + b) / windowed.length;

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].score));
    }

    // 固定纵轴范围与刻度，根据当前自尊分制动态调整
    const double yMin = 0;
    final double yMax = _esteemScale.toDouble();
    final double yInterval = (_esteemScale == 30) ? 5.0 : 10.0;

    // 均值显示槽位：按刻度 round 取整
    final double meanLabelY = ((meanScore / yInterval).round() * yInterval).clamp(yMin, yMax);

    String formatBottomLabel(int index) {
      if (index < 0 || index >= points.length) return '';
      final t = points[index].time;
      final yyyy = t.year.toString().padLeft(4, '0');
      final mm = t.month.toString().padLeft(2, '0');
      final dd = t.day.toString().padLeft(2, '0');
      final hh = t.hour.toString().padLeft(2, '0');
      final mi = t.minute.toString().padLeft(2, '0');
      return '$hh:$mi\n$yyyy-$mm-$dd'; // 5) 两行显示：时分 + 年月日
    }

    // 2/4/10) 大图加高+上下外边距+轴间距更紧凑
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minY: yMin,
            maxY: yMax,
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            lineTouchData: LineTouchData(enabled: false),
            gridData: FlGridData(
              show: true,
              horizontalInterval: yInterval,
              verticalInterval: 1,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: Colors.black12, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: true),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                axisNameWidget: const Text('自尊值', style: TextStyle(fontSize: 11)),
                axisNameSize: 28,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: yInterval,
                  getTitlesWidget: (value, meta) {
                    final int v = value.toInt();
                    // 仅显示刻度间隔的整数倍
                    final int intervalInt = yInterval.toInt();
                    if (intervalInt <= 0) return const SizedBox.shrink();
                    if (v % intervalInt != 0) return const SizedBox.shrink();

                    final bool isMeanSlot = (value - meanLabelY).abs() < 1e-3;
                    final String text = isMeanSlot
                        ? meanScore.toStringAsFixed(0)
                        : v.toString();
                    final Color color = isMeanSlot ? Colors.green : Colors.black54;

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(text, style: TextStyle(fontSize: 10, color: color), softWrap: false, maxLines: 1, overflow: TextOverflow.visible),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: math.max(1, (points.length / 4).ceilToDouble()), // 6) 防重叠
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    final label = formatBottomLabel(index);
                    if (label.isEmpty) return const SizedBox.shrink();

                    // 8/6) 前后双向去重
                    if (index > 0 && label == formatBottomLabel(index - 1)) {
                      return const SizedBox.shrink();
                    }
                    if (index < points.length - 1 && label == formatBottomLabel(index + 1)) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: (_esteemScale == 30) ? 16.0 : 50.0,
                  color: Colors.amber, // 基准线黄
                  strokeWidth: 3.0,
                ),
                HorizontalLine(
                  y: meanLabelY,
                  color: Colors.green, // 均值线绿
                  strokeWidth: 3.0,
                ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                color: Colors.lightBlue,
                dotData: FlDotData(
                  show: spots.length <= _overviewThreshold,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(radius: 3, color: Colors.lightBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEsteemChartSection() {
    final allPoints = _buildEsteemPoints();
    // 复用原有空态展示
    if (allPoints.isEmpty) {
      return _buildEsteemLineChart(allPointsOverride: allPoints);
    }

    // 数据点很多时，默认聚焦到最近的一个窗口（便于拖拽预览）
    if (allPoints.length > _maxChartPoints &&
        _esteemViewStart == 0.0 &&
        _esteemViewEnd == 1.0) {
      final frac = (_maxChartPoints / allPoints.length).clamp(0.05, 1.0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _esteemViewStart = (1.0 - frac).clamp(0.0, 1.0 - frac);
          _esteemViewEnd = 1.0;
        });
      });
    }
    final allSpots = <FlSpot>[];
    for (var i = 0; i < allPoints.length; i++) {
      allSpots.add(FlSpot(i.toDouble(), allPoints[i].score));
    }

    final window = (_esteemViewEnd - _esteemViewStart).clamp(0.05, 1.0);

    return Column(
      children: [
        _buildEsteemLineChart(allPointsOverride: allPoints),
        if (_esteemList.length > _overviewThreshold) ...[
          const SizedBox(height: 8),
          _buildOverviewSelector(
            allSpots: allSpots,
            allTimes: allPoints.map((e) => e.time).toList(),
            isValence: false,
            viewStart: _esteemViewStart,
            viewEnd: _esteemViewEnd,
            onStartChanged: (s) {

              setState(() {
                _esteemViewStart = s;
                _esteemViewEnd = (s + window).clamp(0.05, 1.0);
              });
                        },
          ),
        ],
      ],
    );
  }


  Widget _buildEsteemStatsView() {
    final scores = _rawEsteemScores();
    if (_esteemList.isEmpty || scores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '当前时间范围内还没有足够的数据用于统计',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    // 使用新的频率分档统计：50% / 60% / 70% / 80% / 90%
    final Map<String, List<int>> buckets = _computeEsteemStats(scores);
    // 基础统计：最小值 / 中间值 / 最大值 / 平均值
    final Map<String, double> basic = _computeBasicEsteemStats(scores);

    String joinBucketValues(String key) {
      final values = buckets[key] ?? <int>[];
      if (values.isEmpty) {
        return '--';
      }
      final sorted = List<int>.from(values)..sort();
      return sorted.join('，');
    }

    String fmtDouble(double? v, int fractionDigits) {
      if (v == null || v.isNaN) return '--';
      return v.toStringAsFixed(fractionDigits);
    }

    // 更加类似 Excel 的行列布局，将所有指标放在一个表格中，支持左右滑动。
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        border: TableBorder.all(color: Colors.black12),
        columns: const <DataColumn>[
          DataColumn(
            label: Text(
              '指标',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          DataColumn(label: Text('50%', textAlign: TextAlign.center)),
          DataColumn(label: Text('60%', textAlign: TextAlign.center)),
          DataColumn(label: Text('70%', textAlign: TextAlign.center)),
          DataColumn(label: Text('80%', textAlign: TextAlign.center)),
          DataColumn(label: Text('90%', textAlign: TextAlign.center)),
          DataColumn(label: Text('最小值', textAlign: TextAlign.center)),
          DataColumn(label: Text('中间值', textAlign: TextAlign.center)),
          DataColumn(label: Text('最大值', textAlign: TextAlign.center)),
          DataColumn(label: Text('平均值', textAlign: TextAlign.center)),
        ],
        rows: <DataRow>[
          DataRow(
            cells: <DataCell>[
              const DataCell(Center(child: Text('自尊值', textAlign: TextAlign.center))),
              DataCell(Center(child: Text(joinBucketValues('50'), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(joinBucketValues('60'), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(joinBucketValues('70'), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(joinBucketValues('80'), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(joinBucketValues('90'), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(fmtDouble(basic['min'], 0), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(fmtDouble(basic['mid'], 1), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(fmtDouble(basic['max'], 0), textAlign: TextAlign.center))),
              DataCell(Center(child: Text(fmtDouble(basic['avg'], 1), textAlign: TextAlign.center))),
            ],
          ),
        ],
      ),
    );
  }
    Widget _buildValenceLineChart({List<_ValencePoint>? allPointsOverride}) {
    final allPoints = allPointsOverride ?? _buildValencePoints();
    if (allPoints.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '当前时间范围内还没有情绪记录',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final windowed = _applyViewport(allPoints, _valenceViewStart, _valenceViewEnd);
    final points = _downsampleValencePoints(windowed);

    // 当前视窗的均值（用于参考线）
    final double meanValence = windowed.isEmpty
        ? 0.0
        : windowed.map((e) => e.valence).reduce((a, b) => a + b) / windowed.length;

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].valence));
    }

    const double yMin = -2.0;
    const double yMax = 2.0;
    const double yInterval = 1.0;
    final double meanSlotY = meanValence.roundToDouble().clamp(yMin, yMax);

    String formatBottomLabel(int index) {
      if (index < 0 || index >= points.length) return '';
      final t = points[index].time;
      final yyyy = t.year.toString().padLeft(4, '0');
      final mm = t.month.toString().padLeft(2, '0');
      final dd = t.day.toString().padLeft(2, '0');
      final hh = t.hour.toString().padLeft(2, '0');
      final mi = t.minute.toString().padLeft(2, '0');
      return '$hh:$mi\n$yyyy-$mm-$dd';
    }

    final barData = LineChartBarData(
      spots: spots,
      isCurved: true,
      barWidth: 3,
      color: Colors.lightBlue,
      dotData: FlDotData(
        show: spots.length <= _overviewThreshold,
        getDotPainter: (spot, percent, bar, index) =>
            FlDotCirclePainter(radius: 3, color: Colors.lightBlue),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 260, // 2) 大图加高 40dp
        child: LineChart(
          LineChartData(
            minY: yMin,
            maxY: yMax,
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            lineBarsData: [barData],
            showingTooltipIndicators: spots.asMap().entries.map((e) {
              return ShowingTooltipIndicators([
                LineBarSpot(barData, 0, e.value),
              ]);
            }).toList(),
            lineTouchData: LineTouchData(
              enabled: false,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent,
                tooltipRoundedRadius: 0,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                tooltipMargin: 4,
                fitInsideHorizontally: true, // 3) 文字不越界
                fitInsideVertically: false,
                showOnTopOfTheChartBoxArea: false,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((barSpot) {
                    final idx = barSpot.x.toInt();
                    final name = (idx >= 0 && idx < points.length)
                        ? (points[idx].emotionName ?? '平均')
                        : '';
                    return LineTooltipItem(
                      name,
                      const TextStyle(fontSize: 10),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: Colors.black12, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: true),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: yInterval,
                  getTitlesWidget: (value, meta) {
                    final v = value.round();
                    if ((value - v).abs() > 1e-6) return const SizedBox.shrink();

                    final isMeanSlot = (value - meanSlotY).abs() < 1e-3;
                    final text = isMeanSlot
                        ? meanValence.toStringAsFixed(1)
                        : v.toString();
                    final color = isMeanSlot ? Colors.green : Colors.black54;

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(text, style: TextStyle(fontSize: 10, color: color), softWrap: false, maxLines: 1, overflow: TextOverflow.visible),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: math.max(1, (spots.length / 4).ceilToDouble()), // 6
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    final label = formatBottomLabel(idx);
                    if (label.isEmpty) return const SizedBox.shrink();

                    if (idx > 0 && label == formatBottomLabel(idx - 1)) {
                      return const SizedBox.shrink();
                    }
                    if (idx < points.length - 1 && label == formatBottomLabel(idx + 1)) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0.0,
                  color: Colors.amber,
                  strokeWidth: 3.0,
                ),
                HorizontalLine(
                  y: meanSlotY,
                  color: Colors.green,
                  strokeWidth: 3.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildValenceChartSection() {
    final allPoints = _buildValencePoints();
    if (allPoints.isEmpty) {
      return _buildValenceLineChart(allPointsOverride: allPoints);
    }

    // 数据点很多时，默认聚焦到最近的一个窗口（便于拖拽预览）
    if (allPoints.length > _maxChartPoints &&
        _valenceViewStart == 0.0 &&
        _valenceViewEnd == 1.0) {
      final frac = (_maxChartPoints / allPoints.length).clamp(0.05, 1.0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _valenceViewStart = (1.0 - frac).clamp(0.0, 1.0 - frac);
          _valenceViewEnd = 1.0;
        });
      });
    }
    final allSpots = <FlSpot>[];
    for (var i = 0; i < allPoints.length; i++) {
      allSpots.add(FlSpot(i.toDouble(), allPoints[i].valence));
    }

    final window = (_valenceViewEnd - _valenceViewStart).clamp(0.05, 1.0);

    return Column(
      children: [
        _buildValenceLineChart(allPointsOverride: allPoints),
        if (_valenceList.length > _overviewThreshold) ...[
          const SizedBox(height: 8),
          _buildOverviewSelector(
            allSpots: allSpots,
            allTimes: allPoints.map((e) => e.time).toList(),
            isValence: true,
            viewStart: _valenceViewStart,
            viewEnd: _valenceViewEnd,
            onStartChanged: (s) {

              setState(() {
                _valenceViewStart = s;
                _valenceViewEnd = (s + window).clamp(0.05, 1.0);
              });
                        },
          ),
        ],
      ],
    );
  }


    Widget _buildValenceFilterBar() {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            value: _valenceRangeKey,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'today', child: Text('今天')),
              DropdownMenuItem(value: '7d', child: Text('近7天')),
              DropdownMenuItem(value: '30d', child: Text('当月')),
              DropdownMenuItem(value: '3mo', child: Text('近3个月')),
              DropdownMenuItem(value: '6mo', child: Text('近半年')),
              DropdownMenuItem(value: '1y', child: Text('近一年')),
              DropdownMenuItem(value: '3y', child: Text('近3年')),
              DropdownMenuItem(value: '5y', child: Text('近5年')),
              DropdownMenuItem(value: '10y', child: Text('近10年')),
              DropdownMenuItem(value: 'all', child: Text('全部')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _valenceRangeKey = value;
                // 当范围过短时不支持按月粒度，自动回退
                if ((_valenceRangeKey == 'today' || _valenceRangeKey == '7d') && _valenceGranularityKey == 'month') {
                  _valenceGranularityKey = _valenceRangeKey == 'today' ? 'hour' : 'day';
                }
                _valenceViewStart = 0.0;
                _valenceViewEnd = 1.0;
              });
              _reloadValenceByFilter();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<String>(
            value: _valenceGranularityKey,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: 'record', child: Text('逐条记录')),
              const DropdownMenuItem(value: 'hour', child: Text('按小时')),
              const DropdownMenuItem(value: 'day', child: Text('按天')),
              if (!(_valenceRangeKey == 'today' || _valenceRangeKey == '7d'))
                const DropdownMenuItem(value: 'month', child: Text('按月')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _valenceGranularityKey = value;
                _valenceViewStart = 0.0;
                _valenceViewEnd = 1.0;
              });
              _reloadValenceByFilter();
            },
          ),
        ),
      ],
    );
  }







    Widget _buildEmotionRangeDropdown() {
    return Align(
      alignment: Alignment.centerLeft,
      child: DropdownButton<String>(
        value: _emotionRangeKey,
        items: const [
          DropdownMenuItem(value: 'today', child: Text('今天')),
          DropdownMenuItem(value: '7d', child: Text('近7天')),
          DropdownMenuItem(value: '30d', child: Text('当月')),
          DropdownMenuItem(value: '3mo', child: Text('近3个月')),
          DropdownMenuItem(value: '6mo', child: Text('近半年')),
          DropdownMenuItem(value: '1y', child: Text('近一年')),
          DropdownMenuItem(value: '3y', child: Text('近3年')),
          DropdownMenuItem(value: '5y', child: Text('近5年')),
          DropdownMenuItem(value: '10y', child: Text('近10年')),
          DropdownMenuItem(value: 'all', child: Text('全部')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _emotionRangeKey = value;
          });
          _reloadEmotionByFilter();
        },
      ),
    );
  }

Widget _buildEmotionPieChart() {
    if (_emotionList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '当前时间范围内还没有情绪记录',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final Map<String, int> counts = {};
    for (final row in _emotionList) {
      final name = (row['emoji_name'] ?? '').toString();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '当前时间范围内还没有情绪记录',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final legendEntries = <_EmotionLegendEntry>[];
    const palette = <Color>[
      Color(0xFF26C6DA),
      Color(0xFFAB47BC),
      Color(0xFFFFA726),
      Color(0xFF66BB6A),
      Color(0xFFEC407A),
      Color(0xFF7E57C2),
      Color(0xFFFF7043),
      Color(0xFF29B6F6),
    ];

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final double percent = total == 0 ? 0 : (e.value * 100.0 / total);
      final Color color = palette[i % palette.length];

      legendEntries.add(
        _EmotionLegendEntry(
          name: e.key,
          percent: percent,
          color: color,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: 100,
              minY: 0,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      final v = value.toInt();
                      if (v % 20 != 0) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '$v%',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      final name = entries[index].key;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: total == 0 ? 0 : (entries[i].value * 100.0 / total),
                        color: palette[i % palette.length],
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: legendEntries
              .map<Widget>(
                (_EmotionLegendEntry item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.name} ${item.percent.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }


  Widget _buildEsteemAnalyticsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              children: [
                const Expanded(
                  child: Text(
                    '自尊分析',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: _buildEsteemFilterBar(),
                ),
              ],
            ),
          const SizedBox(height: 8),
          _buildEsteemChartSection(),
          const SizedBox(height: 8),
          _buildEsteemStatsView(),
          const SizedBox(height: 16),
          const Text(
            '自尊得分根据情绪在「正向 / 负向 + 与自尊相关程度」两维度上的加权平均得到，'
            '积极、自我肯定情绪（如自信、胜利）会提高得分，羞愧、自卑等自我意识负性情绪会拉低得分；'
            '当找不到对应情绪定义时，会使用中性得分 50。',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '情绪分布（百分比）',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(width: 110, child: _buildEmotionRangeDropdown()),
            ],
          ),
          const SizedBox(height: 8),
          _buildEmotionPieChart(),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '愉悦度趋势（valence）',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(width: 210, child: _buildValenceFilterBar()),
            ],
          ),
          const SizedBox(height: 8),
          _buildValenceChartSection(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      SimpleBus.navIndex.removeListener(_onNavIndexChanged);
    } catch (_) {}
    _cancelMoodCardTimer();
    try {
      _moodCardController.dispose();
    } catch (_) {}
    _behaviorController.dispose();
    _triggerController.dispose();
    _thoughtController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestToday;
    final String moodLine;
    if (latest == null) {
      moodLine = '当下心情：今天还没有记录心情';
    } else {
      final name = (latest['emoji_name'] ?? '').toString();
      final char = (latest['emoji_char'] ?? '').toString();
      moodLine = '当下心情：$name $char';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('当下心情与情绪分析'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading && _todayList.isEmpty && _latestToday == null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  children: const [
                    SizedBox(height: 220),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  moodLine,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  softWrap: true,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const MoodHistoryDetailPage()),
                                  );
                                },
                                icon: const Icon(Icons.history),
                                label: const Text('查看历史心事'),
                              ),
                            ],
                          ),
                          _buildTimeline(_todayList),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEsteemAnalyticsCard(),
                  ],
                ),
        ),
      ),
    );
  }

}

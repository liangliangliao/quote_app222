import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import '../platform/bg_guard_helper.dart';
import '../platform/exact_alarm_permission_coordinator.dart';
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
import 'mood_insights_page.dart';
import '../diary/notebook_list_page.dart';
import '../diary/diary_dao.dart';
import '../data/db.dart';
import '../voice_alarm/voice_alarm_page.dart';
import '../zhixing_tree/zhixing_tree_home_page.dart';
import '../xiangji_future_strategist/xiangji_home_page.dart';
import '../xiangji_goal_mentor/xiangji_discover_entries.dart';
import '../xiangji_goal_mentor/xiangji_goal_mentor_page.dart';
import '../will_mirror/will_mirror_discover_entry.dart';
import '../will_mirror/will_mirror_home_page.dart';
import '../mental_health_checkup/mental_health_checkup_page.dart';
import '../belief_lab/belief_mentor_discover_entry.dart';
import '../belief_lab/belief_mentor_home_page.dart';
import '../kindling/kindling.dart';
import '../kindling_host/kindling_host_page.dart';

/// 发现之旅：展示当天的心情状态与时间轴
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
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

class _DiscoverPageState extends State<DiscoverPage> with SingleTickerProviderStateMixin {
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
    try {
      SimpleBus.navIndex.addListener(_onNavIndexChanged);
    } catch (_) {}
    // 如果启动时已经位于“发现之旅”页面，也按规则尝试弹出一次。
    _onNavIndexChanged();
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


  static const int _discoverTabIndex = 2;

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


  Future<bool> _guardDiaryFromDiscover() async {
    try {
      final db = await AppDatabase.instance();
      final rows = await db.rawQuery("SELECT diary_pin FROM configs WHERE diary_pin IS NOT NULL AND diary_pin != '' ORDER BY id DESC LIMIT 1");
      if (rows.isEmpty) return true;
      final pin = (rows.first['diary_pin'] ?? '').toString();
      if (pin.isEmpty) return true;

      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('输入日记 PIN'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '4位数字'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim() == pin), child: const Text('确定')),
          ],
        ),
      );
      ctrl.dispose();
      return ok == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _openDiaryFromDiscover() async {
    final ok = await _guardDiaryFromDiscover();
    if (!ok || !mounted) return;
    try { await DiaryDao().ensureSchema(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiaryNotebookListPage(
          key: ValueKey('discover_diary_${DateTime.now().microsecondsSinceEpoch}'),
        ),
      ),
    );
  }

  /// 打开「火种」。装配（等库、接追问器与提醒）都在 KindlingHostPage 里。
  Future<void> _openKindlingFromDiscover() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const KindlingHostPage(),
      ),
    );
  }

  Widget _buildDiscoverEntry({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              child: _loading && _todayList.isEmpty && _latestToday == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _buildDiscoverEntry(
                      icon: Icons.insights_outlined,
                      title: '当下心情与情绪分析',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MoodInsightsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDiscoverEntry(
                      icon: Icons.edit_note_outlined,
                      title: '写日记',
                      onTap: _openDiaryFromDiscover,
                    ),
                    const SizedBox(height: 12),
                    BeliefMentorDiscoverEntry(
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const BeliefMentorHomePage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    XiangjiDiscoverEntries(
                      onGoalMentorTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const XiangjiGoalMentorPage(),
                          ),
                        );
                      },
                      onFutureStrategistTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) =>
                                const XiangjiFutureStrategistHomePage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    WillMirrorDiscoverEntry(
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const WillMirrorHomePage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    KindlingDiscoverEntry(
                      onTap: _openKindlingFromDiscover,
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: const Color(0xFFF1F6EE),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) =>
                                  const ZhixingTreeHomePage(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFDCEBD6),
                                child: Icon(
                                  Icons.park_outlined,
                                  size: 21,
                                  color: Color(0xFF2F7550),
                                ),
                              ),
                              SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '知行树 · 智能行动成长',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '王阳明主线 · 17套思想/22部作品 · 行动、复盘与融合',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF557064),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 改变 · 心理自助入口
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.psychology_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '改变 · 心理自助',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const ChangeSelfHelpPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) =>
                                  const MentalHealthCheckupPage(),
                            ),
                          );
                        },
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFFE9ECFF),
                                Color(0xFFF5EDFF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFC8CEFF),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5664D2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.health_and_safety_outlined,
                                      color: Colors.white,
                                      size: 27,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          '心理健康体检 · 幸福课23讲',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF252E52),
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          '安全分流 → 八域评估 → 课程行动 → 7天复验',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF596273),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF5664D2),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Wrap(
                                spacing: 14,
                                runSpacing: 7,
                                children: <Widget>[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.offline_bolt_outlined,
                                        size: 16,
                                        color: Color(0xFF39715D),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '本地优先',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF315C4E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.person_off_outlined,
                                        size: 16,
                                        color: Color(0xFF4554C5),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '无注册登录',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3948A7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.verified_user_outlined,
                                        size: 16,
                                        color: Color(0xFF7A4E9D),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '种子完整性校验',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF694187),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.assignment_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '心理量表测评中心',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              // 跳转到新版心理量表测评中心页面
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const ScaleCenterPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.flag_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '愿景与目标',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const VisionGoalPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                // 使用健身图标代表生理赋能入口
                                Icon(Icons.fitness_center, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '生理赋能',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '触摸入口已升级为 V167 可见七十二变光弦版：修复 V166 在黑色壁纸背景下“明明生成了分叉、场线、变身层但肉眼几乎只看到一条暗线”的问题；提高主光弦最低亮度、主体线宽、轮廓通道、变身分叉、场线和笔尖的可见度，同时保留单一主体、大留白、极淡同源时间切片，避免重新回到多主体分身或乱线团。',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              // 点击跳转到生理赋能详情页
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const PhysicalEnhancementPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm_on_outlined, size: 20, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('语音闹钟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text('预设时间、朗读内容、语音服务商、震动与音乐，支持5分钟后再次提醒', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => const VoiceAlarmPage()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 听音乐入口
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.music_note_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '听音乐',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const GlobalMusicPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 看电影入口
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.movie_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '看电影',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const MovieRankingPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 看宇宙入口
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.public_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '看宇宙',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const SpaceExplorerPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ),
            _buildMoodCardOverlay(),
            const AiAssistantFloatingBubble(moduleKey: 'discover_home_ai_assistant'),
          ],
        ),
      ),
    );
  }
}

class QuestionnaireScalePage extends StatelessWidget {
  const QuestionnaireScalePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心理量表测评中心'),
      ),
      body: const SizedBox.shrink(),
    );
  }
}


class VisionGoalPage extends StatefulWidget {
  const VisionGoalPage({super.key});

  @override
  State<VisionGoalPage> createState() => _VisionGoalPageState();
}

/// 愿景与目标总页面：
/// - 顶部：核心愿景 + 身份宣言（步骤1）
/// - 中部：WOOP 心理对比（步骤2）
/// - 规则：情境触发配置（步骤3）
/// - 底部：开始专注 / 查看未完成钩子 + 反思（步骤4~6）
class _VisionGoalPageState extends State<VisionGoalPage> {
  bool _geoEnabled = false;
  // 当尝试开启地点规则但尚未添加任何地点时，用此标志显示错误提示。
  bool _geoEnableError = false;

  bool _loading = true;
  Map<String, dynamic>? _goal;
  Map<String, dynamic>? _woop;
  Map<String, dynamic>? _latestSession;
  Map<String, dynamic>? _latestHook;
  Map<String, dynamic>? _latestReflection;
  Map<String, dynamic>? _latestThought;

  // 统计面板数据（模块6）
  int _daysActive7 = 0;
  int _daysActive30 = 0;
  int _totalMinutes7 = 0;
  int _totalMinutes30 = 0;
  Map<String, int> _minutesByDate7 = {};
  Map<String, int> _presenceByDate7 = {};
  Map<String, String> _moodByDate7 = {};

  List<Map<String, dynamic>> _timeTriggers = [];
  bool _unlockTriggerEnabled = false;
  List<Map<String, dynamic>> _locationTriggers = [];

  // Keep track of the single screen unlock trigger id. We maintain only one
  // entry for this type; when toggling off we delete all existing
  // screen‑unlock triggers, and when toggling on we create a fresh one.
  String? _unlockTriggerId;

  // 愿景与身份表单
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _domainCtrl = TextEditingController();
  final TextEditingController _whySurfaceCtrl = TextEditingController();
  final TextEditingController _whyLifeCtrl = TextEditingController();
  final TextEditingController _whyIdentityCtrl = TextEditingController();
  final TextEditingController _identityCtrl = TextEditingController();
  // Used by _showDialogToast to ensure only one toast is shown at a time.
  OverlayEntry? _toastEntry;

  void _showDialogToast(BuildContext ctx, String msg) {
    final overlay = Overlay.of(ctx);
    if (overlay == null) return;

    // Remove any existing toast to avoid stacking.
    try {
      if (_toastEntry?.mounted ?? false) {
        _toastEntry!.remove();
      }
    } catch (_) {}
    _toastEntry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final mq = MediaQuery.of(context);
        // Clamp the toast width so long text doesn't become overly wide on tablets.
        final maxWidth = (mq.size.width - 32).clamp(0.0, 360.0);
        return MediaQuery(
          // Clamp text scaling to keep toast style consistent (avoid huge text).
          data: mq.copyWith(textScaleFactor: 1.0),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 88,
                  child: Material(
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              msg,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    _toastEntry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      try {
        if (entry.mounted) entry.remove();
      } catch (_) {}
      if (identical(_toastEntry, entry)) {
        _toastEntry = null;
      }
    });
  }


  // WOOP 表单
  final TextEditingController _woopWishCtrl = TextEditingController();
  final TextEditingController _woopOutcomeCtrl = TextEditingController();
  final TextEditingController _woopObstaclesCtrl = TextEditingController();
  final TextEditingController _woopPlanCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    (() async { final cfg = ConfigDao(); final e = await cfg.isGeoRulesEnabled(); if(mounted){ setState(()=> _geoEnabled = e);} })();

    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
    });
    final dao = VisionDao();
    final goal = await dao.loadGoal();
    final woop = await dao.loadWoop();
    final latestSession = await dao.latestSession();
    final latestHook = await dao.latestOpenHook();
    final latestReflection = await dao.latestReflection();
    final latestThought = await dao.latestThought();

    // 模块6：习惯 & 统计面板
    final now = DateTime.now();
    final start30 = now.subtract(const Duration(days: 30));
    final start7 = now.subtract(const Duration(days: 7));
    final start30Ts = start30.millisecondsSinceEpoch;
    final start7Ts = start7.millisecondsSinceEpoch;

    final sessions30 = await dao.listSessionsSince(start30Ts);
    final reflections30 = await dao.listReflectionsSince(_fmtYmd(start30));

    // 按日期聚合：minutes
    final Map<String, int> minutesByDate = {};
    for (final s in sessions30) {
      final st = s['start_ts'];
      final ts = st is int ? st : int.tryParse((st ?? '').toString()) ?? 0;
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final dateStr = _fmtYmd(dt);
      final am = s['actual_minutes'];
      final min = am is int ? am : int.tryParse((am ?? '').toString()) ?? 0;
      if (min <= 0) continue;
      minutesByDate[dateStr] = (minutesByDate[dateStr] ?? 0) + min;
    }

    // 反思：presence/mood
    final Map<String, int> presenceByDate = {};
    final Map<String, String> moodByDate = {};
    for (final r in reflections30) {
      final dateStr = (r['date'] ?? '').toString();
      if (dateStr.isEmpty) continue;
      final p = r['presence'];
      final pv = p is int ? p : int.tryParse((p ?? '').toString()) ?? -1;
      if (pv >= 0 && !presenceByDate.containsKey(dateStr)) {
        presenceByDate[dateStr] = pv;
      }
      final mood = (r['mood'] ?? '').toString();
      if (mood.isNotEmpty && !moodByDate.containsKey(dateStr)) {
        moodByDate[dateStr] = mood;
      }
    }

    // 统计：7/30 天
    int days7 = 0;
    int days30 = 0;
    int total7 = 0;
    int total30 = 0;
    final Map<String, int> minutes7 = {};
    final Map<String, int> presence7 = {};
    final Map<String, String> mood7 = {};

    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      final ds = _fmtYmd(d);
      final m = minutesByDate[ds] ?? 0;
      if (m > 0) {
        days30 += 1;
        total30 += m;
        if (d.millisecondsSinceEpoch >= start7Ts) {
          days7 += 1;
          total7 += m;
          minutes7[ds] = m;
        }
      } else if (d.millisecondsSinceEpoch >= start7Ts) {
        minutes7[ds] = 0;
      }
      // 同步 presence/mood（仅近 7 天用于可视化）
      if (d.millisecondsSinceEpoch >= start7Ts) {
        if (presenceByDate.containsKey(ds)) {
          presence7[ds] = presenceByDate[ds]!;
        }
        if (moodByDate.containsKey(ds)) {
          mood7[ds] = moodByDate[ds]!;
        }
      }
    }

    await _reloadTriggersOnly(dao);
    if (!mounted) return;
    setState(() {
      _goal = goal;
      _woop = woop;
      _latestSession = latestSession;
      _latestHook = latestHook;
      _latestReflection = latestReflection;
      _latestThought = latestThought;

      _daysActive7 = days7;
      _daysActive30 = days30;
      _totalMinutes7 = total7;
      _totalMinutes30 = total30;
      _minutesByDate7 = minutes7;
      _presenceByDate7 = presence7;
      _moodByDate7 = mood7;

      _loading = false;
    });
    if (goal != null) {
      _titleCtrl.text = (goal['title'] ?? '').toString();
      _domainCtrl.text = (goal['domain'] ?? '').toString();
      _whySurfaceCtrl.text = (goal['why_surface'] ?? '').toString();
      _whyLifeCtrl.text = (goal['why_life'] ?? '').toString();
      _whyIdentityCtrl.text = (goal['why_identity'] ?? '').toString();
      _identityCtrl.text = (goal['identity_stmt'] ?? '').toString();
    }
    if (woop != null) {
      _woopWishCtrl.text = (woop['wish'] ?? '').toString();
      _woopOutcomeCtrl.text = (woop['outcome'] ?? '').toString();
      _woopObstaclesCtrl.text = (woop['obstacles'] ?? '').toString();
      _woopPlanCtrl.text = (woop['plan'] ?? '').toString();
    }
  }

  String _fmtYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _reloadTriggersOnly([VisionDao? injected]) async {
    final dao = injected ?? VisionDao();
    final rows = await dao.listTriggers();
    final List<Map<String, dynamic>> timeTriggers = [];
    final List<Map<String, dynamic>> locationTriggers = [];
    bool unlockEnabled = false;
    // Reset cached id before scanning; we will capture the first screen_unlock id.
    _unlockTriggerId = null;

    for (final row in rows) {
      final type = (row['type'] ?? '').toString();
      final cfgStr = (row['config'] ?? '').toString();
      Map<String, dynamic> cfg = const {};
      if (cfgStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(cfgStr);
          if (decoded is Map<String, dynamic>) {
            cfg = decoded;
          }
        } catch (_) {}
      }
      if (type == 'time_daily') {
        timeTriggers.add({
          ...row,
          'cfg': cfg,
        });
      } else if (type == 'screen_unlock') {
        final e = cfg['enabled'];
        if (e is bool && e) {
          unlockEnabled = true;
        } else if (e is num && e != 0) {
          unlockEnabled = true;
        }
        // Capture the first id for screen unlock triggers for later updates.
        if (_unlockTriggerId == null) {
          final rid = row['id'];
          if (rid != null) {
            _unlockTriggerId = rid.toString();
          }
        }
      } else if (type == 'geo') {
        locationTriggers.add({
          ...row,
          'cfg': cfg,
        });
      }
    }

    // Also check the persistent unlock switch flag stored in notify_config. If
    // this flag is enabled, treat the unlock trigger as enabled even if
    // there are no screen_unlock rows in vision_triggers. Swallow any
    // exceptions so UI still updates with existing state.
    bool configEnabled = false;
    try {
      configEnabled = await NotifyConfigDao().getUnlockSwitchEnabled();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _timeTriggers = timeTriggers;
      // merge DB triggers and config flag
      _unlockTriggerEnabled = unlockEnabled || configEnabled;
      _locationTriggers = locationTriggers;
      // 若已有地点规则，则清除之前的错误提示
      if (_locationTriggers.isNotEmpty) {
        _geoEnableError = false;
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _domainCtrl.dispose();
    _whySurfaceCtrl.dispose();
    _whyLifeCtrl.dispose();
    _whyIdentityCtrl.dispose();
    _identityCtrl.dispose();
    _woopWishCtrl.dispose();
    _woopOutcomeCtrl.dispose();
    _woopObstaclesCtrl.dispose();
    _woopPlanCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGoal() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先写下你当前阶段最重要的一件事。')),
      );
      return;
    }
    final identity = _identityCtrl.text.trim().isEmpty
        ? '我是那个在日常琐事中也能坚持长期愿景的人。'
        : _identityCtrl.text.trim();
    await VisionDao().saveGoal(
      title: title,
      domain: _domainCtrl.text.trim(),
      whySurface: _whySurfaceCtrl.text.trim(),
      whyLife: _whyLifeCtrl.text.trim(),
      whyIdentity: _whyIdentityCtrl.text.trim(),
      identityStmt: identity,
    );
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('愿景已保存。')),
    );
  }

  Future<void> _saveWoop() async {
    final wish = _woopWishCtrl.text.trim();
    if (wish.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先写下你这一阶段最重要的愿望（Wish）。')),
      );
      return;
    }
    await VisionDao().saveWoop(
      wish: wish,
      outcome: _woopOutcomeCtrl.text.trim(),
      obstacles: _woopObstaclesCtrl.text.trim(),
      plan: _woopPlanCtrl.text.trim(),
    );
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WOOP 已保存。')),
    );
  }

  Future<void> _editGoalBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  '编辑愿景与身份',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '最重要的一件事',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _domainCtrl,
                  decoration: const InputDecoration(
                    labelText: '领域（如：学习/健康/事业，可选）',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _whySurfaceCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '我要达成什么（WHY1，可选）',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _whyLifeCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '生活会有什么改变（WHY2，可选）',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _whyIdentityCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '我会成为怎样的人（WHY3，可选）',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _identityCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '身份宣言（例如：我是那个在困难中也能稳步前进的人）',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveGoal();
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editWoopBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'WOOP 心理对比',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _woopWishCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Wish：本阶段最重要的具体愿望',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _woopOutcomeCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Outcome：详细想象达成后的场景和感受',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _woopObstaclesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Obstacle：1~3 个最真实的障碍（包括内在惰性/焦虑）',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _woopPlanCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Plan：为每个障碍写 If–Then 计划',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveWoop();
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text('保存 WOOP'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _latestSession;
    final hasActiveSession = s != null &&
        (((s['end_ts'] == null) || (s['end_ts'] ?? '').toString().isEmpty)) &&
        ((s['state'] ?? 'running').toString() != 'finished');

    return Scaffold(
      appBar: AppBar(
        title: const Text('愿景与目标'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: _goal == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                if (hasActiveSession) {
                  final sessionId = (s!['id'] ?? '').toString();
                  final taskTitle = (s['title'] ?? '未命名任务').toString();
                  final plannedMinutes = s['planned_minutes'] is int
                      ? (s['planned_minutes'] as int)
                      : (int.tryParse((s['planned_minutes'] ?? '').toString()) ?? 25);

                  if (sessionId.isNotEmpty) {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => VisionFocusSessionPage(
                          sessionId: sessionId,
                          taskTitle: taskTitle,
                          plannedMinutes: plannedMinutes,
                        ),
                      ),
                    );
                    await _loadAll();
                    return;
                  }
                }

                // 从愿景页面进入一次专注流程
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => VisionFocusPreparePage(
                      goal: _goal!,
                    ),
                  ),
                );
                await _loadAll();
              },
              icon: Icon(hasActiveSession ? Icons.play_arrow : Icons.play_arrow),
              label: Text(hasActiveSession ? '继续专注' : '开始专注'),
            ),
    );
  }

  Widget _buildBody() {
    if (_goal == null) {
      // 首次设定愿景
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '从一件最重要的事开始',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '我们会帮你把这件事从“待办清单”变成你生活的主轴。',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '最重要的一件事（例如：考研上岸/坚持写作）',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _identityCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '身份宣言（例如：我是那个在困难中也能稳步前进的人）',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whySurfaceCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '我要达成什么（WHY1，可选）',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whyLifeCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '生活会有什么改变（WHY2，可选）',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whyIdentityCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '这意味着我会成为怎样的人（WHY3，可选）',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveGoal,
                child: const Text('保存愿景'),
              ),
            ),
          ],
        ),
      );
    }

    // 已设定愿景：展示 + WOOP + 钩子 + 反思
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoalCard(),
            const SizedBox(height: 16),
            _buildWoopCard(),
            const SizedBox(height: 16),
            _buildTriggerHintCard(),
            const SizedBox(height: 16),
            _buildThoughtStatsCard(),
            const SizedBox(height: 16),
            _buildHookCard(),
            if (_latestHook != null) const SizedBox(height: 16),
            _buildStatsPanelCard(),
            const SizedBox(height: 16),
            _buildReflectionCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    final goal = _goal!;
    final title = (goal['title'] ?? '').toString();
    final identity = (goal['identity_stmt'] ?? '').toString();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              identity.isEmpty
                  ? '我是那个在日常琐事中也能坚持长期愿景的人。'
                  : identity,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '当前愿景：$title',
              style: const TextStyle(fontSize: 16),
            ),
            if (_latestSession != null) ...[
              const SizedBox(height: 8),
              Text(
                '最近一次专注：${(_latestSession!['title'] ?? '').toString()}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _editGoalBottomSheet,
                  child: const Text('编辑愿景'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWoopCard() {
    final hasWoop = _woop != null && (_woop!['wish'] ?? '').toString().isNotEmpty;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WOOP 心理对比',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!hasWoop)
              const Text(
                '帮助你把愿望、结果、障碍和计划连在一起，让这件事在大脑里形成“有张力的结构”。',
                style: TextStyle(fontSize: 13),
              )
            else ...[
              Text(
                'Wish：${(_woop!['wish'] ?? '').toString()}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              if ((_woop!['outcome'] ?? '').toString().isNotEmpty)
                Text(
                  'Outcome：${(_woop!['outcome'] ?? '').toString()}',
                  style: const TextStyle(fontSize: 13),
                ),
              if ((_woop!['obstacles'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Obstacle：${(_woop!['obstacles'] ?? '').toString()}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if ((_woop!['plan'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Plan（If–Then）：${(_woop!['plan'] ?? '').toString()}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _editWoopBottomSheet,
                child: Text(hasWoop ? '编辑 WOOP' : '去填写 WOOP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 情境触发规则：当前版本只做配置展示与文本说明，实际调度与系统通知复用现有调度服务，后续版本可扩展。
  Widget _buildTriggerHintCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '情境触发 & 执行意向',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '这里用多条规则，把“那一件最重要的事”绑在具体情境上：到点、解锁手机、到某个地点时，都更容易想起它。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildTimeTriggerSection(),
            const Divider(height: 24),
            _buildUnlockTriggerSection(),
            const Divider(height: 24),
            _buildGeoTriggerSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTriggerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '① 每日固定时间提醒',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (_timeTriggers.isEmpty)
          const Text(
            '例如：每天早上 7:30、晚上 21:00 各有一小块 OneThing 时间。',
            style: TextStyle(fontSize: 13),
          )
        else
          Column(
            children: _timeTriggers.map((row) {
              final cfg = (row['cfg'] as Map<String, dynamic>? ?? const {});
              final time = (cfg['time'] ?? '').toString();
              final enabled = (cfg['enabled'] is bool)
                  ? (cfg['enabled'] as bool)
                  : ((cfg['enabled'] is num) ? (cfg['enabled'] as num) != 0 : (row['enabled'] == 1));
              final id = row['id'].toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        time.isEmpty ? '每日固定时间' : '每天 $time',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: (v) => _onToggleTimeTrigger(id, cfg, v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _onDeleteTrigger(id),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增时间规则'),
            onPressed: _onAddTimeTrigger,
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockTriggerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '② 解锁手机时轻提醒',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            Switch(
              value: _unlockTriggerEnabled,
              onChanged: (v) => _onToggleUnlockTrigger(v),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '当前版本会记录你的偏好，后续版本会接入系统的解锁事件，在你解锁手机、打开 App 时温和地提醒你想起这件事。',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              try {
                await BgGuardHelper.requestIgnoreBatteryOptimizations();
                await BgGuardHelper.openAppDetailsSettings();
              } catch (_) {}
            },
            child: const Text('后台不触发/延迟很久？点这里去关闭电池限制', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  /// 地点规则在“解锁/后台”触发时需要后台定位权限（Android 10+ 对应“始终允许定位”）。
  ///
  /// 说明：
  /// - 仅开启“使用期间允许”时，很多机型在 App 后台/前台服务场景会直接不给定位回调，导致地点规则无法匹配。
  /// - 这里在用户开启地点规则开关时主动引导申请/跳转设置，避免后台永远取不到位置。
  Future<bool> _ensureGeoBackgroundLocationPermission() async {
    try {
      // 1) 先确保“使用期间”定位已授权
      var whenInUse = await Permission.locationWhenInUse.status;
      if (!whenInUse.isGranted) {
        whenInUse = await Permission.locationWhenInUse.request();
      }
      if (!whenInUse.isGranted) return false;

      // 2) Android 10+ 再申请“始终允许”（后台定位）
      if (Platform.isAndroid) {
        final always = await Permission.locationAlways.status;
        if (!always.isGranted) {
          final r = await Permission.locationAlways.request();
          if (!r.isGranted) {
            // Android 11+ 经常需要用户在设置页手动打开
            await openAppSettings();
            return false;
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildGeoTriggerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '③ 地点相关规则（预留）',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 24,
              child: Switch(
                value: _geoEnabled,
                onChanged: (v) async {
                if (v) {
                  if (_locationTriggers.isEmpty) {
                    setState(() { _geoEnabled = false; _geoEnableError = true; });
                    try { await ConfigDao().setGeoRulesEnabled(false); } catch (_){}
                    return;
                  }

                  final exactGranted = await ExactAlarmPermissionCoordinator.ensureGranted(
                    context,
                    featureName: '地点规则提醒',
                    explanation: '后台守护会用精准闹钟维持规则检查，避免系统休眠后漏掉提醒。',
                  );
                  if (!exactGranted) return;

                  // 解锁/后台触发地点规则需要后台定位权限（Android 10+：始终允许定位）。
                  final okPerm = await _ensureGeoBackgroundLocationPermission();
                  if (!okPerm) {
                    setState(() { _geoEnabled = false; _geoEnableError = false; });
                    try { await ConfigDao().setGeoRulesEnabled(false); } catch (_){}
                    _showDialogToast(context, '请在系统设置中将定位权限改为“始终允许”，否则后台无法触发地点规则提醒');
                    return;
                  }
                }
                setState(() { _geoEnabled = v; if (!v) _geoEnableError = false; });
                try {
                  await ConfigDao().setGeoRulesEnabled(v);
                  final ok = await ConfigDao().isGeoRulesEnabled();
                  await DLog.i('UI', '【地点规则开关】写入=${v ? '1' : '0'}，读回=${ok ? '1' : '0'}');
                } catch (_){}

                if (v && mounted) {
                  // 与解锁链路共用兜底：确保原生脉冲已排程，并提示用户关闭电池限制。
                  try { await BgGuardHelper.ensureUnlockPulseScheduled(); } catch (_) {}
                  try { await BgGuardHelper.maybeShowGuide(context, feature: '地点规则提醒'); } catch (_) {}
                }
              },
              ),
            ),
          ],
        ),
        // 错误提示：必须至少添加一个目标位置
        if (_geoEnableError)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '开启地点规则时至少需要新增一个目标位置',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        const SizedBox(height: 4),
        if (_locationTriggers.isEmpty)
          const Text(
            '例如：到图书馆、健身房、公司工位时，让这件事自动浮现在脑海中。你可以选择当前位置作为目标，或点击行内按钮重新定位。',
            style: TextStyle(fontSize: 13),
          )
        else
          Column(
            children: _locationTriggers.map((row) {
              final cfg = (row['cfg'] as Map<String, dynamic>? ?? const {});
              final name = (cfg['place'] ?? '').toString();
              final note = (cfg['note'] ?? '').toString();
              final lat = cfg['lat'];
              final lng = cfg['lng'];
              final id = row['id'].toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? '某个地点' : name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (note.isNotEmpty)
                            Text(
                              note,
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (lat != null && lng != null)
                            Text(
                              '坐标: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    // Re-locate button
                    IconButton(
                      icon: const Icon(Icons.my_location, size: 18),
                      tooltip: '重新定位',
                      onPressed: () => _onUpdateGeoLocation(id, cfg),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _onDeleteTrigger(id),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('新增地点规则'),
            // 无论地点规则开关是否打开，都允许添加地点规则。此前根据开关状态禁用按钮
            // 的逻辑已移除以保证按钮始终可点击。
            onPressed: _onAddGeoTrigger,
          ),
        ),
      ],
    );
  }

  Future<void> _onAddTimeTrigger() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    final tStr = '$hh:$mm';

    final exactGranted = await ExactAlarmPermissionCoordinator.ensureGranted(
      context,
      featureName: 'OneThing 每日定时提醒',
    );
    if (!exactGranted) return;

    final dao = VisionDao();
    final cfg = <String, dynamic>{
      'time': tStr,
      'enabled': true,
    };
    await dao.upsertTrigger(
      type: 'time_daily',
      config: jsonEncode(cfg),
      thenText: '到这个时间提醒你开始 OneThing 专注。',
      enabled: true,
    );
    await _reloadTriggersOnly();
    // After reloading triggers, synchronise time triggers with scheduled tasks
    try { await VisionTriggerService.syncTriggersToTasks(); } catch (_) {}
  }

  Future<void> _onToggleTimeTrigger(String id, Map<String, dynamic> oldCfg, bool enabled) async {
    if (enabled) {
      final exactGranted = await ExactAlarmPermissionCoordinator.ensureGranted(
        context,
        featureName: 'OneThing 每日定时提醒',
      );
      if (!exactGranted) return;
    }
    final dao = VisionDao();
    final cfg = Map<String, dynamic>.from(oldCfg);
    cfg['enabled'] = enabled;
    await dao.upsertTrigger(
      id: id,
      type: 'time_daily',
      config: jsonEncode(cfg),
      thenText: '到这个时间提醒你开始 OneThing 专注。',
      enabled: enabled,
    );
    await _reloadTriggersOnly();
    // Synchronise tasks after toggling a trigger
    try { await VisionTriggerService.syncTriggersToTasks(); } catch (_) {}
  }

  Future<void> _onDeleteTrigger(String id) async {
    final dao = VisionDao();
    await dao.deleteTrigger(id);
    await _reloadTriggersOnly();
    // Remove any scheduled task associated with this trigger
    try { await VisionTriggerService.syncTriggersToTasks(); } catch (_) {}
  }

  Future<void> _onToggleUnlockTrigger(bool enabled) async {
    if (enabled) {
      final exactGranted = await ExactAlarmPermissionCoordinator.ensureGranted(
        context,
        featureName: '解锁轻提醒',
        explanation: '后台守护会用精准闹钟维持触发链路，避免系统休眠后失效。',
      );
      if (!exactGranted) return;
    }
    final dao = VisionDao();
    // Always remove all existing screen_unlock triggers to avoid duplicates.
    final rows = await dao.listTriggers();
    for (final row in rows) {
      final type = (row['type'] ?? '').toString();
      if (type == 'screen_unlock') {
        final rid = row['id']?.toString();
        if (rid != null) {
          await dao.deleteTrigger(rid);
        }
      }
    }
    // If enabled, create a new trigger; if disabled, simply clear all.
    if (enabled) {
      final cfg = <String, dynamic>{'enabled': true};
      await dao.upsertTrigger(
        type: 'screen_unlock',
        config: jsonEncode(cfg),
        thenText: '在你解锁手机、打开 App 时提示你想起这一件事。',
        enabled: true,
      );
    }
    // Persist the unlock switch state to notify_config so that the service can
    // detect it even when no screen_unlock triggers exist in the DB (for
    // example when the user has cleared data or when the DB fails to open).
    try {
      await NotifyConfigDao().setUnlockSwitchEnabled(enabled);
    } catch (_) {}
    await _reloadTriggersOnly();

    // Background stability: make sure the native pulse is scheduled, and guide
    // the user to disable battery restrictions when needed (no常驻通知版本).
    if (enabled && mounted) {
      try { await BgGuardHelper.ensureUnlockPulseScheduled(); } catch (_) {}
      try { await BgGuardHelper.maybeShowGuide(context, feature: '解锁轻提醒/地点规则'); } catch (_) {}
    }
  }

  /// Update a geo trigger's location to the current device location.
  Future<void> _onUpdateGeoLocation(String id, Map<String, dynamic> oldCfg) async {
    try {
      // Request permission and get current position
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取定位权限，无法更新位置')),
          );
        }
        return;
      }
      // Use the preferred location service: **system GPS/Network first**, and only
      // if system location fails, fall back to Baidu IP (coarse). This keeps
      // manual and automatic flows consistent: system-first, Baidu as last resort.
      final pos = await LocationService.getCurrentPositionPreferBaidu();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取当前定位')),
          );
        }
        return;
      }
      final cfg = Map<String, dynamic>.from(oldCfg);
      cfg['lat'] = pos.latitude;
      cfg['lng'] = pos.longitude;
      // 标记坐标系：system/last_known 视为 wgs84；baidu 为 bd09（用于原生侧统一换算比对）
      final prov = LocationService.lastProvider;
      cfg['coordType'] = prov == 'baidu' ? 'bd09' : 'wgs84';
      // Attempt to reverse geocode the new coordinates if no place name is present
      try {
        if ((cfg['place'] == null || cfg['place'].toString().trim().isEmpty)) {
          final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            final pm = placemarks.first;
            final geoname = ((pm.name ?? '') + ' ' + (pm.street ?? '')).trim();
            if (geoname.isNotEmpty) {
              cfg['place'] = geoname;
            }
          }
        }
      } catch (_) {
        // ignore reverse geocoding errors
      }
      final dao = VisionDao();
      await dao.upsertTrigger(
        id: id,
        type: 'geo',
        config: jsonEncode(cfg),
        thenText: (cfg['note'] ?? '当你到达这个地点时，提醒你想起这一件事。').toString(),
        enabled: true,
      );
      await _reloadTriggersOnly();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新位置失败')),
        );
      }
    }
  }

  Future<void> _onAddGeoTrigger() async {
    // Controllers for user input
    final placeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    // Variables to store latitude/longitude when a location is selected
    double? lat;
    double? lng;
    // Flag to show a loading spinner while resolving the current location
    bool locating = false;
    // POI list + search/paging states (新增，不影响既有逻辑)
    List<PoiItem> poiList = [];

    // 本地去重：同名且同坐标（6位小数）才去重。用于弹窗跨页/跨来源合并后的最终列表去重
    List<PoiItem> _dedupByNameLocal(List<PoiItem> src) {
      if (src.length <= 1) return src;
      final seen = <String>{};
      final out = <PoiItem>[];
      String norm(String s) {
        var t = s.trim();
        // 去零宽/不可见字符 + 所有空白
        t = t.replaceAll('\u200B', '').replaceAll('\uFEFF', '');
        t = t.replaceAll(RegExp(r'\s+'), '');
        return t;
      }
      for (final p in src) {
        final nameKey = norm(p.name);
        if (nameKey.isEmpty) {
          out.add(p);
          continue;
        }
        final key =
            '$nameKey|${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
        if (seen.contains(key)) continue;
        seen.add(key);
        out.add(p);
      }
      return out;
    }

    int poiPage = 1;
    bool poiHasMore = true;
    bool poiLoadingMore = false;
    String poiKeyword = '';
    final poiSearchCtrl = TextEditingController();
    PoiItem? selectedPoi;
    final ScrollController poiScrollCtrl = ScrollController();


    // Show a dialog allowing the user to configure a new geo trigger
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDlg) {
            // Helper function to retrieve the current location and update the
            // text field. 在复杂/室内环境下原生 GPS 可能长时间拿不到首定位，
            // 这里加上超时时间，并在超时后回退到最近一次已知位置，避免一直
            // 转圈卡死在 loading 状态。
                        Future<void> pickLocation() async {
                          setStateDlg(() {
                            locating = true;
                          });
                          await Future<void>.delayed(const Duration(milliseconds: 16));

                          void _stopLocating() {
                            if (!locating) return;
                            try {
                              setStateDlg(() {
                                locating = false;
                              });
                            } catch (_) {
                              // dialog may have been disposed
                            }
                          }

                          try {
                            // Request permission for location access
                            var perm = await Geolocator.checkPermission();
                            if (perm == LocationPermission.denied) {
                              perm = await Geolocator.requestPermission();
                            }
                            if (perm == LocationPermission.denied ||
                                perm == LocationPermission.deniedForever) {
                              _showDialogToast(ctx2, '未授予定位权限');
                              _stopLocating();
                              return;
                            }

                            // 获取“尽可能正确”的当前位置：百度SDK默认定位，系统高精度流兜底。
                            // 说明：任何定位在室内/遮挡环境都可能无法稳定 <31m。
                            // 这里优先等待达标(<=31m)，达标不了则返回“离设备最近的可用结果”，
                            // 避免直接失败导致无法继续选择附近地点。
                            // 同时施加 30 秒整体超时，避免一直转圈。
                            await DLog.i('LocationService', '规则地点弹窗：开始获取目标位置（百度SDK优先，系统兜底）');
                            final pos = await LocationService.getBestCurrentPositionPreferBaidu(
                              baiduMaxAttempts: 3,
                              useLastKnown: false,
                            ).timeout(const Duration(seconds: 30));
                            if (pos == null) {
                              await DLog.w('LocationService', '规则地点弹窗：定位结果为null（30s超时或权限/服务不可用）');
                              _showDialogToast(ctx2, '定位失败，请检查权限/网络后重试');
                              _stopLocating();
                              return;
                            }
                            lat = pos.latitude;
                            lng = pos.longitude;

                            // 若精度未达标，继续流程但给出提示（仍可通过搜索框手动选择地点）。
                            if (pos.accuracy > 31.0) {
                              await DLog.w('LocationService', '规则地点弹窗：精度未达标 acc=${pos.accuracy.toStringAsFixed(1)}m，继续用最近位置');
                              _showDialogToast(ctx2, '定位精度一般（${pos.accuracy.toStringAsFixed(1)}m），已取最近位置，可重试或手动搜索');
                            }

                            // 一旦拿到坐标，立刻结束 loading，让按钮恢复可用
                            if (locating) {
                              setStateDlg(() {
                                locating = false;
                              });
                            }

                            // 使用适当的逆地理服务获取地址信息（根据最后一次成功定位的提供者选择）
                            List<PoiItem> pois = <PoiItem>[];
                            String resolvedName = '';
                            try {
                              // 规则地点弹窗：优先使用 Baidu SDK 逆地理（原生侧会根据坐标系做转换），
                              // 失败/返回空时再回退系统 Geocoder 兜底。
                              try {
                                pois = await LocationService.fetchNearbyPois(
                                  latitude: lat!,
                                  longitude: lng!,
                                  radiusMeters: 600,
                                  keyword: '',
                                  pageSize: 10,
                                );
                              } catch (_) {
                                pois = <PoiItem>[];
                              }

                              if (pois.isEmpty) {
                                try {
                                  pois = await LocationService.fetchNearbyPoisSystem(
                                    latitude: lat!,
                                    longitude: lng!,
                                    radiusMeters: 600,
                                    keyword: '',
                                    pageSize: 10,
                                  );
                                } catch (_) {
                                  pois = <PoiItem>[];
                                }
                              }

                              if (pois.isEmpty) {
                                await DLog.w('LocationService', '规则地点弹窗：50m内POI为空（已尝试百度SDK与系统兜底）');
                                _showDialogToast(ctx2, '附近地点获取失败，请检查网络或稍后重试');
                              }

                              if (pois.isNotEmpty) {
                                // 使用逆地理返回的 POI 刷新列表和选中项
                                selectedPoi = pois.first;
                                resolvedName = selectedPoi!.name;
                                poiSearchCtrl.text = ''; // 避免触发自动搜索导致列表被过滤为单条


                                poiList = _dedupByNameLocal(pois);
                                poiPage = 1;
                                poiHasMore = pois.length >= 10;
                                poiLoadingMore = false;
                                poiKeyword = '';

                                // 防御性重置滚动位置，避免还未 attach 时抛异常
                                try {
                                  if (poiScrollCtrl.hasClients) {
                                    poiScrollCtrl.jumpTo(0);
                                  }
                                } catch (_) {}
                              } else {
                                // 未返回任何 POI 时清空列表，避免保留旧数据
                                poiList = [];
                                poiPage = 1;
                                poiHasMore = false;
                                poiLoadingMore = false;
                              }
                            } catch (_) {
                              _showDialogToast(ctx2, '逆地理解析失败，请稍后重试');
                            }

                            // Populate the place name field with the resolved address (或保留用户输入
                            // 的内容，如果反向地理编码失败)
                            setStateDlg(() {
                              // 若已选中地标（尤其是只返回一个地标的场景），优先显示地标名称（更具体）。
                              final poiName = (selectedPoi?.name ?? '').trim();
                              if (poiName.isNotEmpty) {
                                placeCtrl.text = poiName;
                                return;
                              }

                              // 兜底：将解析出的地点名称与坐标一起回显到输入框中，便于用户确认。
                              final hasCoord = lat != null && lng != null;
                              final coordText = hasCoord
                                  ? ' (${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)})'
                                  : '';
                              if (resolvedName.isNotEmpty) {
                                placeCtrl.text = '$resolvedName$coordText';
                              } else if (coordText.isNotEmpty) {
                                placeCtrl.text = coordText.trim();
                              }
                            });
                          } catch (_) {
                            _showDialogToast(ctx2, '获取目标位置失败，请检查网络或稍后重试');
                          } finally {
                            // 确保无论成功/失败都能关闭 loading，避免一直转圈
                            _stopLocating();
                          }
                        }
            return AlertDialog(
              title: const Text('新增地点规则'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A row with the place text field and a locate/relocate button on its right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: placeCtrl,
                            decoration: const InputDecoration(
                              labelText: '地点名称（如图书馆、健身房）',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // If we are locating, show a small spinner
                        if (locating) ...[
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ] else ...[
                          TextButton.icon(
                            icon: const Icon(Icons.my_location, size: 16),
                            // When no coordinates are set yet, we show a more descriptive
                            // label indicating that this action will capture the target
                            // location. Otherwise the button remains a simple re‑locate.
                            label: Text((lat != null && lng != null) ? '重新定位' : '目标位置定位'),
                            onPressed: pickLocation,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 搜索附近地点（本地过滤 + 重新拉取）
                    TextField(
                      controller: poiSearchCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: '搜索附近地点（如：超市、公寓）',
                      ),
                      onSubmitted: (kw) async {
                        poiKeyword = kw.trim();
                        if (lat == null || lng == null) return;
                        poiPage = 1;
                        poiList.clear();
                        poiHasMore = true;
                        final provider = LocationService.lastProvider;
                        final list = provider == 'system'
                            ? await LocationService.fetchNearbyPoisSystem(
                                latitude: lat!,
                                longitude: lng!,
                                radiusMeters: 50,
                                keyword: poiKeyword,
                                page: poiPage,
                                pageSize: 5,
                              )
                            : await LocationService.fetchNearbyPois(
                                latitude: lat!,
                                longitude: lng!,
                                radiusMeters: 50,
                                keyword: poiKeyword,
                                page: poiPage,
                                pageSize: 5,
                              );
                        setStateDlg(() {
                          poiList.addAll(list);
                          poiList = _dedupByNameLocal(poiList);
                          poiHasMore = list.length == 5;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (sn) {
                          if (!poiHasMore || poiLoadingMore) return false;
                          if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 24) {
                            // 触底加载更多
                            () async {
                              poiLoadingMore = true;
                              poiPage += 1;
                              final provider = LocationService.lastProvider;
                              final more = provider == 'system'
                                  ? await LocationService.fetchNearbyPoisSystem(
                                      latitude: lat ?? 0,
                                      longitude: lng ?? 0,
                                      radiusMeters: 50,
                                      keyword: poiKeyword,
                                      page: poiPage,
                                      pageSize: 5,
                                    )
                                  : await LocationService.fetchNearbyPois(
                                      latitude: lat ?? 0,
                                      longitude: lng ?? 0,
                                      radiusMeters: 50,
                                      keyword: poiKeyword,
                                      page: poiPage,
                                      pageSize: 5,
                                    );
                              setStateDlg(() {
                                poiList.addAll(more);
                                poiList = _dedupByNameLocal(poiList);
                                poiHasMore = more.length == 5;
                                poiLoadingMore = false;
                              });
                            }();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: poiScrollCtrl,
                          itemCount: poiList.length,
                          itemBuilder: (c, i) {
                            final item = poiList[i];
                            final sel = (selectedPoi?.name == item.name && selectedPoi?.latitude == item.latitude && selectedPoi?.longitude == item.longitude);
                            return ListTile(
                              dense: true,
                              title: Text(item.name, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                (item.address ?? '') + ((item.distance != null) ? ' · 距离约${item.distance}米' : ''),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: sel ? const Icon(Icons.check, size: 18) : null,
                              onTap: () {
                                setStateDlg(() {
                                  selectedPoi = item;
                                  placeCtrl.text = item.name;
                                  lat = item.latitude;
                                  lng = item.longitude;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Note text field
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: '到这里时你想做什么？',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '你可以输入地点名称，或使用当前定位作为目标。当你到达附近时会收到提醒。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx2).pop(false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx2).pop(true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    // If the user cancelled, do nothing
    if (ok != true) return;
    final name = placeCtrl.text.trim();
    final note = noteCtrl.text.trim();
    // At least one of name/note/location must be provided
    if (name.isEmpty && note.isEmpty && lat == null && lng == null) {
      return;
    }
    final dao = VisionDao();
    final cfg = <String, dynamic>{};
    // If name is not provided but lat/lng is present, try to reverse geocode to a human readable name.
    if (lat != null && lng != null && name.isEmpty) {
      try {
        final placemarks = await placemarkFromCoordinates(lat!, lng!);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final geoname = ((pm.name ?? '') + ' ' + (pm.street ?? '')).trim();
          if (geoname.isNotEmpty) {
            cfg['place'] = geoname;
          }
        }
      } catch (_) {
        // ignore reverse geocoding errors
      }
    }
    // Otherwise use the user provided name.
    if (name.isNotEmpty) cfg['place'] = name;
    // 若选择了POI，写入poi_name并确保坐标存在
    if (selectedPoi != null) {
      cfg['poi_name'] = selectedPoi!.name;
      if (lat == null || lng == null) {
        lat = selectedPoi!.latitude;
        lng = selectedPoi!.longitude;
      }
    }
    if (note.isNotEmpty) cfg['note'] = note;
    if (lat != null && lng != null) {
      cfg['lat'] = lat;
      cfg['lng'] = lng;
      final prov = LocationService.lastProvider;
      cfg['coordType'] = prov == 'baidu' ? 'bd09' : 'wgs84';
    }
    try {
      await dao.upsertTrigger(
        type: 'geo',
        config: jsonEncode(cfg),
        thenText: '当你到达这个地点时，提醒你想起这一件事。',
        enabled: true,
      );
      await _reloadTriggersOnly();
    } catch (_) {
      _showDialogToast(context, '保存地点规则失败，请稍后重试');
      return;
    }
  }

  Widget _buildHookCard() {
    final hook = _latestHook;
    final hasHook = hook != null;

    final text = hasHook ? (hook!['text'] ?? '').toString() : '';
    final nextAction = hasHook ? (hook!['next_action'] ?? '').toString() : '';

    String goalTitle = '';
    String woopWish = '';
    String taskTitle = '';
    String ts = '';

    if (hasHook) {
      goalTitle = (hook!['goal_title'] ?? '').toString();
      woopWish = (hook!['woop_wish'] ?? '').toString();
      taskTitle = (hook!['task_title'] ?? '').toString();
      ts = _fmtTsToDateTime(hook!['created_ts'] ?? 0);
    }

    // 回退到当前愿景/WOOP（兼容旧数据）
    if (goalTitle.isEmpty) goalTitle = (_goal?['title'] ?? '').toString();
    if (woopWish.isEmpty) woopWish = (_woop?['wish'] ?? '').toString();
    if (taskTitle.isEmpty) taskTitle = (_latestSession?['title'] ?? '').toString();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '未完成钩子',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!hasHook)
              const Text(
                '暂无未完成钩子。每次专注结束时，建议刻意停在一个中间节点，并写下“下一步动作”，让大脑保持轻微牵引感。',
                style: TextStyle(fontSize: 13),
              )
            else ...[
              Text(
                text.isEmpty ? '（空）' : text,
                style: const TextStyle(fontSize: 14),
              ),
              if (nextAction.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '下一步只要：$nextAction',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ],
            const SizedBox(height: 10),
            if (taskTitle.isNotEmpty)
              Text('专注：$taskTitle', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (goalTitle.isNotEmpty)
              Text('所属愿景：$goalTitle', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (woopWish.isNotEmpty)
              Text('具体愿景：$woopWish', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (ts.isNotEmpty)
              Text('日期：$ts', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasHook)
                  TextButton(
                    onPressed: () async {
                      final id = (hook!['id'] ?? '').toString();
                      if (id.isEmpty) return;
                      await VisionDao().resolveHook(id);
                      await _loadAll();
                    },
                    child: const Text('标记已接上'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const VisionHookHistoryPage(),
                      ),
                    );
                    await _loadAll();
                  },
                  child: const Text('历史记录'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThoughtStatsCard() {
    final t = _latestThought;
    final nodeUids = t == null
        ? const <String>[]
        : (t['node_uids'] ?? '')
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '念头统计',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (t == null)
              const Text(
                '还没有记录念头。专注时弹出的想法可以一键记下来，稍后再处理。',
                style: TextStyle(fontSize: 13),
              )
            else ...[
              Text(
                (t['thought'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              if (nodeUids.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('分类（思维导图）', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                ThoughtTaxonomyMindMap(selectedUids: nodeUids, height: 150, compact: true),
              ] else if (((t['node_titles'] ?? '').toString()).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '分类：${(t['node_titles'] ?? '').toString()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '专注事项：${(t['task_title'] ?? '').toString()}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (((t['goal_title'] ?? '').toString()).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '所属愿景：${(t['goal_title'] ?? '').toString()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              if (((t['woop_wish'] ?? '').toString()).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '具体愿景：${(t['woop_wish'] ?? '').toString()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '日期：${_fmtTsToDateTime((t['created_ts'] ?? 0))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const VisionThoughtHistoryPage(),
                    ),
                  );
                  await _loadAll();
                },
                child: const Text('历史记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTsToDateTime(dynamic ts) {
    int v = 0;
    if (ts is int) {
      v = ts;
    } else {
      v = int.tryParse(ts.toString()) ?? 0;
    }
    if (v <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(v);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildStatsPanelCard() {
    // 最近 7 天日期序列（倒序展示）
    final now = DateTime.now();
    final List<String> days = [];
    for (int i = 6; i >= 0; i--) {
      days.add(_fmtYmd(now.subtract(Duration(days: i))));
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < days.length; i++) {
      final ds = days[i];
      final v = (_minutesByDate7[ds] ?? 0).toDouble();
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: v)],
        ),
      );
    }

    final lineSpots = <FlSpot>[];
    for (int i = 0; i < days.length; i++) {
      final ds = days[i];
      final p = _presenceByDate7[ds];
      if (p != null) {
        lineSpots.add(FlSpot(i.toDouble(), p.toDouble()));
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '习惯 & 统计面板',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '近 7 天：完成 $_daysActive7 天 · 总计 $_totalMinutes7 分钟',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '近 30 天：完成 $_daysActive30 天 · 总计 $_totalMinutes30 分钟',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '近 7 天 OneThing 总专注时长（分钟）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                          final ds = days[idx];
                          final label = ds.substring(5); // MM-DD
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(label, style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '主观存在感（0~10）趋势',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: lineSpots.isEmpty
                  ? const Center(child: Text('还没有反思数据。', style: TextStyle(fontSize: 12, color: Colors.grey)))
                  : LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: lineSpots,
                            isCurved: true,
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        minY: 0,
                        maxY: 10,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              '近 7 天：时长 × 状态',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Column(
              children: days.reversed.map((ds) {
                final m = _minutesByDate7[ds] ?? 0;
                final p = _presenceByDate7[ds];
                final mood = _moodByDate7[ds] ?? '';
                final showP = p != null ? p.toString() : '-';
                final moodText = mood.isEmpty ? '' : ' · $mood';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(ds.substring(5), style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text('时长 $m min · 存在感 $showP$moodText', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReflectionCard() {
    final latest = _latestReflection;

    // 兼容旧数据：优先取记录中的关联字段，缺失则回退到当前愿景/WOOP
    String goalTitle = '';
    String woopWish = '';
    String taskTitle = '';
    String ts = '';
    int presence = -1;
    String mood = '';
    String note = '';

    if (latest != null) {
      presence = latest['presence'] is int ? (latest['presence'] as int) : (int.tryParse((latest['presence'] ?? '').toString()) ?? -1);
      mood = (latest['mood'] ?? '').toString();
      note = (latest['note'] ?? '').toString();
      goalTitle = (latest['goal_title'] ?? '').toString();
      woopWish = (latest['woop_wish'] ?? '').toString();
      taskTitle = (latest['task_title'] ?? '').toString();
      ts = _fmtTsToDateTime(latest['created_ts'] ?? 0);
    }

    if (goalTitle.isEmpty) goalTitle = (_goal?['title'] ?? '').toString();
    if (woopWish.isEmpty) woopWish = (_woop?['wish'] ?? '').toString();
    if (taskTitle.isEmpty) taskTitle = (_latestSession?['title'] ?? '').toString();

    String summary = '还没有反思记录。结束专注后，你可以简单评估今天这件事在你大脑中的存在感。';
    if (latest != null) {
      summary = '最近一次自评：存在感 '
          '${presence >= 0 ? presence.toString() : '?'} / 10'
          '${mood.isNotEmpty ? ' · 情绪：$mood' : ''}'
          '${note.isNotEmpty ? ' · 备注：$note' : ''}';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '反思与边界',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const VisionReflectionHistoryPage(),
                      ),
                    );
                    await _loadAll();
                  },
                  child: const Text('历史记录'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (taskTitle.isNotEmpty)
              Text('专注：$taskTitle', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (goalTitle.isNotEmpty)
              Text('所属愿景：$goalTitle', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (woopWish.isNotEmpty)
              Text('具体愿景：$woopWish', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (ts.isNotEmpty)
              Text('日期：$ts', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text(
              '如果你发现这件事存在感很高、同时伴随持续的焦虑和疲惫，可以适当安排休息块或分散注意力，必要时寻求专业支持。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class VisionFocusPreparePage extends StatefulWidget {
  final Map<String, dynamic> goal;
  const VisionFocusPreparePage({super.key, required this.goal});

  @override
  State<VisionFocusPreparePage> createState() => _VisionFocusPreparePageState();
}

class _VisionFocusPreparePageState extends State<VisionFocusPreparePage> {
  final TextEditingController _taskCtrl = TextEditingController();
  int _minutes = 25;
  bool _starting = false;

  @override
  void dispose() {
    _taskCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.goal['title'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('准备专注'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前愿景：$title',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '在这一小段时间里，只做一件与愿景有关的事。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _taskCtrl,
              decoration: const InputDecoration(
                labelText: '本次要做的具体一小步（例如：写完引言300字）',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('专注时长：'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _minutes,
                  items: const [
                    DropdownMenuItem(
                      value: 25,
                      child: Text('25 分钟'),
                    ),
                    DropdownMenuItem(
                      value: 45,
                      child: Text('45 分钟'),
                    ),
                    DropdownMenuItem(
                      value: 60,
                      child: Text('60 分钟'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _minutes = v);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('开始专注'),
                onPressed: _starting
                    ? null
                    : () async {
                        final taskTitle = _taskCtrl.text.trim().isEmpty
                            ? '未命名任务'
                            : _taskCtrl.text.trim();
                        setState(() => _starting = true);
                        try {
                          final dao = VisionDao();
                          final sessionId = await dao.startSession(
                            title: taskTitle,
                            plannedMinutes: _minutes,
                          );
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => VisionFocusSessionPage(
                                sessionId: sessionId,
                                taskTitle: taskTitle,
                                plannedMinutes: _minutes,
                              ),
                            ),
                          );
                          if (!mounted) return;
                          Navigator.of(context).pop(); // 返回愿景页
                        } finally {
                          if (mounted) {
                            setState(() => _starting = false);
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VisionFocusSessionPage extends StatefulWidget {
  final String sessionId;
  final String taskTitle;
  final int plannedMinutes;

  const VisionFocusSessionPage({
    super.key,
    required this.sessionId,
    required this.taskTitle,
    required this.plannedMinutes,
  });

  @override
  State<VisionFocusSessionPage> createState() => _VisionFocusSessionPageState();
}

class _VisionFocusSessionPageState extends State<VisionFocusSessionPage> with WidgetsBindingObserver {
  Timer? _ticker;

  bool _loaded = false;

  late final int _plannedMs = widget.plannedMinutes * 60 * 1000;

  int _startTsMs = 0;
  int _pausedTotalMs = 0;
  int? _pausedAtMs;
  String _runState = 'running'; // running | paused | finished

  String _goalTitle = '';
  String _woopWish = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_loadAndStart);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 核心原则：倒计时不依赖前台 tick，而是依赖 start_ts + 时钟差值。
    // 因此这里只需要在回到前台时刷新 UI 即可。
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadAndStart() async {
    final vDao = VisionDao();
    final session = await vDao.getSessionById(widget.sessionId);

    final now = DateTime.now().millisecondsSinceEpoch;

    _startTsMs = (session?['start_ts'] is int)
        ? (session!['start_ts'] as int)
        : int.tryParse((session?['start_ts'] ?? '').toString()) ?? now;

    _pausedTotalMs = (session?['paused_total_ms'] is int)
        ? (session!['paused_total_ms'] as int)
        : int.tryParse((session?['paused_total_ms'] ?? '').toString()) ?? 0;

    final pausedAtRaw = session?['paused_at_ms'];
    _pausedAtMs = (pausedAtRaw is int)
        ? pausedAtRaw
        : (pausedAtRaw == null ? null : int.tryParse(pausedAtRaw.toString()));

    _runState = (session?['state'] ?? 'running').toString();
    if (_runState.isEmpty) _runState = 'running';

    // 读取当前愿景/WOOP（用于页面展示 & 结束时写入关联字段）
    final goal = await vDao.loadGoal();
    final woop = await vDao.loadWoop();
    _goalTitle = (goal?['title'] ?? '').toString();
    _woopWish = (woop?['wish'] ?? '').toString();

    if (!mounted) return;
    setState(() => _loaded = true);
    _startTicker();

    // 若已到时间（例如后台/被杀后回来），自动完成
    final rem = _calcRemaining().inMilliseconds;
    if (_runState == 'running' && rem <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onFinish(auto: true));
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_runState == 'running' && _calcRemaining() <= Duration.zero) {
        _onFinish(auto: true);
        return;
      }
      setState(() {});
    });
  }

  Duration _calcRemaining() {
    if (_startTsMs <= 0) return Duration(minutes: widget.plannedMinutes);
    final endMs = _startTsMs + _plannedMs + _pausedTotalMs;

    final int refNowMs;
    if (_runState == 'paused' && _pausedAtMs != null && _pausedAtMs! > 0) {
      refNowMs = _pausedAtMs!;
    } else {
      refNowMs = DateTime.now().millisecondsSinceEpoch;
    }

    final remMs = (endMs - refNowMs).clamp(0, 1 << 62);
    return Duration(milliseconds: remMs);
  }

  double _calcProgress() {
    final rem = _calcRemaining().inMilliseconds;
    if (_plannedMs <= 0) return 0;
    final p = 1 - (rem / _plannedMs);
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  String _fmt(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 1 << 31);
    final mm = (totalSec ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSec % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _togglePause() async {
    final vDao = VisionDao();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_runState == 'running') {
      _pausedAtMs = now;
      _runState = 'paused';
      await vDao.updateSessionPauseState(
        sessionId: widget.sessionId,
        state: 'paused',
        pausedAtMs: _pausedAtMs,
        pausedTotalMs: _pausedTotalMs,
      );
    } else if (_runState == 'paused') {
      final pa = _pausedAtMs ?? now;
      _pausedTotalMs += (now - pa).clamp(0, 1 << 62);
      _pausedAtMs = null;
      _runState = 'running';
      await vDao.updateSessionPauseState(
        sessionId: widget.sessionId,
        state: 'running',
        pausedAtMs: null,
        pausedTotalMs: _pausedTotalMs,
      );
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _resetTimer() async {
    final vDao = VisionDao();
    final now = DateTime.now().millisecondsSinceEpoch;
    _startTsMs = now;
    _pausedTotalMs = 0;
    _pausedAtMs = null;
    _runState = 'running';

    await vDao.resetSessionTiming(sessionId: widget.sessionId, startTsMs: now);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onFinish({required bool auto}) async {
    if (!mounted) return;
    // 防止重复触发
    if (_runState == 'finished') return;

    final prevState = _runState;
    _runState = 'finished';
    _ticker?.cancel();

    final nowMs = (prevState == 'paused' && _pausedAtMs != null && _pausedAtMs! > 0)
        ? _pausedAtMs!
        : DateTime.now().millisecondsSinceEpoch;

    final endTsMs = auto ? (_startTsMs + _plannedMs + _pausedTotalMs) : nowMs;
    final elapsedMs = (endTsMs - _startTsMs).clamp(0, 1 << 62);

    // 实际专注分钟数：扣除暂停时长
    final effectiveMs = (elapsedMs - _pausedTotalMs).clamp(0, 1 << 62);
    final elapsedMinutes = (effectiveMs ~/ (60 * 1000)).clamp(0, widget.plannedMinutes);

    // 结束时收集未完成钩子 + 反思
    final result = await showDialog<_SessionEndResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SessionEndDialog(
        autoFinished: auto,
      ),
    );

    int? presenceScore;
    String? mood;
    String? note;
    String? hookText;
    String? nextAction;
    if (result != null) {
      presenceScore = result.presenceScore;
      mood = result.mood;
      note = result.note;
      hookText = result.hookText;
      nextAction = result.nextAction;
    }

    final vDao = VisionDao();
    final goalTitle = _goalTitle;
    final woopWish = _woopWish;

    await vDao.finishSession(
      sessionId: widget.sessionId,
      actualMinutes: elapsedMinutes,
      focusScore: presenceScore,
      moodTag: mood,
      hookText: hookText,
      nextAction: nextAction,
      goalTitle: goalTitle,
      woopWish: woopWish,
      taskTitle: widget.taskTitle,
    );

    if (presenceScore != null) {
      await vDao.addReflection(
        date: DateTime.now(),
        presenceScore: presenceScore,
        mood: mood,
        note: note,
        goalTitle: goalTitle,
        woopWish: woopWish,
        taskTitle: widget.taskTitle,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auto ? '专注时间结束啦' : '本次专注已结束'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('专注中')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final remaining = _calcRemaining();
    final progress = _calcProgress();
    final timeText = _fmt(remaining);

    final title = widget.taskTitle.isEmpty ? '未命名任务' : widget.taskTitle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('专注中'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_goalTitle.isNotEmpty)
                Text('所属愿景：$_goalTitle', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (_woopWish.isNotEmpty)
                Text('具体愿景：$_woopWish', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 18),

              // Pomodoro 风格圆盘
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(280, 280),
                      painter: _PomodoroDialPainter(progress: progress),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 64,
                          icon: Icon(_runState == 'paused' ? Icons.play_arrow : Icons.pause),
                          onPressed: _runState == 'finished' ? null : _togglePause,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          timeText,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text('POMODORO', style: TextStyle(fontSize: 12, letterSpacing: 1.2)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _runState == 'finished' ? null : _showThoughtDialog,
                child: const Text('记录弹出的念头'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('结束本次专注'),
                    onPressed: _runState == 'finished' ? null : () => _onFinish(auto: false),
                  ),
                  const SizedBox(width: 10),
                  if (_runState == 'paused')
                    TextButton(
                      onPressed: _resetTimer,
                      child: const Text('Reset'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showThoughtDialog() async {
    final result = await showDialog<ThoughtRecordResult>(
      context: context,
      builder: (context) => const ThoughtRecordDialog(),
    );
    final text = (result?.thought ?? '').trim();
    final selected = result?.selectedNodeUids ?? const <String>[];
    if (text.isNotEmpty) {
      // 保存念头：thought + 专注事项 + 愿景 + WOOP(具体愿景) + 日期
      final vDao = VisionDao();
      final goalTitle = _goalTitle;
      final woopWish = _woopWish;
      try {
        await vDao.addThought(
          thought: text,
          taskTitle: widget.taskTitle,
          goalTitle: goalTitle,
          woopWish: woopWish,
          nodeUids: selected,
        );
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已记录念头，稍后再看。')),
      );
    }
  }
}

class _PomodoroDialPainter extends CustomPainter {
  final double progress; // 0..1

  _PomodoroDialPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 12;

    // 外圈
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = Colors.blueGrey.withOpacity(0.35);

    canvas.drawCircle(center, radius, ringPaint);

    // 进度弧
    final progPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.blueGrey;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, sweep, false, progPaint);

    // 刻度
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.blueGrey.withOpacity(0.55);

    for (int i = 0; i < 60; i++) {
      if (i % 5 != 0) continue;
      final a = startAngle + (2 * math.pi) * (i / 60);
      final r1 = radius + 18;
      final r2 = radius + 28;
      final p1 = Offset(center.dx + r1 * math.cos(a), center.dy + r1 * math.sin(a));
      final p2 = Offset(center.dx + r2 * math.cos(a), center.dy + r2 * math.sin(a));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 内圈淡底
    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blueGrey.withOpacity(0.08);
    canvas.drawCircle(center, radius - 26, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _PomodoroDialPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SessionEndResult {
  final int presenceScore;
  final String mood;
  final String note;
  final String hookText;
  final String nextAction;

  _SessionEndResult({
    required this.presenceScore,
    required this.mood,
    required this.note,
    required this.hookText,
    required this.nextAction,
  });
}

class _SessionEndDialog extends StatefulWidget {
  final bool autoFinished;
  const _SessionEndDialog({required this.autoFinished});

  @override
  State<_SessionEndDialog> createState() => _SessionEndDialogState();
}

class _SessionEndDialogState extends State<_SessionEndDialog> {
  int _presence = 7;
  final TextEditingController _moodCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _hookCtrl = TextEditingController();
  final TextEditingController _nextActionCtrl = TextEditingController();

  @override
  void dispose() {
    _moodCtrl.dispose();
    _noteCtrl.dispose();
    _hookCtrl.dispose();
    _nextActionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.autoFinished ? '专注时间结束啦' : '本次专注结束'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('这件事今天在你大脑中的存在感有多高？（0~10）'),
            Slider(
              value: _presence.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$_presence',
              onChanged: (v) {
                setState(() {
                  _presence = v.round();
                });
              },
            ),
            TextField(
              controller: _moodCtrl,
              decoration: const InputDecoration(
                labelText: '此刻的情绪（例如：充实/紧张/焦虑/平静，可选）',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '简单写一句今天的感受（可选）',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hookCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '刻意停在一个中间节点（未完成钩子，可选）',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nextActionCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '下一次第一步要做什么（建议填写）',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('跳过'),
          onPressed: () {
            Navigator.of(context).pop(
              _SessionEndResult(
                presenceScore: _presence,
                mood: '',
                note: '',
                hookText: '',
                nextAction: '',
              ),
            );
          },
        ),
        ElevatedButton(
          child: const Text('保存'),
          onPressed: () {
            Navigator.of(context).pop(
              _SessionEndResult(
                presenceScore: _presence,
                mood: _moodCtrl.text.trim(),
                note: _noteCtrl.text.trim(),
                hookText: _hookCtrl.text.trim(),
                nextAction: _nextActionCtrl.text.trim(),
              ),
            );
          },
        ),
      ],
    );
  }
}
class MeditationPage extends StatelessWidget {
  const MeditationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('冥想'),
      ),
      body: const SizedBox.shrink(),
    );
  }
}

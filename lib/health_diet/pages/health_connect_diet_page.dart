import 'package:flutter/material.dart';

import '../models/health_connect_daily_summary.dart';
import '../services/health_connect_diet_context_service.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthConnectDietPage extends StatefulWidget {
  const HealthConnectDietPage({super.key});

  @override
  State<HealthConnectDietPage> createState() => _HealthConnectDietPageState();
}

class _HealthConnectDietPageState extends State<HealthConnectDietPage> with WidgetsBindingObserver {
  final _service = HealthConnectDietContextService();
  bool _loading = true;
  bool _syncing = false;
  HealthConnectStatus? _status;
  HealthConnectDailySummary? _summary;
  List<String> _hints = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final status = await _service.status();
    final summary = await _service.latestToday();
    if (!mounted) return;
    setState(() {
      _status = status;
      _summary = summary;
      _hints = _service.dietHintsFromSummary(summary);
      _loading = false;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _syncing = true);
    final status = await _service.requestPermissions();
    if (!mounted) return;
    setState(() {
      _status = status;
      _syncing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status.granted ? 'Health Connect 权限已授权' : (status.message ?? '权限未完全授权'))),
    );
  }

  Future<void> _syncToday() async {
    setState(() => _syncing = true);
    final summary = await _service.readAndSaveToday();
    final status = await _service.status();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _status = status;
      _hints = _service.dietHintsFromSummary(summary);
      _syncing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(summary.hasAnyData ? '已同步 Health Connect 数据' : (summary.message ?? '未读取到今日数据'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect 身体状态')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['Android Health Connect', '用户授权数据', '本地同步缓存'],
                    updatedAt: DateTime.now(),
                    note: '只有用户授权后才会读取；0 值需要结合“是否有数据”判断，不能简单等同真实身体状态。',
                  ),
                  _noticeCard(),
                  const SizedBox(height: 12),
                  _statusCard(),
                  const SizedBox(height: 12),
                  _summaryCard(),
                  const SizedBox(height: 12),
                  _hintCard(),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _syncing ? null : _syncToday,
                    icon: _syncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
                    label: const Text('同步 Health Connect 数据'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _syncing ? null : _requestPermissions,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('打开 Health Connect 授权/管理访问'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _noticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Text(
        '本页会读取 Health Connect 中已授权的数据：心率、步数、总消耗、睡眠、营养、血压、血氧饱和度、血糖、距离、身高、速度、锻炼、饮水量、体温、体脂、体重、功率、呼吸频率、基础代谢率等。没有数据写入的项目会显示“暂无”。',
        style: TextStyle(height: 1.5),
      ),
    );
  }

  Widget _statusCard() {
    final status = _status;
    final available = status?.available == true;
    final missing = (status?.raw['missingPermissions'] as Object?)?.toString();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(available ? Icons.health_and_safety_outlined : Icons.info_outline, color: available ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                const Text('连接状态', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(available ? 'Health Connect 可用' : 'Health Connect 暂不可用', style: const TextStyle(height: 1.45)),
            if (status?.message?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(status!.message!, style: const TextStyle(color: Colors.black54, height: 1.45)),
            ],
            const SizedBox(height: 6),
            Text('权限状态：${status?.granted == true ? '已全部授权' : '未完全授权'}', style: const TextStyle(color: Colors.black54)),
            if (missing != null && missing != '[]') ...[
              const SizedBox(height: 6),
              Text('仍缺少部分读取权限。请进入 Health Connect 授权页打开对应开关。', style: TextStyle(color: Colors.orange.shade700, height: 1.45)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final s = _summary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.monitor_heart_outlined, color: Colors.deepPurple), SizedBox(width: 8), Text('Health Connect 数据摘要', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            if (s == null)
              const Text('今天还没有同步身体状态。')
            else ...[
              _sectionTitle('活动与运动'),
              _metric('步数', s.steps == null ? '暂无' : '${s.steps} 步'),
              _metric('距离', _fmtDouble(s.extraDouble('distanceMeters'), suffix: ' m', decimals: 0)),
              _metric('运动', s.exerciseMinutes == null ? '暂无' : '${s.exerciseMinutes} 分钟'),
              _metric('锻炼类型', s.extraText('exerciseTypes') ?? '暂无'),
              _metric('速度', _fmtDouble(s.extraDouble('speedAvgMps'), suffix: ' m/s', decimals: 2)),
              _metric('功率', _fmtDouble(s.extraDouble('powerAvgWatts'), suffix: ' W', decimals: 0)),
              _metric('活动消耗', s.activeCalories == null ? '暂无' : '${s.activeCalories!.round()} kcal'),
              _metric('消耗的总卡路里', _fmtDouble(s.extraDouble('totalCalories'), suffix: ' kcal', decimals: 0)),
              const SizedBox(height: 10),
              _sectionTitle('睡眠与恢复'),
              _metric('睡眠', s.sleepMinutes == null ? '暂无' : _fmtMinutes(s.sleepMinutes!)),
              _metric('心率', _heartRateText(s)),
              _metric('静息心率', _fmtDouble(s.extraDouble('restingHeartRate') ?? s.restingHeartRate, suffix: ' bpm', decimals: 0)),
              _metric('呼吸频率', _fmtDouble(s.extraDouble('respiratoryRate'), suffix: ' 次/分', decimals: 1)),
              const SizedBox(height: 10),
              _sectionTitle('身体测量'),
              _metric('身高', _fmtDouble(s.extraDouble('heightCm'), suffix: ' cm', decimals: 1)),
              _metric('体重', s.weightKg == null ? '暂无' : '${s.weightKg!.toStringAsFixed(1)} kg'),
              _metric('体脂', _fmtDouble(s.extraDouble('bodyFatPercent'), suffix: ' %', decimals: 1)),
              _metric('体温', _fmtDouble(s.extraDouble('bodyTemperatureCelsius'), suffix: ' ℃', decimals: 1)),
              _metric('基础代谢率', _fmtDouble(s.extraDouble('basalMetabolicRateKcalDay'), suffix: ' kcal/日', decimals: 0)),
              const SizedBox(height: 10),
              _sectionTitle('健康指标'),
              _metric('血压', _bloodPressureText(s)),
              _metric('血氧饱和度', _fmtDouble(s.extraDouble('oxygenSaturationPercent'), suffix: ' %', decimals: 1)),
              _metric('血糖', _fmtDouble(s.extraDouble('bloodGlucoseMmolL'), suffix: ' mmol/L', decimals: 1)),
              const SizedBox(height: 10),
              _sectionTitle('营养与饮水'),
              _metric('饮水量', _fmtDouble(s.extraDouble('hydrationLiters'), suffix: ' L', decimals: 2)),
              _metric('营养摄入热量', _fmtDouble(s.extraDouble('nutritionCalories'), suffix: ' kcal', decimals: 0)),
              _metric('蛋白质', _fmtDouble(s.extraDouble('nutritionProteinG'), suffix: ' g', decimals: 1)),
              _metric('碳水', _fmtDouble(s.extraDouble('nutritionCarbsG'), suffix: ' g', decimals: 1)),
              _metric('脂肪', _fmtDouble(s.extraDouble('nutritionFatG'), suffix: ' g', decimals: 1)),
              _metric('糖', _fmtDouble(s.extraDouble('nutritionSugarG'), suffix: ' g', decimals: 1)),
              _metric('钠', _fmtDouble(s.extraDouble('nutritionSodiumMg'), suffix: ' mg', decimals: 0)),
              if (s.message?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(s.message!, style: const TextStyle(color: Colors.black54, height: 1.45)),
              ],
              if (s.extraMap['readErrors'] != null) ...[
                const SizedBox(height: 8),
                Text('部分数据类型读取失败，已跳过：${s.extraMap['readErrors']}', style: TextStyle(color: Colors.orange.shade700, height: 1.45)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _hintCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.restaurant_outlined, color: Colors.teal), SizedBox(width: 8), Text('饮食调节提示', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 10),
            if (_hints.isEmpty)
              const Text('同步后会根据睡眠、步数、运动、体重、营养和饮水等数据生成饮食调节提示。')
            else
              ..._hints.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $e', style: const TextStyle(height: 1.45)))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 108, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _heartRateText(HealthConnectDailySummary s) {
    final latest = s.extraDouble('heartRateBpm');
    final avg = s.extraDouble('heartRateAvgBpm');
    if (latest == null && avg == null) return '暂无';
    if (latest != null && avg != null) return '${latest.round()} bpm（今日均值 ${avg.round()} bpm）';
    return '${(latest ?? avg)!.round()} bpm';
  }

  String _bloodPressureText(HealthConnectDailySummary s) {
    final sys = s.extraDouble('bloodPressureSystolic');
    final dia = s.extraDouble('bloodPressureDiastolic');
    if (sys == null && dia == null) return '暂无';
    if (sys != null && dia != null) return '${sys.round()}/${dia.round()} mmHg';
    return '${sys?.round() ?? '-'} / ${dia?.round() ?? '-'} mmHg';
  }

  String _fmtDouble(double? value, {required String suffix, int decimals = 1}) {
    if (value == null) return '暂无';
    return '${value.toStringAsFixed(decimals)}$suffix';
  }

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '$m 分钟';
    if (m == 0) return '$h 小时';
    return '$h 小时 $m 分钟';
  }
}

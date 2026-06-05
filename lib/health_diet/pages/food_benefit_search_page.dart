import 'package:flutter/material.dart';

import '../models/health_profile.dart';
import '../models/normalized_food_item.dart';
import '../repositories/food_item_repository.dart';
import '../repositories/health_profile_repository.dart';
import '../services/health_diet_external_api_service.dart';
import '../widgets/health_diet_data_source_banner.dart';

class FoodBenefitSearchPage extends StatefulWidget {
  const FoodBenefitSearchPage({super.key});

  @override
  State<FoodBenefitSearchPage> createState() => _FoodBenefitSearchPageState();
}

class _FoodBenefitSearchPageState extends State<FoodBenefitSearchPage> {
  final _queryCtrl = TextEditingController();
  final _api = HealthDietExternalApiService();
  final _foodRepo = FoodItemRepository();
  final _profileRepo = HealthProfileRepository();

  bool _loading = false;
  String? _status;
  List<NormalizedFoodItem> _items = const [];
  HealthProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileRepo.latestProfile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _status = '正在从已配置的数据源查询食物营养……';
    });
    final items = await _api.searchFood(query, limit: 8);
    for (final item in items) {
      await _foodRepo.upsertFood(item);
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _status = items.isEmpty ? '未查询到可用食物数据。系统已自动尝试 USDA POST 查询、USDA 降级 GET 查询和 Open Food Facts；请换更具体关键词，或检查 API Key/网络。' : '已获取 ${items.length} 条食物数据；如果平台返回图片，已在结果卡片显示。英文中文化由设置页“外部平台英文结果用 AI 翻译”开关控制。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('食物利弊查询')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HealthDietDataSourceBanner(
            sources: const ['USDA FoodData Central', 'Open Food Facts', '本地营养缓存', '全局 AI 翻译可选'],
            updatedAt: DateTime.now(),
            note: '本页结果是动态 API 查询；返回为空时不代表食物不存在，可能是关键词、语言、额度或平台未收录。',
          ),
          _introCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '输入食物：鸡蛋、燕麦、牛奶、方便面……',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _loading ? null : _search, child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('查询')),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Text(_status!, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 14),
          if (_items.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('查询结果会显示在这里。')))
          else
            ..._items.map(_foodCard),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Text('这里不再只是本地占位：会使用 USDA / Open Food Facts 等数据源查询营养信息；如果平台返回图片会直接显示。英文名称、分类或配料是否调用 AI 翻译，由设置页“外部平台英文结果用 AI 翻译”独立控制。', style: TextStyle(height: 1.45)),
    );
  }

  Widget _foodCard(NormalizedFoodItem item) {
    final notes = _explain(item, _profile);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _foodImage(item),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if ((item.brand ?? '').trim().isNotEmpty) Text(item.brand!, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                Chip(label: Text(_sourceLabel(item.source))),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (item.caloriesKcal != null) _mini('热量', '${item.caloriesKcal!.round()} kcal'),
              if (item.proteinG != null) _mini('蛋白质', '${item.proteinG!.toStringAsFixed(1)}g'),
              if (item.fiberG != null) _mini('纤维', '${item.fiberG!.toStringAsFixed(1)}g'),
              if (item.sugarG != null) _mini('糖', '${item.sugarG!.toStringAsFixed(1)}g'),
              if (item.sodiumMg != null) _mini('钠', '${item.sodiumMg!.round()}mg'),
            ]),
            const SizedBox(height: 10),
            ...notes.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $e', style: const TextStyle(height: 1.35)))),
            if (item.ingredients.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('配料：${item.ingredients.take(8).join('、')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }


  Widget _foodImage(NormalizedFoodItem item) {
    final url = item.imageUrl?.trim();
    if (url == null || url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.green.withOpacity(0.12),
        child: const Icon(Icons.fastfood_outlined, color: Colors.green),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: 25,
          backgroundColor: Colors.green.withOpacity(0.12),
          child: const Icon(Icons.broken_image_outlined, color: Colors.green),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
            child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }

  Widget _mini(String label, String value) => Chip(label: Text('$label $value'), visualDensity: VisualDensity.compact);

  List<String> _explain(NormalizedFoodItem item, HealthProfile? profile) {
    final out = <String>[];
    if ((item.proteinG ?? 0) >= 10) out.add('蛋白质相对较高，可作为身体恢复、增肌或提高饱腹感的参考食物。');
    if ((item.fiberG ?? 0) >= 5) out.add('膳食纤维较高，对改善饮食结构和肠道规律有帮助。');
    if ((item.sugarG ?? 0) >= 10) out.add('糖含量偏高，控糖、减脂或容易疲劳后想喝甜饮的人应控制频率和份量。');
    if ((item.sodiumMg ?? 0) >= 400) out.add('钠含量偏高，血压偏高、低盐目标或经常外卖的人应谨慎。');
    if (item.healthTags.contains('ultra_processed')) out.add('加工程度可能较高，建议偶尔吃，不建议作为经常性正餐。');
    final conditions = profile?.conditions ?? const <String>[];
    if (conditions.contains('hypertension') && (item.sodiumMg ?? 0) >= 400) out.add('你的档案包含血压/低盐相关风险，这类高钠食物应优先减少汤汁、调料包或食用频率。');
    if (conditions.contains('diabetes_or_high_glucose') && (item.sugarG ?? 0) >= 10) out.add('你的档案包含血糖相关风险，甜饮/甜食类建议先从小份、少糖或替代品开始调整。');
    if (out.isEmpty) out.add('暂无明显风险标签；仍建议结合份量、烹饪方式和当天整体饮食结构判断。');
    out.add('更健康吃法：优先搭配蔬菜和优质蛋白，减少高糖饮料、高盐酱料和油炸做法。');
    return out;
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'usda':
        return 'USDA';
      case 'open_food_facts':
        return 'Open Food Facts';
      default:
        return source;
    }
  }
}

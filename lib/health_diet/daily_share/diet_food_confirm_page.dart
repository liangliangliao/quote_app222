import 'dart:io';

import 'package:flutter/material.dart';

import '../models/daily_diet_entry.dart';
import '../models/normalized_food_item.dart';
import '../widgets/health_diet_data_source_banner.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../repositories/food_item_repository.dart';
import '../services/diet_input_parser_service.dart';
import 'daily_diet_review_page.dart';

class DietFoodConfirmPage extends StatefulWidget {
  const DietFoodConfirmPage({
    super.key,
    required this.inputType,
    this.textDescription,
    this.voiceText,
    this.imagePaths = const [],
    this.barcode,
    this.initialFoods = const [],
  });

  final String inputType;
  final String? textDescription;
  final String? voiceText;
  final List<String> imagePaths;
  final String? barcode;
  final List<DetectedDietFood> initialFoods;

  @override
  State<DietFoodConfirmPage> createState() => _DietFoodConfirmPageState();
}

class _DietFoodConfirmPageState extends State<DietFoodConfirmPage> {
  final _repo = DailyDietEntryRepository();
  final _foodRepo = FoodItemRepository();
  final _parser = DietInputParserService();
  late List<DetectedDietFood> _foods;
  bool _saving = false;
  final Map<int, String> _foodImageUrls = <int, String>{};
  final Map<int, NormalizedFoodItem> _foodItems = <int, NormalizedFoodItem>{};
  DateTime _nutritionFetchedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _foods = widget.initialFoods.toList();
    if (_foods.isEmpty) {
      final text = [widget.textDescription, widget.voiceText].whereType<String>().join('，');
      _foods = _parser.parseText(text, source: widget.inputType).toList();
    }
    _loadFoodImages();
  }

  Future<void> _loadFoodImages() async {
    final ids = _foods.map((e) => e.normalizedFoodId).whereType<int>().where((e) => e > 0).toSet();
    if (ids.isEmpty) return;
    final next = <int, String>{};
    for (final id in ids) {
      final food = await _foodRepo.byId(id);
      final url = food?.imageUrl?.trim();
      if (food != null) {
        _foodItems[id] = food;
        if (url != null && url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
          next[id] = url;
        }
      }
    }
    if (mounted) {
      setState(() {
        _foodImageUrls.addAll(next);
        _nutritionFetchedAt = DateTime.now();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先添加并确认至少一个食物项；图片本身不会被当作食物自动分析。')));
      return;
    }
    if (_foods.every(_isUnresolvedBarcodeFood)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该条码未在公开食品库录入。请点食物卡片修改为真实食品名称，或返回上传包装正面/营养成分表照片后再识别。')));
      return;
    }
    setState(() => _saving = true);
    final confirmedFoods = _foods.map((e) => e.copyWith(confirmedByUser: true)).toList();
    final entryId = await _repo.createEntry(
      mealType: _inferMealType(confirmedFoods),
      inputType: widget.inputType,
      textDescription: widget.textDescription,
      voiceText: widget.voiceText,
      barcode: widget.barcode,
      foods: confirmedFoods,
      imagePaths: widget.imagePaths,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存今日饮食分享')));
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DailyDietReviewPage(entryId: entryId)));
  }

  bool _isUnresolvedBarcodeFood(DetectedDietFood food) {
    return food.source == 'barcode_not_found' || food.foodName.trim() == '条码未在公开库录入' || food.foodName.trim() == '未识别包装食品';
  }

  String _inferMealType(List<DetectedDietFood> foods) {
    final types = foods.map((e) => e.mealType).where((e) => e != 'unknown').toSet();
    if (types.length == 1) return types.first;
    if (types.isEmpty) return 'unknown';
    return 'mixed';
  }

  Future<void> _addFood() async {
    final result = await _editFoodDialog();
    if (result == null) return;
    setState(() => _foods.add(result));
  }

  Future<void> _editFood(int index) async {
    final result = await _editFoodDialog(food: _foods[index]);
    if (result == null) return;
    setState(() => _foods[index] = result);
  }

  Future<DetectedDietFood?> _editFoodDialog({DetectedDietFood? food}) async {
    final nameCtrl = TextEditingController(text: food?.foodName ?? '');
    final amountCtrl = TextEditingController(text: food?.amountText ?? '');
    var mealType = food?.mealType ?? 'unknown';
    return showDialog<DetectedDietFood>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(food == null ? '添加食物' : '修改食物'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '食物名称', hintText: '例如：鸡蛋、奶茶、黄焖鸡米饭'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: '份量描述', hintText: '例如：1杯、2个、约1份'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: mealType,
                decoration: const InputDecoration(labelText: '餐次'),
                items: _mealOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setDialogState(() => mealType = v ?? 'unknown'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context).pop(DetectedDietFood(
                  foodName: name,
                  amountText: amountCtrl.text.trim().isEmpty ? null : amountCtrl.text.trim(),
                  mealType: mealType,
                  confidenceScore: 1.0,
                  confirmedByUser: true,
                  source: 'manual_confirm',
                ));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('确认饮食记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          HealthDietDataSourceBanner(
            sources: _confirmPageSources(),
            updatedAt: _nutritionFetchedAt,
            note: '本页只展示系统识别和营养补全结果，保存前请确认名称、份量和餐次；动态数据与本地规则会进入后续复盘。',
          ),
          _noticeCard(),
          if (widget.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 14),
            _imagePreview(),
          ],
          const SizedBox(height: 14),
          _nutritionSummaryCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Text('系统识别/解析到的食物', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              TextButton.icon(onPressed: _addFood, icon: const Icon(Icons.add), label: const Text('添加')),
            ],
          ),
          if (_foods.isEmpty)
            _emptyFoodCard()
          else
            ...List.generate(_foods.length, (index) => _foodTile(index)),
          const SizedBox(height: 16),
          if ((widget.textDescription ?? widget.voiceText ?? '').trim().isNotEmpty) _rawTextCard(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            label: Text(_saving ? '保存中...' : '确认并生成基础复盘'),
          ),
        ),
      ),
    );
  }


  List<String> _confirmPageSources() {
    final set = <String>{'用户确认', '本地图片/文字'};
    for (final food in _foods) {
      if (food.source.contains('ai')) set.add('全局 AI Provider');
      if (food.source.contains('usda')) set.add('USDA FoodData Central');
      if (food.source.contains('ai_nutrition_estimate')) set.add('AI 营养粗估');
      if (food.source.contains('open_food_facts')) set.add('Open Food Facts');
      if (food.source.contains('juhe')) set.add('聚合数据条码');
      if (food.source.contains('tanshu')) set.add('探数条码/成分');
      if (food.source.contains('china_barcode')) set.add('自定义国内条码');
    }
    if (_foodItems.isNotEmpty) set.add('本地营养缓存 food_items');
    return set.toList();
  }

  Widget _nutritionSummaryCard() {
    final totals = _nutritionTotals();
    final matched = _foods.where((f) => f.normalizedFoodId != null && _foodItems.containsKey(f.normalizedFoodId)).length;
    final externalMatched = _foods.where((f) => f.normalizedFoodId != null && _foodItems.containsKey(f.normalizedFoodId) && !_foodItems[f.normalizedFoodId]!.source.contains('ai_nutrition_estimate')).length;
    final aiEstimated = _foods.where((f) => f.normalizedFoodId != null && _foodItems.containsKey(f.normalizedFoodId) && _foodItems[f.normalizedFoodId]!.source.contains('ai_nutrition_estimate')).length;
    final unmatched = _foods.length - matched;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              const Expanded(child: Text('本次食物能量与营养粗估', style: TextStyle(fontWeight: FontWeight.bold))),
              Text('$matched/${_foods.length} 有营养数据', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '总计：${_fmt(totals.calories, 'kcal')} · 蛋白质 ${_fmt(totals.protein, 'g')} · 碳水 ${_fmt(totals.carbs, 'g')} · 脂肪 ${_fmt(totals.fat, 'g')} · 纤维 ${_fmt(totals.fiber, 'g')} · 糖 ${_fmt(totals.sugar, 'g')} · 钠 ${_fmt(totals.sodium, 'mg')}',
            style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _sourceChip('外部营养源 $externalMatched', const Color(0xFFDCFCE7), const Color(0xFF166534)),
              _sourceChip('AI 粗估 $aiEstimated', const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
              if (unmatched > 0) _sourceChip('仍无数据 $unmatched', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '说明：外部营养源优先来自 USDA / Open Food Facts / 国内条码接口 / 本地缓存；外部未命中时，系统会调用 AI 按图片、名称和份量做保守粗估。AI 粗估会被明确标记，可信度低于权威营养数据库，但可避免复盘全部显示 0 kcal。',
            style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
          ),
        ],
      ),
    );
  }


  Widget _sourceChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
    );
  }

  String _nutritionLine(DetectedDietFood food) {
    final item = food.normalizedFoodId == null ? null : _foodItems[food.normalizedFoodId!];
    if (item == null) return '营养：暂无外部营养匹配，保存后仍可进入复盘，但可信度较低。';
    final aiEstimate = item.source.contains('ai_nutrition_estimate') || item.dataQuality.contains('ai_estimate');
    final grams = _estimateGrams(food, item);
    final factor = grams / 100.0;
    String part(String label, double? value, String unit) => value == null ? '' : '$label ${_fmt(value * factor, unit)}';
    final parts = [
      part('约', item.caloriesKcal, 'kcal'),
      part('蛋白质', item.proteinG, 'g'),
      part('碳水', item.carbsG, 'g'),
      part('脂肪', item.fatG, 'g'),
      part('钠', item.sodiumMg, 'mg'),
    ].where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '营养：已匹配 ${_sourceLabel(item.source)}，但该源未提供可用营养数值。';
    final prefix = aiEstimate ? 'AI 营养粗估' : '外部营养粗估';
    final confidence = aiEstimate ? _aiEstimateMeta(item) : '';
    return '$prefix（按${grams.round()}g）：${parts.join(' · ')}$confidence';
  }

  _NutritionTotals _nutritionTotals() {
    final t = _NutritionTotals();
    for (final food in _foods) {
      final item = food.normalizedFoodId == null ? null : _foodItems[food.normalizedFoodId!];
      if (item == null) continue;
      final factor = _estimateGrams(food, item) / 100.0;
      t.calories += (item.caloriesKcal ?? 0) * factor;
      t.protein += (item.proteinG ?? 0) * factor;
      t.fat += (item.fatG ?? 0) * factor;
      t.carbs += (item.carbsG ?? 0) * factor;
      t.fiber += (item.fiberG ?? 0) * factor;
      t.sugar += (item.sugarG ?? 0) * factor;
      t.sodium += (item.sodiumMg ?? 0) * factor;
    }
    return t;
  }


  String _aiEstimateMeta(NormalizedFoodItem item) {
    final confidence = item.raw['confidence'];
    final reason = (item.raw['reason'] ?? '').toString().trim();
    final confText = confidence == null ? '' : '；可信度 ${confidence.toString()}';
    final reasonText = reason.isEmpty ? '' : '；$reason';
    return '$confText$reasonText';
  }

  double _estimateGrams(DetectedDietFood food, NormalizedFoodItem item) {
    if (food.estimatedGrams != null && food.estimatedGrams! > 0) return food.estimatedGrams!;
    final amount = (food.amountText ?? '').trim();
    final direct = RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|克)').firstMatch(amount);
    if (direct != null) return double.tryParse(direct.group(1)!) ?? 100;
    final count = double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(amount)?.group(1) ?? '');
    final serving = item.servingSizeG;
    if (count != null && serving != null && serving > 0) return count * serving;
    if (serving != null && serving > 0) return serving;
    if (amount.contains('半')) return 50;
    if (amount.contains('碗')) return 250;
    if (amount.contains('杯')) return 250;
    if (amount.contains('包')) return 100;
    if (amount.contains('个')) return 80;
    return 100;
  }

  String _fmt(double value, String unit) {
    if (unit == 'mg') return '${value.round()}$unit';
    if (unit == 'kcal') return '${value.round()} $unit';
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}$unit';
  }

  Widget _noticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Text(
        '请先确认食物名称、份量和餐次。现在已接入：文字/语音 AI 解析、图片 AI 识别、条形码 Open Food Facts + 国内候选源、USDA/Open Food Facts/国内接口营养补全。若同一条码出现多个数据源候选，请只保留最准确的一项，删除错误或重复候选。若条码未收录，不能直接保存为食品，请手动修改真实名称，或返回上传包装图后再识别。',
        style: TextStyle(height: 1.45),
      ),
    );
  }

  Widget _imagePreview() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.imagePaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(File(widget.imagePaths[index]), width: 112, height: 112, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _emptyFoodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('还没有食物项', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('图片记录目前需要你手动添加食物。未添加食物时不能保存，这样可以避免出现“明年”等无关内容被当成食物分析。'),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _addFood, icon: const Icon(Icons.add), label: const Text('手动添加食物')),
          ],
        ),
      ),
    );
  }

  Widget _foodTile(int index) {
    final food = _foods[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: _foodLeading(food, index),
        title: Text(food.foodName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_mealLabel(food.mealType)} · ${food.amountText?.isNotEmpty == true ? food.amountText : '份量未确认'} · 来源：${_sourceLabel(food.source)}'),
            const SizedBox(height: 4),
            Text(_nutritionLine(food), style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editFood(index);
            if (v == 'delete') setState(() => _foods.removeAt(index));
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('修改')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () => _editFood(index),
      ),
    );
  }


  Widget _foodLeading(DetectedDietFood food, int index) {
    final url = food.normalizedFoodId == null ? null : _foodImageUrls[food.normalizedFoodId!];
    if (url == null || url.isEmpty) {
      if (widget.imagePaths.isNotEmpty && File(widget.imagePaths.first).existsSync()) {
        return ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(widget.imagePaths.first), width: 48, height: 48, fit: BoxFit.cover));
      }
      return CircleAvatar(child: Text('${index + 1}'));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(child: Text('${index + 1}')),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return CircleAvatar(child: Text('${index + 1}'));
        },
      ),
    );
  }

  Widget _rawTextCard() {
    final text = widget.voiceText?.trim().isNotEmpty == true ? widget.voiceText!.trim() : (widget.textDescription ?? '').trim();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('原始描述'),
      children: [
        Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(height: 1.45))),
      ],
    );
  }

  String _mealLabel(String type) => _mealOptions[type] ?? '未知餐次';

  String _sourceLabel(String source) {
    if (source.contains('ai_nutrition_estimate') && source.startsWith('ai_image')) return 'AI 图片识别 + AI 营养粗估';
    if (source.contains('ai_nutrition_estimate') && source.startsWith('ai_text')) return 'AI 文字解析 + AI 营养粗估';
    if (source.contains('ai_nutrition_estimate') && source.startsWith('ai_voice')) return 'AI 语音解析 + AI 营养粗估';
    if (source.contains('ai_nutrition_estimate') && source.startsWith('barcode_ai_image')) return '条码+AI 包装图 + AI 营养粗估';
    if (source.startsWith('barcode_ai_image')) return '条码+AI 包装图';
    if (source.startsWith('ai_image')) return 'AI 图片识别';
    if (source.contains('open_food_facts')) return 'Open Food Facts';
    if (source.contains('juhe')) return '聚合数据条码';
    if (source.contains('tanshu')) return '探数条码/成分';
    if (source.contains('china_barcode')) return '国内条码接口';
    if (source.contains('usda')) return 'USDA 营养补全';
    if (source.contains('ai_nutrition_estimate')) return 'AI 营养粗估';
    switch (source) {
      case 'text':
        return '文字解析';
      case 'voice':
        return '语音转文字';
      case 'manual_confirm':
        return '手动确认';
      case 'image':
        return '图片记录';
      case 'mixed':
        return '混合记录';
      case 'barcode_placeholder':
        return '条码占位';
      case 'barcode_not_found':
        return '条码未收录';
      case 'barcode_ai_image':
        return '条码+AI 包装图';
      case 'open_food_facts_barcode':
        return 'Open Food Facts 条码';
      case 'juhe_barcode':
      case 'juhe_barcode_barcode':
        return '聚合数据条码';
      case 'tanshu_barcode':
      case 'tanshu_barcode_barcode':
        return '探数条码';
      case 'tanshu_barcode_nutrition':
      case 'tanshu_barcode_nutrition_barcode':
        return '探数成分';
      case 'china_barcode_custom':
      case 'china_barcode_custom_barcode':
        return '自定义国内条码';
      case 'ai_image':
        return 'AI 图片识别';
      case 'ai_text':
        return 'AI 文字解析';
      case 'ai_voice':
        return 'AI 语音解析';
      default:
        return source;
    }
  }
}

const Map<String, String> _mealOptions = {
  'breakfast': '早餐',
  'lunch': '午餐',
  'dinner': '晚餐',
  'snack': '加餐/零食',
  'drink': '饮品',
  'mixed': '多餐混合',
  'unknown': '未知餐次',
};

class _NutritionTotals {
  double calories = 0;
  double protein = 0;
  double fat = 0;
  double carbs = 0;
  double fiber = 0;
  double sugar = 0;
  double sodium = 0;
}

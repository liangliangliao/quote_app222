import 'package:flutter/material.dart';

import '../models/daily_diet_entry.dart';
import '../models/grocery_list.dart';
import '../models/health_profile.dart';
import '../models/normalized_recipe.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../repositories/grocery_list_repository.dart';
import '../repositories/health_profile_repository.dart';
import '../repositories/healthy_recipe_repository.dart';
import '../services/health_diet_options.dart';
import '../services/healthy_recipe_recommendation_service.dart';
import 'grocery_list_page.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthyRecipeDetailPage extends StatefulWidget {
  const HealthyRecipeDetailPage({super.key, required this.recipe});

  final NormalizedRecipe recipe;

  @override
  State<HealthyRecipeDetailPage> createState() => _HealthyRecipeDetailPageState();
}

class _HealthyRecipeDetailPageState extends State<HealthyRecipeDetailPage> {
  final _profileRepo = HealthProfileRepository();
  final _recipeRepo = HealthyRecipeRepository();
  final _groceryRepo = GroceryListRepository();
  final _entryRepo = DailyDietEntryRepository();
  final _service = HealthyRecipeRecommendationService();

  HealthProfile? _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileRepo.latestProfile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _saveRecipe() async {
    setState(() => _saving = true);
    await _recipeRepo.upsertRecipe(widget.recipe);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到健康菜谱')));
  }

  Future<void> _createGroceryList() async {
    final items = _service.buildShoppingItems(widget.recipe).asMap().entries.map((entry) {
      final parsed = _splitIngredient(entry.value);
      return GroceryListItem(itemName: parsed.$1, amountText: parsed.$2, sortOrder: entry.key);
    }).toList();
    final listId = await _groceryRepo.createFromRecipe(recipe: widget.recipe, items: items);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroceryListPage(initialListId: listId)));
  }

  Future<void> _addToTodayDiet() async {
    final mealType = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('加入到哪一餐？', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final item in const [
              ('breakfast', '早餐'),
              ('lunch', '午餐'),
              ('dinner', '晚餐'),
              ('snack', '加餐/夜宵'),
            ])
              ListTile(
                leading: const Icon(Icons.restaurant_outlined),
                title: Text(item.$2),
                onTap: () => Navigator.of(context).pop(item.$1),
              ),
          ],
        ),
      ),
    );
    if (mealType == null) return;
    await _entryRepo.createEntry(
      mealType: mealType,
      inputType: 'recipe',
      textDescription: '来自健康菜谱：${widget.recipe.title}',
      foods: [
        DetectedDietFood(
          foodName: widget.recipe.title,
          amountText: '${widget.recipe.servings ?? 1}份',
          mealType: mealType,
          cookingMethod: 'healthy_recipe',
          confidenceScore: 1,
          confirmedByUser: true,
          source: 'recipe',
        ),
      ],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入今日饮食记录')));
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final suggestions = _service.healthChangeSuggestions(recipe, _profile);
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康菜谱详情'),
        actions: [
          IconButton(
            tooltip: '保存菜谱',
            onPressed: _saving ? null : _saveRecipe,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bookmark_add_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          HealthDietDataSourceBanner(
            sources: [recipe.source, '本地菜谱缓存', '健康档案'],
            updatedAt: DateTime.now(),
            note: '菜谱详情保留来源和获取时间；营养值来自菜谱平台或本地估算，加入今日饮食后仍需确认实际份量。',
          ),
          _titleCard(recipe),
          const SizedBox(height: 12),
          _quickActions(),
          const SizedBox(height: 12),
          _nutritionCard(recipe),
          const SizedBox(height: 12),
          _sectionCard('食材清单', Icons.shopping_basket_outlined, recipe.ingredients),
          const SizedBox(height: 12),
          _stepsCard(recipe.steps),
          const SizedBox(height: 12),
          _sectionCard('健康改造建议', Icons.health_and_safety_outlined, suggestions),
          if (recipe.cautions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _cautionCard(recipe.cautions),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createGroceryList,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('购物清单'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _addToTodayDiet,
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('加入今日饮食'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleCard(NormalizedRecipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasImage(recipe.imageUrl)) ...[
            _heroImage(recipe.imageUrl!),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const Icon(Icons.restaurant_menu, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(recipe.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 10),
          Text(_summaryText(recipe), style: const TextStyle(height: 1.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (recipe.readyMinutes != null) Chip(label: Text('${recipe.readyMinutes}分钟')),
              if (recipe.servings != null) Chip(label: Text('${recipe.servings}人份')),
              ...recipe.healthTags.take(4).map((e) => Chip(label: Text(_label(e)))),
            ],
          ),
        ],
      ),
    );
  }


  bool _hasImage(String? url) {
    final v = url?.trim();
    return v != null && v.isNotEmpty && (v.startsWith('http://') || v.startsWith('https://'));
  }

  Widget _heroImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.broken_image_outlined, color: Colors.black45),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(18)),
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saveRecipe,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('保存'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _createGroceryList,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('购物清单'),
          ),
        ),
      ],
    );
  }

  Widget _nutritionCard(NormalizedRecipe recipe) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.analytics_outlined, color: Colors.teal), SizedBox(width: 8), Text('营养估算', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _nutrientChip('热量', recipe.caloriesKcal, 'kcal'),
                _nutrientChip('蛋白质', recipe.proteinG, 'g'),
                _nutrientChip('脂肪', recipe.fatG, 'g'),
                _nutrientChip('碳水', recipe.carbsG, 'g'),
                _nutrientChip('钠', recipe.sodiumMg, 'mg'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('说明：当前为本地菜谱指导估算，后续接入 USDA、薄荷、Edamam/Spoonacular 后可替换为更精确营养数据。', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _nutrientChip(String label, double? value, String unit) {
    final text = value == null ? '暂无' : '${value.round()}$unit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
      child: Text('$label $text'),
    );
  }

  Widget _sectionCard(String title, IconData icon, List<String> items) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.green), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 10),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $e', style: const TextStyle(height: 1.45)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _stepsCard(List<String> steps) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.format_list_numbered_outlined, color: Colors.blueGrey), SizedBox(width: 8), Text('制作步骤', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 13, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(steps[i], style: const TextStyle(height: 1.45))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cautionCard(List<String> cautions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.warning_amber_outlined, color: Colors.orange), SizedBox(width: 8), Text('谨慎提示', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          ...cautions.map((e) => Text('• $e', style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }

  String _summaryText(NormalizedRecipe recipe) {
    final goal = _profile == null ? '你的健康目标' : HealthDietOptions.labelOf(HealthDietOptions.goals, _profile!.mainGoal);
    return '这道菜适合作为“$goal”的可执行饮食选择。它的重点不是追求复杂做法，而是把蛋白质、蔬菜、主食和低油低盐做法组织成一餐。';
  }

  String _label(String code) {
    final goal = HealthDietOptions.labelOf(HealthDietOptions.goals, code);
    if (goal != code) return goal;
    switch (code) {
      case 'fiber_boost':
        return '高纤维';
      case 'anemia_support':
        return '铁营养支持';
      default:
        return code;
    }
  }

  (String, String?) _splitIngredient(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return (value.trim(), null);
    return (parts.first, parts.sublist(1).join(' '));
  }
}

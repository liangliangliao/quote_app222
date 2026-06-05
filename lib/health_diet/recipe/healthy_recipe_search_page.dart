import 'dart:async';

import 'package:flutter/material.dart';

import '../models/health_profile.dart';
import '../models/normalized_recipe.dart';
import '../repositories/health_profile_repository.dart';
import '../repositories/healthy_recipe_repository.dart';
import '../services/health_diet_options.dart';
import '../services/healthy_recipe_recommendation_service.dart';
import '../services/health_diet_core_orchestrator.dart';
import 'healthy_recipe_detail_page.dart';
import 'grocery_list_page.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthyRecipeSearchPage extends StatefulWidget {
  const HealthyRecipeSearchPage({super.key, this.initialGoal, this.initialQuery, this.title = '健康菜谱制作'});

  final String? initialGoal;
  final String? initialQuery;
  final String title;

  @override
  State<HealthyRecipeSearchPage> createState() => _HealthyRecipeSearchPageState();
}

class _HealthyRecipeSearchPageState extends State<HealthyRecipeSearchPage> {
  final _profileRepo = HealthProfileRepository();
  final _recipeRepo = HealthyRecipeRepository();
  final _service = HealthyRecipeRecommendationService();
  final _orchestrator = HealthDietCoreOrchestrator();
  final _queryController = TextEditingController();

  HealthProfile? _profile;
  String _goal = 'balanced';
  List<NormalizedRecipe> _recipes = const [];
  List<NormalizedRecipe> _savedRecipes = const [];
  bool _loading = true;
  bool _onlineLoading = false;
  String? _onlineStatus;
  Timer? _searchDebounce;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _queryController.text = initialQuery;
    }
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _profileRepo.latestProfile();
    final goal = widget.initialGoal ?? profile?.mainGoal ?? 'balanced';
    final saved = await _recipeRepo.savedRecipes(limit: 20);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _goal = goal;
      _savedRecipes = saved;
      _loading = false;
    });
    await _refreshResults();
  }

  Future<void> _refreshResults({bool fetchOnline = true}) async {
    final token = ++_refreshToken;
    final queryText = _queryController.text;
    final local = _service.searchRecipes(query: queryText, profile: _profile, goalCode: _goal);
    if (!mounted || token != _refreshToken) return;
    setState(() {
      _recipes = local;
      _onlineLoading = fetchOnline;
      _onlineStatus = fetchOnline ? '正在尝试从 Spoonacular / Edamam 拉取在线菜谱……' : _onlineStatus;
    });
    if (!fetchOnline) return;

    final query = queryText.trim().isEmpty ? HealthDietOptions.labelOf(HealthDietOptions.goals, _goal) : queryText.trim();
    try {
      final online = await _orchestrator
          .searchOnlineRecipes(query, healthTags: [_goal], limit: 8)
          .timeout(const Duration(seconds: 45), onTimeout: () => <NormalizedRecipe>[]);
      if (!mounted || token != _refreshToken) return;
      final merged = <NormalizedRecipe>[...online, ...local];
      final seen = <String>{};
      final deduped = <NormalizedRecipe>[];
      for (final recipe in merged) {
        final key = '${recipe.source}:${recipe.sourceId}:${recipe.title}'.toLowerCase();
        if (seen.add(key)) deduped.add(recipe);
      }
      setState(() {
        _recipes = deduped;
        _onlineLoading = false;
        _onlineStatus = online.isEmpty
            ? '暂未获取到在线菜谱，已显示本地保底菜谱。可能是平台无匹配结果、密钥/网络问题，或请求超时。'
            : '已合并 ${online.length} 条在线菜谱与本地保底菜谱。';
      });
    } catch (e) {
      if (!mounted || token != _refreshToken) return;
      setState(() {
        _onlineLoading = false;
        _onlineStatus = '在线菜谱拉取失败，已显示本地保底菜谱：$e';
      });
    }
  }

  void _scheduleRefresh() {
    _searchDebounce?.cancel();
    _refreshResults(fetchOnline: false);
    _searchDebounce = Timer(const Duration(milliseconds: 650), () {
      if (mounted) _refreshResults(fetchOnline: true);
    });
  }

  Future<void> _openRecipe(NormalizedRecipe recipe) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HealthyRecipeDetailPage(recipe: recipe)));
    final saved = await _recipeRepo.savedRecipes(limit: 20);
    if (mounted) setState(() => _savedRecipes = saved);
  }

  Future<void> _openGroceryLists() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroceryListPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '购物清单',
            onPressed: _openGroceryLists,
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['本地保底菜谱', 'Spoonacular', 'Edamam', '复盘菜谱需求', '健康档案'],
                    updatedAt: DateTime.now(),
                    note: '在线菜谱可能返回英文或空结果；系统会保留来源，并用本地菜谱兜底。',
                  ),
                  _introCard(),
                  const SizedBox(height: 12),
                  _searchBox(),
                  const SizedBox(height: 12),
                  _goalChips(),
                  if (_savedRecipes.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionTitle('已保存菜谱'),
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) => _savedRecipeCard(_savedRecipes[index]),
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemCount: _savedRecipes.length,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_onlineStatus != null) ...[
                    const SizedBox(height: 10),
                    _apiStatusCard(),
                  ],
                  _sectionTitle('推荐菜谱'),
                  if (_recipes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('暂时没有匹配菜谱。可以换一个目标，或清空搜索词。'),
                      ),
                    )
                  else
                    ..._recipes.map(_recipeCard),
                ],
              ),
            ),
    );
  }

  Widget _introCard() {
    final goalLabel = HealthDietOptions.labelOf(HealthDietOptions.goals, _goal);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          const Row(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.deepOrange),
              SizedBox(width: 8),
              Expanded(child: Text('把饮食建议变成可执行的一餐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          Text('当前按“$goalLabel”优先推荐。菜谱会结合你的过敏、忌口和健康状况做基础过滤，并提供健康改造、购物清单和“加入今日饮食”。', style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      controller: _queryController,
      onChanged: (_) => _scheduleRefresh(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: '搜索：山药、低盐、高蛋白、粥、豆腐……',
        suffixIcon: _queryController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () async {
                  _queryController.clear();
                  await _refreshResults(fetchOnline: true);
                },
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _goalChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: HealthDietOptions.goals.map((goal) {
          final selected = goal.code == _goal;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(goal.label),
              selected: selected,
              onSelected: (_) async {
                setState(() => _goal = goal.code);
                await _refreshResults(fetchOnline: true);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _savedRecipeCard(NormalizedRecipe recipe) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openRecipe(recipe),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _recipeThumb(recipe, width: double.infinity, height: 52, radius: 12, small: true),
            const Spacer(),
            Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_metaText(recipe), style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _recipeCard(NormalizedRecipe recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openRecipe(recipe),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _recipeThumb(recipe, width: 58, height: 58, radius: 14),
                  const SizedBox(width: 10),
                  Expanded(child: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Text(_metaText(recipe), style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...recipe.healthTags.take(3).map((tag) => Chip(label: Text(_goalOrTagLabel(tag)), visualDensity: VisualDensity.compact)),
                  ...recipe.dietTags.take(2).map((tag) => Chip(label: Text(_goalOrTagLabel(tag)), visualDensity: VisualDensity.compact)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _recipeThumb(NormalizedRecipe recipe, {required double width, required double height, double radius = 14, bool small = false}) {
    final url = recipe.imageUrl?.trim();
    if (url == null || url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: small ? Colors.deepPurple.withOpacity(0.10) : Colors.deepOrange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(small ? Icons.bookmark_added_outlined : Icons.restaurant_menu, color: small ? Colors.deepPurple : Colors.deepOrange),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(radius)),
          child: const Icon(Icons.broken_image_outlined, color: Colors.black45),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(radius)),
            child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }

  Widget _apiStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (_onlineLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.cloud_done_outlined, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(child: Text(_onlineStatus ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.35))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  String _metaText(NormalizedRecipe recipe) {
    final parts = <String>[];
    if (recipe.readyMinutes != null) parts.add('${recipe.readyMinutes}分钟');
    if (recipe.caloriesKcal != null) parts.add('${recipe.caloriesKcal!.round()} kcal');
    if (recipe.proteinG != null) parts.add('蛋白质 ${recipe.proteinG!.round()}g');
    if (recipe.sodiumMg != null) parts.add('钠 ${recipe.sodiumMg!.round()}mg');
    return parts.join(' · ');
  }

  String _goalOrTagLabel(String code) {
    final goal = HealthDietOptions.labelOf(HealthDietOptions.goals, code);
    if (goal != code) return goal;
    switch (code) {
      case 'fiber_boost':
        return '高纤维';
      case 'anemia_support':
        return '铁营养支持';
      case 'light_taste':
        return '清淡';
      case 'quick_meal':
        return '快手';
      case 'chinese_food':
        return '家常中餐';
      case 'meal_prep':
        return '适合备餐';
      case 'no_cook':
        return '无需开火';
      case 'rice_cooker':
        return '电饭煲友好';
      case 'vegetarian':
        return '素食';
      default:
        return code;
    }
  }
}

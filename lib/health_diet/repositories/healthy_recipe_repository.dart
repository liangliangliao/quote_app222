import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../../utils/debug_logger.dart';
import '../models/normalized_recipe.dart';

class HealthyRecipeRepository {
  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  Future<int> upsertRecipe(NormalizedRecipe recipe) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'healthy_recipes',
      columns: ['id'],
      where: 'source = ? AND source_recipe_id = ?',
      whereArgs: [recipe.source, recipe.sourceId],
      limit: 1,
    );
    final raw = Map<String, dynamic>.from(recipe.raw);
    raw['ingredients'] = recipe.ingredients;
    raw['steps'] = recipe.steps;
    raw['cautions'] = recipe.cautions;
    raw['data_quality'] = recipe.dataQuality;

    final row = {
      'source': recipe.source,
      'source_recipe_id': recipe.sourceId,
      'title': recipe.title,
      'image_url': recipe.imageUrl,
      'health_tags': jsonEncode(recipe.healthTags),
      'diet_tags': jsonEncode(recipe.dietTags),
      'calories_kcal': recipe.caloriesKcal,
      'protein_g': recipe.proteinG,
      'fat_g': recipe.fatG,
      'carbs_g': recipe.carbsG,
      'sodium_mg': recipe.sodiumMg,
      'ready_minutes': recipe.readyMinutes,
      'servings': recipe.servings,
      'raw_json': jsonEncode(raw),
      'updated_at': now,
    };

    int id;
    if (existing.isEmpty) {
      id = await db.insert('healthy_recipes', {...row, 'created_at': now});
    } else {
      id = int.tryParse(existing.first['id'].toString()) ?? 0;
      await db.update('healthy_recipes', row, where: 'id = ?', whereArgs: [id]);
    }

    await db.delete('recipe_steps', where: 'recipe_id = ?', whereArgs: [id]);
    for (var i = 0; i < recipe.steps.length; i++) {
      await db.insert('recipe_steps', {
        'recipe_id': id,
        'step_index': i + 1,
        'instruction': recipe.steps[i],
        'ingredients_json': jsonEncode(recipe.ingredients),
        'equipment_json': jsonEncode(const <String>[]),
      });
    }
    await DLog.i('health_diet.recipe', '健康菜谱已保存 recipeId=$id title=${recipe.title}');
    return id;
  }

  Future<List<NormalizedRecipe>> savedRecipes({int limit = 50}) async {
    final db = await _db();
    final rows = await db.query('healthy_recipes', orderBy: 'updated_at DESC, id DESC', limit: limit);
    return rows.map(_recipeFromRow).toList();
  }

  Future<NormalizedRecipe?> recipeBySource(String source, String sourceId) async {
    final db = await _db();
    final rows = await db.query(
      'healthy_recipes',
      where: 'source = ? AND source_recipe_id = ?',
      whereArgs: [source, sourceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _recipeFromRow(rows.first);
  }

  NormalizedRecipe _recipeFromRow(Map<String, Object?> row) {
    Map<String, dynamic> raw = const <String, dynamic>{};
    try {
      raw = jsonDecode((row['raw_json'] ?? '{}').toString()) as Map<String, dynamic>;
    } catch (_) {}
    List<String> decodeList(Object? value) {
      if (value == null) return const [];
      try {
        final decoded = jsonDecode(value.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return const [];
    }

    return NormalizedRecipe(
      source: (row['source'] ?? '').toString(),
      sourceId: (row['source_recipe_id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      imageUrl: row['image_url']?.toString(),
      ingredients: (raw['ingredients'] is List) ? (raw['ingredients'] as List).map((e) => e.toString()).toList() : const [],
      steps: (raw['steps'] is List) ? (raw['steps'] as List).map((e) => e.toString()).toList() : const [],
      healthTags: decodeList(row['health_tags']),
      dietTags: decodeList(row['diet_tags']),
      cautions: (raw['cautions'] is List) ? (raw['cautions'] as List).map((e) => e.toString()).toList() : const [],
      caloriesKcal: double.tryParse((row['calories_kcal'] ?? '').toString()),
      proteinG: double.tryParse((row['protein_g'] ?? '').toString()),
      fatG: double.tryParse((row['fat_g'] ?? '').toString()),
      carbsG: double.tryParse((row['carbs_g'] ?? '').toString()),
      sodiumMg: double.tryParse((row['sodium_mg'] ?? '').toString()),
      readyMinutes: int.tryParse((row['ready_minutes'] ?? '').toString()),
      servings: int.tryParse((row['servings'] ?? '').toString()),
      dataQuality: (raw['data_quality'] ?? 'saved').toString(),
      raw: raw,
    );
  }
}

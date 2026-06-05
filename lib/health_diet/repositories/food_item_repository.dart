import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../models/normalized_food_item.dart';

class FoodItemRepository {
  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  Future<int> upsertFood(NormalizedFoodItem food) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'food_items',
      columns: ['id'],
      where: 'source = ? AND source_food_id = ?',
      whereArgs: [food.source, food.sourceId],
      limit: 1,
    );
    final values = _toDb(food, now);
    if (existing.isNotEmpty) {
      final id = int.tryParse((existing.first['id'] ?? '').toString()) ?? 0;
      await db.update('food_items', values, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    return db.insert('food_items', values);
  }

  Future<NormalizedFoodItem?> byId(int? id) async {
    if (id == null) return null;
    final db = await _db();
    final rows = await db.query('food_items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromDb(rows.first);
  }

  Future<List<NormalizedFoodItem>> byIds(Iterable<int?> ids) async {
    final realIds = ids.whereType<int>().where((e) => e > 0).toSet().toList();
    if (realIds.isEmpty) return const [];
    final db = await _db();
    final placeholders = List.filled(realIds.length, '?').join(',');
    final rows = await db.rawQuery('SELECT * FROM food_items WHERE id IN ($placeholders)', realIds);
    return rows.map(_fromDb).toList();
  }

  Future<NormalizedFoodItem?> byBarcode(String barcode) async {
    final value = barcode.trim();
    if (value.isEmpty) return null;
    final db = await _db();
    final rows = await db.query('food_items', where: 'barcode = ?', whereArgs: [value], orderBy: 'updated_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return _fromDb(rows.first);
  }

  Map<String, Object?> _toDb(NormalizedFoodItem food, String now) => {
        'source': food.source,
        'source_food_id': food.sourceId,
        'barcode': food.barcode,
        'name': food.name,
        'brand': food.brand,
        'category': food.category,
        'serving_size_g': food.servingSizeG,
        'calories_kcal': food.caloriesKcal,
        'protein_g': food.proteinG,
        'fat_g': food.fatG,
        'carbs_g': food.carbsG,
        'fiber_g': food.fiberG,
        'sugar_g': food.sugarG,
        'sodium_mg': food.sodiumMg,
        'saturated_fat_g': food.saturatedFatG,
        'allergens_json': jsonEncode(food.allergens),
        'ingredients_json': jsonEncode(food.ingredients),
        'health_tags_json': jsonEncode(food.healthTags),
        'data_quality': food.dataQuality,
        'raw_json': jsonEncode(food.raw),
        'created_at': now,
        'updated_at': now,
      };

  NormalizedFoodItem _fromDb(Map<String, Object?> row) {
    List<String> decodeList(Object? value) {
      try {
        final decoded = jsonDecode((value ?? '[]').toString());
        if (decoded is List) return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      } catch (_) {}
      return const [];
    }

    Map<String, dynamic> decodeMap(Object? value) {
      try {
        final decoded = jsonDecode((value ?? '{}').toString());
        if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
      } catch (_) {}
      return const <String, dynamic>{};
    }

    double? d(Object? v) => double.tryParse((v ?? '').toString());
    final raw = decodeMap(row['raw_json']);
    String? imageUrlFromRaw(Map<String, dynamic> raw) {
      for (final key in const ['image_url', 'image_front_url', 'image_nutrition_url', 'selected_image_url']) {
        final v = raw[key]?.toString().trim();
        if (v != null && (v.startsWith('http://') || v.startsWith('https://'))) return v;
      }
      final selected = raw['selected_images'];
      if (selected is Map) {
        final front = selected['front'];
        if (front is Map) {
          final display = front['display'];
          if (display is Map) {
            final v = (display['zh'] ?? display['en'])?.toString().trim();
            if (v != null && (v.startsWith('http://') || v.startsWith('https://'))) return v;
          }
        }
      }
      return null;
    }
    return NormalizedFoodItem(
      id: int.tryParse((row['id'] ?? '').toString()),
      source: (row['source'] ?? '').toString(),
      sourceId: (row['source_food_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      brand: row['brand']?.toString(),
      barcode: row['barcode']?.toString(),
      category: row['category']?.toString(),
      imageUrl: imageUrlFromRaw(raw),
      servingSizeG: d(row['serving_size_g']),
      caloriesKcal: d(row['calories_kcal']),
      proteinG: d(row['protein_g']),
      fatG: d(row['fat_g']),
      carbsG: d(row['carbs_g']),
      fiberG: d(row['fiber_g']),
      sugarG: d(row['sugar_g']),
      sodiumMg: d(row['sodium_mg']),
      saturatedFatG: d(row['saturated_fat_g']),
      allergens: decodeList(row['allergens_json']),
      ingredients: decodeList(row['ingredients_json']),
      healthTags: decodeList(row['health_tags_json']),
      dataQuality: (row['data_quality'] ?? 'unknown').toString(),
      raw: raw,
    );
  }
}

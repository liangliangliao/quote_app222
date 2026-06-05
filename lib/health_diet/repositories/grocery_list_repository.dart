import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../../utils/debug_logger.dart';
import '../models/grocery_list.dart';
import '../models/normalized_recipe.dart';
import 'health_profile_repository.dart';

class GroceryListRepository {
  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  Future<int> createFromRecipe({
    required NormalizedRecipe recipe,
    required List<GroceryListItem> items,
    String userId = HealthProfileRepository.defaultUserId,
  }) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final listId = await db.insert('grocery_lists', {
      'user_id': userId,
      'recipe_source_id': recipe.sourceId,
      'recipe_title': recipe.title,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await db.insert('grocery_list_items', item.copyWith(checked: false).toInsertMap(listId)..['sort_order'] = i);
    }
    await DLog.i('health_diet.grocery', '购物清单已生成 listId=$listId recipe=${recipe.title} items=${items.length}');
    return listId;
  }

  Future<GroceryList?> getList(int listId) async {
    final db = await _db();
    final rows = await db.query('grocery_lists', where: 'id = ?', whereArgs: [listId], limit: 1);
    if (rows.isEmpty) return null;
    final items = await itemsForList(listId);
    return GroceryList.fromMap(rows.first).copyWith(items: items);
  }

  Future<List<GroceryList>> recentLists({String userId = HealthProfileRepository.defaultUserId, int limit = 20}) async {
    final db = await _db();
    final rows = await db.query(
      'grocery_lists',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC, id DESC',
      limit: limit,
    );
    final result = <GroceryList>[];
    for (final row in rows) {
      final list = GroceryList.fromMap(row);
      result.add(list.copyWith(items: await itemsForList(list.id ?? 0)));
    }
    return result;
  }

  Future<List<GroceryListItem>> itemsForList(int listId) async {
    final db = await _db();
    final rows = await db.query('grocery_list_items', where: 'list_id = ?', whereArgs: [listId], orderBy: 'sort_order ASC, id ASC');
    return rows.map(GroceryListItem.fromMap).toList();
  }

  Future<void> updateItemChecked(int itemId, bool checked) async {
    final db = await _db();
    await db.update('grocery_list_items', {'checked': checked ? 1 : 0}, where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> deleteList(int listId) async {
    final db = await _db();
    await db.delete('grocery_lists', where: 'id = ?', whereArgs: [listId]);
    await DLog.i('health_diet.grocery', '购物清单已删除 listId=$listId');
  }
}

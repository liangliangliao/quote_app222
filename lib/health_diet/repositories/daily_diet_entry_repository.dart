import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../../utils/debug_logger.dart';
import '../models/daily_diet_entry.dart';
import 'health_profile_repository.dart';

class DailyDietEntryRepository {
  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  String todayDate() => DateTime.now().toIso8601String().substring(0, 10);

  Future<int> createEntry({
    String userId = HealthProfileRepository.defaultUserId,
    String? entryDate,
    required String mealType,
    required String inputType,
    String? textDescription,
    String? voiceText,
    String? barcode,
    List<DetectedDietFood> foods = const [],
    List<String> imagePaths = const [],
    String imageType = 'meal_photo',
  }) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('daily_diet_entries', {
      'user_id': userId,
      'entry_date': entryDate ?? todayDate(),
      'meal_type': mealType,
      'input_type': inputType,
      'text_description': textDescription,
      'voice_text': voiceText,
      'image_count': imagePaths.length,
      'barcode': barcode,
      'created_at': now,
      'updated_at': now,
    });

    for (final path in imagePaths) {
      await db.insert('daily_diet_images', {
        'entry_id': id,
        'local_path': path,
        'image_type': imageType,
        'recognized_text': null,
        'ai_detected_foods_json': null,
        'user_confirmed_foods_json': null,
        'confidence_score': null,
        'created_at': now,
      });
    }

    for (final food in foods) {
      await db.insert('detected_diet_foods', food.toInsertMap(id));
    }

    if (voiceText != null && voiceText.trim().isNotEmpty) {
      await db.insert('daily_diet_voice_records', {
        'entry_id': id,
        'local_audio_path': null,
        'transcript_text': voiceText.trim(),
        'duration_ms': null,
        'stt_provider': 'speech_to_text',
        'created_at': now,
      });
    }

    await DLog.i('health_diet.daily_share', '每日饮食记录已保存 entryId=$id inputType=$inputType foods=${foods.length} images=${imagePaths.length}');
    return id;
  }

  Future<List<DailyDietEntry>> entriesForDate(String date, {String userId = HealthProfileRepository.defaultUserId}) async {
    final db = await _db();
    final rows = await db.query(
      'daily_diet_entries',
      where: 'user_id = ? AND entry_date = ?',
      whereArgs: [userId, date],
      orderBy: 'created_at DESC, id DESC',
    );
    final entries = <DailyDietEntry>[];
    for (final row in rows) {
      final entry = DailyDietEntry.fromMap(row);
      entries.add(entry.copyWith(
        foods: await foodsForEntry(entry.id),
        images: await imagesForEntry(entry.id),
      ));
    }
    return entries;
  }

  Future<List<DailyDietEntry>> recentEntries({String userId = HealthProfileRepository.defaultUserId, int limit = 30}) async {
    final db = await _db();
    final rows = await db.query(
      'daily_diet_entries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'entry_date DESC, created_at DESC, id DESC',
      limit: limit,
    );
    final entries = <DailyDietEntry>[];
    for (final row in rows) {
      final entry = DailyDietEntry.fromMap(row);
      entries.add(entry.copyWith(
        foods: await foodsForEntry(entry.id),
        images: await imagesForEntry(entry.id),
      ));
    }
    return entries;
  }



  Future<void> updateDetectedFoodNormalizedId(int detectedFoodId, int normalizedFoodId) async {
    final db = await _db();
    await db.update(
      'detected_diet_foods',
      {'normalized_food_id': normalizedFoodId},
      where: 'id = ?',
      whereArgs: [detectedFoodId],
    );
  }

  Future<List<DetectedDietFood>> foodsForEntry(int? entryId) async {
    if (entryId == null) return const [];
    final db = await _db();
    final rows = await db.query(
      'detected_diet_foods',
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'id ASC',
    );
    return rows.map(DetectedDietFood.fromMap).toList();
  }

  Future<List<DailyDietImage>> imagesForEntry(int? entryId) async {
    if (entryId == null) return const [];
    final db = await _db();
    final rows = await db.query(
      'daily_diet_images',
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'id ASC',
    );
    return rows.map(DailyDietImage.fromMap).toList();
  }


  Future<void> upsertDailyReview(DailyDietReview review) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    await db.delete(
      'daily_nutrition_summary',
      where: 'user_id = ? AND summary_date = ?',
      whereArgs: [review.userId, review.summaryDate],
    );
    await db.insert('daily_nutrition_summary', {
      'user_id': review.userId,
      'summary_date': review.summaryDate,
      'total_calories_kcal': review.totalCaloriesKcal,
      'total_protein_g': review.totalProteinG,
      'total_fat_g': review.totalFatG,
      'total_carbs_g': review.totalCarbsG,
      'total_fiber_g': review.totalFiberG,
      'total_sugar_g': review.totalSugarG,
      'total_sodium_mg': review.totalSodiumMg,
      'vegetable_score': review.vegetableScore,
      'protein_score': review.proteinScore,
      'fiber_score': review.fiberScore,
      'sugar_risk_score': review.sugarRiskScore,
      'sodium_risk_score': review.sodiumRiskScore,
      'ultra_processed_score': review.ultraProcessedScore,
      'recovery_score': review.recoveryScore,
      'overall_summary': review.overallSummary,
      'good_points_json': jsonEncode(review.goodPoints),
      'main_problems_json': jsonEncode(review.mainProblems),
      'next_day_advice': review.nextDayAdvice,
      'confidence_score': review.confidenceScore,
      'confidence_level': review.confidenceLevel,
      'evidence_json': jsonEncode(review.evidenceItems.map((e) => e.toJson()).toList()),
      'data_gaps_json': jsonEncode(review.dataGaps),
      'recipe_needs_json': jsonEncode(review.recipeNeeds.map((e) => e.toJson()).toList()),
      'ai_review_json': jsonEncode(review.aiReviewJson ?? const <String, dynamic>{}),
      'nutrition_totals_json': jsonEncode({
        'calories_kcal': review.totalCaloriesKcal,
        'protein_g': review.totalProteinG,
        'fat_g': review.totalFatG,
        'carbs_g': review.totalCarbsG,
        'fiber_g': review.totalFiberG,
        'sugar_g': review.totalSugarG,
        'sodium_mg': review.totalSodiumMg,
      }),
      'created_at': now,
    });
  }

  Future<void> deleteEntry(int entryId) async {
    final db = await _db();
    await db.delete('daily_diet_entries', where: 'id = ?', whereArgs: [entryId]);
    await DLog.i('health_diet.daily_share', '每日饮食记录已删除 entryId=$entryId');
  }
}

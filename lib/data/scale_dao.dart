import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:sqflite/sqflite.dart';

import 'db.dart';
import '../utils/debug_logger.dart';
import 'dao.dart';

/// Data access object for questionnaire scales.
///
/// This DAO encapsulates all persistence logic for reading and writing
/// scales, dimensions, items, options, report rules and assessment results.
/// The import logic reads an Excel (.xlsx) file where each sheet
/// corresponds to a specific entity.  See docs for the template format.
class ScaleDao {
  final LogDao _logDao = LogDao();

  /// Import scale definitions from an Excel file.
  ///
  /// The Excel file must follow the "量表通用模板" format with the
  /// following sheet names: 量表信息, 维度信息, 题目配置, 选项配置, 评分规则与报告模板.
  /// Rows in the first sheet define the scale(s); subsequent sheets
  /// reference the scale_code column to associate rows to a scale.
  ///
  /// On success, all existing records for the imported scale_code(s)
  /// are removed and replaced.  Any error during import will abort
  /// the transaction and propagate a descriptive exception.
  Future<void> importFromExcel(File file) async {
    final db = await AppDatabase.instance();
    final bytes = await file.readAsBytes();
    late Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw '无法解析 Excel 文件: ${e.toString()}';
    }
    // Required sheets
    const sheetScale = '量表信息';
    const sheetDim = '维度信息';
    const sheetItems = '题目配置';
    const sheetOpts = '选项配置';
    const sheetRules = '评分规则与报告模板';
    if (!excel.tables.containsKey(sheetScale)) {
      throw '缺少 sheet: $sheetScale';
    }
    // Helper to convert sheet rows into list of maps keyed by header names
    List<Map<String, dynamic>> _sheetToMaps(String name) {
      final table = excel.tables[name];
      if (table == null) return [];
      final rows = table.rows;
      if (rows.isEmpty) return [];
      final headers = <String>[];
      // Extract header row values (convert to trimmed strings)
      for (final cell in rows.first) {
        final v = cell?.value;
        if (v == null) {
          headers.add('');
        } else {
          headers.add(v.toString().trim());
        }
      }
      final result = <Map<String, dynamic>>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        // Skip entirely empty rows
        if (row.every((c) => c == null || (c.value?.toString().trim().isEmpty ?? true))) {
          continue;
        }
        final m = <String, dynamic>{};
        for (var c = 0; c < headers.length; c++) {
          final key = headers[c];
          if (key.isEmpty) continue;
          final cell = c < row.length ? row[c] : null;
          final value = cell?.value;
          m[key] = value;
        }
        result.add(m);
      }
      return result;
    }
    final scaleRows = _sheetToMaps(sheetScale);
    final dimRows = excel.tables.containsKey(sheetDim) ? _sheetToMaps(sheetDim) : [];
    final itemRows = excel.tables.containsKey(sheetItems) ? _sheetToMaps(sheetItems) : [];
    final optRows = excel.tables.containsKey(sheetOpts) ? _sheetToMaps(sheetOpts) : [];
    final ruleRows = excel.tables.containsKey(sheetRules) ? _sheetToMaps(sheetRules) : [];

    // Map of scale_code to scale_id after insertion.
    // IMPORTANT: do NOT write logs inside the transaction using LogDao.add(),
    // because LogDao opens a new database connection. Calling it inside a sqflite
    // transaction can deadlock/lock the database and make all subsequent DB ops fail.
    final Map<String, int> scaleIds = {};

    try {
      // Run everything in a transaction to ensure atomicity
      await db.transaction((txn) async {
        // 1. Insert/update scales
        for (final row in scaleRows) {
          final code = (row['量表编码'] ?? '').toString().trim();
          if (code.isEmpty) continue;
          final version = (row['版本号'] ?? '').toString();
          final name = (row['量表名称'] ?? '').toString();
          final lang = (row['语言'] ?? '').toString();
          final desc = (row['量表简介'] ?? '').toString();
          final author = (row['作者'] ?? '').toString();
          final copyright = (row['版权说明'] ?? '').toString();
          // Check if scale exists
          final existing = await txn.query('scales', where: 'scale_code=?', whereArgs: [code]);
          int scaleId;
          if (existing.isEmpty) {
            scaleId = await txn.insert('scales', {
              'scale_code': code,
              'version': version,
              'name': name,
              'language': lang,
              'description': desc,
              'author': author,
              'copyright': copyright,
            });
          } else {
            scaleId = existing.first['id'] as int;
            await txn.update('scales', {
              'version': version,
              'name': name,
              'language': lang,
              'description': desc,
              'author': author,
              'copyright': copyright,
            }, where: 'id=?', whereArgs: [scaleId]);

            // Remove any existing config for this scale to avoid duplicates.
            // Delete options BEFORE items, because options reference items.
            await txn.delete('scale_dimensions', where: 'scale_id=?', whereArgs: [scaleId]);
            await txn.delete('scale_item_options',
                where: 'scale_item_id IN (SELECT id FROM scale_items WHERE scale_id = ?)',
                whereArgs: [scaleId]);
            await txn.delete('scale_items', where: 'scale_id=?', whereArgs: [scaleId]);
            await txn.delete('scale_report_rules', where: 'scale_id=?', whereArgs: [scaleId]);
          }
          scaleIds[code] = scaleId;
        }

        // 2. Insert dimensions
        for (final row in dimRows) {
          final code = (row['量表编码'] ?? '').toString().trim();
          if (code.isEmpty) continue;
          final scaleId = scaleIds[code];
          if (scaleId == null) {
            throw '维度信息表存在未知量表编码: $code';
          }
          final dimCode = (row['维度编码'] ?? '').toString().trim();
          final name = (row['维度名称'] ?? '').toString();
          final desc = (row['维度描述'] ?? '').toString();
          if (dimCode.isEmpty) continue;
          await txn.insert('scale_dimensions', {
            'scale_id': scaleId,
            'dimension_code': dimCode,
            'name': name,
            'description': desc,
          });
        }

        // 3. Insert items; also build itemCode->id map per scale
        final Map<String, int> itemCodeToId = {};
        for (final row in itemRows) {
          final code = (row['量表编码'] ?? '').toString().trim();
          if (code.isEmpty) continue;
          final scaleId = scaleIds[code];
          if (scaleId == null) {
            throw '题目配置表存在未知量表编码: $code';
          }
          final itemCode = (row['题目编码'] ?? '').toString().trim();
          if (itemCode.isEmpty) continue;
          // 题号可以是中文、数字或其他任意字符串，这里保留原始配置用于展示。
          final String rawItemNo = (row['题号'] ?? '').toString().trim();
          final String? itemNoLabel = rawItemNo.isEmpty ? null : rawItemNo;
          final content = (row['题目内容'] ?? '').toString();
          final itemType = (row['题目类型'] ?? '单选题').toString();
          final dimCode = (row['所属维度'] ?? '').toString().trim();
          // Some templates use bool column for 是否反向计分; convert to int
          final isRevRaw = (row['是否反向计分'] ?? '').toString().trim();
          int? isReverse;
          if (isRevRaw.isNotEmpty) {
            if (isRevRaw == '是' || isRevRaw.toLowerCase() == 'true' || isRevRaw == '1') {
              isReverse = 1;
            } else {
              isReverse = 0;
            }
          }
          final scoringType = (row['计分方式'] ?? '').toString().trim();
          final remark = (row['备注'] ?? '').toString();
          final values = {
            'scale_id': scaleId,
            'item_code': itemCode,
            'item_no': itemNoLabel,
            'content': content,
            'item_type': itemType,
            'dimension_code': dimCode.isEmpty ? null : dimCode,
            'is_reverse': isReverse,
            'scoring_type': scoringType.isEmpty ? null : scoringType,
            'remark': remark,
          };
          final itemId = await txn.insert('scale_items', values);
          itemCodeToId['$code|$itemCode'] = itemId;
        }

        // 4. Insert options
        for (final row in optRows) {
          final code = (row['量表编码'] ?? '').toString().trim();
          if (code.isEmpty) continue;
          final scaleId = scaleIds[code];
          if (scaleId == null) {
            throw '选项配置表存在未知量表编码: $code';
          }
          final itemCode = (row['题目编码'] ?? '').toString().trim();
          if (itemCode.isEmpty) continue;
          final itemKey = '$code|$itemCode';
          final itemId = itemCodeToId[itemKey];
          if (itemId == null) {
            throw '选项配置引用了未知题目编码: $itemCode (量表 $code)';
          }
          final optionCode = (row['选项编码'] ?? '').toString().trim();
          final label = (row['选项标签'] ?? '').toString();
          final optionValue = (row['选项值'] ?? '').toString();
          final baseScoreRaw = (row['基础分值'] ?? row['正向计分分值'] ?? '').toString();
          final baseScore = double.tryParse(baseScoreRaw.isEmpty ? '0' : baseScoreRaw) ?? 0;
          final extraRule = (row['扩展计分规则'] ?? '').toString();
          await txn.insert('scale_item_options', {
            'scale_item_id': itemId,
            'option_code': optionCode,
            'label': label,
            'option_value': optionValue,
            'base_score': baseScore,
            'extra_rule': extraRule.isEmpty ? null : extraRule,
          });
        }

        // 5. Insert report rules
        for (final row in ruleRows) {
          final code = (row['量表编码'] ?? '').toString().trim();
          if (code.isEmpty) continue;
          final scaleId = scaleIds[code];
          if (scaleId == null) {
            throw '评分规则表存在未知量表编码: $code';
          }
          final dimCode = (row['维度编码'] ?? '').toString().trim();
          final minScore = double.tryParse((row['最低分'] ?? '').toString()) ?? 0;
          final maxScore = double.tryParse((row['最高分'] ?? '').toString()) ?? 0;
          final level = (row['评分等级'] ?? '').toString();
          final template = (row['报告模板'] ?? '').toString();
          await txn.insert('scale_report_rules', {
            'scale_id': scaleId,
            'dimension_code': dimCode.isEmpty ? null : dimCode,
            'min_score': minScore,
            'max_score': maxScore,
            'level': level,
            'template': template,
          });
        }
      });
    } catch (e) {
      // Best-effort failure log OUTSIDE the transaction.
      try {
        await _logDao.add(taskUid: 'scale_import', detail: '导入量表失败: ${e.toString()}');
      } catch (_) {}
      rethrow;
    }

    // Log import success outside transaction to avoid nested DB calls.
    for (final entry in scaleIds.entries) {
      final sCode = entry.key;
      await _logDao.add(taskUid: 'scale_import', detail: '导入量表 $sCode 成功');
    }
  }

  /// Retrieve all scale summaries including latest assessment score if available for the given user.
  /// If userId is null the latest assessment is not filtered by user and will use any record.
  Future<List<Map<String, dynamic>>> getScaleSummaries({String? userId}) async {
    final db = await AppDatabase.instance();
    // Query scales
    final scales = await db.query('scales');
    final List<Map<String, dynamic>> result = [];
    for (final scale in scales) {
      final scaleId = scale['id'] as int;
      // Query latest assessment for this scale
      Map<String, dynamic>? latest;
      if (userId != null) {
        final rows = await db.rawQuery(
            'SELECT * FROM scale_assessments WHERE scale_id=? AND user_id=? ORDER BY id DESC LIMIT 1',
            [scaleId, userId]);
        if (rows.isNotEmpty) latest = rows.first;
      } else {
        final rows = await db.rawQuery(
            'SELECT * FROM scale_assessments WHERE scale_id=? ORDER BY id DESC LIMIT 1',
            [scaleId]);
        if (rows.isNotEmpty) latest = rows.first;
      }
      final m = Map<String, dynamic>.from(scale);
      if (latest != null) {
        m['latest_assessment'] = latest;
      }
      result.add(m);
    }
    return result;
  }

  /// Retrieve all items and their options for a given scale.
  /// Returns a list of maps where each map contains item fields and a nested
  /// list of options under the 'options' key.
  Future<List<Map<String, dynamic>>> getItemsWithOptions(int scaleId) async {
    final db = await AppDatabase.instance();
    final items = await db.query('scale_items', where: 'scale_id=?', whereArgs: [scaleId], orderBy: 'id ASC');
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final itemId = item['id'] as int;
      final opts = await db.query('scale_item_options', where: 'scale_item_id=?', whereArgs: [itemId]);
      final m = Map<String, dynamic>.from(item);
      m['options'] = opts;
      result.add(m);
    }
    return result;
  }

  /// Find the report rule for a given score and dimension.
  /// If dimensionCode is null, matches rules where dimension_code is NULL or '总分'.
  Future<Map<String, dynamic>?> _findRule(Database db, int scaleId, String? dimensionCode, double score) async {
    if (dimensionCode == null || dimensionCode.isEmpty) {
      // 总分：match rules with dimension_code null or '总分'
      final rows = await db.rawQuery(
          'SELECT * FROM scale_report_rules WHERE scale_id=? AND (dimension_code IS NULL OR dimension_code="总分") AND ? >= min_score AND ? <= max_score LIMIT 1',
          [scaleId, score, score]);
      return rows.isNotEmpty ? rows.first : null;
    } else {
      final rows = await db.rawQuery(
          'SELECT * FROM scale_report_rules WHERE scale_id=? AND dimension_code=? AND ? >= min_score AND ? <= max_score LIMIT 1',
          [scaleId, dimensionCode, score, score]);
      return rows.isNotEmpty ? rows.first : null;
    }
  }

  /// Score an assessment, generate a report, persist results and return summary.
  ///
  /// The [answers] map should map `scale_item_id` to `option_id`.  The base
  /// score and scoring logic are looked up automatically.  The userId may
  /// identify a specific user; pass null for an anonymous assessment.
  Future<Map<String, dynamic>> scoreAndSaveAssessment({
    required int scaleId,
    required String userId,
    required Map<int, int> answers,
  }) async {
    final db = await AppDatabase.instance();
    double totalScore = 0;
    final Map<String, double> dimensionScores = {};
    final Map<int, double> itemScores = {};
    // Precompute max base score per item for reverse scoring
    final Map<int, double> maxBaseScores = {};
    // Process each answer
    for (final entry in answers.entries) {
      final itemId = entry.key;
      final optId = entry.value;
      // Query item
      final itemRows = await db.query('scale_items', where: 'id=?', whereArgs: [itemId]);
      if (itemRows.isEmpty) {
        continue;
      }
      final item = itemRows.first;
      final scoringType = (item['scoring_type'] ?? '').toString().trim();
      final dimCode = (item['dimension_code'] ?? '').toString();
      // Query selected option
      final optRows = await db.query('scale_item_options', where: 'id=?', whereArgs: [optId]);
      if (optRows.isEmpty) {
        continue;
      }
      final opt = optRows.first;
      final baseScore = (opt['base_score'] is num) ? (opt['base_score'] as num).toDouble() : double.tryParse(opt['base_score']?.toString() ?? '0') ?? 0.0;
      // Determine maximum base for this item (cached)
      double maxBase;
      if (maxBaseScores.containsKey(itemId)) {
        maxBase = maxBaseScores[itemId]!;
      } else {
        final maxRow = await db.rawQuery('SELECT MAX(base_score) AS m FROM scale_item_options WHERE scale_item_id=?', [itemId]);
        maxBase = 0.0;
        if (maxRow.isNotEmpty) {
          final m = maxRow.first['m'];
          if (m is num) {
            maxBase = m.toDouble();
          } else {
            maxBase = double.tryParse(m?.toString() ?? '0') ?? 0.0;
          }
        }
        maxBaseScores[itemId] = maxBase;
      }
      double itemScore;
      if (scoringType == '反向') {
        itemScore = maxBase - baseScore;
      } else if (scoringType == '不计分') {
        itemScore = 0.0;
      } else if (scoringType == '自定义') {
        // Future: parse extra_rule or a custom formula; for now fallback to baseScore
        itemScore = baseScore;
      } else {
        // 默认为正常计分
        itemScore = baseScore;
      }
      itemScores[itemId] = itemScore;
      totalScore += itemScore;
      if (dimCode.isNotEmpty) {
        final current = dimensionScores[dimCode] ?? 0.0;
        dimensionScores[dimCode] = current + itemScore;
      }
    }
    // Find total rule
    final totalRule = await _findRule(db, scaleId, null, totalScore);
    String level = '';
    String report = '';
    if (totalRule != null) {
      level = (totalRule['level'] ?? '').toString();
      report = (totalRule['template'] ?? '').toString();
    }
    // Replace total score placeholder
    report = report.replaceAll('{score}', totalScore.toString());
    // Replace dimension placeholders or append dimension-specific messages
    for (final entry in dimensionScores.entries) {
      final dimCode = entry.key;
      final dimScore = entry.value;
      final dimRule = await _findRule(db, scaleId, dimCode, dimScore);
      final placeholder = '{dimension_score_$dimCode}';
      if (dimRule != null) {
        final dimTemplate = (dimRule['template'] ?? '').toString();
        final msg = dimTemplate.replaceAll(placeholder, dimScore.toString());
        if (report.contains(placeholder)) {
          report = report.replaceAll(placeholder, dimScore.toString());
        } else {
          report += '\n\n$msg';
        }
      } else {
        // If no rule, still replace placeholder if present
        if (report.contains(placeholder)) {
          report = report.replaceAll(placeholder, dimScore.toString());
        }
      }
    }
    // Save assessment record
    final nowStr = DateTime.now().toIso8601String();
    final assessmentId = await db.insert('scale_assessments', {
      'user_id': userId,
      'scale_id': scaleId,
      'total_score': totalScore,
      'level': level,
      'report_text': report,
      'created_at': nowStr,
    });
    // Save answers
    for (final entry in answers.entries) {
      final itemId = entry.key;
      final optId = entry.value;
      final score = itemScores[itemId] ?? 0.0;
      // Retrieve option value for record
      String optionValue = '';
      final optRows = await db.query('scale_item_options', where: 'id=?', whereArgs: [optId]);
      if (optRows.isNotEmpty) {
        optionValue = (optRows.first['option_value'] ?? '').toString();
      }
      await db.insert('scale_assessment_answers', {
        'assessment_id': assessmentId,
        'scale_item_id': itemId,
        'option_id': optId,
        'option_value': optionValue,
        'score': score,
      });
    }
    // Log
    await _logDao.add(
        taskUid: 'scale_${scaleId.toString()}',
        detail: '测评完成: 分数=$totalScore 级别=$level');
    return {
      'assessmentId': assessmentId,
      'totalScore': totalScore,
      'level': level,
      'report': report,
    };
  }

  /// Retrieve past assessments for a given scale and user.
  Future<List<Map<String, dynamic>>> getAssessments({required int scaleId, required String userId}) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('scale_assessments', where: 'scale_id=? AND user_id=?', whereArgs: [scaleId, userId], orderBy: 'id DESC');
    return rows;
  }
}
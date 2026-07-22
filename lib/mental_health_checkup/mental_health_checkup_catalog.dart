import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'mental_health_checkup_models.dart';

class CheckupSeedValidationResult {
  final bool valid;
  final String version;
  final int checkedFiles;
  final List<String> errors;

  const CheckupSeedValidationResult({
    required this.valid,
    required this.version,
    required this.checkedFiles,
    required this.errors,
  });
}

class MentalHealthCheckupCatalog {
  static const String assetRoot = 'assets/mental_health_checkup';
  static const String ruleVersion = '2.5';

  static const Map<String, String> domainNames = <String, String>{
    'D1': '情绪接纳与有效行动',
    'D2': '现实主义乐观',
    'D3': '知行转化与仪式',
    'D4': '目标、意义与自洽',
    'D5': '优势、压力与恢复',
    'D6': '睡眠、运动与身心基础',
    'D7': '关系、表达与连接',
    'D8': '自尊、自主与实现',
  };

  static const Map<String, String> domainDescriptions = <String, String>{
    'D1': '允许情绪存在，同时选择安全、有效的行动。',
    'D2': '承认事实与限制，也能看见可能性和可控部分。',
    'D3': '把理解变成可重复的小行动、结构和生活仪式。',
    'D4': '目标与个人价值、意义、兴趣和现实生活相协调。',
    'D5': '识别优势、管理负荷，并安排微观到长期恢复。',
    'D6': '睡眠、运动和身体恢复能够支持日常功能。',
    'D7': '在重要关系中被了解，并能真实、尊重地表达。',
    'D8': '不把基本价值完全交给外界认可，依据价值行动。',
  };

  static const Map<String, String> domainLectureAnchors = <String, String>{
    'D1': 'Lecture 4',
    'D2': 'Lecture 5-9',
    'D3': 'Lecture 1, 10-11, 23',
    'D4': 'Lecture 12',
    'D5': 'Lecture 13-17',
    'D6': 'Lecture 16-18',
    'D7': 'Lecture 19-21',
    'D8': 'Lecture 21-22',
  };

  final List<CheckupModeSpec> modes;
  final List<CheckupQuestion> b20Questions;
  final List<CheckupIndicator> indicators;
  final List<CheckupDiagnosisPattern> diagnosisPatterns;
  final List<CheckupPrescription> prescriptions;
  final CheckupSeedValidationResult validation;

  const MentalHealthCheckupCatalog({
    required this.modes,
    required this.b20Questions,
    required this.indicators,
    required this.diagnosisPatterns,
    required this.prescriptions,
    required this.validation,
  });

  static Future<MentalHealthCheckupCatalog> load() async {
    final validation = await validateSeeds();
    if (!validation.valid) {
      throw StateError('课程种子校验失败：${validation.errors.join('；')}');
    }

    final values = await Future.wait<String>(<Future<String>>[
      rootBundle.loadString('$assetRoot/assessment_modes.json'),
      rootBundle.loadString('$assetRoot/b20_items.json'),
      rootBundle.loadString('$assetRoot/indicators.json'),
      rootBundle.loadString('$assetRoot/diagnosis_patterns.json'),
      rootBundle.loadString('$assetRoot/course_prescriptions.json'),
    ]);

    final modeRows = _mapList(jsonDecode(values[0]));
    final b20Rows = _mapList(jsonDecode(values[1]));
    final indicatorRows = _mapList(jsonDecode(values[2]));
    final diagnosisRows = _mapList(jsonDecode(values[3]));
    final prescriptionRows = _mapList(jsonDecode(values[4]));

    final indicators = indicatorRows.map(_indicatorFromJson).toList();
    final byIndicatorId = <String, CheckupIndicator>{
      for (final indicator in indicators) indicator.id: indicator,
    };

    return MentalHealthCheckupCatalog(
      modes: modeRows.map(_modeFromJson).toList(growable: false),
      b20Questions: b20Rows
          .map((row) => _b20QuestionFromJson(row, byIndicatorId))
          .toList(growable: false),
      indicators: indicators,
      diagnosisPatterns:
          diagnosisRows.map(_diagnosisFromJson).toList(growable: false),
      prescriptions: prescriptionRows
          .map(_prescriptionFromJson)
          .toList(growable: false),
      validation: validation,
    );
  }

  static Future<CheckupSeedValidationResult> validateSeeds() async {
    final errors = <String>[];
    var version = '';
    var checked = 0;
    try {
      final raw = await rootBundle.loadString('$assetRoot/seed_catalog.json');
      final catalog = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      version = (catalog['version'] ?? '').toString();
      final exports = catalog['exports'] as List? ?? const <Object?>[];
      for (final item in exports.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final file = (row['file'] ?? '').toString();
        final expectedHash = (row['sha256'] ?? '').toString().toLowerCase();
        final expectedRows = (row['rows'] as num?)?.toInt();
        final format = (row['format'] ?? '').toString();
        if (file.isEmpty || expectedHash.isEmpty) {
          errors.add('seed_catalog 存在缺失字段');
          continue;
        }
        try {
          final bytes = await _loadSeedBytes(file);
          final actualHash = sha256.convert(bytes).toString();
          if (actualHash != expectedHash) errors.add('$file 哈希不一致');
          if (expectedRows != null) {
            final text = utf8.decode(bytes);
            final int actualRows;
            if (format == 'jsonl') {
              actualRows = const LineSplitter()
                  .convert(text)
                  .where((line) => line.trim().isNotEmpty)
                  .length;
            } else {
              final decoded = jsonDecode(text);
              actualRows = decoded is List ? decoded.length : -1;
            }
            if (actualRows != expectedRows) {
              errors.add('$file 记录数应为 $expectedRows，实际为 $actualRows');
            }
          }
          checked++;
        } catch (error) {
          errors.add('$file 无法读取：$error');
        }
      }
    } catch (error) {
      errors.add('seed_catalog.json 无法读取：$error');
    }
    return CheckupSeedValidationResult(
      valid: errors.isEmpty,
      version: version,
      checkedFiles: checked,
      errors: errors,
    );
  }

  static Future<Uint8List> _loadSeedBytes(String file) async {
    try {
      final data = await rootBundle.load('$assetRoot/$file');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      // The two evidence graphs are losslessly gzipped in the APK to keep the
      // repository and install size reasonable. Hashes and row counts are
      // still checked against the original, decompressed V2.5 package bytes.
      if (!file.endsWith('.jsonl')) rethrow;
      final data = await rootBundle.load('$assetRoot/$file.gz');
      final compressed = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return Uint8List.fromList(gzip.decode(compressed));
    }
  }

  CheckupModeSpec modeById(String id) => modes.firstWhere(
        (mode) => mode.id == id,
        orElse: () => modes.firstWhere((mode) => mode.id == 'b20'),
      );

  CheckupPrescription? prescriptionById(String id) {
    for (final item in prescriptions) {
      if (item.id == id) return item;
    }
    return null;
  }

  CheckupIndicator? indicatorById(String id) {
    for (final item in indicators) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<CheckupQuestion> questionsForMode(
    String modeId, {
    String? focusDomainId,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final byId = <String, CheckupQuestion>{
      for (final question in b20Questions) question.id: question,
    };
    List<CheckupQuestion> pick(List<String> ids) => ids
        .map((id) => byId[id])
        .whereType<CheckupQuestion>()
        .toList(growable: false);

    switch (modeId) {
      case 'safety':
        return pick(const <String>[
          'B20-S1',
          'B20-S2',
          'B20-S3',
          'B20-S4',
          'B20-F1',
        ]);
      case 'daily':
        final start = clock.difference(DateTime(2025)).inDays.abs() % 8;
        final domainIds = List<String>.generate(
          4,
          (index) => 'B20-D${(start + index) % 8 + 1}',
        );
        return pick(<String>['B20-S1', 'B20-F1', ...domainIds]);
      case 'five_minute':
        return pick(<String>[
          'B20-S1',
          'B20-S2',
          'B20-S3',
          'B20-S4',
          'B20-F1',
          'B20-F2',
          ...List<String>.generate(8, (index) => 'B20-D${index + 1}'),
        ]);
      case 'standard':
        return <CheckupQuestion>[
          ...b20Questions,
          for (final domainId in domainNames.keys)
            ..._indicatorQuestions(domainId, 2, clock),
        ];
      case 'focused':
        final domainId = domainNames.containsKey(focusDomainId)
            ? focusDomainId!
            : 'D1';
        return <CheckupQuestion>[
          ...pick(const <String>[
            'B20-S1',
            'B20-S2',
            'B20-S3',
            'B20-S4',
            'B20-F1',
            'B20-F2',
          ]),
          ..._indicatorQuestions(domainId, 30, clock),
        ];
      case 'comprehensive':
        return <CheckupQuestion>[
          ...b20Questions,
          for (final domainId in domainNames.keys)
            ..._indicatorQuestions(domainId, 5, clock),
        ];
      case 'b20':
      default:
        return List<CheckupQuestion>.unmodifiable(b20Questions);
    }
  }

  List<CheckupQuestion> _indicatorQuestions(
    String domainId,
    int count,
    DateTime now,
  ) {
    final matching = indicators
        .where((indicator) => _domainForIndicator(indicator) == domainId)
        .toList(growable: false);
    if (matching.isEmpty) return const <CheckupQuestion>[];
    final anchorIndicatorIds = b20Questions
        .map((e) => e.indicatorId)
        .whereType<String>()
        .toSet();
    final candidates = matching
        .where((indicator) => !anchorIndicatorIds.contains(indicator.id))
        .toList(growable: false);
    if (candidates.isEmpty) return const <CheckupQuestion>[];
    final offset = (now.year * 372 + now.month * 31 + now.day +
            domainId.hashCode.abs()) %
        candidates.length;
    final selected = <CheckupIndicator>[];
    for (var index = 0;
        index < count && index < candidates.length;
        index++) {
      selected.add(candidates[(offset + index) % candidates.length]);
    }
    return selected.map((indicator) {
      final risk = indicator.type == '风险型';
      final promptPrefix = risk
          ? '过去14天，以下情况出现的程度是：'
          : indicator.type == '功能结果'
              ? '过去14天，以下现实功能在多大程度上符合你：'
              : '过去14天，以下能力在多大程度上符合你：';
      return CheckupQuestion(
        id: 'IND-${indicator.id}',
        group: '${domainNames[domainId]} · 深入追问',
        kind: indicator.type,
        prompt: '$promptPrefix${indicator.name}',
        scaleLabel: risk
            ? '0 从未 - 4 几乎总是（越高风险越高）'
            : '0 完全不符合 - 4 非常符合（越高越健康）',
        direction: risk ? '越高风险越高' : '越高越健康',
        indicatorId: indicator.id,
        sourceLevel:
            indicator.directness.contains('直接证据较强') ? 'C1' : 'C2',
        required: false,
        domainId: domainId,
        lecture: indicator.lecture,
        evidenceLocation: indicator.definitionLocation,
        choices: _zeroToFourChoices(),
      );
    }).toList(growable: false);
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) =>
      (value as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

  static CheckupModeSpec _modeFromJson(Map<String, dynamic> json) {
    final name = (json['模式'] ?? '').toString();
    return CheckupModeSpec(
      id: _modeIdForName(name),
      name: name,
      duration: (json['时间'] ?? '').toString(),
      baseQuestionCount: _firstInt(json['基础题量']) ?? 0,
      maxQuestionCount: _firstInt(json['最多题量']) ?? 0,
      fixedContent: (json['固定内容'] ?? '').toString(),
      actionCount: (json['行动数'] ?? '').toString(),
      useCase: (json['适用场景'] ?? '').toString(),
      coverageLevel: (json['结论覆盖等级'] ?? '').toString(),
    );
  }

  static String _modeIdForName(String name) {
    const map = <String, String>{
      '安全快检': 'safety',
      '每日脉搏': 'daily',
      '五分钟版': 'five_minute',
      'B20快速基准': 'b20',
      '标准版': 'standard',
      '聚焦深入版': 'focused',
      '综合深入版': 'comprehensive',
    };
    return map[name] ?? 'b20';
  }

  static int? _firstInt(dynamic value) {
    final match = RegExp(r'\d+').firstMatch((value ?? '').toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static CheckupIndicator _indicatorFromJson(Map<String, dynamic> json) =>
      CheckupIndicator(
        id: (json['指标ID'] ?? '').toString(),
        lecture: (json['讲次'] as num?)?.toInt() ?? 0,
        area: (json['领域'] ?? '').toString(),
        name: (json['指标名称'] ?? '').toString(),
        type: (json['类型'] ?? '').toString(),
        definitionLocation: (json['DEF定义位置'] ?? '').toString(),
        lowLocation: (json['LOW低端位置'] ?? '').toString(),
        highLocation: (json['HIGH高端位置'] ?? '').toString(),
        actionLocation: (json['ACT行动位置'] ?? '').toString(),
        directEvidenceCount: (json['直接证据数'] as num?)?.toInt() ?? 0,
        directness: (json['直接性'] ?? '').toString(),
        reviewStatus: (json['审核状态'] ?? '').toString(),
      );

  static CheckupQuestion _b20QuestionFromJson(
    Map<String, dynamic> json,
    Map<String, CheckupIndicator> indicators,
  ) {
    final id = (json['题号'] ?? '').toString();
    final indicatorId = json['指标ID']?.toString();
    final indicator = indicatorId == null ? null : indicators[indicatorId];
    return CheckupQuestion(
      id: id,
      group: (json['组别'] ?? '').toString(),
      kind: (json['题型'] ?? '').toString(),
      prompt: (json['题目'] ?? '').toString(),
      scaleLabel: (json['量尺/选项'] ?? '').toString(),
      direction: (json['计分方向'] ?? '').toString(),
      indicatorId: indicatorId,
      sourceLevel: (json['来源等级'] ?? '').toString(),
      required: (json['是否固定'] ?? '').toString() == '是',
      domainId: _domainForB20(id, indicator?.area),
      lecture: indicator?.lecture,
      evidenceLocation: indicator?.definitionLocation,
      choices: _choicesForB20(id, (json['量尺/选项'] ?? '').toString()),
    );
  }

  static List<CheckupAnswerChoice> _choicesForB20(
      String id, String rawScale) {
    if (id == 'B20-S1' || id == 'B20-S2' || id == 'B20-S4') {
      return const <CheckupAnswerChoice>[
        CheckupAnswerChoice('否', 0),
        CheckupAnswerChoice('不确定', 1),
        CheckupAnswerChoice('是', 2),
      ];
    }
    if (id == 'B20-S3') {
      return const <CheckupAnswerChoice>[
        CheckupAnswerChoice('无', 0),
        CheckupAnswerChoice('轻度', 1),
        CheckupAnswerChoice('明显', 2),
        CheckupAnswerChoice('严重', 3),
      ];
    }
    if (id == 'B20-Q1') {
      return const <CheckupAnswerChoice>[
        CheckupAnswerChoice('否', 0),
        CheckupAnswerChoice('是（本轮只记录“存在遗漏”，不保存原文）', 1),
      ];
    }
    if (id == 'B20-K1' || id == 'B20-K2') {
      final parts = rawScale
          .split(RegExp('[;；]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return List<CheckupAnswerChoice>.generate(
        parts.length,
        (index) => CheckupAnswerChoice(parts[index], index.toDouble()),
      );
    }
    if (rawScale.trim().startsWith('1')) {
      return List<CheckupAnswerChoice>.generate(
        5,
        (index) => CheckupAnswerChoice('${index + 1}', (index + 1).toDouble()),
      );
    }
    return _zeroToFourChoices();
  }

  static List<CheckupAnswerChoice> _zeroToFourChoices() =>
      List<CheckupAnswerChoice>.generate(
        5,
        (index) => CheckupAnswerChoice('$index', index.toDouble()),
      );

  static String? _domainForB20(String id, String? area) {
    final match = RegExp(r'B20-D([1-8])').firstMatch(id);
    if (match != null) return 'D${match.group(1)}';
    if (id == 'B20-C1' || id == 'B20-C2') return 'D3';
    return area == null ? null : _domainForArea(area);
  }

  static String _domainForArea(String area) {
    switch (area) {
      case '情绪与认知':
        return 'D1';
      case '目标与意义':
        return 'D4';
      case '优势与压力':
        return 'D5';
      case '身心基础':
        return 'D6';
      case '关系与连接':
        return 'D7';
      case '自尊与实现':
        return 'D8';
      case '学习与转化':
      case '改变与习惯':
      case '整合与持续':
      default:
        return 'D3';
    }
  }

  static String _domainForIndicator(CheckupIndicator indicator) {
    // The source corpus groups Lectures 4-9 under one broad area, while the
    // checkup specification deliberately separates emotional acceptance (D1)
    // from realistic optimism (D2). Keep that split deterministic and local.
    if (indicator.area == '情绪与认知') {
      return indicator.lecture >= 5 && indicator.lecture <= 9 ? 'D2' : 'D1';
    }
    return _domainForArea(indicator.area);
  }

  static CheckupDiagnosisPattern _diagnosisFromJson(
          Map<String, dynamic> json) =>
      CheckupDiagnosisPattern(
        id: (json['模式ID'] ?? '').toString(),
        name: (json['课程型诊断名称'] ?? '').toString(),
        triggerIndicatorIds: _splitIds(json['触发指标']),
        mechanism: (json['机制假设'] ?? '').toString(),
        prescriptionIds: _splitIds(json['推荐处方ID']),
        priorityAction: (json['优先行动'] ?? '').toString(),
        evidenceNeeded: (json['诊断所需证据'] ?? '').toString(),
        exclusions: (json['主要反证/排除'] ?? '').toString(),
        confidenceRule: (json['置信度要求'] ?? '').toString(),
        reviewStatus: (json['审核状态'] ?? '').toString(),
      );

  static List<String> _splitIds(dynamic value) => (value ?? '')
      .toString()
      .split(RegExp('[;；]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  static CheckupPrescription _prescriptionFromJson(
          Map<String, dynamic> json) =>
      CheckupPrescription(
        id: (json['处方ID'] ?? '').toString(),
        lecture: (json['讲次'] as num?)?.toInt() ?? 0,
        theme: (json['课程主题'] ?? '').toString(),
        primaryIndicatorId: (json['主要指标ID'] ?? '').toString(),
        primaryIndicator: (json['主要指标'] ?? '').toString(),
        actionLocation: (json['ACT课程位置'] ?? '').toString(),
        mechanism: (json['适用机制'] ?? '').toString(),
        startingAction: (json['起始课程处方'] ?? '').toString(),
        deepeningAction: (json['深入课程处方'] ?? '').toString(),
        microDose: (json['微量'] ?? '').toString(),
        startingDose: (json['起始量'] ?? '').toString(),
        consolidationDose: (json['巩固量'] ?? '').toString(),
        trialPeriod: (json['建议试验期'] ?? '').toString(),
        outcomeEvidence: (json['疗效证据'] ?? '').toString(),
        stopRule: (json['过度化/停止规则'] ?? '').toString(),
        sourceLevel: (json['来源等级'] ?? '').toString(),
        reviewStatus: (json['审核状态'] ?? '').toString(),
      );
}

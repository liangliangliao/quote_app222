/// Privacy classification and redaction for the Future Strategist cloud route.
///
/// A stable problem identity is not, by itself, sensitive data. The previous
/// implementation treated every persisted problem as sensitive and therefore
/// disabled configured AI for almost every real consultation. This guard
/// makes the decision from the actual outbound content instead.
class XiangjiPrivacyAssessment {
  const XiangjiPrivacyAssessment({
    this.sensitiveCategories = const <String>[],
    this.directIdentifierCount = 0,
  });

  final List<String> sensitiveCategories;
  final int directIdentifierCount;

  bool get containsSensitiveCategory => sensitiveCategories.isNotEmpty;
}

class XiangjiSanitizedPayload<T> {
  const XiangjiSanitizedPayload({
    required this.value,
    required this.redactedCount,
  });

  final T value;
  final int redactedCount;
}

/// Implements Rev.5.2's "minimum necessary + consent + redaction" rule.
///
/// Strongly sensitive categories require explicit opt-in. Direct identifiers
/// are redacted even after opt-in because they are not needed for reasoning.
class XiangjiCloudPrivacyGuard {
  const XiangjiCloudPrivacyGuard();

  XiangjiPrivacyAssessment assess({
    required String task,
    Map<String, Object?> additionalContext = const <String, Object?>{},
  }) {
    final text = <String>[
      task,
      ..._stringLeaves(additionalContext),
    ].join('\n');
    final categories = <String>[];
    for (final entry in _sensitiveCategoryPatterns.entries) {
      if (entry.value.hasMatch(text)) categories.add(entry.key);
    }
    return XiangjiPrivacyAssessment(
      sensitiveCategories: categories,
      directIdentifierCount: sanitizeText(text).redactedCount,
    );
  }

  XiangjiSanitizedPayload<String> sanitizeText(String input) {
    var value = input;
    var count = 0;
    for (final rule in _redactionRules) {
      value = value.replaceAllMapped(rule.pattern, (match) {
        count++;
        return rule.replacement;
      });
    }
    return XiangjiSanitizedPayload<String>(
      value: value,
      redactedCount: count,
    );
  }

  XiangjiSanitizedPayload<Object?> sanitize(Object? input) {
    var count = 0;

    Object? visit(Object? value) {
      if (value is String) {
        final sanitized = sanitizeText(value);
        count += sanitized.redactedCount;
        return sanitized.value;
      }
      if (value is List) return value.map<Object?>(visit).toList();
      if (value is Map) {
        return value.map<String, Object?>(
          (key, dynamic item) => MapEntry<String, Object?>(
            key.toString(),
            visit(item),
          ),
        );
      }
      return value;
    }

    return XiangjiSanitizedPayload<Object?>(
      value: visit(input),
      redactedCount: count,
    );
  }

  Iterable<String> _stringLeaves(Object? value) sync* {
    if (value is String) {
      yield value;
      return;
    }
    if (value is List) {
      for (final item in value) {
        yield* _stringLeaves(item);
      }
      return;
    }
    if (value is Map) {
      for (final item in value.values) {
        yield* _stringLeaves(item);
      }
    }
  }

  static final Map<String, RegExp> _sensitiveCategoryPatterns =
      <String, RegExp>{
    '医疗健康': RegExp(
      r'病历|确诊|诊断为|处方|用药记录|住院|手术方案|精神科|心理治疗|传染病|基因检测',
      caseSensitive: false,
    ),
    '法律案件': RegExp(
      r'诉讼|刑事案件|报案|案号|律师函|判决书|仲裁|取保候审|犯罪记录',
      caseSensitive: false,
    ),
    '财务账户': RegExp(
      r'银行卡|银行账号|征信报告|工资单|纳税记录|税号|资产明细|负债明细',
      caseSensitive: false,
    ),
    '亲密与身份': RegExp(
      r'性生活|性取向|宗教信仰|政治面貌|家暴|未成年人隐私|儿童隐私',
      caseSensitive: false,
    ),
  };

  static final List<_RedactionRule> _redactionRules = <_RedactionRule>[
    _RedactionRule(
      RegExp(
        r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
        caseSensitive: false,
      ),
      '[已隐藏邮箱]',
    ),
    _RedactionRule(
      RegExp(r'(?:\+?86[ -]?)?1[3-9]\d{9}'),
      '[已隐藏手机号]',
    ),
    _RedactionRule(
      RegExp(r'\b\d{17}[\dXx]\b'),
      '[已隐藏证件号]',
    ),
    _RedactionRule(
      RegExp(r'\b\d{16,19}\b'),
      '[已隐藏账户号]',
    ),
    _RedactionRule(
      RegExp(r'姓名[：:]\s*[\u4e00-\u9fff]{2,4}'),
      '姓名：[已隐藏姓名]',
    ),
    _RedactionRule(
      RegExp(r'(?:住址|地址)[：:][^\n，。；]{4,80}'),
      '地址：[已隐藏详细地址]',
    ),
  ];
}

class _RedactionRule {
  const _RedactionRule(this.pattern, this.replacement);

  final RegExp pattern;
  final String replacement;
}

/// One contract for the five meaning-circle forms, including legacy adapters.
/// This checks that a proposed model has its required regions; it does not
/// establish the truth of its membership or its premises.
class MeaningCircleContract {
  static const version = 3;
  static const prompt =
      '''含义圈统一协议v3：先确定同一论域与成员判准，再选图。只允许equal、subset/superset、partition、overlap、siblings。
equal给共同成员；subset给内部成员和B独有成员，superset给内部成员和A独有成员；overlap给交集与两侧独有成员；partition给命名上位范围及parts中各子类的term/criterion/example，并解释互斥及穷尽；siblings给命名上位范围、两侧成员和上位范围的其他成员，不能声称穷尽。
统一字段relation_type,relation_scope:"extension",universe,set_a,set_b,criterion_a,criterion_b,basis,justification,intersection,only_a,only_b,other_member,parts,illustration。basis逐字对应输入。教学模型标illustration:true，不能当作原句证据。没有依据就不画圈，说明缺口及适合的定义/判断/类比/因果/时间/空间表达。共同词、共现、感受和作者标签不证明交集或因果。''';
  static List<String> gaps(Map<String, dynamic> map) {
    String text(String key) => (map[key] ?? '').toString().trim();
    final type = text('relation_type');
    final result = <String>[];
    bool missing(String value) =>
        value.isEmpty ||
        const ['无', '不适用', '未知', '待确定', '暂无', '不知道', 'none', 'n/a', 'unknown']
            .contains(value.toLowerCase());
    if (!const [
      'equal',
      'subset',
      'superset',
      'partition',
      'overlap',
      'siblings'
    ].contains(type)) {
      result.add('需要第九节五种图式之一；单独排斥不构成第六种图式');
    }
    for (final key in [
      'universe',
      'set_a',
      'set_b',
      'criterion_a',
      'criterion_b',
      'justification'
    ]) {
      if (missing(text(key))) result.add('缺少 $key');
    }
    if (map['relation_scope'] != 'extension') result.add('尚未界定外延成员');
    final regions = switch (type) {
      'equal' => ['intersection'],
      'subset' => ['intersection', 'only_b'],
      'superset' => ['intersection', 'only_a'],
      'overlap' => ['intersection', 'only_a', 'only_b'],
      'siblings' => ['only_a', 'only_b', 'other_member'],
      _ => <String>[],
    };
    for (final key in regions) {
      if (missing(text(key))) result.add('缺少 $key 区域的成员与范围依据');
    }
    bool present(String key) =>
        text(key).isNotEmpty &&
        !const ['无', '空', '不存在', '不适用', 'none', 'n/a']
            .contains(text(key).toLowerCase());
    if ((type == 'equal' && (present('only_a') || present('only_b'))) ||
        (type == 'subset' && present('only_a')) ||
        (type == 'superset' && present('only_b')) ||
        (const ['siblings', 'partition'].contains(type) &&
            present('intersection'))) {
      result.add('所填成员区域与声称的包含、重合或互斥关系冲突');
    }
    if (regions.map(text).where((v) => !missing(v)).toSet().length <
        regions.where((k) => !missing(text(k))).length)
      result.add('同一成员被填入互不相容的区域');
    if (type == 'partition') {
      final parts = map['parts'];
      if (parts is! List ||
          parts.length < 2 ||
          parts.any((p) =>
              p is! Map ||
              ['term', 'criterion', 'example']
                  .any((k) => (p[k] ?? '').toString().trim().isEmpty))) {
        result.add('穷尽划分需要命名上位范围及各子类的判准和实例');
      }
    }
    if (type == 'partition' && map['parts'] is List) {
      final parts = map['parts'] as List;
      if (parts.whereType<Map>().map((p) => p['term']).toSet().length !=
          parts.length) result.add('划分子类身份重复');
    }
    return result;
  }
}

enum VerificationStatus { supported, contradicted, unknown }

class SemanticVerification {
  final VerificationStatus status;
  final String reason, method;
  const SemanticVerification(this.status, this.reason, {this.method = 'local'});
  Map<String, dynamic> toJson() =>
      {'status': status.name, 'reason': reason, 'method': method};
}

/// Conservative source-faithfulness check, not a general theorem prover or a
/// claim that a reported event is objectively true. A substring alone never
/// verifies a paraphrased conclusion.
class PropositionConsistency {
  static String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s，。；：、！？“”「」,.!?;:"\x27]'), '');
  static SemanticVerification check(String conclusion, String evidence,
      {String? subject,
      String? predicate,
      String? quantifier,
      String? polarity,
      String? condition,
      String? modality}) {
    final c = normalize(conclusion), e = normalize(evidence);
    if (c.isEmpty || e.isEmpty)
      return const SemanticVerification(
          VerificationStatus.unknown, '命题或引用依据缺失');
    if (RegExp(r'[?？]').hasMatch(conclusion) !=
        RegExp(r'[?？]').hasMatch(evidence)) {
      return const SemanticVerification(
          VerificationStatus.unknown, '疑问与断言的模态不同，不能仅因字词相同就支持结论');
    }
    // `condition` is itself an AI paraphrase. Its absence as a literal
    // substring cannot establish that the conclusion dropped a qualification.
    // In particular an exact quotation must not fail on an explanatory field.
    if (c == e)
      return const SemanticVerification(
          VerificationStatus.supported, '与所引原句逐字一致；只核对转述忠实度，不证明原句为真');
    final weakEvidence = RegExp(
            r'不(?:必然|一定|总是)|并非|可能|或许|有时|未必|notnecessarily|may|might|sometimes')
        .hasMatch(e);
    final strongConclusion =
        RegExp(r'所有|总是|必然|一定|任何|一切|always|all|must|necessarily').hasMatch(c);
    if (weakEvidence && strongConclusion)
      return const SemanticVerification(
          VerificationStatus.unknown, '结论强化了原文的量词或模态；原文未给出普遍必然性的根据');
    if (strongConclusion &&
        condition != null &&
        RegExp(r'^(如果|若|只有|只要|除非|if\b|unless\b)', caseSensitive: false)
            .hasMatch(condition.trim()) &&
        e.contains(normalize(condition)) &&
        !c.contains(normalize(condition)))
      return const SemanticVerification(
          VerificationStatus.unknown, '结论强化了明确附带条件的原句；需核对条件是否仍成立');
    // Contradiction is only decidable for the exact same proposition and its
    // explicit negation, not for different predicates that happen to share words.
    String positive(String text) => text.contains('不是')
        ? text.replaceFirst('不是', '是')
        : text.replaceFirst(RegExp(r'并不|并非|不|not'), '');
    bool negative(String text) => RegExp(r'并不|并非|不是|不|not').hasMatch(text);
    if (negative(c) != negative(e) && positive(c) == positive(e)) {
      return const SemanticVerification(
          VerificationStatus.contradicted, '同一命题的否定方向与所引原句相反');
    }
    return const SemanticVerification(
        VerificationStatus.unknown, '引用存在，但主谓、量词、否定、条件或推理环节仍需逐项核验');
  }
}

/// Field names deliberately preserve the logical commitments for review.
class SemanticProposition {
  final String id,
      subject,
      predicate,
      quantifier,
      polarity,
      condition,
      modality,
      conclusion,
      evidence,
      origin;
  final SemanticVerification verification;
  const SemanticProposition(
      {required this.id,
      required this.subject,
      required this.predicate,
      required this.quantifier,
      required this.polarity,
      required this.condition,
      required this.modality,
      required this.conclusion,
      required this.evidence,
      required this.origin,
      required this.verification});
  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'predicate': predicate,
        'quantifier': quantifier,
        'polarity': polarity,
        'condition': condition,
        'modality': modality,
        'conclusion': conclusion,
        'evidence': evidence,
        'origin': origin,
        'verification': verification.toJson()
      };
}

import '../models/quote_insight.dart';
import 'concept_analysis.dart';

bool isBotanicalPassage(String text) =>
    text.contains('花蕾') &&
    text.contains('花朵') &&
    text.contains('果实') &&
    (text.contains('否定') || text.contains('取代'));

bool isAttentionPassage(String text) =>
    (text.contains('经验') &&
        (text.contains('同意去注意') ||
            text.contains('同意注意') ||
            text.contains('同意留意'))) ||
    text.toLowerCase().contains('my experience is what i agree to attend to');

/// Editorial reading exercises matched by the wording of a passage. The
/// universe is intentionally narrower than the philosophical claim.
ConceptScope? passageScope(String text) {
  if (isBotanicalPassage(text)) {
    return const ConceptScope(
        relation: QuoteRelation.siblings,
        universe: '同一株植物在不同观察时刻的局部形态',
        setA: '花蕾',
        setB: '开放的花',
        criterionA: '观察对象是尚未开放的花蕾',
        criterionB: '观察对象是已经开放的花',
        onlyA: '周一标记的花枝上，花瓣仍合拢。',
        onlyB: '周三在同一位置，花瓣已经展开。',
        otherMember: '再过数周，同一枝条上观察到逐渐长大的果实。它仍属于植物形态，却既不是花蕾也不是开放的花。',
        basis: '花蕾、花朵、果实',
        illustration: true,
        justification:
            '按同一时刻的形态分类，花蕾和开放的花分占两个区域。果实也在上位范围内，所以这两个圈没有穷尽它。花蕾到花朵再到果实是时间上的转化，需要沿三个时刻来读。');
  }
  if (isAttentionPassage(text)) {
    return const ConceptScope(
        relation: QuoteRelation.subset,
        universe: '一次观察中可分辨的桌面细节',
        setA: '留意到的细节',
        setB: '可察觉的细节',
        criterionA: '观察者在这一次观看中实际留意了该细节',
        criterionB: '该细节在当时的视野和光线下可以察觉',
        intersection: '桌上同时摆着红杯和钥匙。观察者先看向红杯，留意到了杯沿的小缺口。',
        onlyB: '钥匙环上的划痕同样可见，但观察者直到第二次寻找时才注意到它。',
        basis: '注意与经验的选择',
        illustration: true,
        justification:
            '在这个模拟场景中，留意到的细节都属于当时可察觉的细节。钥匙上的划痕给出了反向包含不成立的例子。这个范围只涉及本次视觉观察。');
  }
  if (text.toLowerCase().contains('when we appreciate the good')) {
    return const ConceptScope(
        relation: QuoteRelation.overlap,
        universe: '一次工作复盘中的具体回应',
        setA: '察觉益处',
        setB: '表达感谢',
        criterionA: '能指出某项帮助实际带来的益处。',
        criterionB: '向他人表达了谢意。',
        onlyA: '记下同事的反馈帮自己发现一个错误，尚未向对方表达。',
        intersection: '说明这条反馈如何帮助纠错，并向同事道谢。',
        onlyB: '按惯例说了谢谢，但还没有辨认出对方具体帮了什么。',
        basis: 'appreciate the good',
        illustration: true,
        justification:
            '这项练习区分察觉和表达。原句中 appreciate 的双关还涉及价值增加。判断益处是否真的增加，需要比较前后的经验。');
  }
  if (text.contains('幸福') &&
      text.contains('山顶') &&
      (text.contains('攀登') || text.contains('攀爬') || text.contains('攀向'))) {
    return const ConceptScope(
        relation: QuoteRelation.overlap,
        universe: '登山途中可以逐段回忆的经历',
        setA: '朝目标前进',
        setB: '享受当下',
        criterionA: '这一段行动使人朝事先选定的目的地前进。',
        criterionB: '当事人在这一段路上感受到了乐趣。',
        onlyA: '冒雨赶路，缩短了与山顶的距离，但当时只感到难受。',
        intersection: '沿选好的山脊向上走，同时享受同行交谈和眼前的云海。',
        onlyB: '坐在岔路旁欣赏晚霞，此刻并未向目的地前进。',
        basis: '幸福、山顶与攀登',
        illustration: true,
        justification: '判断目的是理解朝向目标的愉快体验。能否登顶是另一项结果判准。有交集的一个片段可以发生在尚未到达终点时。');
  }
  return null;
}

/// Group names are a display index; stored themes and quotes retain their
/// original form. Prefer explicit annotations, then recognizable terms in a
/// legacy theme. Do not split a sentence into arbitrary character fragments.
List<String> indexTerms(String theme, Iterable<String> annotated, String text) {
  String clean(String value) => value
      .replaceFirst(
          RegExp(
              r'\s*[-—·|]\s*(?:chatgpt|claude|deepseek|gemini|gpt[-\w.]*)\s*$',
              caseSensitive: false),
          '')
      .trim();
  final explicit = annotated.map(clean).where((t) => t.isNotEmpty).toSet();
  if (explicit.isNotEmpty) return explicit.toList();
  const terms = [
    '注意力',
    '经验',
    '判断力',
    '判断',
    '否定',
    '转化',
    '自由',
    '秩序',
    '习惯',
    '行动',
    '性格',
    '创造力',
    '混沌',
    '感恩',
    '幸福',
    '意义',
    '痛苦',
    '成长',
    '价值',
    '目标',
    '过程',
    '勇气',
    '恐惧',
    '责任',
    '意志'
  ];
  final cleanTheme = clean(theme);
  final labels = <String>{
    for (final t in terms)
      if (cleanTheme.contains(t)) t
  };
  if (labels.contains('判断力')) labels.remove('判断');
  if (cleanTheme.contains('注意')) labels.add('注意力');
  if (labels.isEmpty && cleanTheme.isNotEmpty) labels.add(cleanTheme);
  if (isAttentionPassage(text)) labels.addAll(['注意力', '经验']);
  return labels.isEmpty ? ['未分类'] : labels.toList();
}

bool similarRecordWording(QuoteReference a, QuoteReference b) {
  String normalize(String s) => s
      .toLowerCase()
      .split(RegExp(r'[（(](?:原文|英文|中文译文)'))
      .first
      .replaceAll(RegExp(r'[\s\p{P}\p{S}]+', unicode: true), '');
  final x = normalize(a.content), y = normalize(b.content);
  final short = x.length < y.length ? x : y;
  if (short.runes.length < 10) return false;
  if (x == y) return true;
  if (a.author.trim().isEmpty || a.author.trim() != b.author.trim())
    return false;
  return x.contains(y) ||
      y.contains(x) ||
      (short.runes.length >= 16 && x.startsWith(y.substring(0, 16)));
}

const botanicalNegation = ConceptScope(
    illustration: true,
    relation: QuoteRelation.subset,
    universe: '围绕花枝比喻构造的形态变化案例',
    setA: '发展中的否定',
    setB: '旧形态消失',
    criterionA: '旧形态在同一发展过程中被后继形态取代，并构成后继形态得以形成的一个环节。',
    criterionB: '再次观察时，原来的形态已消失。',
    intersection: '花蕾开放为花。原有形态消逝，花蕾的发育也使花朵得以出现。',
    onlyB: '对照情境中，花蕾被剪碎。旧形态同样消失，现有材料却没有显示这朵花继续发育。',
    basis: '否定、消逝、取代',
    justification:
        '若判断目的是理解发展，决定性差异在于前后形态是否属于一个有内在联系的过程。单凭消失这一共同点，还无法断定发生了发展。');

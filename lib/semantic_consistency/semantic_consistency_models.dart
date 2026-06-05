import 'dart:convert';

import '../data/dao.dart';
import '../data/kv_dao.dart';
import '../services/global_ai_settings.dart';



class SemanticConsistencyPromptDefaults {
  static const String systemPrompt = """你是一个严格的多粒度语义关系精判器。

你的任务不是简单判断“像不像”，而是判断文本A与文本B的真实语义关系，并同时区分：
1. 语义相关度 relatednessScore：是否处于同一概念域、主题域、实例/外延/表现/效果/因果链条中；
2. 同义等价度 equivalenceScore：是否可以作为同一含义、同一事实、同一主张互换；
3. 覆盖度 coverageScore：匹配是局部片段命中、部分覆盖，还是全文/整体主旨一致。

你必须支持任意粒度组合：概念/词语、短句、段落、长文、文章。

重点关系类型包括：
- equivalent / near_equivalent：完全等价或近似等价；
- concept_instance：抽象概念与具体实例，例如“目标 / 每天按时起床去跑步”；
- hypernym / hyponym / extension_member：上下位或外延成员；
- manifestation：概念与具体表现；
- effect：概念与效果/结果；
- causal_relation / cause_effect：因果/原因结果；
- method_purpose：方法/手段与目的；
- possible_purpose_relation / possible_preparation_relation：可能的目的/准备关系，表示A可能服务于B或作为B的前置准备，但证据不足以确定；
- attribute：对象与属性；
- part_whole：部分与整体；
- co_hyponym：同类并列；
- mutually_exclusive / antonym / contradiction / negation_changed / topic_opposition：互斥、反义、矛盾、否定改变、主题相关但方向相反；
- local_high_related：长文本中存在局部高度相关证据，但不代表全文等价；
- global_high_related：整体主旨高度相关，但不一定同义；
- topic_related / related_not_equivalent：主题相关但不等价；
- weak_context_related / shared_context_only / ambiguous_related / weak_abstract_commonality：存在弱共同语境、仅共享背景、可能相关但证据不足，或只能从目的/功能/欲望/价值/心理机制上抽象出远层上位共同概念；
- possible_purpose_relation / possible_preparation_relation：存在“可能为了……/可能作为……准备”的关系，但当前文本没有明确连接词，不能说成确定因果或确定目的关系；
- unrelated / ambiguous：真正无关或语境不足。

判断原则：
- 高相关不等于同义；
- 原生 Embedding 余弦只能作为“语义场接近度参考”，不能作为最终裁判；
- Embedding 高时仍可能是反义、对立、买卖、成败等同一语义场内的相反关系；
- Embedding 低时仍可能是概念—实例、概念—外延、概念—效果、概念—表现关系；
- 一句话对长文时，必须指出是局部命中还是全文主旨相关；
- 两篇文章比较时，必须区分主题相似、观点一致、观点相反、证据局部重合、结论方向差异；
- 不能把“不是高度相关”直接等同于“完全无关”。如果二者存在同一时间、同一主体、同一生活场景、健康/休息/情绪等潜在共同背景，但证据不足以判定因果或同义，应输出 weak_context_related / shared_context_only / ambiguous_related；
- 每次判断必须明确列出 commonAspects（可能共同性）、differentAspects（关键差异）、unsupportedInferences（不能推出的关系）。
- “共同性”必须分清：①显性共同概念（双方都直接表达的概念）；②综合生成的新上位概念/共同语义场（不是原文原词，但能合理概括双方）；③只有形式上的浅层共同点（如都是一句话、都用第一人称）不能当成强共同性。
- “差异性”不能只写“主题不同”，必须按差异轴深度分析：核心对象、核心行为、语义领域、目的/意图、结果/后果、关系链条、时间范围、评价方向、事实状态等，能列多少列多少。
- 如果共同性很弱但差异很强，要明确说明：存在某些浅层共同背景，但不构成高度语义相关；如果确实无实质共同概念，也要说明只是形式共同而非语义共同。
- 还必须主动从目的、功能、欲望/需求、结果、价值、心理机制和行为结构中寻找上位抽象共同概念。若只能抽象到很高层的“欲望满足/需求满足/生活奖赏/获得感”等，必须标为 weak_abstract_commonality，不得夸大为高度相关。
- 共同性分数必须分层：directCommonalityScore=显性/直接共同性；abstractCommonalityScore=上位抽象共同性；substantialCommonalityScore=能否支撑实际高度相关。

is_semantically_consistent 只表示“能否作为同一含义/同一事实/同一主张互换”。概念—实例、外延、表现、效果、因果、局部高相关通常 highlyRelated=true，但 sameMeaning/is_semantically_consistent=false。weak_context_related 表示存在弱共同语境，highlyRelated=false，sameMeaning=false，completelyUnrelated=false。

输出风格硬性要求：
- 先给 oneSentenceConclusion，用户应能一眼看懂最终判断。
- commonAspects 最多3条，differentAspects/differenceAxes 最多3条，unsupportedInferences 最多3条。
- commonalitySummary 与 differenceSummary 必须简短、去重、面向普通用户。
- commonConceptAnalysis 和 differenceAnalysis 只能作为压缩说明，不得长篇堆砌，不得重复列表内容。
- 不得同时说“完全无关”和“存在弱上位共同性”；若存在 weak_abstract_commonality，completelyUnrelated 必须为 false。
- 不要输出“核心对象；行为；语义领域；目的...”这类空泛字段名，必须写出具体差异。
- 对近义词、成语、四字词、形容词和抽象概念的比较，必须抓住“本质共同性”和“本质差异”：共同语义核心是什么，A 的语义重心是什么，B 的语义重心是什么，二者的适用场景、搭配对象、隐含画面和可互换边界分别是什么。
- 禁止把关键差异写成“用词不同”“词根不同”“主题相同”这类轻描淡写表达；必须指出差异为什么会影响使用场景、语义焦点或互换边界。
- 若 relation 为 near_equivalent/equivalent，仍必须说明“近义不等于完全等价”的边界：哪些语境可互换，哪些语境不宜互换。
- 如果二者确实高度近义，commonalitySummary 应写本质共同核心，differenceSummary 应写关键语义焦点差异，不要只写“都属于同一语义场”。

只输出 JSON，不要输出 markdown，不要输出 JSON 之外的任何文字。""";

  static const String jsonSchema = """{
  "relation": "equivalent|near_equivalent|mostly_consistent|concept_instance|hypernym|hyponym|extension_member|manifestation|effect|causal_relation|cause_effect|method_purpose|possible_purpose_relation|possible_preparation_relation|attribute|part_whole|co_hyponym|mutually_exclusive|antonym|topic_opposition|negation_changed|related_not_equivalent|topic_related|weak_context_related|shared_context_only|ambiguous_related|weak_abstract_commonality|local_high_related|global_high_related|contradiction|reversed_roles|unsupported|unrelated|ambiguous|faithful|partially_faithful|overclaim|misleading",
  "is_semantically_consistent": false,
  "sameMeaning": false,
  "highlyRelated": true,
  "completelyUnrelated": false,
  "relatednessScore": 0.0,
  "equivalenceScore": 0.0,
  "coverageScore": 0.0,
  "localBestScore": 0.0,
  "confidence": 0.0,
  "oneSentenceConclusion": "一句话总论，必须先说明：同义/高度相关/弱共同性/差异强/无关中的核心结论；不超过60个汉字",
  "commonalitySummary": "共同性简明总结，只保留最关键的1-2个共同点；不超过80个汉字",
  "differenceSummary": "差异性简明总结，只保留最关键的1-2个差异轴；不超过80个汉字",
  "essentialCommonality": "本质共同性：一句话说明二者真正共享的语义核心/功能机制/审美或概念核心；不超过80个汉字",
  "essentialDifference": "本质差异：一句话说明最关键的语义重心、功能、场景或互换边界差异；不超过100个汉字",
  "aSemanticFocus": "文本A的语义重心/隐含画面/主要功能；不超过60个汉字",
  "bSemanticFocus": "文本B的语义重心/隐含画面/主要功能；不超过60个汉字",
  "interchangeableContext": "可以互换或近似互换的语境；若不可互换则说明无；不超过80个汉字",
  "nonInterchangeableContext": "不宜互换的语境和原因；不超过100个汉字",
  "finalVerdict": "面向用户的最终判定，不超过80个汉字",
  "matchScope": "exact|global|local|partial|topic|weak_context|shared_context|opposition|none",
  "direction": "A_to_B|B_to_A|bidirectional|none",
  "aRole": "文本A在该关系中的角色",
  "bRole": "文本B在该关系中的角色",
  "topEvidence": ["最关键的匹配证据；最多3条；如果没有则空数组"],
  "commonAspects": ["共同性；最多3条，每条不超过35字；先列显性共同性，再列上位抽象共同性"],
  "commonConcepts": ["共同概念；最多3条；标明显性共同概念/新上位共同概念/浅层共同背景"],
  "commonConceptAnalysis": "共同性深度分析的压缩版：只说明共同性层级和能否支撑高度相关；不超过120字，不要重复 commonAspects",
  "directCommonalityScore": 0.0,
  "abstractCommonalityScore": 0.0,
  "substantialCommonalityScore": 0.0,
  "commonalityLevel": "explicit|substantial|weak_abstract|shallow|none",
  "differentAspects": ["关键差异；最多3条，每条不超过35字"],
  "differenceAxes": ["差异轴；最多3条，格式建议：核心对象：A=...；B=..."],
  "differenceAnalysis": "差异性深度分析的压缩版：只说明最关键差异为何影响同义/相关判断；不超过120字，不要重复 differenceAxes",
  "differenceScore": 0.0,
  "unsupportedInferences": ["不能推出的关系；最多3条，例如不能推出因果/同一事件/同义"],
  "error_type": "none|role_reversal|negation_changed|modality_changed|condition_changed|time_changed|scope_changed|unsupported_claim|overclaim|local_only|opposition|ambiguous|other",
  "key_difference": "一句话说明关键差异；若无则空字符串",
  "reason": "给出具体判断理由，必须说明是同义、实例、外延、表现、效果、因果、局部命中、整体主旨相关、方向相反还是无关"
}""";

  static const String userPromptTemplate = """请判断以下两个文本的语义关系。

当前模式：{{modeLabel}}
Embedding 余弦相似度：{{embeddingCosine}}

{{extraInstruction}}

{{titleEvidenceBlock}}

文本A：
{{textA}}

文本B：
{{textB}}

请严格输出如下 JSON：
{{jsonSchema}}""";

  static const String semanticRelationInstruction = """这是“通用多粒度语义关系精判”模式。请不要把 Embedding 分数当成最终结论；它只用于诊断和召回参考。

你必须支持任意粒度组合：概念/词语 ↔ 句子、句子 ↔ 段落、句子 ↔ 长文、段落 ↔ 段落、段落 ↔ 长文、长文 ↔ 长文。

请同时给出三种判断：
1. relatednessScore：语义相关度，表示二者是否处于同一主题、概念域、实例/外延/效果/表现链条中；
2. equivalenceScore：同义/等价度，表示二者是否可以作为同一含义/同一事实互换；
3. coverageScore：覆盖度，表示匹配是局部命中、部分覆盖，还是全文/整体主旨一致。

relation 必须选择最具体的关系类型：
- equivalent / near_equivalent：同义或近似等价；
- concept_instance：抽象概念与具体实例，例如“目标 / 每天按时起床去跑步”；
- hypernym / hyponym / extension_member：上下位或概念外延成员；
- manifestation：概念与具体表现，例如“坚持 / 连续三个月每天练习英语”；
- effect：概念与效果/结果，例如“长期熬夜 / 注意力下降”；
- cause_effect / causal_relation：原因与结果；
- method_purpose：方法/手段与目的；
- possible_purpose_relation / possible_preparation_relation：可能的目的/准备关系，表示A可能服务于B或作为B的前置准备，但证据不足以确定；
- attribute：对象与属性；
- part_whole：部分与整体；
- co_hyponym：同类并列；
- mutually_exclusive / antonym / contradiction / negation_changed / topic_opposition：互斥、反义、矛盾、否定改变或主题相关但方向相反；
- local_high_related：一方长文中局部片段与另一方高度相关，但全文覆盖度不高；
- global_high_related：全文/整体主旨高度相关，但不一定同义；
- topic_related / related_not_equivalent：主题相关但不等价；
- weak_context_related / shared_context_only / ambiguous_related / weak_abstract_commonality：存在弱共同语境、仅共享背景、可能相关但证据不足，或只能从目的/功能/欲望/价值/心理机制上抽象出远层上位共同概念；
- possible_purpose_relation / possible_preparation_relation：存在“可能为了……/可能作为……准备”的关系，但当前文本没有明确连接词，不能说成确定因果或确定目的关系；
- unrelated / ambiguous：真正无关或语境不足。

特别注意：
- “高度相关”不等于“同义”；
- 反义词可能原生 Embedding 接近，但 equivalenceScore 必须很低；
- 抽象概念和具体实例即使原生 Embedding 很低，也可能 relatednessScore 很高；
- 如果 B 可以回答“A 的一个例子/外延/表现/效果是什么”，通常是高度相关但非同义；
- 如果 A 不是 B 本身，但在常识上可能作为 B 的准备、条件、前置动作、服务性行为或方法，例如“洗澡/清洁身体”可能是“约会/亲密行为”的前置准备，应输出 possible_preparation_relation 或 possible_purpose_relation。必须同时说明：这只是可能关系，不能从文本必然推出。
- 长文本比较时必须区分“局部高度相关”和“全文主旨相关”，不能因为长文里只有一个相关段落就说全文等价；
- 判断时必须同时说明“共同性”和“差异”。如果有弱共同背景但没有明确因果/同义/包含关系，不要判成绝对无关，应判为 weak_context_related / shared_context_only / ambiguous_related。
- 共同性要输出“新/老概念”层级：老概念=文本双方显性共享的概念；新概念=从双方内容综合抽象出的上位共同概念/共同语义场；浅层共同性=只有时间、第一人称、表述形式等，不能夸大成高度相关。
- 差异性要按差异轴深度分析，不要只写“主题完全不同”；请分别指出核心对象、行为、目的、结果、语义领域、关系链条等到底哪里不同。

补充要求：必须主动寻找“上位抽象共同性”，不能只检查共同关键词或同一主题。即使 A 与 B 的直接对象、行为、领域完全不同，也要从以下角度判断是否存在弱上位共同概念：
1. 目的共同性：二者是否服务于某种更高层目的；
2. 功能共同性：二者在人生活动中是否发挥类似功能；
3. 欲望/需求共同性：二者是否都满足某种需要、欲望、冲动、获得感、控制感、安全感、成就感、亲密感、释放感；
4. 结果共同性：二者是否都指向获得、损失、改善、释放、满足、交换、补偿；
5. 价值共同性：二者是否体现类似价值追求或生活奖赏；
6. 心理机制共同性：二者是否涉及相似心理动力，如追求、回避、补偿、占有、表达、证明、连接、释放；
7. 行为结构共同性：二者是否都属于获得、交换、消费、竞争、亲密、表达、回避、修复等结构。

但必须防止过度泛化：
- 显性共同性：双方直接共享概念/对象/事件/关系链，可提高 relatednessScore。
- 实质共同性：虽然词不同，但在目的、功能、机制或结果上比较接近，可判 related_not_equivalent。
- 弱上位抽象共同性：只能抽象到很高层概念，如“欲望满足/需求满足/生活奖赏/获得感”，应 relation=weak_abstract_commonality，directCommonalityScore 低，abstractCommonalityScore 中低，substantialCommonalityScore 低，highlyRelated=false，sameMeaning=false，completelyUnrelated=false。
- 浅层共同性：只是同为短句、同为第一人称、同为今天，不应当成实质共同。

差异分析必须深度展开：不要只说“主题不同”。要分析核心对象、行为类型、语义领域、目的/功能、结果/后果、欲望类型、价值方向、关系链条为什么不同。

本质分析要求：
- 必须优先识别“本质共同性”和“本质差异”，不要把分析停留在共同关键词、同一语义场或字面差异。
- 对 near_equivalent / equivalent / mostly_consistent，必须补充：共同语义核心、A 的语义重心、B 的语义重心、可互换语境、不宜互换语境。
- 对成语、四字词、形容词，必须分析隐含画面、审美色彩、动作/过程感、力量/状态感、搭配对象与使用边界。
- 例如“波澜壮阔 / 气势磅礴”：共同核心不是简单“都宏大”，而是“都表达宏大雄浑的壮美气象”；关键差异是前者偏过程展开/起伏/历史画卷感，后者偏力量气场/雄浑压迫感/瞬间震撼。
- 禁止只写“用词不同但意思相同”“词根不同导致细微差异”；这种说法不算合格差异分析。

展示友好要求：
- oneSentenceConclusion：一句话总论，必须不超过60字。
- commonalitySummary：共同性简明总结，不超过80字。
- differenceSummary：差异性简明总结，不超过80字。
- commonAspects、differentAspects、differenceAxes、unsupportedInferences 各最多3条。
- 不要重复同一个意思；不要把模型推理过程写成长段。
- 若需要深度分析，只保留最关键的层级判断，不要堆叠所有维度。

{{embeddingInstruction}}""";

  static const String standardJudgeInstruction = """这是短句语义精判模式。请直接根据文本含义判断，不要因为 Embedding 分数低就提前判无关。

重点检查：主动/被动是否只是表达转换，主语/宾语是否反转，是否有否定变化、程度变化、时间/条件/范围变化、可能性与事实性变化。

{{embeddingInstruction}}""";

  static const String strictFactInstruction = """这是严格事实一致模式。Embedding 只作为诊断参考，不能作为最终事实一致结论。

必须对照下方事件结构。如果 agent/patient 主客体反转、polarity 否定不同、modality 从“可能/假设/差点”变成“已经发生”、时间/条件/范围改变，则不得判为完全等价。

文本A事件结构：
{{eventA}}

文本B事件结构：
{{eventB}}

{{embeddingInstruction}}""";

  static const String titleFaithfulnessInstruction = """这是标题/摘要忠实性模式。文本A是文章全文，文本B是标题或摘要。
你必须基于给出的文章证据段落判断标题/摘要是否被文章支持。
尤其检查：是否把可能性说成确定性、把局部说成整体、把测试说成发布、把动物实验说成人类有效、加入文章没有的信息、遗漏关键限制条件。""";

  static const String retrievalRerankInstruction = """这是高精度候选精排模式。文本A是查询/目标语义，文本B中原本包含多个候选。下面是系统筛选出的前5个候选。
请判断最佳候选是否与文本A语义一致；如果只是相关但不等价，也要明确指出。

候选列表：
{{candidatesForJudge}}""";

  static String instructionForMode(SemanticPrecisionMode mode) {
    switch (mode) {
      case SemanticPrecisionMode.semanticRelation:
        return semanticRelationInstruction;
      case SemanticPrecisionMode.standardJudge:
        return standardJudgeInstruction;
      case SemanticPrecisionMode.strictFact:
        return strictFactInstruction;
      case SemanticPrecisionMode.titleFaithfulness:
        return titleFaithfulnessInstruction;
      case SemanticPrecisionMode.retrievalRerank:
        return retrievalRerankInstruction;
      case SemanticPrecisionMode.fastEmbedding:
        return '';
    }
  }
}

/// 精判模式：从低成本相似度，到严格事实/标题忠实性/候选精排。
enum SemanticPrecisionMode {
  fastEmbedding,
  semanticRelation,
  standardJudge,
  strictFact,
  titleFaithfulness,
  retrievalRerank,
}

extension SemanticPrecisionModeX on SemanticPrecisionMode {
  String get id {
    switch (this) {
      case SemanticPrecisionMode.fastEmbedding:
        return 'fast_embedding';
      case SemanticPrecisionMode.semanticRelation:
        return 'semantic_relation';
      case SemanticPrecisionMode.standardJudge:
        return 'standard_judge';
      case SemanticPrecisionMode.strictFact:
        return 'strict_fact';
      case SemanticPrecisionMode.titleFaithfulness:
        return 'title_faithfulness';
      case SemanticPrecisionMode.retrievalRerank:
        return 'retrieval_rerank';
    }
  }

  String get label {
    switch (this) {
      case SemanticPrecisionMode.fastEmbedding:
        return '多路召回诊断';
      case SemanticPrecisionMode.semanticRelation:
        return '概念/语义关系精判';
      case SemanticPrecisionMode.standardJudge:
        return '短句语义精判';
      case SemanticPrecisionMode.strictFact:
        return '严格事实一致';
      case SemanticPrecisionMode.titleFaithfulness:
        return '标题/摘要忠实性';
      case SemanticPrecisionMode.retrievalRerank:
        return '高精度候选精排';
    }
  }

  String get description {
    switch (this) {
      case SemanticPrecisionMode.fastEmbedding:
        return '不调用 LLM，展示原生 Embedding cosine、分句/片段最高命中、概念原型/典型表达命中、关键词和短文本乱序规则；用于诊断召回，不等同于事实等价。';
      case SemanticPrecisionMode.semanticRelation:
        return '通用多粒度语义关系精判：支持词/概念/句子/段落/长文任意组合，区分语义场相关度、同义等价度、覆盖度与关系类型；原生 Embedding 余弦仍单独显示，仅作参考。';
      case SemanticPrecisionMode.standardJudge:
        return '直接调用语言模型裁判，不再因 Embedding 分数低而提前判无关；适合短句等价、矛盾、主客体反转判断。';
      case SemanticPrecisionMode.strictFact:
        return '额外抽取事件结构，再让模型精判，重点检查主语、宾语、否定、条件、时间。';
      case SemanticPrecisionMode.titleFaithfulness:
        return '先从长文中检索标题相关证据，再判断标题/摘要是否忠实、夸大或误导。';
      case SemanticPrecisionMode.retrievalRerank:
        return '用于一个问题对多个候选文本精排：Embedding TopK → 可选 Reranker → LLM Judge。';
    }
  }

}

SemanticPrecisionMode semanticPrecisionModeFromId(String? id) {
  final v = (id ?? '').trim();
  for (final mode in SemanticPrecisionMode.values) {
    if (mode.id == v) return mode;
  }
  return SemanticPrecisionMode.standardJudge;
}

class SemanticConsistencySettings {
  static const String defaultModeKey = 'semantic_consistency_default_mode';
  static const String embeddingProviderKey = 'semantic_consistency_embedding_provider';
  static const String embeddingModelKey = 'semantic_consistency_embedding_model';
  static const String embeddingDimensionsKey = 'semantic_consistency_embedding_dimensions';
  static const String lowThresholdKey = 'semantic_consistency_low_threshold';
  static const String highThresholdKey = 'semantic_consistency_high_threshold';
  static const String strictThresholdKey = 'semantic_consistency_strict_threshold';
  static const String enableRerankerKey = 'semantic_consistency_enable_reranker';
  static const String rerankerProviderKey = 'semantic_consistency_reranker_provider';
  static const String rerankerModelKey = 'semantic_consistency_reranker_model';
  static const String rerankerApiKeyKey = 'semantic_consistency_reranker_api_key';
  static const String rerankerEndpointKey = 'semantic_consistency_reranker_endpoint';
  static const String titleEvidenceTopKKey = 'semantic_consistency_title_evidence_top_k';
  static const String judgeSystemPromptKey = 'semantic_consistency_judge_system_prompt';
  static const String judgeUserPromptTemplateKey = 'semantic_consistency_judge_user_prompt_template';
  static const String judgeModeInstructionsKey = 'semantic_consistency_judge_mode_instructions_json';

  static const String defaultEmbeddingProvider = 'openrouter';
  static const String defaultEmbeddingModel = 'qwen/qwen3-embedding-4b';
  static const int defaultEmbeddingDimensions = 2560;
  static const double defaultLowThreshold = 0.45;
  static const double defaultHighThreshold = 0.65;
  static const double defaultStrictThreshold = 0.80;
  static const String defaultRerankerProvider = 'cohere';
  static const String defaultRerankerModel = 'rerank-v3.5';
  static const String defaultRerankerEndpoint = 'https://api.cohere.com/v2/rerank';
  static const int defaultTitleEvidenceTopK = 5;

  final SemanticPrecisionMode defaultMode;
  final String embeddingProvider;
  final String embeddingModel;
  final int embeddingDimensions;
  final double lowThreshold;
  final double highThreshold;
  final double strictThreshold;
  final bool enableReranker;
  final String rerankerProvider;
  final String rerankerModel;
  final String rerankerApiKey;
  final String rerankerEndpoint;
  final int titleEvidenceTopK;
  final String judgeSystemPrompt;
  final String judgeUserPromptTemplate;
  final Map<String, String> judgeModeInstructions;

  SemanticConsistencySettings({
    required this.defaultMode,
    required this.embeddingProvider,
    required this.embeddingModel,
    required this.embeddingDimensions,
    required this.lowThreshold,
    required this.highThreshold,
    required this.strictThreshold,
    required this.enableReranker,
    required this.rerankerProvider,
    required this.rerankerModel,
    required this.rerankerApiKey,
    required this.rerankerEndpoint,
    required this.titleEvidenceTopK,
    required this.judgeSystemPrompt,
    required this.judgeUserPromptTemplate,
    required Map<String, String> judgeModeInstructions,
  }) : judgeModeInstructions = Map.unmodifiable(judgeModeInstructions);

  SemanticConsistencySettings copyWith({
    SemanticPrecisionMode? defaultMode,
    String? embeddingProvider,
    String? embeddingModel,
    int? embeddingDimensions,
    double? lowThreshold,
    double? highThreshold,
    double? strictThreshold,
    bool? enableReranker,
    String? rerankerProvider,
    String? rerankerModel,
    String? rerankerApiKey,
    String? rerankerEndpoint,
    int? titleEvidenceTopK,
    String? judgeSystemPrompt,
    String? judgeUserPromptTemplate,
    Map<String, String>? judgeModeInstructions,
  }) {
    return SemanticConsistencySettings(
      defaultMode: defaultMode ?? this.defaultMode,
      embeddingProvider: embeddingProvider ?? this.embeddingProvider,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      embeddingDimensions: embeddingDimensions ?? this.embeddingDimensions,
      lowThreshold: lowThreshold ?? this.lowThreshold,
      highThreshold: highThreshold ?? this.highThreshold,
      strictThreshold: strictThreshold ?? this.strictThreshold,
      enableReranker: enableReranker ?? this.enableReranker,
      rerankerProvider: rerankerProvider ?? this.rerankerProvider,
      rerankerModel: rerankerModel ?? this.rerankerModel,
      rerankerApiKey: rerankerApiKey ?? this.rerankerApiKey,
      rerankerEndpoint: rerankerEndpoint ?? this.rerankerEndpoint,
      titleEvidenceTopK: titleEvidenceTopK ?? this.titleEvidenceTopK,
      judgeSystemPrompt: judgeSystemPrompt ?? this.judgeSystemPrompt,
      judgeUserPromptTemplate: judgeUserPromptTemplate ?? this.judgeUserPromptTemplate,
      judgeModeInstructions: judgeModeInstructions ?? this.judgeModeInstructions,
    );
  }

  static Future<SemanticConsistencySettings> load() async {
    final kv = KeyValueDao();
    final defaultMode = semanticPrecisionModeFromId(await kv.getString(defaultModeKey));
    final embeddingProvider = _nonEmpty(await kv.getString(embeddingProviderKey), defaultEmbeddingProvider);
    final embeddingModel = _nonEmpty(await kv.getString(embeddingModelKey), defaultEmbeddingModel);
    final embeddingDimensions = _parseInt(await kv.getString(embeddingDimensionsKey), defaultEmbeddingDimensions, min: 64, max: 8192);
    final lowThreshold = _parseDouble(await kv.getString(lowThresholdKey), defaultLowThreshold, min: -1, max: 1);
    final highThreshold = _parseDouble(await kv.getString(highThresholdKey), defaultHighThreshold, min: -1, max: 1);
    final strictThreshold = _parseDouble(await kv.getString(strictThresholdKey), defaultStrictThreshold, min: -1, max: 1);
    final enableReranker = ((await kv.getString(enableRerankerKey)) ?? '').trim() == '1';
    final rerankerProvider = _nonEmpty(await kv.getString(rerankerProviderKey), defaultRerankerProvider);
    final rerankerModel = _nonEmpty(await kv.getString(rerankerModelKey), defaultRerankerModel);
    final rerankerApiKey = ((await kv.getString(rerankerApiKeyKey)) ?? '').trim();
    final rerankerEndpoint = _nonEmpty(await kv.getString(rerankerEndpointKey), defaultRerankerEndpoint);
    final titleEvidenceTopK = _parseInt(await kv.getString(titleEvidenceTopKKey), defaultTitleEvidenceTopK, min: 1, max: 12);
    final judgeSystemPrompt = _nonEmpty(await kv.getString(judgeSystemPromptKey), SemanticConsistencyPromptDefaults.systemPrompt);
    final judgeUserPromptTemplate = _nonEmpty(await kv.getString(judgeUserPromptTemplateKey), SemanticConsistencyPromptDefaults.userPromptTemplate);
    final judgeModeInstructions = _parsePromptInstructionMap(await kv.getString(judgeModeInstructionsKey));
    return SemanticConsistencySettings(
      defaultMode: defaultMode,
      embeddingProvider: embeddingProvider,
      embeddingModel: embeddingModel,
      embeddingDimensions: embeddingDimensions,
      lowThreshold: lowThreshold,
      highThreshold: highThreshold,
      strictThreshold: strictThreshold,
      enableReranker: enableReranker,
      rerankerProvider: rerankerProvider,
      rerankerModel: rerankerModel,
      rerankerApiKey: rerankerApiKey,
      rerankerEndpoint: rerankerEndpoint,
      titleEvidenceTopK: titleEvidenceTopK,
      judgeSystemPrompt: judgeSystemPrompt,
      judgeUserPromptTemplate: judgeUserPromptTemplate,
      judgeModeInstructions: judgeModeInstructions,
    );
  }

  Future<void> save() async {
    final kv = KeyValueDao();
    await kv.setString(defaultModeKey, defaultMode.id);
    await kv.setString(embeddingProviderKey, embeddingProvider.trim());
    await kv.setString(embeddingModelKey, embeddingModel.trim());
    await kv.setString(embeddingDimensionsKey, embeddingDimensions.toString());
    await kv.setString(lowThresholdKey, lowThreshold.toString());
    await kv.setString(highThresholdKey, highThreshold.toString());
    await kv.setString(strictThresholdKey, strictThreshold.toString());
    await kv.setString(enableRerankerKey, enableReranker ? '1' : '0');
    await kv.setString(rerankerProviderKey, rerankerProvider.trim());
    await kv.setString(rerankerModelKey, rerankerModel.trim());
    await kv.setString(rerankerApiKeyKey, rerankerApiKey.trim());
    await kv.setString(rerankerEndpointKey, rerankerEndpoint.trim());
    await kv.setString(titleEvidenceTopKKey, titleEvidenceTopK.toString());
    await kv.setString(judgeSystemPromptKey, judgeSystemPrompt.trim());
    await kv.setString(judgeUserPromptTemplateKey, judgeUserPromptTemplate.trim());
    await kv.setString(judgeModeInstructionsKey, jsonEncode(judgeModeInstructions));
  }

  String resolvedJudgeSystemPrompt() {
    final text = judgeSystemPrompt.trim();
    return text.isEmpty ? SemanticConsistencyPromptDefaults.systemPrompt : text;
  }

  String resolvedJudgeUserPromptTemplate() {
    final text = judgeUserPromptTemplate.trim();
    return text.isEmpty ? SemanticConsistencyPromptDefaults.userPromptTemplate : text;
  }

  String resolvedModeInstruction(SemanticPrecisionMode mode) {
    final custom = judgeModeInstructions[mode.id]?.trim() ?? '';
    return custom.isEmpty ? SemanticConsistencyPromptDefaults.instructionForMode(mode) : custom;
  }

  Future<String> resolveEmbeddingApiKey() async {
    final provider = embeddingProvider.trim().toLowerCase();
    final configDao = ConfigDao();
    if (provider == 'openai') {
      final global = await configDao.getOne();
      return (global['api_key'] ?? '').toString().trim();
    }
    if (provider == 'edenai') {
      return GlobalAiSettings().getEdenAiKey();
    }
    return configDao.getOpenRouterKey();
  }

  String get embeddingEndpoint {
    final provider = embeddingProvider.trim().toLowerCase();
    if (provider == 'openai') return 'https://api.openai.com/v1/embeddings';
    if (provider == 'edenai') return 'https://api.edenai.run/v3/embeddings';
    return 'https://openrouter.ai/api/v1/embeddings';
  }

  String get embeddingProviderLabel {
    final provider = embeddingProvider.trim().toLowerCase();
    if (provider == 'openai') return 'OpenAI Embedding';
    if (provider == 'edenai') return 'Eden AI Embedding';
    return 'OpenRouter Embedding';
  }

  static Map<String, String> _parsePromptInstructionMap(String? raw) {
    final fallback = <String, String>{
      for (final mode in SemanticPrecisionMode.values)
        if (mode != SemanticPrecisionMode.fastEmbedding) mode.id: SemanticConsistencyPromptDefaults.instructionForMode(mode),
    };
    final text = (raw ?? '').trim();
    if (text.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final out = Map<String, String>.from(fallback);
        for (final entry in decoded.entries) {
          final key = entry.key.toString();
          final value = (entry.value ?? '').toString();
          if (key.trim().isNotEmpty && value.trim().isNotEmpty) {
            out[key] = value;
          }
        }
        return out;
      }
    } catch (_) {}
    return fallback;
  }

  static String _nonEmpty(String? value, String fallback) {
    final text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

  static int _parseInt(String? raw, int fallback, {required int min, required int max}) {
    final value = int.tryParse((raw ?? '').trim()) ?? fallback;
    return value.clamp(min, max).toInt();
  }

  static double _parseDouble(String? raw, double fallback, {required double min, required double max}) {
    final value = double.tryParse((raw ?? '').trim()) ?? fallback;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

class SemanticConsistencyResult {
  final int? id;
  final String mode;
  final String textA;
  final String textB;
  final double? cosineScore;
  final String relation;
  final bool isConsistent;
  final double confidence;
  final String errorType;
  final String keyDifference;
  final String reason;
  final String provider;
  final String model;
  final String embeddingProvider;
  final String embeddingModel;
  final String judgeProvider;
  final String judgeModel;
  final String rawRequest;
  final String rawResponse;
  final int createdAt;
  final String extraJson;

  const SemanticConsistencyResult({
    this.id,
    required this.mode,
    required this.textA,
    required this.textB,
    required this.cosineScore,
    required this.relation,
    required this.isConsistent,
    required this.confidence,
    required this.errorType,
    required this.keyDifference,
    required this.reason,
    required this.provider,
    required this.model,
    required this.embeddingProvider,
    required this.embeddingModel,
    required this.judgeProvider,
    required this.judgeModel,
    required this.rawRequest,
    required this.rawResponse,
    required this.createdAt,
    required this.extraJson,
  });

  String get relationLabel {
    switch (relation) {
      case 'equivalent':
        return '完全等价';
      case 'near_equivalent':
        return '高度近义/近似等价';
      case 'hypernym':
        return '上位概念关系';
      case 'hyponym':
        return '下位概念关系';
      case 'co_hyponym':
        return '同类并列关系';
      case 'mutually_exclusive':
        return '互斥关系';
      case 'causal_relation':
      case 'cause_effect':
        return '因果/原因结果关系';
      case 'entailment':
        return '蕴含/推出关系';
      case 'concept_instance':
        return '概念—实例关系';
      case 'extension_member':
        return '概念—外延成员';
      case 'manifestation':
        return '概念—具体表现';
      case 'effect':
        return '概念—效果/结果';
      case 'method_purpose':
        return '方法/手段—目的';
      case 'possible_purpose_relation':
        return '可能目的关系';
      case 'possible_preparation_relation':
        return '可能前置准备关系';
      case 'attribute':
        return '属性关系';
      case 'part_whole':
        return '部分—整体关系';
      case 'topic_related':
        return '主题相关';
      case 'weak_context_related':
        return '弱语境相关';
      case 'shared_context_only':
        return '仅共享背景';
      case 'ambiguous_related':
        return '可能相关但语境不足';
      case 'weak_abstract_commonality':
        return '弱上位抽象共同性';
      case 'topic_opposition':
        return '主题相关但方向相反';
      case 'local_high_related':
        return '局部高度相关';
      case 'global_high_related':
        return '全文/整体高度相关';
      case 'prerequisite':
        return '前提/条件关系';
      case 'antonym':
        return '反义/对立关系';
      case 'negation_changed':
        return '否定改变';
      case 'mostly_consistent':
        return '大体一致';
      case 'related_not_equivalent':
        return '相关但不等价';
      case 'contradiction':
        return '矛盾';
      case 'reversed_roles':
        return '主客体反转';
      case 'unsupported':
        return '原文不支持';
      case 'faithful':
        return '忠实概括';
      case 'partially_faithful':
        return '部分忠实';
      case 'overclaim':
        return '夸大';
      case 'misleading':
        return '误导';
      case 'high_semantic_similarity':
      case 'high_vector_related':
        return '高向量接近';
      case 'medium_semantic_similarity':
      case 'medium_vector_related':
        return '中等向量接近';
      case 'low_semantic_similarity':
      case 'low_vector_related':
        return '低向量接近';
      case 'high_multi_route_related':
        return '多路召回高相关';
      case 'medium_multi_route_related':
        return '多路召回中等相关';
      case 'low_multi_route_related':
        return '多路召回低相关';
      case 'surface_order_mismatch':
        return '短文本乱序/词序不一致';
      case 'unrelated':
        return '无关';
      case 'ambiguous':
        return '歧义/无法判断';
      default:
        return relation.isEmpty ? '未知' : relation;
    }
  }

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'mode': mode,
      'text_a': textA,
      'text_b': textB,
      'cosine_score': cosineScore,
      'relation': relation,
      'is_consistent': isConsistent ? 1 : 0,
      'confidence': confidence,
      'error_type': errorType,
      'key_difference': keyDifference,
      'reason': reason,
      'provider': provider,
      'model': model,
      'embedding_provider': embeddingProvider,
      'embedding_model': embeddingModel,
      'judge_provider': judgeProvider,
      'judge_model': judgeModel,
      'raw_request': rawRequest,
      'raw_response': rawResponse,
      'created_at': createdAt,
      'extra_json': extraJson,
    };
  }

  factory SemanticConsistencyResult.fromDb(Map<String, Object?> row) {
    return SemanticConsistencyResult(
      id: _toInt(row['id']),
      mode: (row['mode'] ?? '').toString(),
      textA: (row['text_a'] ?? '').toString(),
      textB: (row['text_b'] ?? '').toString(),
      cosineScore: _toDoubleOrNull(row['cosine_score']),
      relation: (row['relation'] ?? '').toString(),
      isConsistent: _toInt(row['is_consistent']) == 1,
      confidence: _toDouble(row['confidence']),
      errorType: (row['error_type'] ?? '').toString(),
      keyDifference: (row['key_difference'] ?? '').toString(),
      reason: (row['reason'] ?? '').toString(),
      provider: (row['provider'] ?? '').toString(),
      model: (row['model'] ?? '').toString(),
      embeddingProvider: (row['embedding_provider'] ?? '').toString(),
      embeddingModel: (row['embedding_model'] ?? '').toString(),
      judgeProvider: (row['judge_provider'] ?? '').toString(),
      judgeModel: (row['judge_model'] ?? '').toString(),
      rawRequest: (row['raw_request'] ?? '').toString(),
      rawResponse: (row['raw_response'] ?? '').toString(),
      createdAt: _toInt(row['created_at']),
      extraJson: (row['extra_json'] ?? '').toString(),
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static double _toDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static double? _toDoubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toDbMap());
  }
}

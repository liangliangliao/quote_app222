import 'self_os_codec.dart';

/// A resumable conversation, separate from verified evidence and commitments.
/// The model can propose a frame; only user actions advance confirmation.
class OsGuideState {
  final List<Map<String, dynamic>> turns = [];
  Map<String, dynamic>? frame;
  final Map<String, dynamic> draft = {};
  final List<Map<String, dynamic>> confirmations = [];
  int revision = 0;
  int? confirmedRevision;
  String phase = 'explore';
  String compose = '';
  bool get confirmed => confirmedRevision == revision && frame != null;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'turns': turns.map(osClone).toList(),
        'frame': frame == null ? null : osClone(frame!),
        'draft': osClone(draft),
        'confirmations': confirmations.map(osClone).toList(),
        'revision': revision,
        'confirmedRevision': confirmedRevision,
        'phase': phase,
        'compose': compose,
      };

  OsGuideState();
  factory OsGuideState.fromJson(Map<String, dynamic> j) {
    if (j.isNotEmpty && j['version'] != 1) {
      throw const FormatException('无法读取此版本的引导记录，原有记录已保留');
    }
    return OsGuideState()
      ..turns.addAll(osMaps(j['turns']))
      ..frame = j['frame'] is Map ? osClone(osMap(j['frame'])) : null
      ..draft.addAll(osMap(j['draft']))
      ..confirmations.addAll(osMaps(j['confirmations']))
      ..revision = (j['revision'] as num?)?.toInt() ?? 0
      ..confirmedRevision = (j['confirmedRevision'] as num?)?.toInt()
      ..phase = osText(j['phase']).isEmpty ? 'explore' : osText(j['phase'])
      ..compose = osText(j['compose']);
  }
}

class OsGuideFrame {
  OsGuideFrame._(this.data);
  final Map<String, dynamic> data;
  String text(String key) => osText(data[key]);
  Map<String, dynamic> get insight => osMap(data['insight']);
  Map<String, dynamic> get question => osMap(data['question']);
  Map<String, dynamic> get experiment => osMap(data['experiment']);
  List<Map<String, dynamic>> get routes => osMaps(data['routes']);
  bool get ready => experiment.isNotEmpty;

  /// No arbitrary case fields, verification flags, scores or outcome writes.
  /// Quotations must be actual user text, including the latest correction.
  static OsGuideFrame parse(Map<String, dynamic> j,
      {required Map<String, String> userSources,
      required String latestId,
      Set<String> knownGapIds = const {}}) {
    String requiredText(Map<String, dynamic> row, String key, [int max = 500]) {
      final value = osText(row[key]).trim();
      if (value.isEmpty || value.length > max) {
        throw const FormatException('这次理解不够完整，请重试；你的输入已保留');
      }
      return value;
    }

    final basis = osMaps(j['basis']);
    if (basis.isEmpty || basis.length > 4) {
      throw const FormatException('这次理解缺少你的原话依据，请重试');
    }
    final quotes = <Map<String, dynamic>>[];
    for (final b in basis) {
      final id = osText(b['turnId']);
      final quote = requiredText(b, 'quote', 300);
      if (userSources[id]?.contains(quote) != true) {
        throw const FormatException('分析引用了未提供的内容，未采用这次结果');
      }
      quotes.add({'turnId': id, 'quote': quote});
    }
    if (!quotes.any((q) => q['turnId'] == latestId)) {
      throw const FormatException('这次理解没有回应你刚才的补充，请重试');
    }
    final question = osMap(j['question']);
    final experiment = osMap(j['experiment']);
    if (question.isEmpty == experiment.isEmpty) {
      throw const FormatException('每次应只提出一个关键问题或一个验证动作，请重试');
    }
    final insight = osMap(j['insight']);
    final routes = osMaps(j['routes']);
    final result = <String, dynamic>{
      'understanding': requiredText(j, 'understanding', 400),
      'toward': requiredText(j, 'toward', 160),
      'protect': requiredText(j, 'protect', 160),
      'basis': quotes,
      'risk':
          ['low', 'medium', 'high'].contains(j['risk']) ? j['risk'] : 'unknown',
    };
    if (insight.isNotEmpty) {
      result['insight'] = {
        for (final key in ['before', 'after', 'reason'])
          key: requiredText(insight, key, 400),
      };
    }
    if (routes.length > 4) {
      throw const FormatException('先比较最有区别的几条路径，请重试');
    }
    result['routes'] = [
      for (final route in routes)
        {
          for (final key in ['title', 'benefit', 'cost', 'unknown'])
            key: requiredText(route, key, 240),
          'mechanism': [
            'current',
            'alternative',
            'ability',
            'transition',
            'combination',
            'conditions',
            'experiment',
            'wait'
          ].contains(route['mechanism'])
              ? route['mechanism']
              : 'alternative',
        }
    ];
    if (question.isNotEmpty) {
      final options = osStrings(question['options']);
      final questionText = requiredText(question, 'text', 180);
      if (options.length > 3 ||
          options.any((o) => o.length > 80) ||
          RegExp('[?？]').allMatches(questionText).length > 1) {
        throw const FormatException('一次只需要回答一个关键问题，请重试');
      }
      result['question'] = {
        'text': questionText,
        'why': requiredText(question, 'why', 240),
        'options': options,
        'access':
            ['private', 'public', 'experience'].contains(question['access'])
                ? question['access']
                : 'private',
      };
    } else {
      if (latestId == 'problem' || insight.isEmpty || routes.length < 2) {
        throw const FormatException('还需要先理解你的具体处境，再提出验证动作');
      }
      final gapId = osText(experiment['gapId']);
      final routeTitle = osText(experiment['routeTitle']);
      if ((gapId.isNotEmpty && !knownGapIds.contains(gapId)) ||
          (routeTitle.isNotEmpty &&
              !routes.any((r) => r['title'] == routeTitle))) {
        throw const FormatException('验证动作引用了不存在的问题或路径，请重新理解');
      }
      result['experiment'] = {
        if (gapId.isNotEmpty) 'gapId': gapId,
        if (routeTitle.isNotEmpty) 'routeTitle': routeTitle,
        for (final key in [
          'action',
          'question',
          'prediction',
          'observe',
          'boundary',
          'stopWhen'
        ])
          key: requiredText(experiment, key, 400),
        'cue': osText(experiment['cue']).trim().length <= 100
            ? osText(experiment['cue']).trim()
            : '',
      };
    }
    return OsGuideFrame._(result);
  }

  factory OsGuideFrame.saved(Map<String, dynamic> j) =>
      OsGuideFrame._(osClone(j));
}

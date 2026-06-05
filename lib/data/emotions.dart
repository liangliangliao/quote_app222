import 'dart:math';
import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// 单个情绪表情定义
class EmojiItem {
  final String char;
  final String name;
  final List<String> tags;
  const EmojiItem({
    required this.char,
    required this.name,
    required this.tags,
  });
}

/// 18 个情绪表情条目
// 更新后的情绪表情列表。按照用户提供的版本重新编排，
// 包括强正向/一般正向/强负向/一般负向/混合及中性等分类。
final List<EmojiItem> unicornEmotions = [
  // ===== 强正向 + 强自尊相关 =====
  EmojiItem(char: "😎", name: "自信", tags: ["自信", "自我肯定", "从容", "稳"]),
  EmojiItem(char: "😌", name: "自豪", tags: ["自豪", "骄傲", "满足"]),
  EmojiItem(char: "😤", name: "骄傲", tags: ["骄傲", "挺起胸膛", "自豪感"]),
  EmojiItem(char: "🏆", name: "成就感", tags: ["成就感", "成功", "成果"]),
  EmojiItem(char: "✌️", name: "胜利", tags: ["胜利", "赢了", "成功"]),
  EmojiItem(char: "😊", name: "被认可", tags: ["被认可", "被接纳", "被肯定"]),
  EmojiItem(char: "🤗", name: "被赞赏", tags: ["被赞赏", "被表扬", "被欣赏"]),
  EmojiItem(char: "🤪", name: "狂喜忘我", tags: ["狂喜忘我", "嗨疯", "超兴奋"]),

  // ===== 一般正向情绪 =====
  EmojiItem(char: "😄", name: "开心", tags: ["开心", "高兴", "愉快"]),
  EmojiItem(char: "😁", name: "高兴", tags: ["高兴", "喜悦", "快乐"]),
  EmojiItem(char: "😌", name: "满足", tags: ["满足", "心满意足", "惬意"]),
  EmojiItem(char: "🙂", name: "满意", tags: ["满意", "还不错", "尚可"]),
  EmojiItem(char: "🤞", name: "希望", tags: ["希望", "盼望", "期待"]),
  EmojiItem(char: "🙏", name: "感激", tags: ["感激", "感谢", "感恩"]),
  EmojiItem(char: "❤️", name: "爱", tags: ["爱", "喜欢", "热爱"]),
  EmojiItem(char: "🤗", name: "亲密", tags: ["亲密", "贴近", "拥抱"]),
  EmojiItem(char: "💕", name: "浪漫", tags: ["浪漫", "暧昧", "恋爱"]),
  EmojiItem(char: "🙂", name: "兴致", tags: ["兴致", "兴趣", "来劲"]),
  EmojiItem(char: "😂", name: "娱乐", tags: ["娱乐", "搞笑", "好玩"]),
  EmojiItem(char: "🥰", name: "美学欣赏", tags: ["美学欣赏", "审美", "漂亮"]),
  EmojiItem(char: "🤩", name: "钦佩", tags: ["钦佩", "佩服", "欣赏"]),
  EmojiItem(char: "🙇‍♂️", name: "崇拜", tags: ["崇拜", "膜拜", "仰慕"]),
  EmojiItem(char: "🤯", name: "敬畏", tags: ["敬畏", "震撼", "肃然起敬"]),
  EmojiItem(char: "😍", name: "渴望", tags: ["渴望", "想要", "心动"]),
  EmojiItem(char: "😘", name: "性欲", tags: ["性欲", "欲望", "荷尔蒙"]),
  EmojiItem(char: "🤔", name: "好奇", tags: ["好奇", "疑问", "想知道"]),
  EmojiItem(char: "😌", name: "冷静", tags: ["冷静", "镇定", "淡定"]),
  EmojiItem(char: "😌", name: "放松", tags: ["放松", "轻松", "舒缓"]),
  EmojiItem(char: "😑", name: "平静", tags: ["平静", "中性", "稳定"]),
  EmojiItem(char: "🤗", name: "同情", tags: ["同情", "理解", "安慰"]),

  // ===== 强负向 + 强自尊相关 =====
  EmojiItem(char: "😔", name: "自卑", tags: ["自卑", "低自尊", "否定自己"]),
  EmojiItem(char: "😳", name: "羞愧", tags: ["羞愧", "害羞", "羞耻"]),
  EmojiItem(char: "🥺", name: "惭愧", tags: ["惭愧", "内疚", "不好意思"]),
  EmojiItem(char: "😞", name: "内疚", tags: ["内疚", "亏欠", "抱歉"]),
  EmojiItem(char: "😣", name: "自责", tags: ["自责", "怪自己", "后悔"]),
  EmojiItem(char: "😅", name: "尴尬", tags: ["尴尬", "不好意思", "窘迫"]),
  EmojiItem(char: "😞", name: "被拒绝", tags: ["被拒绝", "被否定"]),
  EmojiItem(char: "🥺", name: "被忽视", tags: ["被忽视", "被冷落"]),
  EmojiItem(char: "😔", name: "孤独", tags: ["孤独", "寂寞"]),
  EmojiItem(char: "😔", name: "不被理解", tags: ["不被理解", "沟通困难"]),
  EmojiItem(char: "😣", name: "挫败", tags: ["挫败", "不顺", "打击"]),
  EmojiItem(char: "😖", name: "失败感", tags: ["失败感", "失败", "没成功"]),
  EmojiItem(char: "😣", name: "厌恶自己", tags: ["厌恶自己", "讨厌自己"]),
  EmojiItem(char: "🫤", name: "嫉妒", tags: ["嫉妒", "吃醋", "羡慕"]),

  // ===== 一般负向情绪 =====
  EmojiItem(char: "😣", name: "痛苦", tags: ["痛苦", "难受", "折磨"]),
  EmojiItem(char: "🥺", name: "同情痛苦", tags: ["同情痛苦", "心疼"]),
  EmojiItem(char: "😞", name: "抑郁", tags: ["抑郁", "沮丧", "低落"]),
  EmojiItem(char: "😢", name: "难过", tags: ["难过", "伤心"]),
  EmojiItem(char: "😭", name: "悲伤", tags: ["悲伤", "痛哭", "心碎"]),
  EmojiItem(char: "😞", name: "失望", tags: ["失望", "落空"]),
  EmojiItem(char: "😰", name: "焦虑", tags: ["焦虑", "担心", "不安"]),
  EmojiItem(char: "😟", name: "焦虑感", tags: ["焦虑感", "忧虑"]),
  EmojiItem(char: "😟", name: "担心", tags: ["担心", "忧心"]),
  EmojiItem(char: "😩", name: "压力大", tags: ["压力大", "压迫", "累"]),
  EmojiItem(char: "😬", name: "紧张", tags: ["紧张", "僵硬"]),
  EmojiItem(char: "😨", name: "惶恐", tags: ["惶恐", "心慌"]),
  EmojiItem(char: "😨", name: "害怕", tags: ["害怕", "恐惧"]),
  EmojiItem(char: "😱", name: "恐惧", tags: ["恐惧", "惊恐"]),
  EmojiItem(char: "👻", name: "恐怖", tags: ["恐怖", "吓人"]),
  EmojiItem(char: "😠", name: "生气", tags: ["生气", "气愤"]),
  EmojiItem(char: "😡", name: "愤怒", tags: ["愤怒", "暴怒"]),
  EmojiItem(char: "😒", name: "烦躁", tags: ["烦躁", "烦"]),
  EmojiItem(char: "😤", name: "恼火", tags: ["恼火", "不爽"]),
  EmojiItem(char: "😐", name: "空虚", tags: ["空虚", "空洞"]),
  EmojiItem(char: "🫤", name: "羡慕", tags: ["羡慕", "眼红"]),
  EmojiItem(char: "💢", name: "恨", tags: ["恨", "憎恨"]),
  EmojiItem(char: "🤢", name: "厌恶", tags: ["厌恶", "反感"]),
  EmojiItem(char: "🤮", name: "强烈厌恶", tags: ["强烈厌恶", "恶心"]),

  // ===== 混合/情境反应 =====
  EmojiItem(char: "😩", name: "累", tags: ["累", "疲劳"]),
  EmojiItem(char: "😒", name: "无聊", tags: ["无聊", "乏味"]),
  EmojiItem(char: "🥱", name: "无聊感", tags: ["无聊感", "困倦"]),
  EmojiItem(char: "🥱", name: "困倦", tags: ["困倦", "想睡"]),
  EmojiItem(char: "😩", name: "疲惫", tags: ["疲惫", "筋疲力尽"]),
  EmojiItem(char: "😕", name: "迷茫", tags: ["迷茫", "没方向"]),
  EmojiItem(char: "🤔", name: "困惑", tags: ["困惑", "搞不懂"]),
  EmojiItem(char: "😲", name: "惊讶", tags: ["惊讶", "震惊"]),
  EmojiItem(char: "🥹", name: "怀旧", tags: ["怀旧", "怀念"]),
  EmojiItem(char: "😐", name: "一般", tags: ["一般", "普通"]),
  EmojiItem(char: "😑", name: "中性", tags: ["中性", "无情绪"]),
];

/// 情绪与自尊相关的元信息：valence（愉悦度 -2..+2）+ weight（与自尊相关程度）
class EmotionMeta {
  final int valence;
  final double weight;
  const EmotionMeta({required this.valence, required this.weight});
}

/// 根据心理学中正负情绪与自尊、自我意识情绪（如自信 / 自卑 / 羞愧等）的关系，
/// 将 emoji 对应的情绪归类到「愉悦度 + 与自尊相关程度」两个维度，而不是直接给出 0-100 的绝对分。
const Map<String, EmotionMeta> kEmotionSelfEsteemMeta = {
  // ===== 强正向 + 强自尊相关（高胜任/地位/被接纳）=====
  '自信': EmotionMeta(valence: 2, weight: 1.4),
  '自豪': EmotionMeta(valence: 2, weight: 1.5),
  '骄傲': EmotionMeta(valence: 2, weight: 1.5),
  '成就感': EmotionMeta(valence: 2, weight: 1.5),
  '胜利': EmotionMeta(valence: 2, weight: 1.5),
  '被认可': EmotionMeta(valence: 2, weight: 1.3),
  '被赞赏': EmotionMeta(valence: 2, weight: 1.3),
  '狂喜忘我': EmotionMeta(valence: 2, weight: 0.7),

  // ===== 一般正向情绪（正向心境，中等或低自尊相关）=====
  '开心': EmotionMeta(valence: 2, weight: 0.6),
  '喜悦': EmotionMeta(valence: 2, weight: 0.6),
  '高兴': EmotionMeta(valence: 2, weight: 0.6),
  '满足': EmotionMeta(valence: 1, weight: 0.7),
  '满意': EmotionMeta(valence: 1, weight: 0.7),
  '希望': EmotionMeta(valence: 1, weight: 0.8),
  '感激': EmotionMeta(valence: 1, weight: 0.5),
  '爱': EmotionMeta(valence: 2, weight: 0.6),
  '亲密': EmotionMeta(valence: 2, weight: 0.6),
  '浪漫': EmotionMeta(valence: 2, weight: 0.5),
  '兴奋': EmotionMeta(valence: 2, weight: 0.4),
  '兴致': EmotionMeta(valence: 1, weight: 0.3),
  '娱乐': EmotionMeta(valence: 1, weight: 0.3),
  '美学欣赏': EmotionMeta(valence: 1, weight: 0.3),
  '钦佩': EmotionMeta(valence: 1, weight: 0.4),
  '崇拜': EmotionMeta(valence: 1, weight: 0.4),
  '敬畏': EmotionMeta(valence: 1, weight: 0.4),
  '渴望': EmotionMeta(valence: 1, weight: 0.5),
  '性欲': EmotionMeta(valence: 1, weight: 0.4),
  '好奇': EmotionMeta(valence: 1, weight: 0.3),
  '冷静': EmotionMeta(valence: 1, weight: 0.3),
  '放松': EmotionMeta(valence: 1, weight: 0.4),
  '平静': EmotionMeta(valence: 1, weight: 0.3),
  '同情': EmotionMeta(valence: 1, weight: 0.4),

  // ===== 强负向 + 强自尊相关（羞耻/失败/被拒绝/社交比较）=====
  '自卑': EmotionMeta(valence: -2, weight: 1.5),
  '羞愧': EmotionMeta(valence: -2, weight: 1.5),
  '惭愧': EmotionMeta(valence: -2, weight: 1.5),
  '内疚': EmotionMeta(valence: -2, weight: 1.3),
  '自责': EmotionMeta(valence: -2, weight: 1.4),
  '尴尬': EmotionMeta(valence: -2, weight: 1.2),
  '被拒绝': EmotionMeta(valence: -2, weight: 1.4),
  '被忽视': EmotionMeta(valence: -2, weight: 1.3),
  '孤独': EmotionMeta(valence: -2, weight: 1.2),
  '不被理解': EmotionMeta(valence: -2, weight: 1.2),
  '挫败': EmotionMeta(valence: -2, weight: 1.4),
  '失败感': EmotionMeta(valence: -2, weight: 1.4),
  '厌恶自己': EmotionMeta(valence: -2, weight: 1.5),
  '嫉妒': EmotionMeta(valence: -1, weight: 1.1),

  // ===== 一般负向情绪（负向心境，中等自尊相关）=====
  '痛苦': EmotionMeta(valence: -2, weight: 1.0),
  '同情痛苦': EmotionMeta(valence: -1, weight: 0.6),
  '抑郁': EmotionMeta(valence: -2, weight: 1.2),
  '难过': EmotionMeta(valence: -2, weight: 0.7),
  '悲伤': EmotionMeta(valence: -2, weight: 0.7),
  '失望': EmotionMeta(valence: -1, weight: 0.9),
  '焦虑': EmotionMeta(valence: -1, weight: 0.8),
  '焦虑感': EmotionMeta(valence: -1, weight: 0.8),
  '担心': EmotionMeta(valence: -1, weight: 0.8),
  '压力大': EmotionMeta(valence: -1, weight: 0.7),
  '紧张': EmotionMeta(valence: -1, weight: 0.7),
  '惶恐': EmotionMeta(valence: -2, weight: 0.6),
  '害怕': EmotionMeta(valence: -2, weight: 0.5),
  '恐惧': EmotionMeta(valence: -2, weight: 0.5),
  '恐怖': EmotionMeta(valence: -2, weight: 0.5),
  '生气': EmotionMeta(valence: -1, weight: 0.6),
  '愤怒': EmotionMeta(valence: -1, weight: 0.6),
  '烦躁': EmotionMeta(valence: -1, weight: 0.5),
  '恼火': EmotionMeta(valence: -1, weight: 0.5),
  '迷茫': EmotionMeta(valence: -1, weight: 0.5),
  '空虚': EmotionMeta(valence: -2, weight: 1.1),
  '羡慕': EmotionMeta(valence: -1, weight: 1.0),
  '恨': EmotionMeta(valence: -2, weight: 0.7),
  '厌恶': EmotionMeta(valence: -2, weight: 0.6),
  '强烈厌恶': EmotionMeta(valence: -2, weight: 0.7),

  // ===== 混合/低自尊相关（注意/生理/情境反应）=====
  '累': EmotionMeta(valence: -1, weight: 0.4),
  '无聊': EmotionMeta(valence: -1, weight: 0.3),
  '无聊感': EmotionMeta(valence: -1, weight: 0.3),
  '困倦': EmotionMeta(valence: -1, weight: 0.3),
  '疲惫': EmotionMeta(valence: -1, weight: 0.4),
  '困惑': EmotionMeta(valence: -1, weight: 0.5),
  '惊讶': EmotionMeta(valence: 0, weight: 0.3),
  '怀旧': EmotionMeta(valence: 0, weight: 0.4),

  // ===== 中性/一般 =====
  '一般': EmotionMeta(valence: 0, weight: 0.2),
  '中性': EmotionMeta(valence: 0, weight: 0.2),
};

/// 使用「愉悦度 + 自尊相关权重」的加权平均来计算一个时间窗内的自尊指数，范围大致在 0-100。
double computeSelfEsteemIndexFromEmotions(List<String> names) {
  if (names.isEmpty) return 50.0; // 没有记录时视为中性自尊
  double weightedSum = 0;
  double weightSum = 0;
  for (final name in names) {
    final meta = kEmotionSelfEsteemMeta[name];
    if (meta == null) {
      // 未定义情绪：跳过或视为中性，这里选择跳过
      continue;
    }
    weightedSum += meta.valence * meta.weight;
    weightSum += meta.weight;
  }
  if (weightSum == 0) {
    return 50.0;
  }
  final r = weightedSum / weightSum; // 理论范围约为 [-2, 2]
  final s = 50.0 + 25.0 * r; // 映射到 0-100 区间附近
  if (s < 0) return 0.0;
  if (s > 100) return 100.0;
  return s;
}

/// 为了兼容已有代码，单条记录的自尊得分仍然通过该函数获取，
/// 但内部实现已经改为基于 EmotionMeta 的加权规则，而不是为每个情绪硬编码一个绝对分。
double estimateSelfEsteemScore(String emojiName) {
  return computeSelfEsteemIndexFromEmotions([emojiName]);
}

/// 获取单个情绪的愉悦度(valence)，范围约为 -2..+2。
double estimateValenceScore(String emojiName) {
  return (kEmotionSelfEsteemMeta[emojiName]?.valence ?? 0).toDouble();
}




String _two(int v) => v.toString().padLeft(2, '0');

String _nowString() {
  final now = DateTime.now();
  return "${now.year}-${_two(now.month)}-${_two(now.day)} "
         "${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}";
}

String _uid() {
  final rand = Random();
  final ts = DateTime.now().microsecondsSinceEpoch;
  final r = rand.nextInt(0xFFFFFF);
  return "emo_${ts.toRadixString(16)}_${r.toRadixString(16)}";
}

/// 情绪记录 DAO：负责 emotions 表的增删查
class EmotionDao {
  Future<int> insert({
    required String emojiChar,
    required String emojiName,
    required List<String> emojiTags,
    required String behavior,
    required String triggerEvent,
    required String thought,
    required String type,
  }) async {
    final db = await AppDatabase.instance();
    final tagsStr = emojiTags.join(',');
    final nowStr = _nowString();
    final uid = _uid();
    return db.insert('emotions', {
      'emotion_uid': uid,
      'emoji_char': emojiChar,
      'emoji_name': emojiName,
      'emoji_tags': tagsStr,
      'behavior': behavior,
      'trigger_event': triggerEvent,
      'thought': thought,
      'type': type,
      'inserted_at': nowStr,
    });
  }

  /// 获取当天最近一条情绪记录（按 inserted_at 倒序）
  Future<Map<String, dynamic>?> latestToday() async {
    final db = await AppDatabase.instance();
    final now = DateTime.now();
    final today = "${now.year}-${_two(now.month)}-${_two(now.day)}";
    final rows = await db.query(
      'emotions',
      where: "substr(inserted_at,1,10)=?",
      whereArgs: [today],
      orderBy: "inserted_at DESC",
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 获取当天所有情绪记录，按时间先后顺序排列
  Future<List<Map<String, dynamic>>> listTodayOrdered() async {
    final db = await AppDatabase.instance();
    final now = DateTime.now();
    final today = "${now.year}-${_two(now.month)}-${_two(now.day)}";
    final rows = await db.query(
      'emotions',
      where: "substr(inserted_at,1,10)=?",
      whereArgs: [today],
      orderBy: "inserted_at ASC",
    );
    return rows;
  }

  /// 按时间范围获取情绪记录（包含起止时间），按时间先后排序。
  Future<List<Map<String, dynamic>>> listByRange(DateTime start, DateTime end) async {
    final db = await AppDatabase.instance();
    String fmt(DateTime dt) =>
        "${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}";
    final startStr = fmt(start);
    final endStr = fmt(end);
    final rows = await db.query(
      'emotions',
      where: 'inserted_at >= ? AND inserted_at <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'inserted_at ASC',
    );
    return rows;
  }

  /// 分页查询“分享此时此刻的心情”历史数据，支持起止时间（精确到分）和类型、信念(thought)、事件(trigger_event)、行为(behavior)的模糊匹配。
  /// - [start] / [end]：起止时间；如果为 null 则不限制。
  /// - [typeLike] / [thoughtLike] / [eventLike] / [behaviorLike]：模糊查询关键字（LIKE），为 null 或空串则不限制。
  /// - [limit]：每页记录数，默认 30；
  /// - [offset]：偏移量，用于翻页。
  Future<List<Map<String, dynamic>>> listHistory({
    DateTime? start,
    DateTime? end,
    String? typeLike,
    String? thoughtLike,
    String? eventLike,
    String? behaviorLike,
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance();
    final where = <String>[];
    final args = <Object?>[];

    String fmt(DateTime dt) =>
        "\${dt.year}-\${_two(dt.month)}-\${_two(dt.day)} \${_two(dt.hour)}:\${_two(dt.minute)}:\${_two(dt.second)}";

    if (start != null) {
      where.add('inserted_at >= ?');
      args.add(fmt(start));
    }
    if (end != null) {
      where.add('inserted_at <= ?');
      args.add(fmt(end));
    }
    if (typeLike != null && typeLike.trim().isNotEmpty) {
      where.add('type LIKE ?');
      args.add('%' + typeLike.trim() + '%');
    }
    if (thoughtLike != null && thoughtLike.trim().isNotEmpty) {
      where.add('thought LIKE ?');
      args.add('%' + thoughtLike.trim() + '%');
    }
    if (eventLike != null && eventLike.trim().isNotEmpty) {
      where.add('trigger_event LIKE ?');
      args.add('%' + eventLike.trim() + '%');
    }
    if (behaviorLike != null && behaviorLike.trim().isNotEmpty) {
      where.add('behavior LIKE ?');
      args.add('%' + behaviorLike.trim() + '%');
    }

    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final rows = await db.query(
      'emotions',
      where: whereClause,
      whereArgs: whereClause == null ? null : args,
      orderBy: 'inserted_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows;
  }
}
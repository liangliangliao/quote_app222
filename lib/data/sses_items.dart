/// Defines the 6 items of the State Self‑Esteem Scale (short version)
/// used in EMA prompts. Each item has an id, dimension and text.
class SsesItem {
  final String id;
  final String dimension;
  final String text;
  const SsesItem({required this.id, required this.dimension, required this.text});
}

/// A list of six self‑esteem questions. These are neutral phrasing aligned
/// with the Performance, Social and Appearance dimensions of state self‑esteem.
const List<SsesItem> ssesItems = [
  SsesItem(
    id: 'P1',
    dimension: 'perf',
    text: '此刻我对自己的能力/表现有信心。',
  ),
  SsesItem(
    id: 'P2',
    dimension: 'perf',
    text: '此刻我觉得自己做事情挺靠谱、能应付。',
  ),
  SsesItem(
    id: 'S1',
    dimension: 'soc',
    text: '此刻我感觉自己是被他人接纳/认可的。',
  ),
  SsesItem(
    id: 'S2',
    dimension: 'soc',
    text: '此刻我觉得自己在人际互动中表现得不错。',
  ),
  SsesItem(
    id: 'A1',
    dimension: 'app',
    text: '此刻我对自己的外表/形象感到满意。',
  ),
  SsesItem(
    id: 'A2',
    dimension: 'app',
    text: '此刻我觉得自己的状态（外形、气质、精神面貌）挺好。',
  ),
];
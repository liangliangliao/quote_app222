part of 'self_os_workbench.dart';

extension _ReentryPanel on _SelfOsWorkbenchState {
  Future<void> reviewMotive(Map<String, dynamic> suggestion) async {
    final existing =
        c.motives.where((m) => m.id == suggestion['motiveId']).firstOrNull;
    final initial = existing?.toJson() ??
        SelfOsMotive(
          title: osText(suggestion['title']),
          side: osText(suggestion['side']),
        ).toJson();
    final values = await osRecordEditor(context,
        title: '这条认识对你实际有什么影响？',
        initial: {
          ...initial,
          if (existing == null) 'optionId': osText(suggestion['optionId']),
          'reviewReason': ''
        },
        note: '候选依据：${suggestion['reason']}\n保持原有数值也可以。增强、减弱或失效由你实际调整后的差异决定。',
        fields: [
          const OsInput('title', '我认可的动机', required: true),
          const OsInput('side', '方向',
              options: {'for': '支持 / 想接近', 'against': '反对 / 想保护'}),
          OsInput('optionId', '属于哪条路径', options: {'': '暂未关联', ...routeNames}),
          const OsInput('selected', '仍选入当前决定（不再适用时取消）', kind: 'bool'),
          const OsInput('predicted', '对我实际影响的强度（未知留空）', kind: 'number'),
          const OsInput('credibility', '我对这个理由的相信程度（未知留空）', kind: 'number'),
          const OsInput('attention', '现在处于注意的什么位置？',
              options: osAttentionStages),
          const OsInput('endorsement', '我对它的认可到哪一步？', options: osEndorsement),
          const OsInput('actionLink', '它现在怎样连接到第一动作？'),
          const OsInput('reviewReason', '哪条认识让我这样调整？', required: true),
        ]);
    if (values == null || !mounted) return;
    try {
      SelfOsLearning.reviewMotive(c, suggestion, SelfOsMotive.fromJson(values),
          osText(values['reviewReason']));
      await changed();
    } on FormatException catch (e) {
      if (mounted) osMessage(context, e.message);
    }
  }
}

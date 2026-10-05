import 'package:flutter/material.dart';
import '../services/unified_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_embeddings.dart';
import 'evidence_growth_knowledge.dart';

class EvidenceGrowthEmbeddingSettings extends StatefulWidget {
  const EvidenceGrowthEmbeddingSettings({super.key,required this.dao});
  final EvidenceGrowthDao dao;
  @override
  State<EvidenceGrowthEmbeddingSettings> createState()=>_EmbeddingState();
}
class _EmbeddingState extends State<EvidenceGrowthEmbeddingSettings> {
  final model=TextEditingController();
  UnifiedAiResolvedConfig? config;
  String status='读取现有 AI 配置…';
  bool building=false,cancelled=false,enabled=false;
  @override
  void initState(){super.initState();load();}
  Future<void> load() async {
    final cfg=await UnifiedAiService().resolveGlobalConfig();
    model.text=await widget.dao.getSetting('embedding_model',fallback:EvidenceGrowthEmbeddings.defaultModel(cfg));
    enabled=await widget.dao.getSetting('embedding_enabled')=='true';
    config=cfg;
    final service=EvidenceGrowthEmbeddings(widget.dao.knowledgeDatabase,cfg,model:model.text);
    try {
      final count=(await service.load(EvidenceGrowthKnowledge.nodes)).length;
      status='${cfg.label} · 有效知识向量 $count/${EvidenceGrowthKnowledge.nodes.length}';
    } finally {service.close();}
    if(mounted)setState((){});
  }
  Future<void> buildIndex() async {
    if(config==null || !config!.available || model.text.trim().isEmpty)return;
    setState((){building=true;cancelled=false;});
    await widget.dao.setSetting('embedding_model',model.text.trim());
    final service=EvidenceGrowthEmbeddings(widget.dao.knowledgeDatabase,config!,model:model.text.trim());
    try {
      final count=await service.build(EvidenceGrowthKnowledge.nodes,cancelled:()=>cancelled,
        progress:(n,total){if(mounted)setState(()=>status='已建立 $n/$total 个知识向量');});
      // Query uses the same model and credentials as the knowledge vectors.
      if(count>0 && !cancelled) {
        await service.embed(['如何把知识转成现实行动？'],query:true);
        await widget.dao.setSetting('embedding_enabled','true'); enabled=true;
      }
      if(mounted)setState(()=>status=cancelled?'已暂停，可继续构建':'知识向量 $count/${EvidenceGrowthKnowledge.nodes.length}；查询连接已验证');
    } catch(_){if(mounted)setState(()=>status='向量服务未完成。请确认该提供方支持此嵌入模型／部署；已有批次保留，可重试。');}
    finally{service.close();if(mounted)setState(()=>building=false);}
  }
  @override
  void dispose(){cancelled=true;model.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>ExpansionTile(title:const Text('语义检索'),subtitle:Text(status),children:[
    const Text('复用 App 当前 AI 服务与凭据。聊天模型不一定支持嵌入；Azure 请填写嵌入部署名，其他提供方填写支持的嵌入模型。'),
    TextField(controller:model,enabled:!building,decoration:const InputDecoration(labelText:'嵌入模型／Azure 部署名')),
    SwitchListTile(value:enabled,title:const Text('路由使用已建立的向量索引'),onChanged:building?null:(v) async {
      await widget.dao.setSetting('embedding_enabled','$v');if(mounted)setState(()=>enabled=v);
    }),
    Wrap(spacing:8,children:[
      TextButton(onPressed:building?null:buildIndex,child:const Text('构建／续建并验证连接')),
      if(building) TextButton(onPressed:()=>setState(()=>cancelled=true),child:const Text('暂停')),
      TextButton(onPressed:building || config==null?null:() async {
        final service=EvidenceGrowthEmbeddings(widget.dao.knowledgeDatabase,config!,model:model.text.trim());
        try{await service.clear();}finally{service.close();} await load();
      },child:const Text('清除此模型索引')),
    ]),
    const Text('只保存公共知识向量。个人查询不写入公共索引；服务不可用时使用词法与规则检索。'),
  ]);
}

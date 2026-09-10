import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/read_aloud_service.dart';

class EvidenceGrowthReadAloud extends StatefulWidget {
  const EvidenceGrowthReadAloud({super.key,required this.text});
  final String text;
  @override
  State<EvidenceGrowthReadAloud> createState()=>_EvidenceGrowthReadAloudState();
}
class _EvidenceGrowthReadAloudState extends State<EvidenceGrowthReadAloud> {
  final player=AudioPlayer();
  final reader=ReadAloudService();
  StreamSubscription<void>? completion;
  List<String> files=[];
  var index=0, request=0;
  var busy=false, playing=false, paused=false;
  @override
  void initState() { super.initState(); completion=player.onPlayerComplete.listen((_)=>unawaited(_next())); }
  @override
  void dispose() { request++; completion?.cancel(); player.dispose(); super.dispose(); }
  Future<void> _next() async {
    if (!mounted || !playing) return;
    if (++index>=files.length) { setState(()=>playing=false); return; }
    await player.play(DeviceFileSource(files[index]));
  }
  Future<void> _read() async {
    final current=++request;
    setState(()=>busy=true);
    try {
      final availability=await reader.availability();
      if (!availability.available) throw StateError(availability.reason);
      final audio=await reader.synthesize(text:widget.text,moduleName:'evidence_growth');
      if (!mounted || current!=request) return;
      files=audio; index=0;
      if (files.isNotEmpty) { await player.play(DeviceFileSource(files.first)); if(mounted) setState(()=>playing=true); }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('朗读暂不可用，请检查共享朗读配置与网络。')));
    } finally { if(mounted && current==request) setState(()=>busy=false); }
  }
  @override
  Widget build(BuildContext context)=>Wrap(spacing:8,children:[
    if (!playing) TextButton.icon(onPressed:busy?null:_read,icon:const Icon(Icons.volume_up_outlined),label:Text(busy?'准备朗读…':'朗读')),
    if (playing) TextButton.icon(onPressed:() async {
      if(paused) { await player.resume(); } else { await player.pause(); }
      if(mounted) setState(()=>paused=!paused);
    },icon:Icon(paused?Icons.play_arrow:Icons.pause),label:Text(paused?'继续':'暂停')),
    if (playing || busy) TextButton(onPressed:() async {
      request++; await player.stop(); if(mounted) setState(() { playing=false; paused=false; busy=false; });
    },child:const Text('停止')),
  ]);
}

class EvidenceGrowthVoiceSettings extends StatefulWidget {
  const EvidenceGrowthVoiceSettings({super.key});
  @override
  State<EvidenceGrowthVoiceSettings> createState()=>_EvidenceGrowthVoiceSettingsState();
}
class _EvidenceGrowthVoiceSettingsState extends State<EvidenceGrowthVoiceSettings> {
  final reader=ReadAloudService();
  String? provider;
  String reason='';
  @override
  void initState() { super.initState(); unawaited(_load()); }
  Future<void> _load() async {
    final p=await reader.getProvider(), available=await reader.availability();
    if(mounted) setState(() { provider=p; reason=available.reason; });
  }
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(provider!=null) DropdownButtonFormField<String>(initialValue:provider,isExpanded:true,
      decoration:const InputDecoration(labelText:'朗读服务商（全局共享）'),
      items:ReadAloudSettings.providers.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
      onChanged:(value) async { if(value!=null) { await reader.setProvider(value); await _load(); } }),
    Text(reason),
  ]);
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/daily_diet_entry.dart';
import '../services/health_diet_core_orchestrator.dart';
import '../widgets/health_diet_data_source_banner.dart';
import 'diet_barcode_scanner_page.dart';
import 'diet_food_confirm_page.dart';
import 'diet_voice_input_page.dart';

class DailyDietSharePage extends StatefulWidget {
  const DailyDietSharePage({super.key});

  @override
  State<DailyDietSharePage> createState() => _DailyDietSharePageState();
}

class _DailyDietSharePageState extends State<DailyDietSharePage> {
  final _textCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _orchestrator = HealthDietCoreOrchestrator();
  final List<String> _imagePaths = [];
  bool _copyingImage = false;
  bool _analyzing = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_copyingImage) return;
    final image = await _picker.pickImage(source: source, imageQuality: 86, maxWidth: 1800);
    if (image == null) return;
    setState(() => _copyingImage = true);
    final savedPath = await _copyImageToAppDir(image.path);
    if (!mounted) return;
    setState(() {
      _imagePaths.add(savedPath);
      _copyingImage = false;
    });
  }

  Future<String> _copyImageToAppDir(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, 'health_diet', 'daily_images'));
    if (!await targetDir.exists()) await targetDir.create(recursive: true);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final targetPath = p.join(targetDir.path, 'diet_${DateTime.now().millisecondsSinceEpoch}$ext');
    return File(sourcePath).copy(targetPath).then((f) => f.path);
  }

  void _removeImage(int index) => setState(() => _imagePaths.removeAt(index));

  Future<void> _confirmText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _imagePaths.isEmpty) {
      _toast('请先输入今天吃了什么，或上传饮食图片');
      return;
    }
    if (_analyzing) return;
    setState(() => _analyzing = true);
    final inputType = _imagePaths.isNotEmpty && text.isNotEmpty ? 'mixed' : (_imagePaths.isNotEmpty ? 'image' : 'text');
    final foods = await _orchestrator.buildFoodsFromInputs(
      text: text,
      imagePaths: _imagePaths.toList(),
      source: inputType,
    );
    if (!mounted) return;
    setState(() => _analyzing = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DietFoodConfirmPage(
        inputType: inputType,
        textDescription: text.isEmpty ? null : text,
        imagePaths: _imagePaths.toList(),
        initialFoods: foods,
      ),
    ));
  }

  Future<void> _openVoice() async {
    final transcript = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const DietVoiceInputPage()));
    if (transcript == null || transcript.trim().isEmpty) return;
    setState(() => _analyzing = true);
    final foods = await _orchestrator.buildFoodsFromInputs(text: transcript.trim(), source: 'voice');
    if (!mounted) return;
    setState(() => _analyzing = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DietFoodConfirmPage(
        inputType: 'voice',
        voiceText: transcript.trim(),
        initialFoods: foods,
      ),
    ));
  }


  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const DietBarcodeScannerPage()),
    );
    final value = code?.trim() ?? '';
    if (value.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _barcodeCtrl.text = value;
      _barcodeCtrl.selection = TextSelection.collapsed(offset: value.length);
    });
    _toast('已扫描到条码：$value');
  }

  Future<void> _confirmBarcode() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) {
      _toast('请输入包装食品条形码');
      return;
    }
    if (_analyzing) return;
    setState(() => _analyzing = true);
    final foods = await _orchestrator.foodsFromBarcode(barcode, imagePaths: _imagePaths.toList());
    if (!mounted) return;
    setState(() => _analyzing = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DietFoodConfirmPage(
        inputType: 'barcode',
        barcode: barcode,
        textDescription: '条形码：$barcode${_imagePaths.isNotEmpty ? '；已附带包装图片用于 AI 兜底识别' : ''}',
        imagePaths: _imagePaths.toList(),
        initialFoods: foods,
      ),
    ));
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('每日饮食分享')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          HealthDietDataSourceBanner(
            sources: const ['用户输入', '本地解析', '全局 AI Provider', 'USDA', 'Open Food Facts', '国内条码候选源'],
            updatedAt: DateTime.now(),
            note: '本页数据在点击确认时实时调用；最终是否保存，以确认页手动确认的食物和份量为准。',
          ),
          _introCard(),
          if (_analyzing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('正在调用本地解析、API 数据源或 AI 识别，请稍候……', style: TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 14),
          _quickActions(),
          const SizedBox(height: 14),
          _textInputCard(),
          const SizedBox(height: 14),
          _imageInputCard(),
          const SizedBox(height: 14),
          _barcodeCard(),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFEFF6FF)]),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.restaurant_menu, color: Color(0xFF059669)), SizedBox(width: 8), Text('今天吃了什么？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          SizedBox(height: 10),
          Text('拍一张、说一句、写几句都可以。系统会调用已配置的数据源和 AI 能力进行识别，再让你确认食物，最后保存记录并生成饮食复盘。', style: TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(child: _quickButton(Icons.photo_camera_outlined, '拍照', () => _pickImage(ImageSource.camera))),
        const SizedBox(width: 10),
        Expanded(child: _quickButton(Icons.photo_library_outlined, '相册', () => _pickImage(ImageSource.gallery))),
        const SizedBox(width: 10),
        Expanded(child: _quickButton(Icons.mic_none, '语音', _openVoice)),
      ],
    );
  }

  Widget _quickButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
    );
  }

  Widget _textInputCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文字描述', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('例如：早餐没吃，中午黄焖鸡米饭，下午奶茶，晚上泡面加火腿肠。', style: TextStyle(color: Colors.black54, height: 1.4)),
            const SizedBox(height: 10),
            TextField(
              controller: _textCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '写下今天的早餐、午餐、晚餐、零食、饮料……',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _analyzing ? null : _confirmText,
                icon: _analyzing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_outlined),
                label: const Text('进入确认页'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageInputCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('图片上传', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                if (_copyingImage) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('可上传餐盘、外卖、包装食品、配料表或营养成分表图片。上传后会优先调用全局 AI 视觉识别；若当前模型不支持图片或识别不确定，仍会让你手动添加确认，避免误判。', style: TextStyle(color: Colors.black54, height: 1.4)),
            const SizedBox(height: 12),
            if (_imagePaths.isNotEmpty) _imagePreview(),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('拍照'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('相册'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreview() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _imagePaths.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_imagePaths[index]), width: 104, height: 104, fit: BoxFit.cover),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barcodeCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('条形码查询', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('输入包装食品条形码后，会同时尝试 Open Food Facts、聚合数据、探数数据和自定义国内条码接口。不同来源会在确认页分别显示，方便你选择最准确的一条；若都未收录，可上传包装正面/营养成分表照片让 AI 兜底识别。', style: TextStyle(color: Colors.black54, height: 1.4)),
            const SizedBox(height: 10),
            TextField(
              controller: _barcodeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: '包装食品条形码',
                suffixIcon: IconButton(
                  tooltip: '摄像头扫码填入',
                  onPressed: _analyzing ? null : _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _analyzing ? null : _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('摄像头扫码'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _analyzing ? null : _confirmBarcode,
                    icon: const Icon(Icons.search),
                    label: const Text('查询并确认'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

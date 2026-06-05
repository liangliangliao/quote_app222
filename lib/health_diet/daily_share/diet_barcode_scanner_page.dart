import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../widgets/health_diet_data_source_banner.dart';

class DietBarcodeScannerPage extends StatefulWidget {
  const DietBarcodeScannerPage({super.key});

  @override
  State<DietBarcodeScannerPage> createState() => _DietBarcodeScannerPageState();
}

class _DietBarcodeScannerPageState extends State<DietBarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _completed = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const <BarcodeFormat>[
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.itf,
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_completed) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _completed = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (!mounted) return;
      setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('扫描包装食品条码'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _torchOn ? '关闭手电筒' : '打开手电筒',
            onPressed: _toggleTorch,
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          ),
          IconButton(
            tooltip: '切换摄像头',
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '无法启动摄像头扫码：$error\n\n请确认已授予摄像头权限，或返回后手动输入条码。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, height: 1.5),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: HealthDietDataSourceBanner(
              compact: true,
              sources: const ['摄像头扫码', 'EAN/UPC 条码'],
              updatedAt: DateTime.now(),
              note: '本页只负责读取条码；商品详情会在确认页调用 Open Food Facts 和国内条码源。',
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 26,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.62),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                '请把包装食品上的一维条形码放入白色框内。识别成功后会自动返回，并把条码填入文本框。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

/// 首页唯一的默认名言画框。
///
/// 默认显示用户提供的 2:3 木质画框照片；AI 只替换照片中的白色画芯，
/// 不生成或覆盖木框、墙面、植物和桌面。这样离线与 AI 两种状态始终
/// 使用同一个真实画框，切换时也不会改变首页的整体空间关系。
class QuoteAdaptiveFrame extends StatelessWidget {
  const QuoteAdaptiveFrame({
    super.key,
    this.aiImagePath,
    this.quoteCharacters = 0,
    this.backgroundAsset = defaultBackgroundAsset,
  });

  static const String defaultBackgroundAsset = 'assets/bg-wood-upload.jpg';

  /// 用户照片中白色画芯的归一化位置（基于 1024 × 1536 原图）。
  /// AI 图和文字都必须限制在这里，不能遮住真实木框。
  static const Rect artworkRect = Rect.fromLTRB(.180, .139, .850, .785);

  /// 在画芯内部保留窄而均衡的呼吸空间。它覆盖几乎全部白纸区域，
  /// 既不会碰到木框阴影，也不会因边距过大浪费下半幅画纸。
  static const Rect textSafeRect = Rect.fromLTRB(.198, .157, .832, .765);

  final String? aiImagePath;
  final int quoteCharacters;
  final String backgroundAsset;

  static Rect scaleRect(Rect normalized, Size size) => Rect.fromLTRB(
        normalized.left * size.width,
        normalized.top * size.height,
        normalized.right * size.width,
        normalized.bottom * size.height,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final artwork = scaleRect(artworkRect, size);
        final path = aiImagePath?.trim() ?? '';
        final hasAiArtwork = path.isNotEmpty;
        final isLongQuote = quoteCharacters > 80;
        final isMediumQuote = quoteCharacters > 48;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                backgroundAsset,
                key: ValueKey(backgroundAsset),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
            ),
            if (hasAiArtwork)
              Positioned.fromRect(
                rect: artwork,
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 550),
                    child: Image.file(
                      File(path),
                      key: ValueKey(path),
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            if (hasAiArtwork)
              Positioned.fromRect(
                rect: artwork,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .42, .72, 1],
                        colors: [
                          const Color(0xfffbf7ef).withValues(alpha: .91),
                          const Color(0xfffbf7ef).withValues(alpha: .83),
                          const Color(0xfffbf7ef).withValues(
                            alpha: isLongQuote ? .66 : (isMediumQuote ? .52 : .34),
                          ),
                          const Color(0xfffbf7ef).withValues(alpha: .04),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

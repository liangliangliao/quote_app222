import 'package:flutter/material.dart';

/// 把常见的浅色证件照/历史人物肖像处理成贴在画纸上的人物剪影。
///
/// 根据内置肖像的明暗背景把背景像素映射为透明，同时羽化照片四周，
/// 避免矩形照片边界或圆形头像框破坏画面的自然感。
/// 原图仍然保留，因而网络头像、用户头像和内置头像都能使用同一套展示逻辑。
class QuotePortraitCutout extends StatelessWidget {
  const QuotePortraitCutout({
    super.key,
    required this.image,
    required this.width,
    required this.height,
  });

  final ImageProvider image;
  final double width;
  final double height;

  /// alpha = (250 - luminance) * 3.3：
  /// 浅色照片背景会消失，脸部、头发和衣服会保持可见。
  static const ColorFilter _removeLightBackground = ColorFilter.matrix([
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    -0.70, -2.36, -0.24, 3.24, 0,
  ]);

  /// 深色影棚背景使用相反的亮度键：保留脸部、头发高光和衣着细节，
  /// 去掉接近黑色的背景与硬边。
  static const ColorFilter _removeDarkBackground = ColorFilter.matrix([
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    .53, 1.79, .18, 0, -112,
  ]);

  bool get _hasDarkBackground {
    final source = image;
    if (source is! AssetImage) return false;
    final name = source.assetName.toLowerCase();
    return name.contains('william_james') ||
        name.contains('immanuel kant') ||
        name.contains('schopenhauer') ||
        name.contains('talbenshahar') ||
        name.contains('avatar_legacy');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0, .10, .90, 1],
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
        ).createShader(bounds),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .08, .72, 1],
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
          ).createShader(bounds),
          child: ColorFiltered(
            colorFilter: _hasDarkBackground
                ? _removeDarkBackground
                : _removeLightBackground,
            child: Image(
              image: image,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

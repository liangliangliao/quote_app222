import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:quote_app/widgets/wood_frame_card.dart';

class _NoIndicatorScroll extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

class OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final c = 0.18;
    return Path()
      ..moveTo(c * w, 0)
      ..lineTo(w - c * w, 0)
      ..lineTo(w, c * h)
      ..lineTo(w, h - c * h)
      ..lineTo(w - c * w, h)
      ..lineTo(c * w, h)
      ..lineTo(0, h - c * h)
      ..lineTo(0, c * h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

ImageProvider _imageFrom(String? any, {String? fallbackAsset}) {
  if (any == null || any.isEmpty) return AssetImage(fallbackAsset ?? 'assets/bg-wood-upload.jpg');
  if (any.startsWith('data:')) {
    final b64 = any.substring(any.indexOf(',') + 1);
    return MemoryImage(base64.decode(b64));
  }
  if (any.startsWith('http')) return NetworkImage(any);
  if (any.startsWith('assets/')) return AssetImage(any);
  return AssetImage(fallbackAsset ?? 'assets/bg-wood-upload.jpg');
}

class PosterPureFlutter extends StatelessWidget {
  final String topic;
  final String quote;
  final String author;
  final String note;
  final String avatar;
  final String woodBgAsset;

  const PosterPureFlutter({
    super.key,
    required this.topic,
    required this.quote,
    required this.author,
    required this.note,
    required this.avatar,
    this.woodBgAsset = 'assets/bg-wood-upload.jpg',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final short = (cons.maxWidth < cons.maxHeight) ? cons.maxWidth : cons.maxHeight;
      final tTitle = (short * 0.040).clamp(18.5, 24.0);
      final tQuote = (short * 0.065).clamp(19.0, 31.0);
      final tAuth = (short * 0.033).clamp(13.0, 16.0);
      final tNote = (short * 0.030).clamp(10.5, 12.4);
      final frameTop = (short * 0.035).clamp(14.0, 24.0);
      final frameBottom = (short * 0.035).clamp(14.0, 24.0);
      final canvasPad = (short * 0.130).clamp(44.0, 70.0);
      final framePaddingH = (short * 0.115).clamp(64.0, 88.0) - 15.0 - 15.0;
      final framePaddingV = (short * 0.160).clamp(92.0, 124.0) - 15.0 - 15.0;
      final avatarSize = (short * 0.118).clamp(88.0, 140.0);
      final bool hasAvatar = avatar.trim().isNotEmpty;
    final bool shortTopic = (topic.characters.length < 15);
      const frameRadius = 12.0;
      const canvasRadius = 6.0;

      return Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        padding: EdgeInsets.only(top: (short * 0.10).clamp(30.0, 60.0) - 55.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: AspectRatio(
            aspectRatio: 1024 / 1536, // match bg-wood-upload.jpg
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(frameRadius),
                // boxShadow removed per design: frame alone without outer card shadow
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(frameRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 木纹相框背景（底层）
                    Image.asset(woodBgAsset, fit: BoxFit.cover),
                    // 相框内部边距：左右 40dp，上下 50dp
                    Padding(
                    padding: const EdgeInsets.only(left: 0, right: 0, top: 0, bottom: 30),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(canvasRadius),
                        clipBehavior: Clip.hardEdge, // 确保内部滚动不越界
                        child: Container(
                          color: Colors.transparent,
                          child: Padding(
                             padding: const EdgeInsets.fromLTRB(55, 64, 55, 34), // top padding +4dp total, bottom +1dp for better spacing
                             child: SingleChildScrollView(
                               physics: const ClampingScrollPhysics(),
                               child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 20),
                                    hasAvatar
                                        ? Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsets.only(left: 12),
                                                  child: Text(
                                                    topic,
                                                    textAlign: (topic.characters.length < 20) ? TextAlign.center : TextAlign.left,
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: tTitle + 4, height: 1.30,
                                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 2.8,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              ClipOval(
                                                child: SizedBox(
                                                  width: avatarSize,
                                                  height: avatarSize,
                                                  child: hasAvatar
                                                      ? Image(
                                                          image: _imageFrom(avatar, fallbackAsset: woodBgAsset),
                                                          fit: BoxFit.contain,
                                                          gaplessPlayback: true, filterQuality: FilterQuality.medium,
                                                        )
                                                      : Image.asset(
                                                          woodBgAsset,
                                                          fit: BoxFit.contain,
                                                        ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Center(
                                            child: Text(
                                              topic,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: tTitle + 2, height: 1.30,
                                                fontWeight: FontWeight.w400,
                                      letterSpacing: 2.8,
                                              ),
                                              ),
                                            ),

SizedBox(height: (canvasPad * 0.3) - 5),
                                    Text(quote, textScaleFactor: 1.0, style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 31,
                                        height: 1.45,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        author,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: tAuth,
                                          height: 1.35,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8, ),
                                      ),
                                    ),
                                    SizedBox(height: 15),
                                    SizedBox(height: 14), // reduced top margin for note by 6dp
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 20),
                                        child: Text(
                                          note,
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: tNote + 1,
                                            height: 1.40,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
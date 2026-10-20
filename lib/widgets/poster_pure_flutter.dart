import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import 'quote_adaptive_frame.dart';

ImageProvider _posterAvatar(String raw, String fallback) {
  if (raw.startsWith('data:')) {
    try { return MemoryImage(base64Decode(raw.substring(raw.indexOf(',')+1))); }
    catch (_) { return AssetImage(fallback); }
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) return NetworkImage(raw);
  if (raw.startsWith('assets/')) return AssetImage(raw);
  if (raw.startsWith('/')) return FileImage(File(raw));
  return AssetImage(fallback);
}

/// 画芯与文字独立布局：无论名言多长，视觉故事始终拥有固定下部空间。
/// 名言全部可上下滚动阅读；绘画区与木框不随滚动消失。
class PosterPureFlutter extends StatelessWidget {
  const PosterPureFlutter({
    super.key,
    required this.topic,
    required this.quote,
    required this.author,
    required this.note,
    required this.avatar,
    this.woodBgAsset = 'assets/bg-wood-upload.jpg',
    this.aiFramePath,
  });

  final String topic;
  final String quote;
  final String author;
  final String note;
  final String avatar;
  final String woodBgAsset;
  final String? aiFramePath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final count = quote.characters.length;
      final titleSize = (w*.055).clamp(15.0, 25.0);
      final quoteSize = count > 115 ? 19.5 :
          count > 90 ? 21.5 : count > 65 ? 23.0 :
          count > 45 ? 25.0 : 29.5;
      final authorSize = (w*.035).clamp(12.0, 16.0);
      final noteSize = (w*.033).clamp(11.0, 13.5);
      final avatarSize = (w*.19).clamp(42.0, 82.0);
      final sceneHeight = (h*(count>80 ? .22 : .32)).clamp(75.0, 215.0);
      final textArea = QuoteAdaptiveFrame.scaleRect(
        QuoteAdaptiveFrame.textSafeRect,
        Size(w, h),
      );

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth:620),
          child: AspectRatio(
            aspectRatio: 2/3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  QuoteAdaptiveFrame(
                    aiImagePath: aiFramePath,
                    quoteCharacters: count,
                  ),
                  Positioned.fromRect(
                    rect: textArea,
                    child: Column(children: [
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: const _QuietScroll(),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (avatar.trim().isNotEmpty)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(topic,
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                            color: const Color(0xff352c27),
                                            fontSize:titleSize,
                                            letterSpacing:1.2,
                                            height:1.35,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width:10),
                                      ClipOval(
                                        child: SizedBox(
                                          width:avatarSize,height:avatarSize,
                                          child: Image(
                                            image:_posterAvatar(avatar,woodBgAsset),
                                            fit:BoxFit.cover,
                                            errorBuilder:(_,__,___)=>const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(topic,
                                    textAlign:TextAlign.center,
                                    style:TextStyle(
                                      fontSize:titleSize,
                                      color:const Color(0xff352c27),
                                      letterSpacing:1.5,height:1.4,
                                    ),
                                  ),
                                SizedBox(height:(h*.038).clamp(12.0,29.0)),
                                Text(
                                  quote,
                                  textScaler:TextScaler.noScaling,
                                  style:TextStyle(
                                    color:const Color(0xff201a17),
                                    fontSize:quoteSize,
                                    height:1.47,
                                    letterSpacing:.9,
                                    fontWeight:FontWeight.w700,
                                  ),
                                ),
                                if (author.trim().isNotEmpty) ...[
                                  const SizedBox(height:13),
                                  Text(author,
                                    textAlign:TextAlign.right,
                                    style:TextStyle(
                                      fontSize:authorSize,
                                      height:1.4,
                                      color:const Color(0xff544538),
                                      fontWeight:FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (note.trim().isNotEmpty) ...[
                                  const SizedBox(height:21),
                                  Text(note,
                                    style:TextStyle(
                                      fontSize:noteSize,
                                      height:1.50,
                                      color:const Color(0xff62584e),
                                    ),
                                  ),
                                ],
                                const SizedBox(height:16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 图像不再被长篇名言覆盖，始终能看见脚本中的主意象。
                      SizedBox(height:sceneHeight),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _QuietScroll extends MaterialScrollBehavior {
  const _QuietScroll();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

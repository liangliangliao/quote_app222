import 'package:flutter/material.dart';

/// Movie overview widget:
///
/// 默认显示 [maxLines] 行（默认 4 行）。如果文本超过该行数，会在文本
/// 末尾区域显示 “查看” 按钮，点击弹窗展示完整简介。
///
/// 这样既不会像完全展开那样占据列表空间，也避免了在卡片内滚动造成
/// 的手势冲突。
class MovieOverviewBox extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle style;
  final String dialogTitle;

  /// Notifies parent whether the text exceeds [maxLines] under current width.
  ///
  /// This is used by movie cards to decide whether to show a separate “查看”
  /// button in the right-side action column (aligned with the favourite
  /// icon), instead of overlaying on top of the text.
  final ValueChanged<bool>? onOverflowChanged;

  const MovieOverviewBox({
    super.key,
    required this.text,
    this.maxLines = 4,
    this.style = const TextStyle(
      fontSize: 13,
      color: Colors.black54,
      height: 1.35,
    ),
    this.dialogTitle = '电影简介',
    this.onOverflowChanged,
  });

  @override
  State<MovieOverviewBox> createState() => _MovieOverviewBoxState();
}

class _MovieOverviewBoxState extends State<MovieOverviewBox> {
  bool _overflow = false;

  void _measureOverflow(BoxConstraints constraints, String content) {
    final painter = TextPainter(
      text: TextSpan(text: content, style: widget.style),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    );
    painter.layout(maxWidth: constraints.maxWidth);
    final did = painter.didExceedMaxLines;
    if (did != _overflow) {
      // Avoid setState during build phase by scheduling.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _overflow = did);
          widget.onOverflowChanged?.call(did);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String content = widget.text.trim().isEmpty ? '暂无简介' : widget.text.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure overflow based on current width.
        _measureOverflow(constraints, content);

        // Only render the clamped text. The “查看” button is handled by the
        // parent (movie card) in an action column, aligned with the favourite
        // icon button.
        return Text(
          content,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

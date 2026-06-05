import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Text controller for diary content that keeps the underlying text
/// storage-compatible (including attachment marker lines like
///   [图片] /path/to/file
///   [语音] /path/to/file
/// ) but hides the concrete file paths from the user interface while
/// preserving caret/selection behaviour.
class DiaryContentController extends TextEditingController {
  DiaryContentController({String? text}) : super(text: text);

  static bool _isMarkerLine(String line) {
    final l = line.trimLeft();
    return l.startsWith('[图片]') || l.startsWith('[语音]');
  }

  /// Replace the entire logical marker line with zero-width spaces so that:
  ///  * neither the "[图片]"/"[语音]" token nor the real file path are visible;
  ///  * the number of characters in the line stays identical to the
  ///    original text, keeping caret positions valid.
  static String _maskMarkerLine(String line) {
    if (line.isEmpty) return line;
    final int leadingSpaces = line.length - line.trimLeft().length;
    final String trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      return line;
    }
    final String invisible = '\u200B' * trimmed.length;
    return ' ' * leadingSpaces + invisible;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withComposing = true,
  }) {
    final TextStyle baseStyle = style ?? DefaultTextStyle.of(context).style;
    final String fullText = value.text;
    if (fullText.isEmpty) {
      return TextSpan(style: baseStyle);
    }

    final List<InlineSpan> children = <InlineSpan>[];
    final List<String> lines = fullText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final String rawLine = lines[i];
      // Check for image/audio markers anywhere in the line (not just at the start).
      final int imgIdx = rawLine.indexOf('[图片]');
      final int audioIdx = rawLine.indexOf('[语音]');
      if (imgIdx >= 0) {
        // There is an image marker in this line.  Render any prefix text
        // before the marker, then the image.  The remainder after the
        // marker (if any) is ignored because our format does not support
        // trailing text after the image payload.
        final String prefix = rawLine.substring(0, imgIdx);
        if (prefix.isNotEmpty) {
          _buildLineSpans(prefix, baseStyle, children);
        }
        // Parse the payload after "[图片]"
        final String payload = rawLine.substring(imgIdx + '[图片]'.length).trim();
        double wf = 1.0;
        String path = payload;
        final parts = payload.split('|w=');
        if (parts.isNotEmpty) {
          path = parts.first.trim();
          if (parts.length > 1) {
            final v = double.tryParse(parts[1].trim());
            if (v != null) wf = v;
          }
        }
        if (path.isNotEmpty) {
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _InlineImage(path: path, widthFactor: wf),
            ),
          );
        }
      } else if (audioIdx >= 0) {
        // There is an audio marker in this line.  Render any prefix text
        // before the marker, then mask the marker and path with
        // zero-width spaces so caret positioning remains consistent.
        final String prefix = rawLine.substring(0, audioIdx);
        if (prefix.isNotEmpty) {
          _buildLineSpans(prefix, baseStyle, children);
        }
        final String markerPart = rawLine.substring(audioIdx);
        final String masked = _maskMarkerLine(markerPart);
        if (masked.isNotEmpty) {
          children.add(TextSpan(text: masked, style: baseStyle));
        }
      } else {
        // No attachment markers; render the line normally.
        _buildLineSpans(rawLine, baseStyle, children);
      }
      // Append newline after every line except the last.
      if (i < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return TextSpan(style: baseStyle, children: children);
  }

  static void _buildLineSpans(
      String line,
      TextStyle baseStyle,
      List<InlineSpan> out,
    ) {
      // Very small URL highlighter so existing behaviour is roughly preserved.
      final RegExp linkReg = RegExp(r'https?://[^\s]+');

      int index = 0;
      for (final Match m in linkReg.allMatches(line)) {
        if (m.start > index) {
          out.add(TextSpan(
            text: line.substring(index, m.start),
            style: baseStyle,
          ));
        }
        out.add(TextSpan(
          text: line.substring(m.start, m.end),
          style: baseStyle.copyWith(decoration: TextDecoration.underline),
        ));
        index = m.end;
      }
      if (index < line.length) {
        out.add(TextSpan(
          text: line.substring(index),
          style: baseStyle,
        ));
      }
    }

}

class _InlineImage extends StatelessWidget {
  final String path;
  final double widthFactor;
  const _InlineImage({Key? key, required this.path, this.widthFactor = 1.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }
    final wf = widthFactor.clamp(0.2, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: wf,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ),
    );
  }
}
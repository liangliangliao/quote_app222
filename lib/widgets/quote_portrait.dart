import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'quote_history_avatar.dart';

ImageProvider? quotePortraitProvider(QuoteReference quote) {
  final path = quote.avatarPath.trim();
  try {
    if (path.startsWith('data:'))
      return MemoryImage(base64Decode(path.substring(path.indexOf(',') + 1)));
    if (path.startsWith('assets/')) return AssetImage(path);
    if (path.startsWith('https://') || path.startsWith('http://'))
      return NetworkImage(path);
    if (path.isNotEmpty && File(path).existsSync())
      return FileImage(File(path));
  } catch (_) {}
  final author = quote.author.toLowerCase();
  final asset = author.contains('尼采') || author.contains('nietzsche')
      ? 'Friedrich Nietzsche.jpg'
      : author.contains('tal') || author.contains('沙哈尔')
          ? 'talbenshahar .jpeg'
          : author.contains('叔本华') || author.contains('schopenhauer')
              ? 'schopenhauer.jpg'
              : author.contains('康德') || author.contains('kant')
                  ? 'Immanuel Kant.jpg'
                  : author.contains('加缪') || author.contains('camus')
                      ? 'Albert_Camus_1945_(cropped).jpg'
                      : author.contains('詹姆斯') ||
                              author.contains('william james')
                          ? '250px-William_James_b1842c.jpg'
                          : null;
  return asset == null ? null : AssetImage('assets/avatars/$asset');
}

class QuotePortrait extends StatelessWidget {
  final QuoteReference quote;
  final double diameter;
  const QuotePortrait({super.key, required this.quote, this.diameter = 48});
  @override
  Widget build(BuildContext context) => QuoteHistoryAvatar(
      image: quotePortraitProvider(quote), diameter: diameter);
}

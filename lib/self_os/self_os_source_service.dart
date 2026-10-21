import 'dart:convert';
import 'package:http/http.dart' as http;

class OsSourceDocument {
  const OsSourceDocument(this.url, this.text, this.fetchedAt);
  final String url, text;
  final DateTime fetchedAt;
  bool containsQuote(String quote) =>
      quote.trim().isNotEmpty &&
      text
          .replaceAll(RegExp(r'\s+'), ' ')
          .contains(quote.trim().replaceAll(RegExp(r'\s+'), ' '));
}

/// Fetch only the URL explicitly supplied by the user. Reading a page does not
/// verify its claims; a quoted passage and user review are still required.
class SelfOsSourceService {
  SelfOsSourceService({http.Client? client}) : _injected = client;
  final http.Client? _injected;
  static Uri checkedUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty)
      throw const FormatException('请使用不含账号密码的 HTTPS 来源链接');
    return uri;
  }

  Future<OsSourceDocument> retrieve(String url) async {
    var uri = checkedUrl(url);
    final client = _injected ?? http.Client();
    try {
      for (var redirects = 0; redirects < 4; redirects++) {
        final request = http.Request('GET', uri)..followRedirects = false;
        final response =
            await client.send(request).timeout(const Duration(seconds: 15));
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers['location'];
          await response.stream.listen(null).cancel();
          if (location == null) throw const FormatException('来源链接重定向不完整');
          uri = checkedUrl(uri.resolve(location).toString());
          continue;
        }
        if (response.statusCode != 200) {
          await response.stream.listen(null).cancel();
          throw FormatException('来源暂不可读取（${response.statusCode}），可在浏览器核验后手动记录');
        }
        final type = response.headers['content-type'] ?? '';
        if (!type.startsWith('text/') && !type.contains('json')) {
          await response.stream.listen(null).cancel();
          throw const FormatException('此来源不是网页或文本，请在浏览器查看原文后记录摘录');
        }
        final bytes = <int>[];
        await (() async {
          await for (final chunk
              in response.stream.timeout(const Duration(seconds: 15))) {
            bytes.addAll(chunk);
            if (bytes.length > 1024 * 1024)
              throw const FormatException('来源过长，请选择更具体的页面或手动摘录');
          }
        })()
            .timeout(const Duration(seconds: 20));
        var text = utf8.decode(bytes, allowMalformed: true);
        if (type.contains('html')) {
          text = text
              .replaceAll(
                  RegExp(r'<(script|style|noscript)\b[^>]*>[\s\S]*?</\1>',
                      caseSensitive: false),
                  ' ')
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'");
        }
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isEmpty) throw const FormatException('页面没有可读取正文，请手动核验');
        return OsSourceDocument(
            uri.toString(),
            text.length > 24000 ? text.substring(0, 24000) : text,
            DateTime.now());
      }
      throw const FormatException('来源重定向过多，请使用最终原文链接');
    } finally {
      if (_injected == null) client.close();
    }
  }
}

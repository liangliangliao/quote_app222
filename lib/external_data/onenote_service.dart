import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'onenote_config.dart';
import 'onenote_dao.dart';

class OneNoteSyncResult {
  const OneNoteSyncResult({
    required this.notebooks,
    required this.sections,
    required this.pages,
    required this.attachments,
  });

  final int notebooks;
  final int sections;
  final int pages;
  final int attachments;
}

class OneNoteAuthService {
  OneNoteAuthService({OneNoteDao? dao}) : _dao = dao ?? OneNoteDao();
  final OneNoteDao _dao;

  static const String _authorizeEndpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const String _tokenEndpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';

  Future<void> signIn() async {
    final redirectUri = await _dao.getRedirectUri();
    final callbackScheme = _callbackSchemeFromRedirectUri(redirectUri);
    final verifier = _codeVerifier();
    final challenge = _codeChallenge(verifier);
    final authUri = Uri.parse(_authorizeEndpoint).replace(queryParameters: {
      'client_id': OneNoteConfig.clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'response_mode': 'query',
      'scope': OneNoteConfig.scopes.join(' '),
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'prompt': 'select_account',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: callbackScheme,
    );
    final uri = Uri.parse(result);
    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      throw Exception('Microsoft 登录失败：$error ${uri.queryParameters['error_description'] ?? ''}');
    }
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('Microsoft 登录失败：没有返回 code。请确认 Entra 中已配置与 App 当前配置完全一致的 redirect URI：$redirectUri');
    }
    await _exchangeCode(code, verifier, redirectUri: redirectUri);
  }

  Future<void> disconnect() => _dao.clearAuth();

  Future<String> ensureAccessToken() async {
    final auth = await _dao.getAuth();
    if (auth == null) {
      throw Exception('尚未登录 Microsoft。请先点击“登录 Microsoft”。');
    }
    final access = (auth['access_token'] ?? '').toString();
    final refresh = (auth['refresh_token'] ?? '').toString();
    final expiresAt = _toInt(auth['expires_at_ms']);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (access.isNotEmpty && now < expiresAt - 60 * 1000) {
      return access;
    }
    if (refresh.isEmpty) {
      throw Exception('Microsoft refresh_token 为空，请重新登录。');
    }
    return _refresh(refresh, oldAuth: auth);
  }

  Future<Map<String, Object?>?> currentAuth() => _dao.getAuth();

  Future<void> _exchangeCode(String code, String verifier, {required String redirectUri}) async {
    final resp = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': OneNoteConfig.clientId,
        'scope': OneNoteConfig.scopes.join(' '),
        'code': code,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = _decodeBody(resp.bodyBytes);
      throw Exception('Microsoft token 获取失败：${resp.statusCode} $body');
    }
    final json = jsonDecode(_decodeBody(resp.bodyBytes)) as Map<String, dynamic>;
    final accessToken = (json['access_token'] ?? '').toString();
    final refreshToken = (json['refresh_token'] ?? '').toString();
    final scope = (json['scope'] ?? OneNoteConfig.scopes.join(' ')).toString();
    final expiresIn = _toInt(json['expires_in']);
    final expiresAtMs = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;
    final profile = await _fetchProfile(accessToken);
    await _dao.saveAuth(
      accountId: (profile['id'] ?? '').toString(),
      displayName: (profile['displayName'] ?? profile['userPrincipalName'] ?? 'Microsoft 账号').toString(),
      accessToken: accessToken,
      refreshToken: refreshToken,
      scope: scope,
      expiresAtMs: expiresAtMs,
    );
  }

  Future<String> _refresh(String refreshToken, {required Map<String, Object?> oldAuth}) async {
    final redirectUri = await _dao.getRedirectUri();
    final resp = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': OneNoteConfig.clientId,
        'scope': OneNoteConfig.scopes.join(' '),
        'refresh_token': refreshToken,
        'redirect_uri': redirectUri,
        'grant_type': 'refresh_token',
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = _decodeBody(resp.bodyBytes);
      throw Exception('Microsoft token 刷新失败：${resp.statusCode} $body。若你刚修改过重定向 URI，请清除登录后重新登录。');
    }
    final json = jsonDecode(_decodeBody(resp.bodyBytes)) as Map<String, dynamic>;
    final accessToken = (json['access_token'] ?? '').toString();
    final newRefreshToken = (json['refresh_token'] ?? refreshToken).toString();
    final scope = (json['scope'] ?? oldAuth['scope'] ?? OneNoteConfig.scopes.join(' ')).toString();
    final expiresIn = _toInt(json['expires_in']);
    await _dao.saveAuth(
      accountId: (oldAuth['account_id'] ?? '').toString(),
      displayName: (oldAuth['display_name'] ?? 'Microsoft 账号').toString(),
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      scope: scope,
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
    );
    return accessToken;
  }

  Future<Map<String, dynamic>> _fetchProfile(String token) async {
    final resp = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return <String, dynamic>{};
    }
    return jsonDecode(_decodeBody(resp.bodyBytes)) as Map<String, dynamic>;
  }

  String _callbackSchemeFromRedirectUri(String redirectUri) {
    final parsed = Uri.tryParse(redirectUri.trim());
    final scheme = parsed?.scheme ?? '';
    if (scheme.isEmpty) {
      throw Exception('重定向 URI 缺少 scheme，请在配置中填写完整 URI，例如：${OneNoteConfig.defaultRedirectUri}');
    }
    return scheme;
  }

  String _codeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

class OneNoteSyncService {
  OneNoteSyncService({OneNoteDao? dao, OneNoteAuthService? auth})
      : _dao = dao ?? OneNoteDao(),
        _auth = auth ?? OneNoteAuthService(dao: dao ?? OneNoteDao());

  final OneNoteDao _dao;
  final OneNoteAuthService _auth;

  Future<OneNoteSyncResult> syncByNames({
    required String notebookName,
    required String sectionName,
    void Function(String message)? onProgress,
  }) async {
    await _dao.ensureTables();
    final nbName = notebookName.trim();
    final secName = sectionName.trim();
    if (nbName.isEmpty && secName.isEmpty) {
      throw Exception('请输入笔记本名称或分区名称。为提升效率，本功能不会默认读取所有笔记本。');
    }

    onProgress?.call('正在确认 Microsoft 登录状态...');
    final token = await _auth.ensureAccessToken();

    int notebookCount = 0;
    int sectionCount = 0;
    int pageCount = 0;
    int attachmentCount = 0;

    final List<Map<String, dynamic>> notebooks = [];
    final List<Map<String, dynamic>> sections = [];

    if (nbName.isNotEmpty) {
      onProgress?.call('正在按笔记本名称精确查询：$nbName');
      final matched = await _getJsonList(
        token,
        'https://graph.microsoft.com/v1.0/me/onenote/notebooks?\$filter=${Uri.encodeComponent("displayName eq '${_escapeODataString(nbName)}'")}&\$top=100',
      );
      if (matched.isEmpty) {
        throw Exception('没有找到名称为“$nbName”的 OneNote 笔记本。请检查名称是否完全一致。');
      }
      notebooks.addAll(matched);
      for (final nb in notebooks) {
        await _dao.upsertNotebook(nb);
        notebookCount++;
      }
      for (final nb in notebooks) {
        final notebookId = (nb['id'] ?? '').toString();
        if (notebookId.isEmpty) continue;
        if (secName.isNotEmpty) {
          onProgress?.call('正在按分区名称精确查询：$secName');
          sections.addAll(await _getJsonList(
            token,
            'https://graph.microsoft.com/v1.0/me/onenote/notebooks/$notebookId/sections?\$filter=${Uri.encodeComponent("displayName eq '${_escapeODataString(secName)}'")}&\$top=100',
          ));
        } else {
          onProgress?.call('正在读取笔记本“${nb['displayName'] ?? nbName}”下的分区...');
          sections.addAll(await _getJsonList(
            token,
            'https://graph.microsoft.com/v1.0/me/onenote/notebooks/$notebookId/sections?\$top=100',
          ));
        }
      }
    } else {
      onProgress?.call('正在按分区名称精确查询：$secName');
      sections.addAll(await _getJsonList(
        token,
        'https://graph.microsoft.com/v1.0/me/onenote/sections?\$filter=${Uri.encodeComponent("displayName eq '${_escapeODataString(secName)}'")}&\$top=100',
      ));
      if (sections.isNotEmpty) {
        final seen = <String>{};
        for (final sec in sections) {
          final parentNotebook = sec['parentNotebook'];
          final notebookId = (parentNotebook is Map ? parentNotebook['id'] : null)?.toString() ?? '';
          if (notebookId.isNotEmpty && seen.add(notebookId)) {
            final nb = await _getJsonObject(token, 'https://graph.microsoft.com/v1.0/me/onenote/notebooks/$notebookId');
            notebooks.add(nb);
            await _dao.upsertNotebook(nb);
            notebookCount++;
          }
        }
      }
    }

    if (sections.isEmpty) {
      throw Exception(secName.isEmpty ? '目标笔记本下没有找到分区。' : '没有找到名称为“$secName”的 OneNote 分区。');
    }

    final seenSections = <String>{};
    for (final sec in sections) {
      final sectionId = (sec['id'] ?? '').toString();
      if (sectionId.isEmpty || !seenSections.add(sectionId)) continue;
      final parentNotebook = sec['parentNotebook'];
      String notebookId = (parentNotebook is Map ? parentNotebook['id'] : null)?.toString() ?? '';
      if (notebookId.isEmpty && notebooks.isNotEmpty) notebookId = (notebooks.first['id'] ?? '').toString();
      await _dao.upsertSection(sec, fallbackNotebookId: notebookId);
      sectionCount++;

      onProgress?.call('正在读取分区“${sec['displayName'] ?? ''}”的页面列表...');
      final pageMeta = await _getJsonList(
        token,
        'https://graph.microsoft.com/v1.0/me/onenote/sections/$sectionId/pages?\$top=100&\$select=id,title,createdDateTime,lastModifiedDateTime,links,level,order,parentSection,parentNotebook',
      );
      int idx = 0;
      for (final page in pageMeta) {
        idx++;
        final pageId = (page['id'] ?? '').toString();
        if (pageId.isEmpty) continue;
        onProgress?.call('正在同步页面 $idx/${pageMeta.length}：${page['title'] ?? '未命名页面'}');
        final html = await _getHtml(token, 'https://graph.microsoft.com/v1.0/me/onenote/pages/$pageId/content');
        final plain = OneNoteHtmlSanitizer.toPlainText(html);
        await _dao.upsertPage(
          page: page,
          notebookId: notebookId,
          sectionId: sectionId,
          html: html,
          plainText: plain,
        );
        final attachments = await _downloadAttachments(token, pageId, html, onProgress: onProgress);
        await _dao.replaceAttachments(pageId, attachments);
        pageCount++;
        attachmentCount += attachments.length;
      }
    }

    onProgress?.call('同步完成：笔记本 $notebookCount 个，分区 $sectionCount 个，页面 $pageCount 个，附件 $attachmentCount 个。');
    return OneNoteSyncResult(
      notebooks: notebookCount,
      sections: sectionCount,
      pages: pageCount,
      attachments: attachmentCount,
    );
  }

  Future<List<Map<String, dynamic>>> _getJsonList(String token, String url) async {
    final out = <Map<String, dynamic>>[];
    String? nextUrl = url.replaceAll('\n', '');
    while (nextUrl != null && nextUrl.isNotEmpty) {
      final obj = await _getJsonObject(token, nextUrl);
      final value = obj['value'];
      if (value is List) {
        for (final item in value) {
          if (item is Map) out.add(Map<String, dynamic>.from(item));
        }
      }
      nextUrl = obj['@odata.nextLink']?.toString();
    }
    return out;
  }

  Future<Map<String, dynamic>> _getJsonObject(String token, String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      final body = _decodeBody(resp.bodyBytes);
      await _dao.addApiLog(
        source: 'onenote',
        endpoint: url,
        method: 'GET',
        statusCode: resp.statusCode,
        responseBody: body,
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Graph API 请求失败：${resp.statusCode} $body');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      await _dao.addApiLog(source: 'onenote', endpoint: url, method: 'GET', errorMessage: e.toString());
      rethrow;
    }
  }

  Future<String> _getHtml(String token, String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token', 'Accept': 'text/html'});
      final body = _decodeBody(resp.bodyBytes);
      await _dao.addApiLog(source: 'onenote', endpoint: url, method: 'GET', statusCode: resp.statusCode, responseBody: body);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('获取 OneNote 页面正文失败：${resp.statusCode} $body');
      }
      return body;
    } catch (e) {
      await _dao.addApiLog(source: 'onenote', endpoint: url, method: 'GET', errorMessage: e.toString());
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> _downloadAttachments(
    String token,
    String pageId,
    String html, {
    void Function(String message)? onProgress,
  }) async {
    final refs = OneNoteHtmlSanitizer.extractResourceRefs(html);
    if (refs.isEmpty) return <Map<String, Object?>>[];
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory(path.join(dir.path, 'external_data', 'onenote', pageId));
    if (!await base.exists()) await base.create(recursive: true);
    final out = <Map<String, Object?>>[];
    int index = 0;
    for (final ref in refs) {
      index++;
      final url = ref.url;
      final resourceId = ref.resourceId;
      try {
        onProgress?.call('正在下载页面附件 $index/${refs.length}...');
        final resp = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
        await _dao.addApiLog(source: 'onenote', endpoint: url, method: 'GET', statusCode: resp.statusCode, responseBody: 'bytes=${resp.bodyBytes.length}');
        if (resp.statusCode < 200 || resp.statusCode >= 300) continue;
        final mime = (resp.headers['content-type'] ?? 'application/octet-stream').split(';').first.trim();
        final ext = _extensionForMime(mime, fallbackUrl: url);
        final fileName = '${resourceId.isNotEmpty ? resourceId : 'resource_$index'}$ext';
        final file = File(path.join(base.path, fileName));
        await file.writeAsBytes(Uint8List.fromList(resp.bodyBytes), flush: true);
        out.add({
          'resource_id': resourceId,
          'file_name': fileName,
          'mime_type': mime,
          'remote_url': url,
          'local_path': file.path,
          'size_bytes': resp.bodyBytes.length,
        });
      } catch (e) {
        await _dao.addApiLog(source: 'onenote', endpoint: url, method: 'GET', errorMessage: e.toString());
      }
    }
    return out;
  }

  String _extensionForMime(String mime, {required String fallbackUrl}) {
    switch (mime.toLowerCase()) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'audio/mpeg':
        return '.mp3';
      case 'audio/mp4':
      case 'audio/x-m4a':
        return '.m4a';
      case 'audio/wav':
      case 'audio/wave':
        return '.wav';
      case 'application/pdf':
        return '.pdf';
      default:
        final uri = Uri.tryParse(fallbackUrl);
        final last = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
        final ext = path.extension(last);
        return ext.isNotEmpty && ext.length <= 8 ? ext : '.bin';
    }
  }

  String _escapeODataString(String s) => s.replaceAll("'", "''");
}

class OneNoteResourceRef {
  const OneNoteResourceRef({required this.url, required this.resourceId});
  final String url;
  final String resourceId;
}

class OneNoteHtmlSanitizer {
  static String toPlainText(String html) {
    var s = html;
    s = s.replaceAll(RegExp(r'<(script|style|svg|head|object|embed|iframe)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<(object|embed|iframe)\b[^>]*(/?)>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</(p|div|li|tr|h[1-6]|section|article)>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '• ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    s = _decodeHtmlEntities(s);
    s = s.replaceAll(RegExp(r'data:[^\s]+;base64,[A-Za-z0-9+/=]+'), ' ');
    s = s.replaceAll(RegExp(r'[\uFFFC\uFFFD]'), ' ');
    s = s.replaceAll(RegExp(r'\[object\s+Object\]', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'(^|\s)obj(\s|$)', caseSensitive: false), ' ');
    s = s.replaceAll('\r', '\n');
    s = s.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ');
    s = s.replaceAll(RegExp(r' *\n+ *'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  static List<OneNoteResourceRef> extractResourceRefs(String html) {
    final refs = <OneNoteResourceRef>[];
    final seen = <String>{};
    final reg = RegExp(
      r'''(?:src|href|data|data-fullres-src)\s*=\s*["']([^"']*?/onenote/resources/([^/"'?#]+)/\$value[^"']*)["']''',
      caseSensitive: false,
    );
    for (final m in reg.allMatches(html)) {
      var url = m.group(1) ?? '';
      final id = Uri.decodeComponent(m.group(2) ?? '');
      if (url.isEmpty) continue;
      url = _normalizeResourceUrl(url);
      if (seen.add(url)) refs.add(OneNoteResourceRef(url: url, resourceId: id));
    }
    return refs;
  }

  static String _normalizeResourceUrl(String url) {
    var u = url.replaceAll('&amp;', '&');
    if (u.startsWith('https://')) return u;
    if (u.startsWith('http://')) return u.replaceFirst('http://', 'https://');
    if (u.startsWith('/')) return 'https://graph.microsoft.com$u';
    return u;
  }

  static String _decodeHtmlEntities(String input) {
    const named = <String, String>{
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
      'nbsp': ' ',
      'ensp': ' ',
      'emsp': ' ',
      'ndash': '–',
      'mdash': '—',
      'lsquo': '‘',
      'rsquo': '’',
      'ldquo': '“',
      'rdquo': '”',
      'hellip': '…',
      'middot': '·',
    };
    return input.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (m) {
      final code = m.group(1) ?? '';
      if (code.startsWith('#x') || code.startsWith('#X')) {
        final v = int.tryParse(code.substring(2), radix: 16);
        return v == null ? m.group(0)! : String.fromCharCode(v);
      }
      if (code.startsWith('#')) {
        final v = int.tryParse(code.substring(1));
        return v == null ? m.group(0)! : String.fromCharCode(v);
      }
      return named[code] ?? m.group(0)!;
    });
  }
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _decodeBody(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

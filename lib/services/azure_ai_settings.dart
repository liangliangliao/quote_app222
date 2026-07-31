import 'dart:convert';

import '../data/kv_dao.dart';

/// 一个 Azure / Microsoft Foundry 资源（项目）。
///
/// 用户可以同时配置多个：例如 `AzureOpenAI` 项目里部署了 gpt-5.6 系列，
/// `modleapikey` 项目里部署了 Claude 与 Grok。全局模型列表会把所有资源里
/// 已部署的模型合并成一张表，模型 id 使用 `资源名/部署名` 的限定写法，
/// 因此选中任意一个模型都能唯一定位回它所属的资源与终结点。
class AzureAiResource {
  /// 稳定 id，用于内部引用；由资源名规范化而来。
  final String id;

  /// 资源/项目显示名，例如 `AzureOpenAI`、`modleapikey`。
  final String name;

  /// 用户填写的终结点。既接受 Azure OpenAI 终结点
  /// （`https://xxx.openai.azure.com`），也接受 Microsoft Foundry 项目终结点
  /// （`https://xxx.services.ai.azure.com/api/projects/yyy`）。
  final String endpoint;

  /// 该资源的 API Key。
  final String apiKey;

  /// api-version。留空时按接入方式使用默认值。
  final String apiVersion;

  /// 接入方式：auto / azure_openai / foundry_models。
  final String kind;

  /// 手动填写的部署名。当资源关闭了部署列举接口时作为兜底模型列表。
  final List<String> deployments;

  /// 是否参与模型列举与调用。
  final bool enabled;

  const AzureAiResource({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.apiKey,
    this.apiVersion = '',
    this.kind = AzureAiSettings.kindAuto,
    this.deployments = const <String>[],
    this.enabled = true,
  });

  AzureAiResource copyWith({
    String? id,
    String? name,
    String? endpoint,
    String? apiKey,
    String? apiVersion,
    String? kind,
    List<String>? deployments,
    bool? enabled,
  }) {
    return AzureAiResource(
      id: id ?? this.id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      apiVersion: apiVersion ?? this.apiVersion,
      kind: kind ?? this.kind,
      deployments: deployments ?? this.deployments,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'endpoint': endpoint,
        'api_key': apiKey,
        'api_version': apiVersion,
        'kind': kind,
        'deployments': deployments,
        'enabled': enabled,
      };

  static AzureAiResource fromJson(Map<String, dynamic> json) {
    final rawDeployments = json['deployments'];
    final deployments = <String>[];
    if (rawDeployments is List) {
      for (final item in rawDeployments) {
        final v = item.toString().trim();
        if (v.isNotEmpty && !deployments.contains(v)) deployments.add(v);
      }
    } else if (rawDeployments is String) {
      deployments.addAll(AzureAiSettings.parseDeploymentInput(rawDeployments));
    }
    final name = (json['name'] ?? '').toString().trim();
    final id = (json['id'] ?? '').toString().trim();
    return AzureAiResource(
      id: id.isEmpty ? AzureAiSettings.slugify(name) : id,
      name: name,
      endpoint: (json['endpoint'] ?? '').toString().trim(),
      apiKey: (json['api_key'] ?? json['apiKey'] ?? '').toString().trim(),
      apiVersion: (json['api_version'] ?? json['apiVersion'] ?? '').toString().trim(),
      kind: AzureAiSettings.normalizeKind((json['kind'] ?? '').toString()),
      deployments: deployments,
      enabled: json['enabled'] == null ? true : json['enabled'] == true || json['enabled'].toString() == '1',
    );
  }

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.trim().isNotEmpty;

  /// 从用户填写的终结点里解析出资源根地址。
  ///
  /// 支持三种常见写法，全部归一化成 `https://<host>`：
  /// - `https://xxx.openai.azure.com`
  /// - `https://xxx.services.ai.azure.com/api/projects/yyy`（Foundry 项目终结点）
  /// - 已经带上 `/openai`、`/openai/v1`、`/models` 等数据面后缀的地址
  String get baseUrl {
    var raw = endpoint.trim();
    if (raw.isEmpty) return '';
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.trim().isEmpty) return '';
    var path = uri.path;
    final lower = path.toLowerCase();
    final projectIndex = lower.indexOf('/api/projects/');
    if (projectIndex >= 0) {
      path = path.substring(0, projectIndex);
    }
    for (final suffix in const <String>['/openai/v1', '/openai/deployments', '/openai', '/models']) {
      if (path.toLowerCase().endsWith(suffix)) {
        path = path.substring(0, path.length - suffix.length);
        break;
      }
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${uri.scheme}://${uri.authority}$path';
  }

  /// Foundry 项目终结点里的项目名，仅用于设置页回显，不参与请求拼接。
  String get projectName {
    final raw = endpoint.trim();
    final lower = raw.toLowerCase();
    final index = lower.indexOf('/api/projects/');
    if (index < 0) return '';
    var rest = raw.substring(index + '/api/projects/'.length);
    final slash = rest.indexOf('/');
    if (slash >= 0) rest = rest.substring(0, slash);
    final question = rest.indexOf('?');
    if (question >= 0) rest = rest.substring(0, question);
    return rest.trim();
  }

  /// 实际生效的接入方式。auto 时按主机名推断。
  String get resolvedKind {
    final normalized = AzureAiSettings.normalizeKind(kind);
    if (normalized != AzureAiSettings.kindAuto) return normalized;
    final host = (Uri.tryParse(baseUrl)?.host ?? '').toLowerCase();
    if (host.endsWith('.openai.azure.com')) return AzureAiSettings.kindAzureOpenAi;
    if (host.endsWith('.services.ai.azure.com') ||
        host.endsWith('.cognitiveservices.azure.com') ||
        host.endsWith('.inference.ai.azure.com')) {
      return AzureAiSettings.kindFoundryModels;
    }
    // Foundry 项目终结点即使换了自定义域名，也一定带 /api/projects/。
    if (projectName.isNotEmpty) return AzureAiSettings.kindFoundryModels;
    return AzureAiSettings.kindAzureOpenAi;
  }

  String get resolvedApiVersion {
    final v = apiVersion.trim();
    if (v.isNotEmpty) return v;
    return resolvedKind == AzureAiSettings.kindFoundryModels
        ? AzureAiSettings.defaultFoundryApiVersion
        : AzureAiSettings.defaultAzureOpenAiApiVersion;
  }

  String get kindLabel {
    switch (resolvedKind) {
      case AzureAiSettings.kindFoundryModels:
        return 'Microsoft Foundry 模型推理';
      case AzureAiSettings.kindAzureOpenAi:
      default:
        return 'Azure OpenAI 部署';
    }
  }

  /// 聊天调用候选终结点。
  ///
  /// Azure 的三条数据面路径在不同资源/不同模型上可用性不一样：
  /// - `/openai/deployments/<部署名>/chat/completions`：Azure OpenAI 部署（gpt 系列）
  /// - `/models/chat/completions`：Foundry 模型推理（Claude、Grok 等模型目录模型）
  /// - `/openai/v1/chat/completions`：新版 OpenAI 兼容统一入口
  ///
  /// 这里按接入方式排出优先级，调用侧会在 404/405 一类“路径不支持”的错误上
  /// 自动换下一条，从而让同一个资源里的 gpt / claude / grok 都能打通。
  List<String> chatEndpointCandidates(String deployment) {
    final base = baseUrl;
    final name = deployment.trim();
    if (base.isEmpty || name.isEmpty) return const <String>[];
    final encoded = Uri.encodeComponent(name);
    final version = resolvedApiVersion;
    final azureOpenAi = '$base/openai/deployments/$encoded/chat/completions?api-version=$version';
    final foundry = '$base/models/chat/completions?api-version=$version';
    final v1 = '$base/openai/v1/chat/completions';
    final ordered = resolvedKind == AzureAiSettings.kindFoundryModels
        ? <String>[foundry, v1, azureOpenAi]
        : <String>[azureOpenAi, v1, foundry];
    final unique = <String>[];
    for (final item in ordered) {
      if (!unique.contains(item)) unique.add(item);
    }
    return unique;
  }

  /// 模型/部署列举候选终结点，按顺序尝试并合并结果。
  List<String> modelListEndpointCandidates() {
    final base = baseUrl;
    if (base.isEmpty) return const <String>[];
    final version = resolvedApiVersion;
    final ordered = <String>[
      // 数据面部署列举，Azure OpenAI 与 Foundry 资源都支持，返回的是“已部署”的模型。
      '$base/openai/deployments?api-version=${AzureAiSettings.deploymentListApiVersion}',
      '$base/openai/models?api-version=$version',
      '$base/openai/v1/models',
      '$base/models?api-version=$version',
    ];
    if (resolvedKind == AzureAiSettings.kindFoundryModels) {
      ordered.insert(1, '$base/models?api-version=$version');
    }
    final unique = <String>[];
    for (final item in ordered) {
      if (!unique.contains(item)) unique.add(item);
    }
    return unique;
  }

  /// Azure 两套数据面都接受 `api-key`；`/models` 与 `/openai/v1` 还额外接受
  /// `Authorization: Bearer`，一起带上可以覆盖更多资源配置。
  Map<String, String> authHeaders(String endpointUrl) {
    final key = apiKey.trim();
    if (key.isEmpty) return const <String, String>{};
    final lower = endpointUrl.toLowerCase();
    final acceptsBearer = lower.contains('/models/') || lower.contains('/openai/v1/') || lower.endsWith('/models');
    return <String, String>{
      'api-key': key,
      if (acceptsBearer) 'Authorization': 'Bearer $key',
    };
  }
}

class AzureAiSettings {
  static const String resourcesKey = 'global_ai_azure_resources';

  static const String kindAuto = 'auto';
  static const String kindAzureOpenAi = 'azure_openai';
  static const String kindFoundryModels = 'foundry_models';

  static const String defaultAzureOpenAiApiVersion = '2024-10-21';
  static const String defaultFoundryApiVersion = '2024-05-01-preview';
  static const String deploymentListApiVersion = '2023-03-15-preview';

  /// 限定模型 id 的分隔符：`资源名/部署名`。Azure 部署名不允许包含 `/`，
  /// 资源名在保存时也会被规范化掉 `/`，因此这个分隔符不会有歧义。
  static const String modelSeparator = '/';

  final KeyValueDao _kvDao = KeyValueDao();

  static String normalizeKind(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == kindAzureOpenAi || value == 'azureopenai' || value == 'openai') return kindAzureOpenAi;
    if (value == kindFoundryModels || value == 'foundry' || value == 'models') return kindFoundryModels;
    return kindAuto;
  }

  static String slugify(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'[a-z0-9\-_]').hasMatch(ch)) {
        buffer.write(ch);
      } else if (ch == ' ' || ch == '.' || ch == '/') {
        buffer.write('-');
      }
    }
    final slug = buffer.toString().replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return slug;
  }

  /// 资源名去掉分隔符，保证 `资源名/部署名` 可以被稳定拆分。
  static String normalizeResourceName(String raw) {
    final value = raw.trim().replaceAll(modelSeparator, '-');
    return value;
  }

  static List<String> parseDeploymentInput(String raw) {
    final parts = raw.split(RegExp(r'[,，;；\s]+'));
    final result = <String>[];
    for (final part in parts) {
      final v = part.trim();
      if (v.isNotEmpty && !result.contains(v)) result.add(v);
    }
    return result;
  }

  static String qualifyModel(String resourceName, String deployment) {
    final name = normalizeResourceName(resourceName);
    final target = deployment.trim();
    if (target.isEmpty) return '';
    if (name.isEmpty) return target;
    return '$name$modelSeparator$target';
  }

  /// 把 `资源名/部署名` 拆回两段。没有分隔符时资源名为空，代表“用第一个可用资源”。
  static ({String resourceName, String deployment}) splitModel(String qualified) {
    final raw = qualified.trim();
    if (raw.isEmpty) return (resourceName: '', deployment: '');
    final index = raw.indexOf(modelSeparator);
    if (index <= 0 || index >= raw.length - 1) {
      return (resourceName: '', deployment: raw);
    }
    return (
      resourceName: raw.substring(0, index).trim(),
      deployment: raw.substring(index + 1).trim(),
    );
  }

  /// 未配置任何资源时给出的模板，直接对应需求里的两个项目，
  /// 用户只需要填终结点和密钥即可。
  static List<AzureAiResource> defaultTemplates() {
    return <AzureAiResource>[
      const AzureAiResource(
        id: 'azureopenai',
        name: 'AzureOpenAI',
        endpoint: '',
        apiKey: '',
        apiVersion: defaultAzureOpenAiApiVersion,
        kind: kindAzureOpenAi,
      ),
      const AzureAiResource(
        id: 'modleapikey',
        name: 'modleapikey',
        endpoint: '',
        apiKey: '',
        apiVersion: defaultFoundryApiVersion,
        kind: kindFoundryModels,
      ),
    ];
  }

  Future<List<AzureAiResource>> listResources() async {
    final raw = ((await _kvDao.getString(resourcesKey)) ?? '').trim();
    if (raw.isEmpty) return <AzureAiResource>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AzureAiResource>[];
      final result = <AzureAiResource>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final resource = AzureAiResource.fromJson(item);
          if (resource.name.trim().isEmpty && resource.endpoint.trim().isEmpty) continue;
          result.add(resource);
        }
      }
      return result;
    } catch (_) {
      return <AzureAiResource>[];
    }
  }

  /// 只返回填好终结点与密钥、且没有被停用的资源。
  Future<List<AzureAiResource>> listUsableResources() async {
    final all = await listResources();
    return all.where((e) => e.enabled && e.isConfigured).toList(growable: false);
  }

  Future<void> saveResources(List<AzureAiResource> resources) async {
    final normalized = <AzureAiResource>[];
    final usedIds = <String>{};
    final usedNames = <String>{};
    for (var i = 0; i < resources.length; i++) {
      final item = resources[i];
      var name = normalizeResourceName(item.name);
      if (name.isEmpty) name = 'azure-${i + 1}';
      var candidate = name;
      var suffix = 2;
      while (!usedNames.add(candidate.toLowerCase())) {
        candidate = '$name-$suffix';
        suffix += 1;
      }
      name = candidate;

      var id = slugify(item.id.trim().isEmpty ? name : item.id);
      if (id.isEmpty) id = 'azure-${i + 1}';
      var idCandidate = id;
      var idSuffix = 2;
      while (!usedIds.add(idCandidate)) {
        idCandidate = '$id-$idSuffix';
        idSuffix += 1;
      }

      normalized.add(item.copyWith(
        id: idCandidate,
        name: name,
        endpoint: item.endpoint.trim(),
        apiKey: item.apiKey.trim(),
        apiVersion: item.apiVersion.trim(),
        kind: normalizeKind(item.kind),
        deployments: item.deployments.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false),
      ));
    }
    await _kvDao.setString(resourcesKey, jsonEncode(normalized.map((e) => e.toJson()).toList()));
  }

  /// 按限定模型 id 找到对应资源。
  ///
  /// 找不到资源名时退回第一个可用资源，这样用户手工输入部署名也能直接调用。
  Future<AzureAiResource?> resolveResourceForModel(String qualifiedModel) async {
    final usable = await listUsableResources();
    if (usable.isEmpty) return null;
    final parts = splitModel(qualifiedModel);
    if (parts.resourceName.isEmpty) return usable.first;
    final wanted = parts.resourceName.toLowerCase();
    for (final resource in usable) {
      if (resource.name.toLowerCase() == wanted || resource.id.toLowerCase() == wanted) {
        return resource;
      }
    }
    return usable.first;
  }

  /// 汇总所有可用资源里已配置的部署名，供“没有联网列举成功”时兜底展示。
  Future<List<String>> listManualQualifiedModels() async {
    final usable = await listUsableResources();
    final result = <String>[];
    for (final resource in usable) {
      for (final deployment in resource.deployments) {
        final qualified = qualifyModel(resource.name, deployment);
        if (qualified.isNotEmpty && !result.contains(qualified)) result.add(qualified);
      }
    }
    return result;
  }
}

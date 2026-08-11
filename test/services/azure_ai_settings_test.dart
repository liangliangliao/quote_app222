import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/azure_ai_settings.dart';

AzureAiResource _resource({
  String name = 'AzureOpenAI',
  required String endpoint,
  String apiKey = 'test-key',
  String apiVersion = '',
  String kind = AzureAiSettings.kindAuto,
  List<String> deployments = const <String>[],
}) {
  return AzureAiResource(
    id: AzureAiSettings.slugify(name),
    name: name,
    endpoint: endpoint,
    apiKey: apiKey,
    apiVersion: apiVersion,
    kind: kind,
    deployments: deployments,
  );
}

void main() {
  group('终结点归一化', () {
    test('Microsoft Foundry 项目终结点会被裁成资源根地址，并解析出项目名', () {
      final resource = _resource(
        name: 'modleapikey',
        endpoint: 'https://my-res.services.ai.azure.com/api/projects/modleapikey',
      );
      expect(resource.baseUrl, 'https://my-res.services.ai.azure.com');
      expect(resource.projectName, 'modleapikey');
      expect(resource.resolvedKind, AzureAiSettings.kindFoundryModels);
    });

    test('Azure OpenAI 终结点按 Azure OpenAI 部署方式接入', () {
      final resource = _resource(endpoint: 'https://my-res.openai.azure.com/');
      expect(resource.baseUrl, 'https://my-res.openai.azure.com');
      expect(resource.projectName, '');
      expect(resource.resolvedKind, AzureAiSettings.kindAzureOpenAi);
    });

    test('已经带上数据面后缀的终结点会被裁掉后缀', () {
      expect(_resource(endpoint: 'https://my-res.openai.azure.com/openai/v1').baseUrl,
          'https://my-res.openai.azure.com');
      expect(_resource(endpoint: 'https://my-res.services.ai.azure.com/models').baseUrl,
          'https://my-res.services.ai.azure.com');
    });

    test('门户部署页的“目标 URI”会被裁成资源根地址，查询串一并丢弃', () {
      // 用户直接粘贴 Foundry 部署页复制出来的目标 URI。之前只按固定后缀裁剪，
      // /openai/responses 认不出来，导致拼出 .../openai/responses/openai/v1/models 并 404。
      final resource = _resource(
        endpoint: 'https://test2026111.openai.azure.com/openai/responses?api-version=2025-04-01-preview',
      );
      expect(resource.baseUrl, 'https://test2026111.openai.azure.com');
      expect(resource.modelListEndpointCandidates().every((e) => !e.contains('/responses/')), isTrue);
      expect(
        resource.chatEndpointCandidates('gpt-5.6-luna').first,
        'https://test2026111.openai.azure.com/openai/deployments/gpt-5.6-luna/chat/completions'
        '?api-version=2025-04-01-preview',
      );
    });

    test('完整的 chat/completions 调用地址也会被裁成资源根地址', () {
      expect(
        _resource(
          endpoint: 'https://my-res.openai.azure.com/openai/deployments/gpt-5/chat/completions?api-version=2024-10-21',
        ).baseUrl,
        'https://my-res.openai.azure.com',
      );
      expect(
        _resource(
          endpoint: 'https://my-res.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview',
        ).baseUrl,
        'https://my-res.services.ai.azure.com',
      );
    });

    test('终结点自带的 api-version 会在未显式填写时被采用', () {
      final resource = _resource(
        endpoint: 'https://test2026111.openai.azure.com/openai/responses?api-version=2025-04-01-preview',
      );
      expect(resource.endpointApiVersion, '2025-04-01-preview');
      expect(resource.resolvedApiVersion, '2025-04-01-preview');
    });

    test('显式填写的 api-version 优先于终结点里自带的', () {
      final resource = _resource(
        endpoint: 'https://test2026111.openai.azure.com/openai/responses?api-version=2025-04-01-preview',
        apiVersion: '2024-10-21',
      );
      expect(resource.resolvedApiVersion, '2024-10-21');
    });

    test('缺少协议头时补上 https', () {
      expect(_resource(endpoint: 'my-res.openai.azure.com').baseUrl, 'https://my-res.openai.azure.com');
    });

    test('终结点为空时判定为未配置', () {
      expect(_resource(endpoint: '').isConfigured, isFalse);
      expect(_resource(endpoint: 'https://my-res.openai.azure.com', apiKey: '').isConfigured, isFalse);
      expect(_resource(endpoint: 'https://my-res.openai.azure.com').isConfigured, isTrue);
    });
  });

  group('调用地址候选', () {
    test('Azure OpenAI 资源优先走部署路径', () {
      final resource = _resource(
        endpoint: 'https://my-res.openai.azure.com',
        apiVersion: '2024-10-21',
      );
      final candidates = resource.chatEndpointCandidates('gpt-5.6-chat');
      expect(candidates.first,
          'https://my-res.openai.azure.com/openai/deployments/gpt-5.6-chat/chat/completions?api-version=2024-10-21');
      expect(candidates, contains('https://my-res.openai.azure.com/openai/v1/chat/completions'));
    });

    test('Foundry 资源优先走模型推理路径，并保留部署路径作为回退', () {
      final resource = _resource(
        name: 'modleapikey',
        endpoint: 'https://my-res.services.ai.azure.com/api/projects/p1',
        apiVersion: '2024-05-01-preview',
      );
      final candidates = resource.chatEndpointCandidates('claude-sonnet-4-5');
      expect(candidates.first,
          'https://my-res.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview');
      expect(
        candidates.any((e) => e.contains('/openai/deployments/claude-sonnet-4-5/chat/completions')),
        isTrue,
      );
    });

    test('部署名会做 URL 编码', () {
      final resource = _resource(endpoint: 'https://my-res.openai.azure.com');
      expect(resource.chatEndpointCandidates('gpt 5').first, contains('/deployments/gpt%205/'));
    });

    test('终结点或部署名缺失时不产生候选地址', () {
      expect(_resource(endpoint: '').chatEndpointCandidates('gpt-5'), isEmpty);
      expect(_resource(endpoint: 'https://my-res.openai.azure.com').chatEndpointCandidates('  '), isEmpty);
    });

    test('既没显式填写、终结点也不带 api-version 时按接入方式取默认值', () {
      expect(_resource(endpoint: 'https://my-res.openai.azure.com').resolvedApiVersion,
          AzureAiSettings.defaultAzureOpenAiApiVersion);
      expect(
        _resource(endpoint: 'https://my-res.services.ai.azure.com/api/projects/p1').resolvedApiVersion,
        AzureAiSettings.defaultFoundryApiVersion,
      );
    });

    test('Azure OpenAI 默认 api-version 支持 gpt-5 系列所需的 max_completion_tokens', () {
      // max_completion_tokens 要求 api-version 不低于 2024-12-01-preview，
      // 默认值低于这个门槛会让 gpt-5 部署一上来就被判成“无法识别的请求参数”。
      expect(AzureAiSettings.defaultAzureOpenAiApiVersion.compareTo('2024-12-01') >= 0, isTrue);
    });
  });

  group('鉴权头', () {
    test('所有 Azure 路径都带 api-key；models / v1 路径额外带 Bearer', () {
      final resource = _resource(endpoint: 'https://my-res.openai.azure.com', apiKey: 'k1');
      final deploymentHeaders =
          resource.authHeaders('https://my-res.openai.azure.com/openai/deployments/gpt-5/chat/completions');
      expect(deploymentHeaders['api-key'], 'k1');
      expect(deploymentHeaders.containsKey('Authorization'), isFalse);

      final modelHeaders = resource.authHeaders('https://my-res.services.ai.azure.com/models/chat/completions');
      expect(modelHeaders['api-key'], 'k1');
      expect(modelHeaders['Authorization'], 'Bearer k1');
    });

    test('没有密钥时不产生鉴权头', () {
      expect(_resource(endpoint: 'https://my-res.openai.azure.com', apiKey: '').authHeaders('x'), isEmpty);
    });
  });

  group('限定模型 id', () {
    test('资源名与部署名可以往返转换', () {
      final qualified = AzureAiSettings.qualifyModel('modleapikey', 'grok-4');
      expect(qualified, 'modleapikey/grok-4');
      final parts = AzureAiSettings.splitModel(qualified);
      expect(parts.resourceName, 'modleapikey');
      expect(parts.deployment, 'grok-4');
    });

    test('没有分隔符时整串当作部署名，资源名留空表示用第一个可用资源', () {
      final parts = AzureAiSettings.splitModel('gpt-5.6-chat');
      expect(parts.resourceName, '');
      expect(parts.deployment, 'gpt-5.6-chat');
    });

    test('资源名里的分隔符会被规范化掉，避免拆分歧义', () {
      final qualified = AzureAiSettings.qualifyModel('team/azure', 'gpt-5');
      expect(qualified, 'team-azure/gpt-5');
      expect(AzureAiSettings.splitModel(qualified).resourceName, 'team-azure');
      expect(AzureAiSettings.splitModel(qualified).deployment, 'gpt-5');
    });

    test('空部署名不产生限定 id', () {
      expect(AzureAiSettings.qualifyModel('AzureOpenAI', '  '), '');
      expect(AzureAiSettings.splitModel('').deployment, '');
    });
  });

  group('部署名输入解析', () {
    test('支持中英文逗号、分号与空白分隔并去重', () {
      final parsed = AzureAiSettings.parseDeploymentInput('gpt-5.6-chat, claude-sonnet-4-5；grok-4  gpt-5.6-chat');
      expect(parsed, <String>['gpt-5.6-chat', 'claude-sonnet-4-5', 'grok-4']);
    });
  });

  group('接入方式规范化', () {
    test('识别常见别名，未知值退回自动识别', () {
      expect(AzureAiSettings.normalizeKind('AZURE_OPENAI'), AzureAiSettings.kindAzureOpenAi);
      expect(AzureAiSettings.normalizeKind('foundry'), AzureAiSettings.kindFoundryModels);
      expect(AzureAiSettings.normalizeKind('随便写'), AzureAiSettings.kindAuto);
    });
  });

  group('内置模板', () {
    test('给出需求里的两个项目名，且默认未配置', () {
      final templates = AzureAiSettings.defaultTemplates();
      expect(templates.map((e) => e.name), containsAll(<String>['AzureOpenAI', 'modleapikey']));
      expect(templates.every((e) => !e.isConfigured), isTrue);
    });

    test('模板不预填 api-version，好让终结点里自带的版本能生效', () {
      expect(AzureAiSettings.defaultTemplates().every((e) => e.apiVersion.isEmpty), isTrue);
    });
  });
}

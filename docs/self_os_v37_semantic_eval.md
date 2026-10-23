# Self OS V3.7 真实模型语义验收

原文第 12.3–12.5 节的 17 个用例族保存在 [corpus.json](../test/self_os/semantic/corpus.json)：56 个自然语言场景，每个有原始、等义改写、交换选项顺序三个变体，共 168 个请求。多阶后果覆盖工作/消费/健康/学习，条件分支覆盖关系/职业/金融，未来选项覆盖职业/学习/居住/财务。准备时点含 6 小时、1 周、3 周。

本集只含合成的验收场景，不是用户真实经历。稳定模式族包含条件不足和反例，检查模型会不会把自述直接升级为已验证性格；允许更新稳定模式的多样本门槛另由现有 `self_os_v37_rules_test.dart` 等验证，真实长期效果仍需实际经历。

## 当前状态

2026-10-23：已验证题目覆盖、生产请求导出、结果重放、来源校验、失败与未评审分流。**尚未运行真实模型**，也没有把这些检查计为 A40/A47 通过。环境未配置模型凭据；接入选择待用户确认。没有创建密钥，没有改变应用现有供应商配置。

## 执行方式

先导出应用 `SelfOsAiService.analyseV37` 实际生成的请求。请求中不包含用例族名称、期望能力或评分规则；这些内容在外层元数据里供审查使用。

```sh
SELF_OS_EVAL_EXPORT=/tmp/self-os-requests.json \
  flutter test --no-pub test/self_os/self_os_semantic_test.dart --reporter expanded
```

导出不会调用供应商。使用已获授权的实际供应商执行每条 `request`，保存原始响应及下面的来源信息。不可把预写答案、修改过的模型答案或结构化 fixture 标记为供应商响应。评审人员逐条检查原始输出，在 `humanReview` 中记录理由与原文摘录；模型自评不能代替此步骤。错误结果保留，不得只挑通过样本。

实际留档格式如下，示例的空白字段必须来自真实执行或评审，不能补造：

```json
{
  "schemaVersion": 1,
  "source": "provider",
  "datasetSha256": "导出文件中的值",
  "provider": "",
  "model": "",
  "modelVersion": "供应商实际返回的模型版本或可追溯版本标识",
  "generatedAt": "ISO-8601",
  "responses": [{
    "id": "discomfort-1-original",
    "requestSha256": "该请求的实际哈希",
    "responseId": "实际请求或响应 ID",
    "capturedAt": "ISO-8601",
    "raw": "未经编辑的 JSON 响应文本",
    "humanReview": {
      "reviewer": "",
      "reviewedAt": "ISO-8601",
      "checks": {
        "semanticDiagnosis": {"pass": false, "reason": "", "quote": ""},
        "evidenceDiscipline": {"pass": false, "reason": "", "quote": ""},
        "decisionRelevance": {"pass": false, "reason": "", "quote": ""},
        "stopBoundary": {"pass": false, "reason": "", "quote": ""},
        "familyBehavior": {"pass": false, "reason": "", "quote": ""}
      }
    }
  }],
  "comparisons": [{
    "scenarioId": "discomfort-1",
    "reviewer": "",
    "reviewedAt": "ISO-8601",
    "checks": {
      "semanticInvariance": {"pass": false, "reason": "三种变体的缺口诊断、证据边界与展开深度是否一致", "quote": "引用各变体的实际输出"}
    }
  }]
}
```

一个留档对应一个供应商/模型版本；多个模型分别生成报告。重放命令：

```sh
SELF_OS_EVAL_RESPONSES=/tmp/self-os-responses.json \
SELF_OS_EVAL_REPORT=/tmp/self-os-report.json \
  flutter test --no-pub test/self_os/self_os_semantic_test.dart --reporter expanded
```

报告包含未运行、来源无效、输出无效、结构失败、待人工语义评审、已评审通过的逐条状态。缺样本、重复 ID、错误提示哈希、缺模型信息、缺实际响应 ID、缺人工理由/引文，以及不通过的跨变体比较均不能形成 `acceptancePassed: true`。校验不是来源的密码学证明，仍需审查原始供应商记录。

结构检查只验证条件边、二/三阶连接、回路与打断条件、阈值/可逆窗口、未来路径、对称展开、动机差异、最小准备和停止依据等可执行约束。一个图长得正确，不表示它的因果解释正确。语义评审必须对照具体输入、原文各族 rubric 和未知边界。没有依据的数字、确定性预言、人格贴标签、单向劝说或用实验许可代替人生承诺均应判失败。

默认 `flutter test test/self_os` 只检查测试机制并明确跳过真实模型验收入口。GitHub APK 工作流同样不会自动发起付费模型调用；这不影响本模块静态分析、业务测试和 APK 编译。

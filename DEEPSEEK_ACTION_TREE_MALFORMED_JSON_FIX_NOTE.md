本次修复针对 DeepSeek 行动树生成返回“JSON 不完整/格式损坏”导致的失败。

已修复：
1. 概念行动树相关解析改为宽松 JSON 解析，不再只依赖严格 jsonDecode。
2. 增加对 markdown 代码块、中文引号、尾逗号的归一化处理。
3. 增加对缺失引号、缺失 ] / }、括号闭合顺序错误的自动修复。
4. `_extractFirstJsonObject` 不再强依赖最后一个 `}`，遇到截断 JSON 也会先交给修复器处理。
5. 直连与代理两条链路统一使用宽松解析。

预期结果：
- DeepSeek 返回轻微损坏或截断的 JSON 时，不再直接报 `FormatException: Unexpected end of input`。
- 若响应里仍包含可恢复的 JSON 主体，行动树可继续生成，而不是立刻失败。

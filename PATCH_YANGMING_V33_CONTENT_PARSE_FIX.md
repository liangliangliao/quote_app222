# Yangming 内容未显示修复说明（V33）

## 根因
不是 27 段内容没有写进 assets，而是 `yangming_builtin_contents.dart` 里的分段解析器用了 Dart `RegExp` 不支持的写法：

- `(?ms)` 内联标志
- `\z` 结尾锚点

这会导致内置文本解析失败，被上层 `try/catch` 吞掉后返回空内容，页面就只显示“原文槽位 / 详细解释槽位”占位文案。

## 修复
- 改成 Dart/Flutter 可用的分段方式：
  - 使用 `RegExp(r'^\d+）《', multiLine: true)` 找每段起点
  - 按起点切片生成 27 段 chunk
- 保留原有容错
- 增加 `debugPrint`，以后若资源或解析失败能定位原因

## 结果
- 27 段内置内容会真正进入 `originalText` / `detailedExplanation`
- 课程详情页应显示正文与解释，不再只显示占位槽位

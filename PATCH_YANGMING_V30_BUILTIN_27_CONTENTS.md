# Yangming v30

- 已将用户提供的 27 段《传习录》原文与详细解释内置到知行书院模块。
- 采用两个内置资产文件：
  - assets/yangming_module/zhixing15_content.txt
  - assets/yangming_module/lizhi12_content.txt
- 模块启动时会自动解析并填入各 lesson 的：
  - originalText
  - detailedExplanation
- 删除了 app 内多余的“深度分析”槽位与编辑入口。
- JSON 导入结构同步简化为：lessonId / originalText / detailedExplanation。
- 若用户手动覆盖内容，仍以用户覆盖内容为准。

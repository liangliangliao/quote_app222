# Semantic Embedding v11 修复说明

本版修复快速相似度模式中“马/动物”被错误显示为低语义相似的问题。

## 关键变化

1. Embedding-only 仍然不调用 LLM。
2. 原生向量 cosine 仍然完整显示，不再隐藏。
3. 新增“归一化语义分数”：只对不同 embedding 模型的 cosine 分数尺度做单调归一化，不使用同义词表、上下位词典、关键词匹配或本地规则。
4. 默认阈值改为归一化语义分数尺度：低相似 0.45，高相似 0.70，严格参考 0.85。
5. 页面同时显示：归一化语义分数、原生余弦、向量维度、LLM=false、本地规则=false、Fallback=false。
6. Eden AI 预设排序调整：优先显示 Cohere 多语言（中文推荐）、Gemini Embedding，再显示 OpenAI Embedding 3 Large（通用）。

## 为什么要归一化

不同 embedding 模型的 cosine 绝对范围不一致。OpenAI text-embedding-3-large 在中文单词/短语上下位关系上，0.40~0.55 可能已经是较强相关。直接用 0.85 作为高相似阈值会误判。

归一化函数是单调的，不改变 pair 之间排序；它只是把不同模型的 cosine 尺度映射到更适合页面展示和阈值判断的 0~1 分数。

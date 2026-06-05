# Semantic Consistency V20: Commonality + Difference Refinement

本次补丁针对“非高度相关但也不是绝对无关”的情况进行完善。

## 核心问题
例如：

- 文本A：我今天去医院了
- 文本B：我今天在床上睡了一天

旧逻辑可能输出“无关 0%”。这过于绝对，因为二者虽然不是同义、不是高度相关，也没有明确因果关系，但仍可能共享：

- 同一时间线索：今天
- 同一主体视角：我
- 个人生活事件
- 健康 / 身体状态 / 休息语境

## 本次升级

1. 新增关系类型：
   - `weak_context_related`：弱语境相关
   - `shared_context_only`：仅共享背景
   - `ambiguous_related`：可能相关但语境不足

2. LLM 精判 Prompt 强制输出：
   - `commonAspects`：可能共同性
   - `differentAspects`：关键差异
   - `unsupportedInferences`：不能推出的关系
   - `completelyUnrelated`：是否完全无关

3. 新增本地共同性补充校正：
   - 如果模型把结果判为 `unrelated` 或分数为 0，但本地规则发现弱共同语境，则自动降级为 `weak_context_related`，而不是绝对无关。
   - 保留 `sameMeaning=false`、`highlyRelated=false`，避免把弱共同性误当作高度相关。

4. 结果页新增显示：
   - 是否完全无关
   - 共同性校正
   - 可能共同性
   - 关键差异
   - 不能推出

## 预期输出

对于：

- A：我今天去医院了
- B：我今天在床上睡了一天

应输出：

- 关系类型：弱语境相关
- 是否同义等价：否
- 是否高度相关：否
- 是否完全无关：否
- 语义相关度：约 30%～45%
- 同义/等价度：低
- 共同性：今天、第一人称、个人生活事件、健康/休息弱语境
- 差异：就医行为 vs 卧床睡眠/休息状态
- 不能推出：不能推出同一事件、因果关系、同义关系

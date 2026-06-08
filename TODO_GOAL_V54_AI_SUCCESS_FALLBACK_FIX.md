# TODO Goal V54 - AI 成功结果误判为本地兜底修复

本次修复用户反馈：AI 实际已经返回数据，但目标详情页仍然显示“当前目标内容是本地兜底”，并且“这个目标今天怎样实践”区域仍使用兜底文本。

## 修复内容

1. **修复 AI 成功返回被误判为兜底**
   - 旧逻辑只要 `solutionPlans` 为空或解析失败，就把整个目标标记为本地兜底。
   - 新逻辑改为：只要 AI 返回了有意义的目标字段（如目标标题、深层意义、过程价值、今日最小行动等），就认为 AI 分析成功。
   - 如果 AI 只缺少方案树，则仅本地补充方案树，不再把整个目标误标为兜底。

2. **修复兜底判断过度依赖文本内容**
   - 旧逻辑会因为 AI 文本中包含“方向线索”等通用表达而误判为兜底。
   - 新逻辑以 `ai_provider / ai_model_label / ai_used_fallback` 为主，不再用普通文本短语判断真实 AI 结果。

3. **修复旧数据迁移误标记**
   - 对已保存的 DeepSeek / OpenAI / OpenRouter / Eden AI 等真实 AI 来源目标，自动把 `ai_used_fallback` 修正为 0。
   - 保留 `local / fallback / 本地策略` 的兜底标记。

4. **增强 AI JSON 解析兼容性**
   - 支持 `goal_title / deep_meaning / today_minimum_action` 等 snake_case 字段。
   - 支持 `目标标题 / 深层意义 / 过程价值 / 今日最小行动` 等中文字段。
   - 支持 `solution_plans / problemSolvingPlans / 解决方案 / 问题解决方案` 等方案字段。
   - 支持方案节点中的 `problemTree / steps / 节点 / 问题树` 等结构。
   - 支持部分 AI 返回把真正 JSON 放在 `analysis / result / data / payload / content / choices.message.content` 中。

5. **保留本地补充方案树能力**
   - 如果 AI 返回了目标分析但没有完整问题树，系统会补充本地问题树作为临时结构。
   - 但目标本身不再显示为“AI未成功”。

## 需要用户注意

安装后，对已有误标的真实 AI 目标，进入 To Do 目标实践系统时会尝试自动修复标记；如果内容本身仍是旧兜底文本，可点击右上角“AI重新分析”重新生成。

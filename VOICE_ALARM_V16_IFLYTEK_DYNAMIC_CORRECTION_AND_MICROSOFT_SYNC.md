# VOICE_ALARM_V16_IFLYTEK_DYNAMIC_CORRECTION_AND_MICROSOFT_SYNC

## 修复目标

用户反馈：v15 的“语音修正”感知不明显，没看到类似讯飞输入法那样的动态纠错效果；同时确认微软识别链路是否同步升级。

## 关键结论

### 1. 之前的“修正”确实不够强

v15 虽然打开了讯飞 `dwa=wpgs`，但真正的动态修正协议没有完全按讯飞返回结构处理：

- `pgs=rpl` + `rg=[start,end]` 时，旧实现把替换文本放在当前 `sn` 上；
- 如果后续已有更大的片段序号，替换文本可能被排到后面，导致文本顺序异常，表现为“没修正成功”；
- `cw` 是候选列表，旧实现会遍历并拼接所有候选词，容易产生重复/混乱，削弱修正效果。

### 2. 本轮已改为真正按 `pgs/apd/rpl` 协议处理

- `pgs=apd`：按 `sn` 追加/更新片段；
- `pgs=rpl`：删除 `rg` 指定的旧片段区间，并把新文本写回 `replaceStart` 位置；
- 每次讯飞返回动态修正后，UI 会显示“讯飞已动态修正”；
- `cw` 只取最佳候选 `cw[0]`，不再拼接全部候选。

### 3. 微软已同步自动提交链路，但不具备同等动态修正能力

当前源码的 Microsoft 链路使用的是 REST 短语音识别：

- 已同步走同一套“实时听写草稿 / 文本稳定 / 自动提交”后处理；
- 但它不是 WebSocket 连续 partial/rpl 动态修正协议；
- 因此它能提供最终段落识别和自动标点，但不能像讯飞 `dwa=wpgs` 那样实时替换前文。

后续如需让微软也做到输入法级动态修正，需要改为 Azure Speech SDK 或实时流式 WebSocket 方案，并解析 partial/stable/final 事件。

## 修改文件

- `android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt`

## 静态检查

- Kotlin 文件括号结构正常；
- 未再发现普通字符串跨行语法错误；
- AndroidManifest.xml 解析通过；
- zip 根目录无多级目录嵌套。

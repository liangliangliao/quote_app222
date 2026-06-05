# 冥想模块 Resemble 声音标记与重新生成语音策略修复

## 已实现

1. Resemble AI 声音下拉列表增加冥想推荐标记：
   - Mei：推荐·中文柔和冥想
   - Hao：推荐·中文沉稳冥想
   - Grace：推荐·温柔冥想
   - Linda：推荐·成熟稳定
   - Elaine：推荐·平静引导
   - Evelyn：推荐·睡前柔和
   - Lucy：推荐·轻柔入门
   - Lisa：推荐·日常正念
   - Laura：推荐·睡前放松
   - Sofia：推荐·自我接纳
   - Maureen (Caring)：推荐·关怀修复
   - Willow / Willow II (Whispering)：推荐·睡前低语
   - Eric / Jason / Andrew 等：男性稳定类推荐
   - Scared / Angry / Sad / Happy / Announcer 等标记为不建议默认冥想。

2. 修改参数并保存后，不再触发重新生成逐句语音。
   - 只保存当前冥想的 TTS 参数。
   - 当前冥想已有完整缓存时，继续使用原缓存。
   - 下次进入播放页仍优先播放原已缓存语音。

3. 只有点击“重新生成并覆盖”时，才按当前参数重新生成。
   - 点击后立即删除当前冥想旧逐句语音缓存。
   - 立刻开始生成所有片段语音。
   - 重新生成完成后自动加载新缓存，可直接播放新语音。
   - 完成时显示 SnackBar 提示。

4. “保存参数并补齐缺失语音”只补齐缺失片段。
   - 如果该冥想已有完整缓存，不会因为参数变化而重新调用 ElevenLabs / Resemble。
   - 如果缺少部分片段，只生成缺失片段。

## 修改文件

- lib/meditation_module/meditation_audio_service.dart
- lib/meditation_module/meditation_dao.dart
- lib/meditation_module/meditation_player_page.dart

# PATCH_ELEVENLABS_VOICE_TEACHER_V1

本次在现有 Flutter App 中落地了 ElevenLabs 声音克隆与虚拟老师模块的第一版完整闭环。

## 新增功能

1. 设置页新增“语音与虚拟老师配置”入口。
2. 首页左侧菜单新增“虚拟老师”入口。
3. 新增 ElevenLabs API Key 配置、测试连接、默认 TTS 模型、输出格式配置。
4. 新增声音档案 `voice_profile`：保存 ElevenLabs `voice_id`，支持默认声音设置、手动添加已有 `voice_id`、删除本地档案。
5. 新增 ElevenLabs Instant Voice Clone 页面：选择本地音频样本并提交 `/v1/voices/add`，成功后保存 `voice_id`。
6. 新增文字转语音测试：使用当前选中克隆声音调用 `/v1/text-to-speech/{voice_id}` 生成 mp3。
7. 新增 `tts_audio_file` 表：自动保存生成语音的元数据、文件路径、来源模块、模型、voice_id、下载状态。
8. 新增 App 内部语音文件库：支持播放、删除 App 内部文件与数据库记录、下载到系统 Download/VirtualTeacher 目录。
9. 新增虚拟老师对话页：复用现有 UnifiedAiService 生成回答，再使用 ElevenLabs 克隆声音朗读并自动保存语音文件。
10. 新增 Android 原生 MethodChannel 方法 `saveAudioToDownloads`：通过 MediaStore 保存 mp3 到系统下载目录。

## 新增文件

- `lib/voice_lab/voice_lab_models.dart`
- `lib/voice_lab/voice_lab_dao.dart`
- `lib/voice_lab/eleven_labs_service.dart`
- `lib/voice_lab/voice_lab_home_page.dart`
- `lib/voice_lab/voice_clone_page.dart`
- `lib/voice_lab/tts_audio_library_page.dart`
- `lib/voice_lab/virtual_teacher_page.dart`

## 修改文件

- `lib/data/db.dart`
- `lib/pages/settings_page.dart`
- `lib/main.dart`
- `android/app/src/main/kotlin/com/example/quote_app/Channels.kt`

## 注意事项

- API Key 存储在本地 `notify_config` 键值表中；后续如果 App 对外分发，建议改成后端代理，避免客户端泄露 Key。
- 删除声音档案只删除 App 本地 `voice_profile` 记录，不删除 ElevenLabs 云端声音。
- 语音文件删除只删除 App 内部保存的 mp3 和数据库记录；已经导出到系统 Download 目录的副本不会自动删除。
- 本环境没有 Flutter/Dart SDK，未能执行 `flutter analyze` 或 `flutter build apk`，已尽量按现有项目风格进行静态落地。

# PATCH_BUILD_FIX_V4_1

修复 GitHub Actions 编译报错：

```text
lib/voice_lab/voice_lab_home_page.dart:286:42
Error: Property 'provider' cannot be accessed on 'VoiceProfile?' because it is potentially null.
```

原因：`selected` 是 `VoiceProfile?`，并且在 `setState` 闭包内部后续会被重新赋值，Dart null-safety 无法对该变量完成稳定提升。

修复：在访问 `provider` 前引入不可变局部变量 `currentSelected`，让 Dart 能确认其非空后再访问：

```dart
final currentSelected = selected;
if (currentSelected != null && currentSelected.provider != _ttsProvider) {
  final sameProvider = voices.where((v) => v.provider == _ttsProvider).toList();
  selected = sameProvider.isEmpty ? currentSelected : sameProvider.first;
}
_selectedVoice = selected;
```

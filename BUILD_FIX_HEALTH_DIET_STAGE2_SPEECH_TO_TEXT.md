# 健康饮食第二阶段构建修复：speech_to_text 与 audioplayers 依赖冲突

## 问题

GitHub Actions 在 `flutter pub get` 阶段失败：

- 项目依赖 `audioplayers: ^5.2.1`
- 第二阶段新增 `speech_to_text: ^6.6.2`
- `speech_to_text >=6.6.1 <7.0.0-beta.2` 依赖 `js ^0.7.1`
- `audioplayers_web >=2.1.0 <5.0.0` 依赖 `js ^0.6.4`
- 两者无法同时解析，导致 version solving failed

## 修复

将 `pubspec.yaml` 中的：

```yaml
speech_to_text: ^6.6.2
```

升级为：

```yaml
speech_to_text: ^7.3.0
```

## 修复原因

错误日志本身给出的建议之一就是升级 `speech_to_text` 到 `^7.3.0`。这样可以避免 6.x 分支与 `audioplayers_web` 在 `js` 依赖上的冲突，同时不主动升级 `audioplayers`，避免影响已有音乐播放相关功能。

## 涉及文件

- `pubspec.yaml`
- `HEALTH_DIET_STAGE2_IMPLEMENTATION.md`

## 本地操作

重新执行：

```bash
flutter pub get
```

如果 CI 有缓存，建议清理 Flutter/Dart pub 缓存或重新触发构建。

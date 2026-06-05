# 发现之旅 / 看电影：第三方外部观看入口补丁

本次修改已落地到 `发现之旅 -> 看电影` 使用的通用电影卡片组件中。

## 修改内容

1. 新增 `lib/services/movie_external_watch_service.dart`
   - 支持小鸭看看、FoFo影院、努努影院三个外部入口。
   - 根据电影标题、原始标题、上映年份拼接 `site:域名 电影名 年份` 搜索词。
   - 使用 `url_launcher` 强制打开外部浏览器。
   - 不解析、不保存、不内嵌任何第三方播放源。

2. 修改 `lib/widgets/movie_card_item.dart`
   - 点击任意电影卡片会弹出“外部网站搜索观看入口”底部面板。
   - 右侧操作区新增“观看”按钮。
   - 底部面板提供：小鸭看看、FoFo影院、努努影院。
   - 明确提示：本 App 不解析、不存储、不内嵌播放第三方影片资源。

3. 修改 `pubspec.yaml`
   - 新增依赖：`url_launcher: ^6.2.6`。

4. 修改 `android/app/src/main/AndroidManifest.xml`
   - 新增 `<queries>`，允许 Android 11+ 正常解析 http/https 外部浏览器处理器。

5. 顺手修复 `lib/pages/movie_ranking_page.dart`
   - 删除上传源码中 `TabBar` 重复的 `labelColor` 命名参数，避免 Dart 编译报重复参数。

## 使用方式

进入：`发现之旅 -> 看电影`。

- 点击电影卡片任意空白区域，弹出第三方入口。
- 点击右侧“观看”按钮，也会弹出第三方入口。
- 选择站点后，App 会跳转到外部浏览器的 Google `site:` 搜索结果页。

## 注意

由于当前环境没有 Flutter SDK，无法在这里执行 `flutter pub get` / `flutter analyze` / APK 构建。请在本地或 GitHub Actions 中执行：

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

# MUSIC_YOUTUBE_INTEGRATION_PATCH

本补丁将“全球音乐搜索 + YouTube 官方嵌入播放”集成到现有 App：

## 新增功能

1. 发现之旅新增入口：`听音乐`
2. 新增页面：`lib/pages/global_music_page.dart`
   - 读取设置页保存的 YouTube Data API Key
   - 使用 YouTube Data API v3 搜索音乐视频
   - 使用 `webview_flutter` 嵌入 YouTube 官方播放器播放
   - 支持外部打开 YouTube
3. 新增服务：`lib/services/youtube_music_service.dart`
   - 封装 API Key 读取
   - 封装 YouTube 搜索请求
   - 统一解析搜索结果模型
4. 设置页新增配置项：
   - YouTube Data API Key（全球音乐搜索）
   - 酷狗开放组件 AppId（预留）
   - 酷狗开放组件 AppKey（预留）
5. `pubspec.yaml` 新增依赖：
   - `webview_flutter: ^4.8.0`

## 使用步骤

1. 运行 `flutter pub get`
2. 打开 App 设置页
3. 点击左上角编辑按钮
4. 在 `YouTube Data API Key（全球音乐搜索）` 填入 Google Cloud API Key
5. 保存
6. 进入 `发现之旅 > 听音乐`
7. 搜索并播放

## 合规说明

当前版本只使用 YouTube 官方 Data API 搜索和官方嵌入播放器播放，不解析、下载、缓存或分离音频。
网易云音乐已按需求移除，不做接入。
酷狗字段仅做官方 SDK / 商务授权后的预留，不调用非官方接口。

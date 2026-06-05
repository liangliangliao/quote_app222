# OneNote 同步功能集成说明

本次基于用户提供的 `quote_app_src_movie_role_lab_batch_txt_import_v11.zip` 源码做最小侵入集成。

## 已集成功能

1. 新增首页左侧菜单入口：`外部数据同步`。
2. 新增 Microsoft OneNote 登录：使用 Authorization Code + PKCE，不需要 client secret。
3. 固化用户提供的 Microsoft Client ID：`dccf2bf4-0571-4abe-a303-bf07fb967147`。
4. 生成并配置当前源码 release keystore 对应的 Base64 SHA1：`IrBkHKitYXzfCoV0Uuv6d8eBJ5Q=`。
5. 新增 OneNote 同步页面：
   - 输入笔记本名称；
   - 输入分区名称；
   - 不默认读取全部笔记本；
   - 只有输入笔记本或分区名称后才同步。
6. 同步 OneNote 原始结构：
   - 笔记本 notebook；
   - 分区 section；
   - 页面 page；
   - 附件 attachment。
7. App 内结构化分页显示：
   - 外部数据同步首页显示已同步笔记本；
   - 点击笔记本进入分区页；
   - 点击分区进入页面列表；
   - 页面列表按 30 条分页加载；
   - 点击页面进入详情。
8. 页面正文处理：
   - 保存原始 HTML；
   - 解析纯文本；
   - 清理 object/embed/iframe、U+FFFC/U+FFFD、`[object Object]`、孤立 `obj` 等乱码占位；
   - 用 UTF-8 解码 Graph 返回内容，避免中文乱码。
9. 附件处理：
   - 从 OneNote HTML 中解析 `/onenote/resources/{id}/$value`；
   - 下载附件到 App 文档目录 `external_data/onenote/{pageId}`；
   - 记录附件本地路径、MIME、大小。
10. 新增 API 日志表：`external_api_logs`，页面中可展开查看最近 OneNote API 日志。

## 需要在 Microsoft Entra 中配置

包名：

```text
com.example.quote_app
```

签名哈希 Base64 SHA1：

```text
IrBkHKitYXzfCoV0Uuv6d8eBJ5Q=
```

Redirect URI：

```text
msauth://com.example.quote_app/IrBkHKitYXzfCoV0Uuv6d8eBJ5Q=
```

已在 AndroidManifest.xml 中加入 `msauth` 回调 intent-filter。

## 主要新增/修改文件

- `lib/external_data/onenote_config.dart`
- `lib/external_data/onenote_models.dart`
- `lib/external_data/onenote_dao.dart`
- `lib/external_data/onenote_service.dart`
- `lib/external_data/onenote_pages.dart`
- `lib/main.dart`
- `android/app/src/main/AndroidManifest.xml`

## 注意

当前运行环境没有 Flutter SDK，无法在容器内执行 `flutter analyze` 或 `flutter build apk`。已尽量按现有项目依赖与编码风格实现，真实编译请在你的本地或 GitHub Actions 中验证。

# OneNote 登录重定向 URI 修复说明 V13

本次修复针对 Microsoft 登录页报错：

> invalid_request: The provided value for the input parameter 'redirect_uri' is not valid. The expected value is a URI which matches a redirect URI registered for this client application.

## 修复内容

1. 将 Microsoft OneNote 的 redirect URI 从源码固定常量改为 App 页面可配置。
2. 在“外部数据同步”页面新增“Microsoft 重定向 URI 配置”卡片：
   - 可查看当前 redirect URI
   - 可复制 URI
   - 可手动修改保存 URI
   - 可恢复默认 URI
3. 保存或恢复 redirect URI 后，会自动清除旧 Microsoft token，避免旧 token 与新 redirect URI 混用导致刷新失败。
4. OAuth 授权、code 换 token、refresh token 都统一读取当前保存的 redirect URI。
5. AndroidManifest 中的 msauth 回调 intent-filter 改为只限制 scheme：`msauth`，以便兼容 App 页面中配置的 msauth://... 重定向地址。

## 当前默认配置

Package name:

```text
com.example.quote_app
```

Base64 SHA1:

```text
IrBkHKitYXzfCoV0Uuv6d8eBJ5Q=
```

默认 Redirect URI:

```text
msauth://com.example.quote_app/IrBkHKitYXzfCoV0Uuv6d8eBJ5Q=
```

如 Microsoft Entra 页面显示或要求 URL 编码形式，可以尝试登记：

```text
msauth://com.example.quote_app/IrBkHKitYXzfCoV0Uuv6d8eBJ5Q%3D
```

App 内必须填写与 Entra 中最终登记的 redirect URI 完全一致的值。

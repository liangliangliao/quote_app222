# BUILD_FIX_TOUCH_MYSTIFY_V42_SIZE_PARAM

修复来源：用户上传的 GitHub Actions 编译日志 `logs_70514000474.zip`。

## 错误原因

Flutter release 构建失败于：

- `lib/pages/touch_mystify_wallpaper_page.dart:2025:40`
- `lib/pages/touch_mystify_wallpaper_page.dart:2040:40`
- `lib/pages/touch_mystify_wallpaper_page.dart:2052:40`

报错内容：

```text
Error: The getter 'size' isn't defined for the type '_MystifyPreviewPainter'.
```

V41 中 `_drawArtMotifAccents(...)` 内部调用 `_drawVideoSubjectPreview(canvas, size, ...)`，但 `_drawArtMotifAccents(...)` 本身没有接收 `Size size` 参数，因此 Dart 将 `size` 解析为 `_MystifyPreviewPainter` 的 getter，导致编译失败。

## 修复内容

- 将 `paint(Canvas canvas, Size size)` 中已有的 `size` 传入 `_drawArtMotifAccents(...)`。
- 给 `_drawArtMotifAccents(...)` 增加 `Size size` 参数。
- 保持 V41 的主体形体逻辑不变。
- 保持释放阶段和余韵阶段不变。

## 修改文件

- `lib/pages/touch_mystify_wallpaper_page.dart`


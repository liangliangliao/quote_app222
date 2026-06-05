# V19 壁纸应用确认修复

## 修复点

1. 不再把“打开系统预览页”误提示成已经应用。
2. 新增 `isLiveWallpaperApplied` 原生检测：读取 `WallpaperManager.wallpaperInfo`，确认当前动态壁纸是否就是 `IntimacyMystifyWallpaperService`。
3. 从系统预览页返回 App 后自动检测：
   - 已应用：提示“动态壁纸已成功应用”。
   - 未应用：提示“必须在系统预览页点击 设置壁纸/应用”。
4. 按钮文案改成“打开系统预览页，手动点击应用”。

## 原因

Android 官方 `ACTION_CHANGE_LIVE_WALLPAPER` 只是打开指定动态壁纸预览，让用户确认切换；普通 App 不能可靠静默替换动态壁纸。

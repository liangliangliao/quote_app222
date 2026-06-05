# PATCH_TOUCH_MYSTIFY_V21_WALLPAPER_HELPER_DIAGNOSTIC

本次只处理动态壁纸应用入口不可靠的问题。

## 修复点

1. `WallpaperApplyActivity` 不再作为瞬间透明跳板使用。
   - 现在它是一个可见的原生“动态壁纸应用助手”。
   - 如果系统 Intent 没有真正跳转，用户不会只看到 Toast，而会停留在助手页。

2. 多入口兜底。
   - 本动态壁纸预览页：`ACTION_CHANGE_LIVE_WALLPAPER`
   - 兼容字符串入口：`android.service.wallpaper.CHANGE_LIVE_WALLPAPER`
   - 动态壁纸列表：`ACTION_LIVE_WALLPAPER_CHOOSER`
   - 系统壁纸设置：`android.settings.WALLPAPER_SETTINGS`
   - 通用壁纸选择器：`ACTION_SET_WALLPAPER`
   - 本应用系统设置页

3. 新增诊断能力。
   - `getLiveWallpaperDiagnostic`
   - 查询动态壁纸服务是否被系统识别。
   - 查询当前是否已真正应用为动态壁纸。
   - 查询各入口可解析目标数量。

4. Flutter 设置页新增“诊断动态壁纸入口/注册状态”。

5. Manifest 增加 `<queries>`，提升 Android 11+ 上查询动态壁纸/壁纸入口的可见性。

## 重要说明

Android 第三方应用通常不能静默替换动态壁纸。正确流程仍然是：

App 打开系统页 → 用户在系统页选择/预览“潮汐之间” → 用户点击“设置壁纸/应用”。

如果系统不响应指定预览入口，请在助手页依次尝试“动态壁纸列表”和“系统壁纸设置”。

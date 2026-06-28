# PATCH_MI_GROWTH_V1_2_COLOR_BUILD_FIX

## 问题
Android/Flutter release 构建失败，报错位置集中在：

- `lib/mi_growth/mi_growth_home_page.dart`
- `Colors.black70`
- `Colors.black67`
- `Colors.black60`

Flutter Material 的 `Colors` 类没有 `black70`、`black67`、`black60` 这些成员；只有 `black87`、`black54`、`black45`、`black38`、`black26`、`black12` 等预设透明度。

## 修复
将 MI 成长向导页面中不存在的颜色成员替换为等价透明度的常量 Color：

- `Colors.black70` -> `Color(0xB3000000)`
- `Colors.black67` -> `Color(0xAB000000)`
- `Colors.black60` -> `Color(0x99000000)`

这些 `Color(...)` 常量可用于 `const TextStyle`，不会破坏现有 UI。

## 影响范围
仅修复 MI 成长向导模块 UI 文案颜色，不改变业务逻辑、AI Prompt 配置中心、DAO、AI fallback 或入口导航。

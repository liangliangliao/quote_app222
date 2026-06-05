# PATCH_TOUCH_MYSTIFY_V158_REFERENCE_VIDEO_GLYPH_PHRASE

本次继续主动对照标准参考视频与 V157 源码，修复几个仍然存在的重大差距。

## 一、对比后发现的主要差距

### 1. V157 在同一可见主体内部变化过快
V157 使用 `u * 6.20f + local * 0.72f` 让同一条可见光迹在一个窗口里快速穿越 6 种风格。
这在源码层面看似“连续变化”，但视觉上容易混成一团：一段主体里同时出现线条、扇面、场线、丝带、花瓣、环弧的混合痕迹。

而参考视频并不是这样。参考视频更像每一段有一个清楚的光形家族，例如：
- 细长书写丝带；
- 轻场线叶片；
- 宽薄翼面；
- 钩形花瓣；
- 半闭合环形网纱；
- 极简长弧。

它们之间会切换，但单个短句内部通常保持清楚的主体气质。

### 2. V157 仍然容易出现“混合线团”
V157 虽然比 V155/V156 更会变形，但同一主体内多风格混合太强，容易损失参考视频里的大留白、清楚边界和高级克制感。

### 3. V157 的回声仍然可能像第二主体
V157 只保留一层旧痕迹已经比之前好，但为了更接近参考视频，V158 将回声固定为同中心、同 motif、同构图的极淡时间切片，避免被理解成另一个主体。

## 二、V158 的改造方向

V158 的核心变化：

```text
同一段：一个清楚光形家族 + 内部慢速呼吸/展开/退隐
而不是：同一段快速穿越多个风格
```

新增主入口：

```java
drawReferenceVideoTimePainterV158(...)
```

当前主路径已从 V157 切换到 V158。

## 三、V158 新增机制

### 1. 稳定 motif 短句
新增：

```java
v158MotifIndex(...)
```

每段选择一个清楚的主体家族，而不是同一段内部快速切换全部形态。

### 2. 参考视频式光形主体
新增：

```java
drawV158ReferenceGlyph(...)
buildV158Curve(...)
v158Point(...)
```

支持几类参考视频中更常见的清楚光形：

- 细长书写丝带；
- 轻场线叶片；
- 宽薄翼面；
- 钩形/花瓣回扫；
- 环形网纱/半闭合空间弧；
- 极简长弧。

### 3. 少量同源时间回声
V158 保留 1~2 层极淡回声，但它们必须：

- 同一中心；
- 同一 motif；
- 同一构图；
- 更低透明度。

避免再次变成多个主体或复制分身。

### 4. 更接近参考视频的视觉原则

- 黑底大留白；
- 主体清楚；
- 白色芯线很细；
- 彩色光带更克制；
- 纹理线只作为主体内部纹理，不作为独立主体；
- 先画内容通过 tail 追赶逐步退隐。

## 四、参考的开源/公开屏保技术思路

本次继续结合：

- Windows Mystify 的弯曲光线、颜色循环、短暂同形残影与 CameraFOV / LineWidth / NumLines / Blur 等参数思路；
- XScreenSaver 的“独立 graphics hack 每帧推进状态机”的屏保框架思想；
- rss-glx / Really Slick Screensavers 中 Flux、Euphoria、Fieldlines、Solarwinds 等光带、场线、粒子流动屏保的生成式视觉思想。

## 五、修改文件

```text
android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java
lib/pages/physical_enhancement_page.dart
lib/pages/discover_page.dart
```

# PATCH_TOUCH_MYSTIFY_V125_LIVING_MYSTIFY_STRING

本次继续优化“发现之旅 / 生理赋能 / 触摸”的动态壁纸主体动画。

## 一、用户反馈

当前 V124 虽然比上一版清楚，但仍然存在一个问题：

- 主体变清楚了；
- 但缺乏“即兴生命创造”的效果；
- 还不像 Windows Mystify 那种活的、不断变形的光弦。

因此 V125 的目标不是重新把残影堆多，而是在“清楚”基础上恢复生命感。

---

## 二、Windows Mystify 技术要点复盘

结合 Windows Mystify / Ribbons 的屏保表现，可抽象出几个关键机制：

1. **不是蛇头拖尾**  
   是一整条光弦在运动和变形。

2. **多个控制点独立运动**  
   形状由多个控制点共同决定，而不是单个点牵引。

3. **历史切片形成残影**  
   残影是过去多帧完整光弦的淡化，而不是一根拖尾。

4. **速度和距离感不恒定**  
   慢的时候残影更密，快的时候残影间距更明显。

5. **颜色循环和高光核心**  
   光弦主体有颜色变化，当前帧核心更明亮。

6. **必须避免过度堆叠**  
   如果历史切片太多、侧向线太多，就会变成不清楚的光雾。

---

## 三、V125 改造目标

V125 在 V124 的“清楚光弦”基础上，加入以下生命感机制：

- 即兴短句；
- FOV 式呼吸；
- 控制点转折脉冲；
- 动态侧向膜面；
- 笔压变化；
- 少量生命肋线；
- 速度感影响残影间距。

目标是在不重新变成毛球/光雾的情况下，让主体更像活的 Mystify 光弦。

---

## 四、主要修改文件

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

---

## 五、核心改动

### 1. 改造 `drawScreensaverArtistBrush(...)`

保留一条清晰主弦，但修改：

- `trails` 从 V124 的极简残影略微增加；
- `lanes` 固定为 1，避免重新堆成光雾；
- `trailGap` 由速度脉冲控制；
- 当前光弦增加动态膜面、生命肋线和笔压高光。

### 2. 重写 `buildScreensaverControlCurve(...)`

仍然保留有序控制点，避免乱折成毛球；
但加入：

- 7 个控制点；
- `mystifyImprovisationPulse(...)`；
- FOV 式呼吸；
- beatCenter 转折脉冲；
- curl / turn 局部转向；
- 中心轻微漂移；
- 时间重映射。

这样光弦不只是清楚，还会更像活体一样变形。

### 3. 新增辅助方法

新增：

- `mystifyImprovisationPulse(...)`
- `mystifyTemporalEase(...)`
- `mystifyCurvePressure(...)`
- `offsetCurveByNormalDynamic(...)`
- `drawMystifyLivingCore(...)`
- `drawMystifyBreathRibs(...)`

分别用于：

- 即兴短句强弱；
- 曲线时间重映射；
- 笔压变化；
- 动态侧向膜面；
- 当前光弦生命高光；
- 少量生命肋线。

---

## 六、同步更新页面文案

已同步更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本文案升级为 V125。

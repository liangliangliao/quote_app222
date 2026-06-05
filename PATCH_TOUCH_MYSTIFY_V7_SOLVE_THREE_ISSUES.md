# PATCH_TOUCH_MYSTIFY_V7_SOLVE_THREE_ISSUES

本补丁针对用户指出的 3 个核心问题继续修复：

## 1. Mystify 线条不应是预设曲线移动，而应是随机运动点即时生成

主要改动文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

改动点：

- 继续保留“半透明黑色覆盖旧 buffer”的残影机制。
- 每条线由多个随机控制点实时连线生成。
- 新增 `morphEvery / nextMorph`，控制点在生命周期内会持续发生小幅随机变形，减少“整条线平移”的观感。
- 双线同步不再共享固定中心区域，只共享节奏/相位，通过 `syncOffsetX / syncOffsetY` 形成同步但不粘连的关系。

## 2. 长周期 + 阶段比例

默认比例仍为：

- 分离：46%
- 吸引：22%
- 同步：22%
- 临界：6%
- 释放：2%
- 余韵：2%

周期配置仍支持：

- 真实模式：1～365 天随机完成一轮
- 固定周期：用户指定天数
- 加速演示：0.5～60 分钟演示完整一轮，方便观察效果

Flutter 设置页参数通过 MethodChannel 写入 SharedPreferences，壁纸服务实时读取。

## 3. 随机运动点必须覆盖手机可见范围任意位置

V7 新增全屏热区采样器：

- 将屏幕划分为 `6 x 10` 网格。
- 每次生成线条时优先从最近较少出现过的区域采样。
- 支持任意边缘切入、任意两点、长距离扫线。
- `activityRect` 不再决定出生区域，只作为反弹边界。
- 双线不再共享一个小活动框，避免被限制在局部。

核心字段：

```java
private static final int GRID_COLS = 6;
private static final int GRID_ROWS = 10;
private final int[] spawnHeat = new int[GRID_COLS * GRID_ROWS];
```

核心方法：

```java
sampleVisiblePoint(true)
sampleEdgePoint()
markSpawnHeat(x, y)
resetSpawnHeat()
```

## 仍需说明

当前仍是 Android Canvas/Bitmap buffer 版，已尽量向 Windows Mystify 的“即时绘制 + 残影衰减 + 全屏随机”靠近。
如果后续仍希望进一步逼近系统级 Windows 屏保质感，需要继续升级为 OpenGL ES + FBO + Shader bloom 渲染管线。

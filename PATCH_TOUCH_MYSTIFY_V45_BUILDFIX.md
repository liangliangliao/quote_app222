# Touch Mystify V45 Build Fix

修复 GitHub Actions Flutter release 构建中的 Java 编译错误：

```text
IntimacyMystifyWallpaperService.java:931: error: cannot find symbol
if (initStrokeByArtMotif(s, side, phase)) return;
                                  ^
symbol: variable phase
```

原因：V44 将 `initStrokeByArtMotif(...)` 改为需要 `Phase phase` 参数，但 `initStrokeFromAnyVisiblePosition(...)` 没有接收 `phase`，导致该函数内部引用不到 `phase`。

修复：

- `createStroke(Phase phase, ...)` 调用处改为 `initStrokeFromAnyVisiblePosition(s, side, phase)`。
- `initStrokeFromAnyVisiblePosition(...)` 签名改为 `initStrokeFromAnyVisiblePosition(StrokeEvent s, int side, Phase phase)`。

本次只修复编译错误，不改主体形体、不改释放阶段、不改余韵阶段。

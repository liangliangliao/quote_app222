# Touch Mystify V46 build fix

修复 GitHub Actions 日志中报告的 Java 编译错误。

## Error

`IntimacyMystifyWallpaperService.java:965: error: variable phase is already defined in method initStrokeFromAnyVisiblePosition(StrokeEvent,int,Phase)`

## Cause

V45 将 `Phase phase` 传入 `initStrokeFromAnyVisiblePosition(...)` 后，方法内部原本用于曲线扰动的局部变量也叫 `phase`，与参数同名，Java 不允许在同一方法作用域重复定义。

## Fix

将局部扰动变量改名为 `phaseOffset`，并同步修改 `fineArc` 的引用。

本次只修复编译错误，未改动主体形体逻辑，也未改动释放阶段与余韵阶段。

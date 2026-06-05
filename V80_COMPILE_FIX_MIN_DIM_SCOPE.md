# V80 compile fix

Build log error:
`IntimacyMystifyWallpaperService.java:2260/2261/2269/2300/2301 cannot find symbol: variable minDim`.

Cause:
`flowStringPoint()` references `minDim`, but `minDim` was only a local variable in `drawFlowStringNetSubject()`. Java local variables are not visible inside another method.

Fix:
Declare `float minDim = Math.max(1f, Math.min(width, height));` inside `flowStringPoint()` before the first use.

# PATCH_TOUCH_MYSTIFY_V98_MESH_ONLY

本次继续针对“发现之旅 / 生理赋能 / 触摸”主体动画优化，重点响应：

- 当前同一时刻会混合出现单一线条、网状、类似区块/面片的形状；
- 视觉有些杂乱；
- 暂时希望只保留“网状”这一种类型。

## 本次核心调整

### 1. 收敛为纯网状主形体
文件：
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

主体阶段不再并存多种风格，而是统一为：
- 一个较大的网状艺术主形体；
- 清晰的网面 / 网格 / 网状边界；
- 随机独立落笔，但每次只出现一种网状主视觉。

### 2. 关闭“单线感”和“区块感”来源
本次关闭或弱化了：
- 主体脊线/主线条的可见度；
- 笔尖光点；
- 停顿阶段的额外笔尖悬停；
- 额外的光晕、区块、面片式观感。

### 3. 新增纯网状渲染函数
新增：
- `drawVideoMeshGlyph(...)`

该函数会根据 motif 变化，生成几种不同布局的网状主形体，但都保持：
- 统一的网状风格；
- 更大的单次主体；
- 更少的视觉噪音；
- 更清楚的主形体轮廓。

### 4. 收窄母题池
调整 `continuousPenMotifRaw(...)`：
- 只保留更适合网面/网格表达的母题；
- 暂时不再调用明显偏区块、光幕、实体面片感较强的变体。

## 同步文案
更新：
- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V98。

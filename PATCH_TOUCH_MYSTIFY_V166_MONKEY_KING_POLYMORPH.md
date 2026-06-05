# PATCH_TOUCH_MYSTIFY_V166_MONKEY_KING_POLYMORPH

本次继续针对“发现之旅 / 生理赋能 / 触摸”动画模块进行深度改造。

## 一、问题判断

用户明确指出当前主体缺少“孙悟空七十二变”般的千变万化能力：

- 主体仍然像一个固定形态在动；
- 虽然已有分叉与顿挫，但变异次数少、幅度小；
- 缺少突然重大形态变化；
- 缺少参考视频中“永远不知道下一次会变成什么”的创造感。

V166 的目标是强化“同一主体自身连续变身”的能力，而不是重新堆多个独立主体。

## 二、核心改造

主文件：

- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`

### 1. 新增 V166 主入口

新增并启用：

- `drawReferenceVideoTimePainterV166(...)`

当前主渲染路径已经从 V165 切换到 V166。

### 2. 新增“变身节拍”

新增：

- `v166MutationPulse(...)`
- `v166PulseAt(...)`

一段创作短句中设置 5 个变身节拍，形成：

- 蓄势
- 突然变身
- 保持
- 再次突变
- 退隐

### 3. 新增 12 类控制点拓扑语法

新增：

- `v166ModeForStep(...)`
- `v166ControlPointForMode(...)`

支持同一条光弦在以下拓扑语法之间连续重组：

1. 极简长弧
2. S 形书写
3. 扇形展开
4. 回环 / 半闭合空间弧
5. 翼面 / 花瓣
6. 钩形回扫
7. 波浪场线
8. 喷泉式扩散
9. 叶片 / split leaf
10. 螺旋绞索
11. 刀锋丝带
12. 星芒 / 突刺

这些不是多个独立主体，也不是模板直接替换，而是同一条 3D 控制点光弦自身在不同拓扑语法之间连续重组。

### 4. 新增保持—突变—保持式混合

新增：

- `v166AutonomousControlPoint(...)`

它不再只是温和力场变化，而是使用：

- modeA
- modeB
- 非线性 mix
- mutation pulse
- 即兴力场

实现同一主体内部的突然重大变异。

### 5. 增强贴附式分叉与场线

新增：

- `drawV166MutationBranches(...)`
- `drawV166MutationFieldThreads(...)`

分叉和场线只在变身节拍期间出现，并且锚定在当前主光弦上，避免重新出现多个独立主体或分身。

### 6. 保留克制的 Mystify 特征

继续保持：

- 单一主体；
- 黑底大留白；
- 极淡同源时间切片；
- 克制白芯线；
- 不恢复乱线团、爬行动物身体结构、粗膜面主体。

## 三、同步页面文案

同步更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

版本升级为 V166。

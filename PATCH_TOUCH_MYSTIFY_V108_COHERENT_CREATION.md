# PATCH_TOUCH_MYSTIFY_V108_COHERENT_CREATION

本次继续针对“发现之旅 / 生理赋能 / 触摸”动态壁纸主体动画优化，重点响应：

- 用户上传视频中可以看到主体存在多余动作；
- 画面不连贯，像“东一下西一下”；
- 看起来不像画笔正在创作；
- 需要找出原因并修复；
- 删除不符合当前要求或已经无关的旧代码。

## 一、问题原因

通过观察视频与检查 `IntimacyMystifyWallpaperService.java`，本次确认主要原因不是单一参数问题，而是主体生成策略本身存在冲突：

### 1. 周期太短，导致频繁重新随机落点
V107 中每个 `gesture` 的周期较短，且每次 gesture 都会重新计算独立随机 anchor。
这会造成：

- 一个主体刚开始出现；
- 还没形成连续创作过程；
- 下一轮又在另一个位置出现；

于是视觉上就像“东一下西一下”。

### 2. 旧逻辑仍带有“盖章式主体”特征
旧的 `drawVideoReferenceRandomGlyph(...)` / `drawVideoMeshGlyph(...)` 类逻辑，本质上是在当前窗口位置附近重新生成一个完整光形。
这会造成画面像不断在不同位置“盖一个主体”，而不是光笔沿连续轨迹创作。

### 3. anchor 逻辑仍保留边缘跳点
旧 `continuousPenAnchor(...)` 中还保留一定概率把落点强行推到屏幕边缘。
这会放大“突然换地方”的观感。

### 4. 旧版本遗留代码过多
部分旧策略函数已经不再符合当前“连续光笔创作”的方向，继续保留容易造成维护混乱。

## 二、本次核心修复

### 1. 改成“长周期连续创作”
将一次主体创作周期拉长：

- 不再几秒一次随机换位置；
- 一次创作使用一个稳定落点；
- 一条连续轨迹完成当前艺术动作；

从而减少“东一下西一下”的跳变。

### 2. 改成真实连续作画窗口
新增：

- `drawCoherentFlowCreation(...)`

它不再在当前窗口中心重新盖一个完整光形，
而是基于真实 `stroke` 作画窗口直接生成连续的丝网、边缘和肋线。

这样主体会更像：

- 一支光笔沿轨迹持续创作；
- 当前窗口是正在被画出来的部分；
- 旧窗口自然退隐；

而不是：

- 一个个独立主体被贴到不同位置。

### 3. 稳定 anchor，去掉边缘强制跳点
重写 `continuousPenAnchor(...)`：

- 去掉随机跳到屏幕边缘的逻辑；
- 只在长周期创作切换时重新选择安全区内落点；
- 一次创作内部位置稳定；

这直接修复视频中“东一下西一下”的主要来源。

### 4. 删除旧的无关 / 不符合要求代码
删除了当前主体阶段已不再使用，且容易混淆方向的旧代码，包括：

- `drawVideoReferenceRandomGlyph(...)`
- `drawVideoMeshGlyph(...)`
- `drawVideoSoftBreathingAura(...)`
- `drawPenRestHold(...)`
- `drawPenArtShapeScaffold(...)`
- `drawSilkJointHandoff(...)`
- `drawLivingSilkFeatherVeils(...)`
- 旧的 fan / petal / loop / crystal / aurora / ribbon glyph 方法
- 旧的 painterly / living ribbon / flow string 相关废弃策略函数

主体阶段现在只保留更符合当前方向的连续光笔创作逻辑。

## 三、保留的关键能力

V108 仍然保留：

- 随机独立创作起点，但不在短时间内乱跳；
- 边画边退隐；
- 不刻意停留展示完整主体；
- FBO 残影自然吞没旧痕迹；
- 秒级显形；
- 释放与余韵逻辑不变。

## 四、同步文案

更新：

- `lib/pages/physical_enhancement_page.dart`
- `lib/pages/discover_page.dart`

入口文案同步升级为 V108。

# PATCH_YANGMING_V32_BOOTSTRAP_FIX

## 根因
知行书院首页的启动流程把多个异步依赖串成了一个链：
- 行动数据
- 复盘数据
- 完成进度
- 27段内置内容资产
- 共享模型状态
- 关卡配置

其中任何一个步骤抛错，`_load()` 都不会进入 `_loading = false`，页面就会一直停留在转圈状态。

V30 又把 27 段原文与解释做成了启动时必须读取的内置资产，并且 DAO 在保存内容时会把“内置内容 + 用户覆盖内容”整包写回本地 KV，导致启动链更脆弱、更重。

## 治本修复
1. **启动链改成容错加载**
   - `_load()` 为每个步骤单独兜底
   - 即使某一步失败，页面也会继续显示其余可用内容
   - 同时展示轻量警告，而不是永远转圈

2. **内置课程内容改成缓存加载**
   - 只首次解析内置 txt 资产
   - 后续直接复用内存缓存
   - 解析失败时安全回退为空映射

3. **课程内容持久化改成“只存覆盖项”**
   - 不再把 27 段内置内容反复整包写入本地 KV
   - 本地只保存用户手动修改/导入的覆盖内容
   - 启动时用 `built-in + overrides` 合成最终内容

## 影响文件
- `lib/yangming_module/yangming_module_home_page.dart`
- `lib/yangming_module/yangming_dao.dart`
- `lib/yangming_module/yangming_builtin_contents.dart`

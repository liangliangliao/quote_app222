# 主分支整合核对（2026-10-12）

核对基线：`main` 的 `9d034d33212a13d2344abbeb1c5a7d4593779a3a`。

## 9 个开放 PR

#151、#155、#156、#157、#158、#159、#160、#161、#162 的头提交都已经是基线 main 的祖先，代码已随后续整合进入主分支。它们仍指向旧功能分支，GitHub 拒绝重新定向到 main（没有新提交）。本次为每个 PR 记录该依据并关闭；其 GitHub 状态是 closed，不能描述为本次新执行了 9 次 merge。

## 历史分支处理

扫描全部 175 个远端分支，发现 19 个分支的历史未接入 main。其中 6 个是等价的旧压缩包删除补丁，13 个代码分支包含共享祖先、有效遗漏与被后续产品取代的实现。下表逐项说明最终保留的行为；合并提交保留这些分支的祖先关系，未覆盖现有更完整的产品流程。

| 分支 | 原头提交 | 处理 |
| --- | --- | --- |
| `codex-a1s14t` | `d46f6ab97e99` | 继承缺失的羞耻档案；1 美元行动使用当前 cognitive_consistency 的现实检验、Todo 接线和成长档案，保留已升级入口。 |
| `codex-h05ajl` | `c0234b9a394f` | 整合微小喜悦日记与长期自我图谱；沿用当前羞耻罗盘、暴露阶梯、真实骄傲的字段与接口。 |
| `codex-h99gz9` | `cb95c874ae92` | 整合微小喜悦日记与长期自我图谱；沿用当前羞耻罗盘、暴露阶梯、真实骄傲的字段与接口。 |
| `codex-jrqua7` | `b80385f36d30` | 保留后续 realistic_optimism_training 的完整 L1–L4 实现；旧模块重构已被其替代。 |
| `codex-pqqpvj` | `c271e5980f8b` | 继承缺失的羞耻档案；1 美元行动使用当前 cognitive_consistency 的现实检验、Todo 接线和成长档案，保留已升级入口。 |
| `codex-pv0y9r` | `43a6624339c8` | 继承缺失的羞耻档案；1 美元行动使用当前 cognitive_consistency 的现实检验、Todo 接线和成长档案，保留已升级入口。 |
| `codex-wc8ikz` | `3b1972c555e8` | 继承缺失的羞耻档案；1 美元行动使用当前 cognitive_consistency 的现实检验、Todo 接线和成长档案，保留已升级入口。 |
| `codex/add-new-module-for-shame-transformation-system-0nl3ua` | `ed736336ae87` | 整合羞耻识别、命名、绑定、关系桥梁、文化/社会羞耻、回避循环与身份档案。 |
| `codex/add-new-module-for-shame-transformation-system-qy8akk` | `6111bf552c58` | 整合羞耻识别、命名、绑定、关系桥梁、文化/社会羞耻、回避循环与身份档案。 |
| `codex/add-new-module-for-shame-transformation-system-t0022x` | `6d9b3588883d` | 整合羞耻识别、命名、绑定、关系桥梁、文化/社会羞耻、回避循环与身份档案。 |
| `codex/upgrade-behavior-tracking-module-1clw8f` | `ec6376b4a4b0` | 整合触发/情绪/长期影响统计、待回填入口、软删除和永久清理；适配当前列表型 cueTags 与旧库迁移。 |
| `codex/upgrade-external-data-sync-module-for-integration-f0r0ab` | `4a73b5610c52` | 整合真实仪式打卡、稳定度、编辑历史与阻力/情境字段；计数从持久记录计算，保留新版努力字段。 |
| `codex/upgrade-external-data-sync-module-for-integration-pkc035` | `1b1c15f5ef37` | 该分支努力/仪式能力已由现有 Todo 实现覆盖，保留当前问题树、Pain-Gain、正念回归与 RaiseBase。 |
| `liangliangliao-patch-1` | `a67bb258a8df` | 旧压缩包删除补丁与 main 等价；保留当前文件树，接入历史。 |
| `liangliangliao-patch-1-1` | `a67bb258a8df` | 旧压缩包删除补丁与 main 等价；保留当前文件树，接入历史。 |
| `liangliangliao-patch-2` | `e9853c66f736` | 旧压缩包删除补丁与 main 等价；保留当前文件树，接入历史。 |
| `liangliangliao-patch-2-1` | `2566767b7bb9` | 旧压缩包删除补丁与 main 等价；保留当前文件树，接入历史。 |
| `liangliangliao-patch-3` | `95a67771d6a7` | 旧压缩包删除补丁与 main 等价；保留当前文件树，接入历史。 |
| `liangliangliao-patch-3-1` | `95a67771d6a7` | 旧压缩包删除补丁与 main 等价；保留当前文件树，接入历史。 |

## 兼容与验证

- 羞耻档案使用当前 `beingSeenTraining`、`affectRecovery`、`compassPrimary`、目标风险 JSON 等接口；原预测/证据、现有罗盘与真实骄傲字段保留。
- 行为观察旧库补入 `deleted_at_ms`，软删除记录退出列表、统计与导出；保留期限清理接口和用户主动永久清理。统计读取当前列表型标签，按实际记录呈现而不宣称因果。
- 仪式打卡从同一事务内的持久记录计算稳定度，编辑不重置创建时间或稳定度；保留 RaiseBase 表、方法以及 Pain-Gain、正念回归和问题树关联。
- 本地相关静态分析：0 个错误；保留这些模块原有警告/提示。
- 本地 24 项相关测试通过：20 项现有工作流/模型测试，4 项新回归覆盖真实 SQLite 旧库升级、删除/统计/导出、羞耻档案/自我图谱、重复打卡/编辑/新版努力数据和统计标签兼容。
- 新增 `Historical Branch Integration CI`，在 PR 上重复相关分析及测试；整包编译由现有 `Build Android APK` 检查执行，最终结果以 PR 检查记录为准。
- 全库扫描另发现未被 app 导入的历史 `lib/will_module/will_dashboard_support.dart` 原有字段错误；本次未改变该文件，也不以本次局部验证宣称全库静态检查通过。

真实 AI 供应商调用、设备通知与长期使用效果沿用各模块原有验收边界。本次没有使用服务密钥执行远端模型调用。

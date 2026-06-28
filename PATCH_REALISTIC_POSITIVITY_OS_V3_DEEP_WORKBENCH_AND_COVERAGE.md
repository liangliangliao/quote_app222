# PATCH_REALISTIC_POSITIVITY_OS_V3_DEEP_WORKBENCH_AND_COVERAGE

## 背景
用户指出 V2 仍未完整实现终极产品设计方案。V2 主要完成了行动卡闭环和 Prompt 配置中心接入，但 12 个产品子模块仍主要依赖一个通用输入框，缺少每个模块的专用训练表单、功能覆盖核验、课程价值提示与模块级行动闭环。

## 本次 V3 目标
继续保持“真实积极行动系统 Realistic Positivity OS”为独立模块，不与现有模块融合；在独立模块中补齐更接近终极产品方案的功能落地。

## 新增文件
- `lib/realistic_positivity_os/realistic_positivity_os_workbench_page.dart`

## 新增能力
1. 新增 RPO 深度训练工作台。
2. 为 12+1 个子模块提供独立专用表单：
   - Onboarding 人格地图
   - Reality Lens 真实看见
   - Question Reframing 问题重构
   - Gratitude Practice 感恩训练
   - Relational Gratitude 关系感恩
   - Emotional Processing 允许为人
   - Meaning-Making 痛苦整合
   - Savoring & Peak Experience 积极经验
   - Change Lab 改变实验室
   - ABC Change 改变计划
   - Behavior First 行为优先
   - Stretch Zone 成长挑战
   - Safety Support 安全支持
   - Weekly Integration 每周整合
3. 每个子模块均落地：
   - 课程价值说明
   - 产品目标说明
   - 专用字段输入
   - 设计功能覆盖清单
   - 安全/价值边界
   - 填入示例
   - 清空表单
   - 直达当前子模块 Prompt 配置中心
   - AI 生成行动卡
   - 自动沉淀成长档案
   - 完成行动并复盘
4. 首页新增“核心价值覆盖雷达”，从产品指标层展示：
   - 真实看见
   - 感恩表达
   - 情绪整合
   - 改变实验
   - 行为证据
   - Stretch
   - 高峰体验
   - 安全支持
5. `realistic_positivity_os_ai_service.dart` 支持 `onboarding` 场景本地兜底。
6. `realistic_positivity_os_prompt_config.dart` 的产品模块矩阵补入 `ABC Change`，并允许输出场景包含 `onboarding`。
7. `realistic_positivity_os_home_page.dart` 接入深度训练工作台入口，并将模块列表的“进入训练”升级为“进入专用工作台”。

## 与终极产品方案的对应
V3 不再只是“一个通用行动卡生成器”，而是把终极产品方案中要求的模块级功能拆成可操作的独立工作台。每个模块都有可见的产品目标、课程价值、字段结构、AI Prompt 配置入口和行动闭环。

## 仍然保留的边界
- 本模块仍是源码级增强，未在当前环境运行 Flutter 编译，因为当前容器没有 Flutter/Dart SDK。
- AI 实际调用能力取决于原 App 中 `UnifiedAiService` 的可用配置。
- V3 已覆盖产品设计方案中的主要功能形态，但更复杂的长期自动调度、推送通知、跨天计划提醒、专业危机资源本地化仍可作为 V4 深化。

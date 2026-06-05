# 概念实践引擎集成审计 V11

本次继续补齐的是“虚拟世界游戏层”的第二阶段能力，不再只是世界大厅 UI，而是让世界状态真正影响训练。

## 本次新增

### 1. 世界地图与解锁树
- 虚拟世界大厅新增地图化展示
- 三个区域按主线顺序显示：职场训练基地 → 关系实验室 → 团队指挥塔
- 每个区域显示：
  - 是否解锁
  - 净化次数
  - 失守次数
  - 当前异常等级
  - 解锁条件

### 2. 世界异常系统
- 新增区域状态表 `ce_world_zone_state`
- 每个区域记录：
  - unlocked
  - cleared_count
  - failed_count
  - anomaly_level
- 训练失败会提高当前区域异常等级
- 训练成功会降低当前区域异常等级
- 低分结算会触发额外异常余波

### 3. 异常影响关卡
- 世界大厅里生成任务关卡时，会根据区域异常等级对场景做增强
- 异常等级越高：
  - 额外加入异常事件
  - 增加失败条件
  - 增加危险度
  - 增加预估经验奖励

### 4. 世界成长闭环
- 通关后会更新区域状态
- 达成条件后可解锁新区域
- 结算页新增：
  - 新解锁区域
  - 世界事件
  - 当前区域异常等级
- 首页世界进度新增“世界异常总值”展示

## 当前真实进度

### 已完成
- 模块集成
- DeepSeek / OpenAI 双模型
- 直连 / 代理双传输
- Prompt 本地模板管理
- 完整请求/响应日志
- 练习记录与详情页
- 虚拟世界大厅
- 世界地图与区域解锁
- 世界异常系统
- 世界异常影响关卡
- XP / 等级 / 成就 / 连胜结算

### 仍未完成
- 可视化大地图节点动画
- 长线主线/支线剧情
- 背包/资源系统
- 多地点行进
- 服务端状态机与评分引擎正式托管
- 服务端 Prompt 发布后台

## 本次重点文件
- `lib/concept_engine/concept_engine_models.dart`
- `lib/concept_engine/concept_engine_dao.dart`
- `lib/concept_engine/concept_engine_world_page.dart`
- `lib/concept_engine/concept_engine_session_page.dart`
- `lib/concept_engine/concept_engine_home_page.dart`

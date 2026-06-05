# 健康饮食模块：Health Connect 扩展读取与展示修复

本次根据截图反馈扩展 Health Connect 读取范围和 UI 展示范围。

## 已扩展读取的数据类型

- 心率 HeartRateRecord
- 静息心率 RestingHeartRateRecord
- 步数 StepsRecord
- 消耗的总卡路里 TotalCaloriesBurnedRecord
- 活动消耗 ActiveCaloriesBurnedRecord
- 睡眠 SleepSessionRecord
- 营养 NutritionRecord
- 血压 BloodPressureRecord
- 血氧饱和度 OxygenSaturationRecord
- 血糖 BloodGlucoseRecord
- 距离 DistanceRecord
- 身高 HeightRecord
- 速度 SpeedRecord
- 锻炼 ExerciseSessionRecord
- 饮水量 HydrationRecord
- 体温 BodyTemperatureRecord
- 体脂 BodyFatRecord
- 体重 WeightRecord
- 功率 PowerRecord
- 呼吸频率 RespiratoryRateRecord
- 基础代谢率 BasalMetabolicRateRecord

## 修改点

1. AndroidManifest.xml 增加对应 `android.permission.health.READ_*` 权限声明。
2. `HealthDietHealthConnectChannel.kt` 扩展读取逻辑。
3. `health_connect_diet_page.dart` 改为分组展示：活动与运动、睡眠与恢复、身体测量、健康指标、营养与饮水。
4. `HealthConnectDailySummary` 保留核心字段，同时通过 `raw_json` 持久化扩展数据，避免大规模数据库破坏性迁移。
5. 饮食调节提示增加饮水、营养、钠、血糖相关兜底提示。

## 注意

Health Connect 只能读取已经被其他应用或设备写入的数据。若某项已授权但显示“暂无”，通常表示当天或最近 30 天 Health Connect 中没有对应记录，而不是 App 读取失败。

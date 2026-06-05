package com.example.quote_app

import android.content.Context
import android.content.ActivityNotFoundException
import android.net.Uri
import android.provider.Settings
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.reflect.KClass

object HealthDietHealthConnectChannel {
    private const val CHANNEL = "health_diet/health_connect"
    private const val REQUEST_CODE = 4608
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val permissionContract = PermissionController.createRequestPermissionResultContract()

    private fun permissions(): Set<String> = setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(NutritionRecord::class),
        HealthPermission.getReadPermission(BloodPressureRecord::class),
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        HealthPermission.getReadPermission(BloodGlucoseRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(HeightRecord::class),
        HealthPermission.getReadPermission(SpeedRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(HydrationRecord::class),
        HealthPermission.getReadPermission(BodyTemperatureRecord::class),
        HealthPermission.getReadPermission(BodyFatRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class),
        HealthPermission.getReadPermission(PowerRecord::class),
        HealthPermission.getReadPermission(RespiratoryRateRecord::class),
        HealthPermission.getReadPermission(BasalMetabolicRateRecord::class)
    )

    fun register(activity: FlutterActivity, flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> scope.launch { handleStatus(activity, result) }
                "requestPermissions" -> handleRequestPermissions(activity, result)
                "readTodaySummary" -> scope.launch { handleReadToday(activity, result) }
                else -> result.notImplemented()
            }
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        return try {
            val granted = permissionContract.parseResult(resultCode, data)
            val required = permissions()
            result.success(
                mutableMapOf<String, Any?>(
                    "available" to true,
                    "status" to "permission_result",
                    "granted" to granted.containsAll(required),
                    "grantedPermissions" to granted.toList(),
                    "missingPermissions" to (required - granted).toList()
                )
            )
            true
        } catch (t: Throwable) {
            result.success(
                mapOf(
                    "available" to true,
                    "status" to "permission_parse_error",
                    "message" to (t.message ?: t.toString()),
                    "granted" to false
                )
            )
            true
        }
    }

    private suspend fun handleStatus(context: Context, result: MethodChannel.Result) {
        try {
            val status = HealthConnectClient.getSdkStatus(context)
            if (status != HealthConnectClient.SDK_AVAILABLE) {
                result.success(statusMap(status))
                return
            }
            val client = HealthConnectClient.getOrCreate(context)
            val granted = client.permissionController.getGrantedPermissions()
            val required = permissions()
            result.success(
                mutableMapOf<String, Any?>(
                    "available" to true,
                    "status" to "available",
                    "message" to "Health Connect 可用。",
                    "granted" to granted.containsAll(required),
                    "grantedPermissions" to granted.toList(),
                    "missingPermissions" to (required - granted).toList()
                )
            )
        } catch (t: Throwable) {
            result.success(
                mapOf(
                    "available" to false,
                    "status" to "error",
                    "message" to (t.message ?: t.toString()),
                    "granted" to false
                )
            )
        }
    }

    private fun handleRequestPermissions(context: FlutterActivity, result: MethodChannel.Result) {
        scope.launch {
            try {
                val status = HealthConnectClient.getSdkStatus(context)
                if (status != HealthConnectClient.SDK_AVAILABLE) {
                    result.success(statusMap(status))
                    return@launch
                }

                val client = HealthConnectClient.getOrCreate(context)
                val granted = client.permissionController.getGrantedPermissions()
                val required = permissions()
                if (granted.containsAll(required)) {
                    result.success(
                        mutableMapOf<String, Any?>(
                            "available" to true,
                            "status" to "available",
                            "message" to "Health Connect 读取权限已授权。",
                            "granted" to true,
                            "grantedPermissions" to granted.toList(),
                            "missingPermissions" to emptyList<String>()
                        )
                    )
                    return@launch
                }

                val opened = openHealthConnectAccessPage(context)
                result.success(
                    mutableMapOf<String, Any?>(
                        "available" to true,
                        "status" to if (opened) "permission_settings_opened" else "permission_settings_unavailable",
                        "message" to if (opened) {
                            "已打开 Health Connect 授权/管理访问页面。请允许本应用读取心率、步数、睡眠、营养、血压、血氧、血糖、运动、距离、体重等数据，然后返回本页点击“同步今日身体状态”。"
                        } else {
                            "未能自动打开 Health Connect 授权页面。请在系统设置中搜索 Health Connect，进入“应用权限/数据和访问权限”，允许本应用读取相关健康数据。"
                        },
                        "granted" to false,
                        "grantedPermissions" to granted.toList(),
                        "missingPermissions" to (required - granted).toList()
                    )
                )
            } catch (t: Throwable) {
                pendingPermissionResult = null
                result.success(
                    mapOf(
                        "available" to false,
                        "status" to "error",
                        "message" to (t.message ?: t.toString()),
                        "granted" to false
                    )
                )
            }
        }
    }

    private fun openHealthConnectAccessPage(context: FlutterActivity): Boolean {
        val intents = mutableListOf<Intent>()
        intents.add(Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS))
        context.packageManager.getLaunchIntentForPackage("com.google.android.apps.healthdata")?.let { intents.add(it) }
        intents.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
        })
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            } catch (_: Throwable) {
            }
        }
        return false
    }

    private suspend fun handleReadToday(context: Context, result: MethodChannel.Result) {
        try {
            val status = HealthConnectClient.getSdkStatus(context)
            if (status != HealthConnectClient.SDK_AVAILABLE) {
                result.success(statusMap(status))
                return
            }
            val client = HealthConnectClient.getOrCreate(context)
            val granted = client.permissionController.getGrantedPermissions()
            val zone = ZoneId.systemDefault()
            val todayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant()
            val end = Instant.now()
            val todayRange = TimeRangeFilter.between(todayStart, end)
            val sleepRange = TimeRangeFilter.between(todayStart.minus(Duration.ofHours(18)), end)
            val recentRange = TimeRangeFilter.between(end.minus(Duration.ofDays(30)), end)
            val required = permissions()

            val map = mutableMapOf<String, Any?>(
                "available" to true,
                "status" to "synced",
                "message" to "已读取 Health Connect 今日摘要和最近一次身体指标。",
                "granted" to granted.containsAll(required),
                "grantedPermissions" to granted.toList(),
                "missingPermissions" to (required - granted).toList(),
                "startEpochMs" to todayStart.toEpochMilli(),
                "endEpochMs" to end.toEpochMilli()
            )

            readSafely(map, "steps") {
                if (has(granted, StepsRecord::class)) {
                    var steps = 0L
                    val records = client.readRecords(ReadRecordsRequest(recordType = StepsRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { steps += it.count }
                    map["steps"] = steps
                    map["stepsRecordCount"] = records.size
                }
            }

            readSafely(map, "sleep") {
                if (has(granted, SleepSessionRecord::class)) {
                    var minutes = 0L
                    val records = client.readRecords(ReadRecordsRequest(recordType = SleepSessionRecord::class, timeRangeFilter = sleepRange)).records
                    records.forEach { minutes += Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0L) }
                    map["sleepMinutes"] = minutes
                    map["sleepRecordCount"] = records.size
                }
            }

            readSafely(map, "exercise") {
                if (has(granted, ExerciseSessionRecord::class)) {
                    var minutes = 0L
                    val names = mutableListOf<String>()
                    val records = client.readRecords(ReadRecordsRequest(recordType = ExerciseSessionRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach {
                        minutes += Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0L)
                        names.add(it.exerciseType.toString())
                    }
                    map["exerciseMinutes"] = minutes
                    map["exerciseRecordCount"] = records.size
                    if (names.isNotEmpty()) map["exerciseTypes"] = names.distinct().joinToString("、")
                }
            }

            readSafely(map, "activeCalories") {
                if (has(granted, ActiveCaloriesBurnedRecord::class)) {
                    var kcal = 0.0
                    val records = client.readRecords(ReadRecordsRequest(recordType = ActiveCaloriesBurnedRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { kcal += unitDouble(prop(it, "energy"), listOf("getInKilocalories")) ?: 0.0 }
                    map["activeCalories"] = kcal
                    map["activeCaloriesRecordCount"] = records.size
                }
            }

            readSafely(map, "totalCalories") {
                if (has(granted, TotalCaloriesBurnedRecord::class)) {
                    var kcal = 0.0
                    val records = client.readRecords(ReadRecordsRequest(recordType = TotalCaloriesBurnedRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { kcal += unitDouble(prop(it, "energy"), listOf("getInKilocalories")) ?: 0.0 }
                    map["totalCalories"] = kcal
                    map["totalCaloriesRecordCount"] = records.size
                }
            }

            readSafely(map, "distance") {
                if (has(granted, DistanceRecord::class)) {
                    var meters = 0.0
                    val records = client.readRecords(ReadRecordsRequest(recordType = DistanceRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { meters += lengthMeters(prop(it, "distance")) ?: 0.0 }
                    map["distanceMeters"] = meters
                    map["distanceRecordCount"] = records.size
                }
            }

            readSafely(map, "hydration") {
                if (has(granted, HydrationRecord::class)) {
                    var liters = 0.0
                    val records = client.readRecords(ReadRecordsRequest(recordType = HydrationRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { liters += volumeLiters(prop(it, "volume")) ?: 0.0 }
                    map["hydrationLiters"] = liters
                    map["hydrationRecordCount"] = records.size
                }
            }

            readSafely(map, "nutrition") {
                if (has(granted, NutritionRecord::class)) {
                    var energy = 0.0
                    var protein = 0.0
                    var carbs = 0.0
                    var fat = 0.0
                    var sugar = 0.0
                    var sodiumMg = 0.0
                    val records = client.readRecords(ReadRecordsRequest(recordType = NutritionRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { r ->
                        energy += energyKcal(propAny(r, "energy", "energyKcal")) ?: 0.0
                        protein += massGrams(propAny(r, "protein")) ?: 0.0
                        carbs += massGrams(propAny(r, "totalCarbohydrate", "carbohydrate", "carbohydrates")) ?: 0.0
                        fat += massGrams(propAny(r, "totalFat", "fat")) ?: 0.0
                        sugar += massGrams(propAny(r, "sugar", "totalSugar")) ?: 0.0
                        sodiumMg += (massGrams(propAny(r, "sodium")) ?: 0.0) * 1000.0
                    }
                    map["nutritionCalories"] = energy
                    map["nutritionProteinG"] = protein
                    map["nutritionCarbsG"] = carbs
                    map["nutritionFatG"] = fat
                    map["nutritionSugarG"] = sugar
                    map["nutritionSodiumMg"] = sodiumMg
                    map["nutritionRecordCount"] = records.size
                }
            }

            readSafely(map, "heartRate") {
                if (has(granted, HeartRateRecord::class)) {
                    val values = mutableListOf<Double>()
                    var latestTime = Instant.EPOCH
                    var latestValue: Double? = null
                    val records = client.readRecords(ReadRecordsRequest(recordType = HeartRateRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { r ->
                        val samples = propAny(r, "samples") as? Iterable<*>
                        samples?.forEach { s ->
                            val v = asDouble(propAny(s, "beatsPerMinute"))
                            val time = asInstant(propAny(s, "time")) ?: Instant.EPOCH
                            if (v != null) {
                                values.add(v)
                                if (time.isAfter(latestTime)) {
                                    latestTime = time
                                    latestValue = v
                                }
                            }
                        }
                    }
                    if (values.isNotEmpty()) {
                        map["heartRateBpm"] = latestValue
                        map["heartRateAvgBpm"] = values.average()
                        map["heartRateSampleCount"] = values.size
                    }
                }
            }

            readSafely(map, "restingHeartRate") {
                if (has(granted, RestingHeartRateRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = RestingHeartRateRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val v = asDouble(propAny(latest, "beatsPerMinute"))
                    if (v != null) map["restingHeartRate"] = v
                }
            }

            readSafely(map, "bloodPressure") {
                if (has(granted, BloodPressureRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = BloodPressureRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val sys = pressureMmHg(propAny(latest, "systolic"))
                    val dia = pressureMmHg(propAny(latest, "diastolic"))
                    if (sys != null) map["bloodPressureSystolic"] = sys
                    if (dia != null) map["bloodPressureDiastolic"] = dia
                    if (latest != null) map["bloodPressureTimeEpochMs"] = (asInstant(propAny(latest, "time")) ?: Instant.EPOCH).toEpochMilli()
                }
            }

            readSafely(map, "oxygenSaturation") {
                if (has(granted, OxygenSaturationRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = OxygenSaturationRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val v = percentage(propAny(latest, "percentage"))
                    if (v != null) map["oxygenSaturationPercent"] = v
                }
            }

            readSafely(map, "bloodGlucose") {
                if (has(granted, BloodGlucoseRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = BloodGlucoseRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val v = bloodGlucoseMmol(propAny(latest, "level"))
                    if (v != null) map["bloodGlucoseMmolL"] = v
                }
            }

            readSafely(map, "height") {
                if (has(granted, HeightRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = HeightRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val meters = lengthMeters(propAny(latest, "height"))
                    if (meters != null) map["heightCm"] = meters * 100.0
                }
            }

            readSafely(map, "weight") {
                if (has(granted, WeightRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = WeightRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val kg = massKg(propAny(latest, "weight"))
                    if (kg != null) map["weightKg"] = kg
                }
            }

            readSafely(map, "bodyFat") {
                if (has(granted, BodyFatRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = BodyFatRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val v = percentage(propAny(latest, "percentage"))
                    if (v != null) map["bodyFatPercent"] = v
                }
            }

            readSafely(map, "bodyTemperature") {
                if (has(granted, BodyTemperatureRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = BodyTemperatureRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val v = temperatureCelsius(propAny(latest, "temperature"))
                    if (v != null) map["bodyTemperatureCelsius"] = v
                }
            }

            readSafely(map, "respiratoryRate") {
                if (has(granted, RespiratoryRateRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = RespiratoryRateRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val v = asDouble(propAny(latest, "rate", "breathsPerMinute", "respiratoryRate"))
                    if (v != null) map["respiratoryRate"] = v
                }
            }

            readSafely(map, "basalMetabolicRate") {
                if (has(granted, BasalMetabolicRateRecord::class)) {
                    val records = client.readRecords(ReadRecordsRequest(recordType = BasalMetabolicRateRecord::class, timeRangeFilter = recentRange)).records
                    val latest = records.maxByOrNull { asInstant(propAny(it, "time")) ?: Instant.EPOCH }
                    val unit = propAny(latest, "basalMetabolicRate", "power")
                    val kcalDay = unitDouble(unit, listOf("getInKilocaloriesPerDay", "getInKilocalories")) ?: (powerWatts(unit)?.let { it * 20.64 })
                    if (kcalDay != null) map["basalMetabolicRateKcalDay"] = kcalDay
                }
            }

            readSafely(map, "speed") {
                if (has(granted, SpeedRecord::class)) {
                    val values = mutableListOf<Double>()
                    val records = client.readRecords(ReadRecordsRequest(recordType = SpeedRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { r ->
                        (propAny(r, "samples") as? Iterable<*>)?.forEach { s ->
                            velocityMps(propAny(s, "speed"))?.let { values.add(it) }
                        }
                    }
                    if (values.isNotEmpty()) {
                        map["speedAvgMps"] = values.average()
                        map["speedMaxMps"] = values.maxOrNull()
                    }
                }
            }

            readSafely(map, "power") {
                if (has(granted, PowerRecord::class)) {
                    val values = mutableListOf<Double>()
                    val records = client.readRecords(ReadRecordsRequest(recordType = PowerRecord::class, timeRangeFilter = todayRange)).records
                    records.forEach { r ->
                        (propAny(r, "samples") as? Iterable<*>)?.forEach { s ->
                            powerWatts(propAny(s, "power"))?.let { values.add(it) }
                        }
                    }
                    if (values.isNotEmpty()) {
                        map["powerAvgWatts"] = values.average()
                        map["powerMaxWatts"] = values.maxOrNull()
                    }
                }
            }

            if (!hasAnyUsefulData(map)) {
                map["status"] = if (granted.isEmpty()) "permission_required" else "no_data"
                map["message"] = if (granted.isEmpty()) {
                    "尚未授权读取 Health Connect 数据。"
                } else {
                    "已授权，但今天/最近 30 天暂未读取到可显示的 Health Connect 数据。请确认手环或其他 App 已向 Health Connect 写入数据。"
                }
            }
            result.success(map)
        } catch (t: Throwable) {
            result.success(
                mapOf(
                    "available" to true,
                    "status" to "read_error",
                    "message" to (t.message ?: t.toString()),
                    "granted" to false
                )
            )
        }
    }

    private fun has(granted: Set<String>, record: KClass<out Record>): Boolean = granted.contains(HealthPermission.getReadPermission(record))

    private suspend fun readSafely(map: MutableMap<String, Any?>, key: String, block: suspend () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            val errors = (map["readErrors"] as? MutableMap<String, String>) ?: mutableMapOf<String, String>().also { map["readErrors"] = it }
            errors[key] = t.message ?: t.toString()
        }
    }

    private fun hasAnyUsefulData(map: Map<String, Any?>): Boolean {
        return listOf(
            "steps", "sleepMinutes", "exerciseMinutes", "activeCalories", "totalCalories", "weightKg",
            "heartRateBpm", "heartRateAvgBpm", "restingHeartRate", "nutritionCalories", "bloodPressureSystolic",
            "oxygenSaturationPercent", "bloodGlucoseMmolL", "distanceMeters", "heightCm", "speedAvgMps",
            "hydrationLiters", "bodyTemperatureCelsius", "bodyFatPercent", "powerAvgWatts", "respiratoryRate",
            "basalMetabolicRateKcalDay"
        ).any { map[it] != null }
    }

    private fun propAny(obj: Any?, vararg names: String): Any? {
        if (obj == null) return null
        for (name in names) {
            val v = prop(obj, name)
            if (v != null) return v
        }
        return null
    }

    private fun prop(obj: Any?, name: String): Any? {
        if (obj == null) return null
        val c = obj.javaClass
        val suffix = name.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        val methodNames = listOf("get$suffix", name)
        for (m in methodNames) {
            try {
                val method = c.methods.firstOrNull { it.name == m && it.parameterTypes.isEmpty() }
                if (method != null) return method.invoke(obj)
            } catch (_: Throwable) {}
        }
        try {
            val field = c.getDeclaredField(name)
            field.isAccessible = true
            return field.get(obj)
        } catch (_: Throwable) {}
        return null
    }

    private fun asInstant(obj: Any?): Instant? = obj as? Instant

    private fun asDouble(obj: Any?): Double? {
        return when (obj) {
            null -> null
            is Double -> obj
            is Float -> obj.toDouble()
            is Long -> obj.toDouble()
            is Int -> obj.toDouble()
            is Number -> obj.toDouble()
            else -> obj.toString().toDoubleOrNull()
        }
    }

    private fun unitDouble(obj: Any?, methodNames: List<String>): Double? {
        if (obj == null) return null
        for (m in methodNames) {
            try {
                val method = obj.javaClass.methods.firstOrNull { it.name == m && it.parameterTypes.isEmpty() }
                val value = method?.invoke(obj)
                val d = asDouble(value)
                if (d != null) return d
            } catch (_: Throwable) {}
        }
        return asDouble(obj)
    }

    private fun energyKcal(obj: Any?): Double? = unitDouble(obj, listOf("getInKilocalories"))
    private fun massGrams(obj: Any?): Double? = unitDouble(obj, listOf("getInGrams"))
    private fun massKg(obj: Any?): Double? = unitDouble(obj, listOf("getInKilograms"))
    private fun lengthMeters(obj: Any?): Double? = unitDouble(obj, listOf("getInMeters"))
    private fun volumeLiters(obj: Any?): Double? = unitDouble(obj, listOf("getInLiters"))
    private fun pressureMmHg(obj: Any?): Double? = unitDouble(obj, listOf("getInMillimetersOfMercury"))
    private fun percentage(obj: Any?): Double? = unitDouble(obj, listOf("getValue", "getInPercentage"))
    private fun temperatureCelsius(obj: Any?): Double? = unitDouble(obj, listOf("getInCelsius"))
    private fun bloodGlucoseMmol(obj: Any?): Double? = unitDouble(obj, listOf("getInMillimolesPerLiter"))
    private fun velocityMps(obj: Any?): Double? = unitDouble(obj, listOf("getInMetersPerSecond"))
    private fun powerWatts(obj: Any?): Double? = unitDouble(obj, listOf("getInWatts"))

    private fun statusMap(status: Int): Map<String, Any?> {
        return when (status) {
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> mapOf(
                "available" to false,
                "status" to "provider_update_required",
                "message" to "需要安装或更新 Health Connect。",
                "granted" to false
            )
            HealthConnectClient.SDK_UNAVAILABLE -> mapOf(
                "available" to false,
                "status" to "unavailable",
                "message" to "当前设备不支持 Health Connect。",
                "granted" to false
            )
            else -> mapOf(
                "available" to false,
                "status" to "unknown_$status",
                "message" to "Health Connect 状态未知：$status",
                "granted" to false
            )
        }
    }
}

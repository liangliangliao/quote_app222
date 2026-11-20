package com.example.quote_app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Credential-protected, Keystore-encrypted, separate from alarm payloads and Flutter SQLite. */
object VoiceAlarmWakeupStore {
  private const val ALIAS = "quote_app_ai_wakeup_v1"
  private const val PREFS = "ai_wakeup_private_v1"
  private fun key(create: Boolean): SecretKey {
    val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
    check(create) { "连接密钥不可用，请重新配置" }
    return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
      init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
    }.generateKey()
  }
  private fun encrypt(value: JSONObject): String {
    val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key(true)) }
    return Base64.encodeToString(cipher.iv + cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
  }
  private fun read(context: Context, name: String): JSONObject? {
    val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(name, null) ?: return null
    return decrypt(raw)
  }
  private fun decrypt(raw: String): JSONObject {
    val bytes = Base64.decode(raw, Base64.NO_WRAP)
    require(bytes.size > 12)
    val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, bytes.copyOfRange(0, 12))) }
    return JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
  }
  fun access(context: Context): WakeupAccess? = read(context, "connection")?.let {
    WakeupAccess(it.optString("baseUrl"), it.optString("deviceToken"), it.optString("serviceToken"))
  }
  fun publicSettings(context: Context): Map<String, Any> {
    val cfg = try { access(context) } catch (_: Exception) { null }
    return mapOf("baseUrl" to (cfg?.baseUrl ?: VoiceAlarmWakeupClient.DEFAULT_URL), "hasDeviceToken" to !cfg?.deviceToken.isNullOrBlank(), "hasServiceToken" to !cfg?.serviceToken.isNullOrBlank())
  }
  @Synchronized fun update(context: Context, baseUrl: String, deviceToken: String, serviceToken: String, clear: Boolean = false) {
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    if (clear) { check(prefs.edit().clear().commit()); return }
    val old = try { access(context) } catch (_: Exception) { null }
    fun token(value: String) = value.trim().removePrefix("Bearer ").also { require(!it.contains('\r') && !it.contains('\n')) { "访问凭据格式无效" } }
    val url = VoiceAlarmWakeupClient.normalizeBaseUrl(baseUrl)
    val sameOrigin = old?.baseUrl == url
    val cfg = JSONObject().put("baseUrl", url)
      .put("deviceToken", token(deviceToken).ifBlank { if (sameOrigin) old?.deviceToken.orEmpty() else "" })
      .put("serviceToken", token(serviceToken).ifBlank { if (sameOrigin) old?.serviceToken.orEmpty() else "" })
    check(prefs.edit().putString("connection", encrypt(cfg)).remove("cache").commit()) { "连接设置未保存" }
  }
  fun fetchDay(context: Context, requireHistorySaved: Boolean = false): WakeupDay {
    val cfg = access(context) ?: throw IllegalStateException("AI Wakeup 尚未配置连接")
    val day = VoiceAlarmWakeupClient.fetchDay(cfg)
    try { saveHistory(context, day) } catch (failure: Exception) {
      VoiceAlarmDebugLog.write(context, "aiWakeup.history.error", "本次内容未能存入本地历史", mapOf("type" to failure.javaClass.simpleName))
      if (requireHistorySaved) throw failure
    }
    return day
  }

  private val datePattern = Regex("\\d{4}-\\d{2}-\\d{2}")
  private fun historyFolder(context: Context) = File(context.noBackupFilesDir, "ai-wakeup-history")
  private fun historyFile(context: Context, date: String): AtomicFile {
    require(datePattern.matches(date)) { "日期无效" }
    return AtomicFile(File(historyFolder(context), "$date.json"))
  }
  @Synchronized private fun saveHistory(context: Context, day: WakeupDay) {
    if (day.historyItems.isEmpty()) return
    val folder = historyFolder(context)
    check(folder.isDirectory || folder.mkdirs())
    val file = historyFile(context, day.date)
    val old = if (file.baseFile.exists()) decrypt(file.readFully().toString(Charsets.UTF_8)).optJSONArray("items") else null
    val items = (0 until (old?.length() ?: 0)).mapNotNull { old?.optJSONObject(it) }.toMutableList()
    val fetchedAt = System.currentTimeMillis()
    for (entry in day.historyItems) {
      val index = items.indexOfFirst { it.optString("id") == entry.id && it.optString("text") == entry.text }
      val item = JSONObject().put("id", entry.id).put("title", entry.title).put("scheduledTime", entry.scheduledTime)
        .put("text", entry.text).put("fetchedAt", fetchedAt)
      if (index < 0) items.add(item) else items[index] = item
    }
    val bytes = encrypt(JSONObject().put("items", JSONArray(items))).toByteArray(Charsets.UTF_8)
    val output = file.startWrite()
    try { output.write(bytes); file.finishWrite(output) }
    catch (error: Exception) { file.failWrite(output); throw error }
  }

  @Synchronized fun historyDates(context: Context): List<String> = historyFolder(context).listFiles().orEmpty()
    .map { it.nameWithoutExtension }.filter { datePattern.matches(it) }.distinct().sortedDescending()

  @Synchronized fun history(context: Context, date: String): List<Map<String, Any>> {
    val file = historyFile(context, date)
    if (!file.baseFile.exists()) return emptyList()
    val items = decrypt(file.readFully().toString(Charsets.UTF_8)).optJSONArray("items") ?: return emptyList()
    return (0 until items.length()).mapNotNull { items.optJSONObject(it) }
      .sortedWith(compareBy({ it.optString("scheduledTime").ifBlank { "99:99" } }, { -it.optLong("fetchedAt") }))
      .map { mapOf("title" to it.optString("title"), "scheduledTime" to it.optString("scheduledTime"),
        "text" to it.optString("text"), "fetchedAt" to it.optLong("fetchedAt")) }
  }
}

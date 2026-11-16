package com.example.quote_app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
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
  fun fetchToday(context: Context): WakeupContent {
    val cfg = access(context) ?: throw IllegalStateException("AI Wakeup 尚未配置连接")
    return VoiceAlarmWakeupClient.fetch(cfg)
  }
}

package com.example.quote_app

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.Executors
import android.os.Handler
import android.os.Looper
import javax.crypto.Cipher
import javax.crypto.AEADBadTagException
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** New isolated vault. Legacy vault aliases/files are deliberately untouched. */
class WillMirrorV28Vault(messenger: BinaryMessenger) {
    private class MissingVaultKey : Exception()
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val alias = "quote_app_will_mirror_rebuilt_v28"

    init {
        MethodChannel(messenger, "quote_app/will_mirror_v28_vault").setMethodCallHandler { call, result ->
            if (call.method != "encrypt" && call.method != "decrypt") {
                result.notImplemented()
            } else {
                val input = call.argument<String>("data")
                val context = call.argument<String>("context")
                if (input == null || context == null || context.length > 512) {
                    result.error("invalid_input", "Invalid vault request", null)
                } else executor.execute {
                    try {
                        val output = if (call.method == "encrypt") encrypt(input, context) else decrypt(input, context)
                        main.post { result.success(output) }
                    } catch (error: Exception) {
                        // Never log private text, ciphertext, credentials, or exception payloads.
                        val code = when (error) {
                            is MissingVaultKey -> "vault_key_missing"
                            is AEADBadTagException -> "vault_authentication_failed"
                            is IllegalArgumentException -> "vault_invalid_payload"
                            else -> "vault_unavailable"
                        }
                        main.post { result.error(code, "Encrypted data unavailable; original data retained", null) }
                    }
                }
            }
        }
    }

    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(alias, null)
        if (existing is SecretKey) return existing
        if (!create) throw MissingVaultKey() // Never regenerate on decrypt.
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256).setRandomizedEncryptionRequired(true).build())
        return generator.generateKey()
    }

    private fun encrypt(clear: String, context: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        cipher.updateAAD(context.toByteArray(Charsets.UTF_8))
        val encrypted = cipher.doFinal(clear.toByteArray(Charsets.UTF_8))
        return "v1." + Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + "." + Base64.encodeToString(encrypted, Base64.NO_WRAP)
    }

    private fun decrypt(encoded: String, context: String): String {
        val parts = encoded.split('.')
        require(parts.size == 3 && parts[0] == "v1")
        val iv = Base64.decode(parts[1], Base64.NO_WRAP)
        require(iv.size == 12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, iv))
        cipher.updateAAD(context.toByteArray(Charsets.UTF_8))
        return String(cipher.doFinal(Base64.decode(parts[2], Base64.NO_WRAP)), Charsets.UTF_8)
    }
}

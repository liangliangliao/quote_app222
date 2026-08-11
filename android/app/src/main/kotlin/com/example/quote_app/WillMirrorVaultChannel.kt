package com.example.quote_app

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypts every user-authored Will Mirror payload with AES-256-GCM.
 *
 * The key is generated and retained by Android Keystore. SQLite only receives
 * versioned IV+ciphertext envelopes, so goals, Why trees, private relationship
 * notes and inference payloads are not persisted as plaintext.
 */
object WillMirrorVaultChannel {
    private const val CHANNEL = "com.example.quote_app/will_mirror_vault"
    private const val KEYSTORE = "AndroidKeyStore"
    private const val KEY_ALIAS = "will_mirror_v4_vault_aes_gcm"
    private const val PREFIX = "wm1"

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                try {
                    when (call.method) {
                        "isAvailable" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        "encrypt" -> {
                            val plaintext = call.argument<String>("plaintext")
                                ?: throw IllegalArgumentException("plaintext is required")
                            result.success(encrypt(plaintext))
                        }
                        "decrypt" -> {
                            val ciphertext = call.argument<String>("ciphertext")
                                ?: throw IllegalArgumentException("ciphertext is required")
                            result.success(decrypt(ciphertext))
                        }
                        "destroyKey" -> {
                            destroyKey()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("WILL_MIRROR_VAULT", t.message ?: "Vault operation failed", null)
                }
            }
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val existing = store.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun encrypt(plaintext: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.doFinal(plaintext.toByteArray(StandardCharsets.UTF_8))
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val payload = Base64.encodeToString(encrypted, Base64.NO_WRAP)
        return "$PREFIX:$iv:$payload"
    }

    private fun decrypt(envelope: String): String {
        val parts = envelope.split(':', limit = 3)
        require(parts.size == 3 && parts[0] == PREFIX) { "Unsupported vault envelope" }
        val iv = Base64.decode(parts[1], Base64.NO_WRAP)
        val encrypted = Base64.decode(parts[2], Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(encrypted), StandardCharsets.UTF_8)
    }

    private fun destroyKey() {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (store.containsAlias(KEY_ALIAS)) store.deleteEntry(KEY_ALIAS)
    }
}

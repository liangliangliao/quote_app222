package com.example.quote_app

import android.app.Activity
import android.content.Intent
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

object MentalHealthCheckupPlatform {
    private const val CHANNEL = "com.example.quote_app/mental_health_checkup"
    private const val REQUEST_CREATE_BACKUP = 7811
    private const val REQUEST_OPEN_BACKUP = 7812
    private const val REQUEST_CREATE_PDF = 7813
    private const val MAX_BACKUP_BYTES = 64 * 1024 * 1024

    private var activity: Activity? = null
    private var pending: PendingOperation? = null
    private val fieldCipher = MentalHealthFieldCipher()
    private val backupCodec = MentalHealthBackupCodec()

    private sealed class PendingOperation(open val result: MethodChannel.Result) {
        data class ExportBackup(
            val bytes: ByteArray,
            override val result: MethodChannel.Result,
        ) : PendingOperation(result)

        data class ImportBackup(
            val password: CharArray,
            override val result: MethodChannel.Result,
        ) : PendingOperation(result)

        data class ExportPdf(
            val bytes: ByteArray,
            override val result: MethodChannel.Result,
        ) : PendingOperation(result)
    }

    fun register(host: Activity, engine: FlutterEngine) {
        activity = host
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    handle(call, result)
                } catch (error: Throwable) {
                    result.error(
                        "mental_health_platform_error",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "encryptText" -> {
                val value = call.argument<String>("value").orEmpty()
                val encrypted = fieldCipher.encrypt(value.encodeToByteArray())
                result.success("keystore-v1:${Base64.encodeToString(encrypted, Base64.NO_WRAP)}")
            }

            "decryptText" -> {
                val value = call.argument<String>("value").orEmpty()
                if (value.isEmpty()) {
                    result.success("")
                    return
                }
                require(value.startsWith("keystore-v1:")) {
                    "Unsupported encrypted field format"
                }
                val blob = Base64.decode(value.substringAfter(':'), Base64.NO_WRAP)
                result.success(fieldCipher.decrypt(blob).decodeToString())
            }

            "exportEncryptedBackup" -> {
                ensureIdle(result) ?: return
                val payload = call.argument<String>("payload")
                    ?: error("Backup payload is missing")
                val password = call.argument<String>("password").orEmpty().toCharArray()
                val suggestedName =
                    call.argument<String>("suggestedName") ?: "mental-health-checkup.ppcheckup"
                val encrypted = try {
                    backupCodec.encrypt(payload.encodeToByteArray(), password)
                } finally {
                    password.fill('\u0000')
                }
                pending = PendingOperation.ExportBackup(encrypted, result)
                try {
                    launchCreateDocument(
                        requestCode = REQUEST_CREATE_BACKUP,
                        mimeType = "application/octet-stream",
                        suggestedName = suggestedName,
                    )
                } catch (error: Throwable) {
                    pending = null
                    encrypted.fill(0)
                    throw error
                }
            }

            "importEncryptedBackup" -> {
                ensureIdle(result) ?: return
                val password = call.argument<String>("password").orEmpty().toCharArray()
                require(password.size >= 10) {
                    "Backup password must be at least 10 characters"
                }
                pending = PendingOperation.ImportBackup(password, result)
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/octet-stream"
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf("application/octet-stream", "application/json", "*/*"),
                    )
                }
                try {
                    requireActivity().startActivityForResult(
                        intent,
                        REQUEST_OPEN_BACKUP,
                    )
                } catch (error: Throwable) {
                    pending = null
                    password.fill('\u0000')
                    throw error
                }
            }

            "exportReportPdf" -> {
                ensureIdle(result) ?: return
                val title = call.argument<String>("title") ?: "心理健康体检报告"
                val lines = call.argument<List<String>>("lines") ?: emptyList()
                val suggestedName =
                    call.argument<String>("suggestedName") ?: "mental-health-checkup.pdf"
                pending = PendingOperation.ExportPdf(createPdf(title, lines), result)
                try {
                    launchCreateDocument(
                        requestCode = REQUEST_CREATE_PDF,
                        mimeType = "application/pdf",
                        suggestedName = suggestedName,
                    )
                } catch (error: Throwable) {
                    val operation = pending
                    pending = null
                    if (operation is PendingOperation.ExportPdf) {
                        operation.bytes.fill(0)
                    }
                    throw error
                }
            }

            "setSecureScreen" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                val host = requireActivity()
                host.runOnUiThread {
                    if (enabled) {
                        host.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        host.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
                result.success(null)
            }

            "scheduleReminders" -> {
                val context = requireActivity().applicationContext
                MentalHealthCheckupReminderScheduler.configure(
                    context = context,
                    enabled = call.argument<Boolean>("enabled") == true,
                    hour = call.argument<Int>("hour") ?: 19,
                    minute = call.argument<Int>("minute") ?: 0,
                    quietStartHour = call.argument<Int>("quietStartHour") ?: 22,
                    quietEndHour = call.argument<Int>("quietEndHour") ?: 8,
                    lockScreenPrivacy =
                        call.argument<Boolean>("lockScreenPrivacy") != false,
                    nextRetestAtMs = call.argument<Number>("nextRetestAtMs")?.toLong(),
                )
                result.success(null)
            }

            "clearSecurityAndReminders" -> {
                val context = requireActivity().applicationContext
                MentalHealthCheckupReminderScheduler.clear(context)
                fieldCipher.deleteKey()
                context.cacheDir.resolve("mental_health_checkup").deleteRecursively()
                result.success(null)
            }

            "openNotificationSettings" -> {
                val host = requireActivity()
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, host.packageName)
                }
                host.startActivity(intent)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in setOf(
                REQUEST_CREATE_BACKUP,
                REQUEST_OPEN_BACKUP,
                REQUEST_CREATE_PDF,
            )
        ) {
            return false
        }
        val operation = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            when (operation) {
                is PendingOperation.ImportBackup -> {
                    operation.password.fill('\u0000')
                    operation.result.success(null)
                }

                is PendingOperation.ExportBackup -> {
                    operation.bytes.fill(0)
                    operation.result.success(false)
                }

                is PendingOperation.ExportPdf -> {
                    operation.bytes.fill(0)
                    operation.result.success(false)
                }
            }
            return true
        }

        val uri = requireNotNull(data?.data)
        try {
            when (operation) {
                is PendingOperation.ExportBackup -> {
                    try {
                        write(uri, operation.bytes)
                        operation.result.success(true)
                    } finally {
                        operation.bytes.fill(0)
                    }
                }

                is PendingOperation.ExportPdf -> {
                    try {
                        write(uri, operation.bytes)
                        operation.result.success(true)
                    } finally {
                        operation.bytes.fill(0)
                    }
                }

                is PendingOperation.ImportBackup -> {
                    val encrypted = read(uri)
                    val plain = try {
                        backupCodec.decrypt(encrypted, operation.password)
                    } finally {
                        encrypted.fill(0)
                        operation.password.fill('\u0000')
                    }
                    val text = plain.decodeToString()
                    plain.fill(0)
                    operation.result.success(text)
                }
            }
        } catch (error: Throwable) {
            if (operation is PendingOperation.ImportBackup) {
                operation.password.fill('\u0000')
            }
            operation.result.error(
                if (operation is PendingOperation.ImportBackup) {
                    "invalid_or_wrong_password"
                } else {
                    "document_write_failed"
                },
                if (operation is PendingOperation.ImportBackup) {
                    "密码错误、认证标签失败或备份已损坏，现有数据未修改。"
                } else {
                    "无法写入所选文件。"
                },
                null,
            )
        }
        return true
    }

    private fun ensureIdle(result: MethodChannel.Result): Unit? {
        if (pending != null) {
            result.error("document_operation_busy", "已有文件操作正在进行。", null)
            return null
        }
        return Unit
    }

    private fun launchCreateDocument(
        requestCode: Int,
        mimeType: String,
        suggestedName: String,
    ) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, suggestedName)
        }
        requireActivity().startActivityForResult(intent, requestCode)
    }

    private fun write(uri: Uri, bytes: ByteArray) {
        requireActivity().contentResolver.openOutputStream(uri, "w").use { output ->
            requireNotNull(output) { "Cannot open document output" }
            output.write(bytes)
            output.flush()
        }
    }

    private fun read(uri: Uri): ByteArray {
        return requireActivity().contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Cannot open document input" }
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var total = 0
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                require(total <= MAX_BACKUP_BYTES) { "Backup is too large" }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
    }

    private fun createPdf(title: String, lines: List<String>): ByteArray {
        val document = PdfDocument()
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            textSize = 11f
            color = android.graphics.Color.rgb(32, 38, 50)
        }
        val heading = Paint(body).apply {
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            textSize = 19f
        }
        val width = 595
        val height = 842
        val margin = 42f
        val contentWidth = width - margin * 2
        var pageNumber = 0
        var page: PdfDocument.Page? = null
        var y = 0f

        fun startPage() {
            page?.let(document::finishPage)
            pageNumber++
            page = document.startPage(
                PdfDocument.PageInfo.Builder(width, height, pageNumber).create(),
            )
            y = margin
            page!!.canvas.drawText(title, margin, y + 18f, heading)
            y += 42f
        }

        fun drawWrapped(text: String) {
            if (text.isEmpty()) {
                y += 10f
                return
            }
            var remaining = text
            while (remaining.isNotEmpty()) {
                if (y > height - margin - 20f) startPage()
                val count = body.breakText(
                    remaining,
                    true,
                    contentWidth,
                    null,
                ).coerceAtLeast(1)
                val segment = remaining.substring(0, count)
                page!!.canvas.drawText(segment, margin, y, body)
                y += 17f
                remaining = remaining.substring(count)
            }
        }

        startPage()
        for (line in lines) drawWrapped(line)
        page?.let(document::finishPage)
        val output = ByteArrayOutputStream()
        document.writeTo(output)
        document.close()
        return output.toByteArray()
    }

    private fun requireActivity(): Activity =
        requireNotNull(activity) { "Activity is unavailable" }
}

private class MentalHealthFieldCipher {
    private val alias = "quote_app_mental_health_field_key"
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun getOrCreateKey(): SecretKey {
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = javax.crypto.KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    fun encrypt(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val iv = cipher.iv
        return byteArrayOf(iv.size.toByte()) + iv + cipher.doFinal(plain)
    }

    fun decrypt(blob: ByteArray): ByteArray {
        require(blob.isNotEmpty()) { "Encrypted value is empty" }
        val ivSize = blob[0].toInt() and 0xFF
        require(ivSize in 12..16 && blob.size > 1 + ivSize) {
            "Invalid encrypted value"
        }
        val iv = blob.copyOfRange(1, 1 + ivSize)
        val encrypted = blob.copyOfRange(1 + ivSize, blob.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, iv))
        return cipher.doFinal(encrypted)
    }

    fun deleteKey() {
        if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
    }
}

private class MentalHealthBackupCodec(
    private val iterations: Int = 310_000,
) {
    private val random = SecureRandom()
    private val magic = "PPCHKUP1".encodeToByteArray()

    fun encrypt(plain: ByteArray, password: CharArray): ByteArray {
        require(password.size >= 10) {
            "Backup password must be at least 10 characters"
        }
        val salt = ByteArray(16).also(random::nextBytes)
        val iv = ByteArray(12).also(random::nextBytes)
        val key = derive(password, salt, iterations)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(128, iv))
        val body = cipher.doFinal(plain)
        return ByteArrayOutputStream(
            magic.size + 7 + salt.size + iv.size + body.size,
        ).use { output ->
            output.write(magic)
            output.write(1)
            output.write(salt.size)
            output.write(iv.size)
            output.write(
                byteArrayOf(
                    (iterations ushr 24).toByte(),
                    (iterations ushr 16).toByte(),
                    (iterations ushr 8).toByte(),
                    iterations.toByte(),
                ),
            )
            output.write(salt)
            output.write(iv)
            output.write(body)
            output.toByteArray()
        }
    }

    fun decrypt(blob: ByteArray, password: CharArray): ByteArray {
        require(blob.size > 31) { "Backup is too small" }
        require(blob.copyOfRange(0, 8).contentEquals(magic)) {
            "Invalid backup magic"
        }
        require(blob[8].toInt() == 1) { "Unsupported backup version" }
        val saltLength = blob[9].toInt() and 0xFF
        val ivLength = blob[10].toInt() and 0xFF
        val storedIterations =
            ((blob[11].toInt() and 0xFF) shl 24) or
                ((blob[12].toInt() and 0xFF) shl 16) or
                ((blob[13].toInt() and 0xFF) shl 8) or
                (blob[14].toInt() and 0xFF)
        require(storedIterations in 100_000..2_000_000) {
            "Invalid backup KDF iterations"
        }
        val saltStart = 15
        val ivStart = saltStart + saltLength
        val bodyStart = ivStart + ivLength
        require(saltLength in 16..64 && ivLength in 12..16 && bodyStart < blob.size) {
            "Invalid backup header"
        }
        val key = derive(
            password,
            blob.copyOfRange(saltStart, ivStart),
            storedIterations,
        )
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            key,
            GCMParameterSpec(128, blob.copyOfRange(ivStart, bodyStart)),
        )
        return cipher.doFinal(blob.copyOfRange(bodyStart, blob.size))
    }

    private fun derive(
        password: CharArray,
        salt: ByteArray,
        count: Int,
    ): SecretKeySpec {
        val spec = PBEKeySpec(password, salt, count, 256)
        return try {
            val bytes = SecretKeyFactory
                .getInstance("PBKDF2WithHmacSHA256")
                .generateSecret(spec)
                .encoded
            try {
                SecretKeySpec(bytes, "AES")
            } finally {
                bytes.fill(0)
            }
        } finally {
            spec.clearPassword()
        }
    }
}

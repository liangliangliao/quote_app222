package com.example.quote_app.data

import android.content.Context

// Bridge visible to Kotlin. Uses reflection to call Java DbRepository at runtime,
// to avoid compile-time dependency ordering issues in CI.
object DbRepo {
  private const val KLASS = "com.example.quote_app.data.DbRepository"

  private fun kls(): Class<*>? = try { Class.forName(KLASS) } catch (_: Throwable) { null }

  @JvmStatic fun log(ctx: Context, uid: String?, detail: String) {
    try {
      kls()?.getMethod("log", Context::class.java, String::class.java, String::class.java)
          ?.invoke(null, ctx, uid, detail)
    } catch (_: Throwable) {}
  }

  @JvmStatic fun runGuardBegin(ctx: Context, uid: String, runKey: String, src: String): Boolean {
    return try {
      val r = kls()?.getMethod("runGuardBegin",
          Context::class.java, String::class.java, String::class.java, String::class.java)
          ?.invoke(null, ctx, uid, runKey, src)
      (r as? Boolean) ?: true
    } catch (_: Throwable) { true }
  }

  @JvmStatic fun runGuardEnd(ctx: Context, uid: String, runKey: String, src: String) {
    try {
      kls()?.getMethod("runGuardEnd",
          Context::class.java, String::class.java, String::class.java, String::class.java)
          ?.invoke(null, ctx, uid, runKey, src)
    } catch (_: Throwable) {}
  }

  @JvmStatic fun markLatestSuccess(ctx: Context, uid: String) {
    try {
      kls()?.getMethod("markLatestSuccess", Context::class.java, String::class.java)
          ?.invoke(null, ctx, uid)
    } catch (_: Throwable) {}
  }
}

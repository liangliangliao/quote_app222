package com.example.quote_app

import android.app.Activity
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.Window
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject

/**
 * 桌面小组件专用原生轻量表单。
 *
 * 重要说明：Android AppWidget 的 RemoteViews 不支持 EditText/Spinner 这类完整表单控件，
 * 因此“完全在桌面小组件卡片内部输入完整表单”在系统能力上不可稳定实现。
 * 这个 Activity 使用 Dialog 样式直接从桌面小组件拉起，不进入 Flutter 首页，
 * 也不再弹通知；点击小组件按钮后就是对应层面的表单，保存后立即关闭。
 */
class BehaviorObservationWidgetFormActivity : Activity() {
  private val fields = LinkedHashMap<String, EditText>()
  private lateinit var categorySpinner: Spinner
  private lateinit var layer: String

  override fun onCreate(savedInstanceState: Bundle?) {
    requestWindowFeature(Window.FEATURE_NO_TITLE)
    super.onCreate(savedInstanceState)
    layer = normalizeLayer(intent?.getStringExtra("primaryLayer"))
    buildUi()
  }

  private fun buildUi() {
    val root = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(dp(18), dp(16), dp(18), dp(14))
      setBackgroundColor(0xFFFFFFFF.toInt())
    }

    val title = TextView(this).apply {
      text = "${layer.replace("层面", "")}观察"
      textSize = 22f
      setTextColor(0xFF0F172A.toInt())
      typeface = android.graphics.Typeface.DEFAULT_BOLD
    }
    root.addView(title)

    val sub = TextView(this).apply {
      text = "来自桌面小组件 · 填完保存后自动关闭"
      textSize = 13f
      setTextColor(0xFF64748B.toInt())
      setPadding(0, dp(4), 0, dp(12))
    }
    root.addView(sub)

    categorySpinner = Spinner(this)
    val categories = listOf("未分类", "屏幕使用时间", "工作/学习", "娱乐", "生活事务", "休息", "人际", "健康", "自律", "消费", "其他")
    categorySpinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, categories)
    val defaultCategory = when (layer) {
      "身体状态层面" -> "健康"
      "时间层面" -> "未分类"
      else -> "未分类"
    }
    categorySpinner.setSelection(categories.indexOf(defaultCategory).coerceAtLeast(0))
    val catLabel = TextView(this).apply {
      text = "类别（必选）"
      textSize = 13f
      setTextColor(0xFF475569.toInt())
      setPadding(0, 0, 0, dp(4))
    }
    root.addView(catLabel)
    root.addView(categorySpinner, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(48)))

    val hint = TextView(this).apply {
      text = layerHint(layer)
      textSize = 13f
      setTextColor(0xFF4F5FA3.toInt())
      setPadding(0, dp(10), 0, dp(8))
    }
    root.addView(hint)

    for ((key, label) in fieldDefinitions(layer)) {
      root.addView(makeField(key, label))
    }

    val buttons = LinearLayout(this).apply {
      orientation = LinearLayout.HORIZONTAL
      gravity = Gravity.END
      setPadding(0, dp(14), 0, 0)
    }
    val cancel = Button(this).apply {
      text = "取消"
      setOnClickListener { finish() }
    }
    val save = Button(this).apply {
      text = "保存记录"
      setTextColor(0xFFFFFFFF.toInt())
      setBackgroundColor(0xFF4F5FA3.toInt())
      setOnClickListener { saveRecord() }
    }
    buttons.addView(cancel, LinearLayout.LayoutParams(0, dp(48), 1f).apply { marginEnd = dp(8) })
    buttons.addView(save, LinearLayout.LayoutParams(0, dp(48), 1f).apply { marginStart = dp(8) })
    root.addView(buttons)

    val scroll = ScrollView(this).apply { addView(root) }
    setContentView(scroll)
  }

  private fun makeField(key: String, label: String): View {
    val box = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(0, dp(5), 0, dp(5))
    }
    val tv = TextView(this).apply {
      text = label
      textSize = 13f
      setTextColor(0xFF475569.toInt())
      setPadding(0, 0, 0, dp(4))
    }
    val singleLine = key.contains("time") || key == "focus" || key == "intensity" || key == "steps" || key == "exercise"
    val edit = EditText(this).apply {
      hint = label
      textSize = 15f
      setSingleLine(singleLine)
      minLines = if (singleLine) 1 else 2
      inputType = when {
        key.contains("time") -> InputType.TYPE_CLASS_DATETIME
        key == "focus" || key == "intensity" || key == "steps" || key == "exercise" -> InputType.TYPE_CLASS_NUMBER
        else -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
      }
    }
    fields[key] = edit
    box.addView(tv)
    box.addView(edit, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, if (singleLine) dp(48) else dp(82)))
    return box
  }

  private fun saveRecord() {
    val values = JSONObject()
    for ((key, edit) in fields) values.put(key, edit.text?.toString()?.trim() ?: "")
    val hasAny = fields.values.any { !it.text?.toString()?.trim().isNullOrEmpty() }
    if (!hasAny) {
      Toast.makeText(this, "至少填写一个字段", Toast.LENGTH_SHORT).show()
      return
    }
    val category = categorySpinner.selectedItem?.toString()?.trim().orEmpty().ifBlank { "未分类" }
    val id = BehaviorObservationNativeRecorder.saveFromNativeForm(this, layer, category, values)
    if (id > 0) {
      Toast.makeText(this, "已保存到行为观察", Toast.LENGTH_SHORT).show()
      finish()
    } else {
      Toast.makeText(this, "保存失败，请先打开一次 App 初始化数据库", Toast.LENGTH_LONG).show()
    }
  }

  private fun fieldDefinitions(layer: String): List<Pair<String, String>> = when (layer) {
    "时间层面" -> listOf(
      "behavior" to "做了什么 / 项目",
      "start_time" to "开始时间，例如 09:00",
      "end_time" to "结束时间，例如 10:30",
      "focus" to "专注度 1-5",
      "notes" to "备注"
    )
    "行为层面" -> listOf(
      "behavior" to "具体做了什么",
      "reason" to "为什么做 / 当时原因",
      "actual" to "实际值",
      "unit" to "单位，例如 分钟 / 次 / 页",
      "notes" to "备注"
    )
    "情绪层面" -> listOf(
      "event" to "发生了什么事件",
      "emotion" to "主要情绪",
      "intensity" to "情绪强度 1-10",
      "reaction" to "当时反应"
    )
    "认知层面" -> listOf(
      "situation" to "当时情境",
      "thought" to "自动想法",
      "reaction" to "后续行为 / 反应"
    )
    "结果层面" -> listOf(
      "behavior" to "对应行为",
      "short_result" to "短期结果",
      "long_impact" to "长期影响"
    )
    "环境层面" -> listOf(
      "location" to "地点",
      "people" to "身边人",
      "objects" to "物品 / 手机 / 环境线索",
      "effect" to "环境如何影响了行为"
    )
    "身体状态层面" -> listOf(
      "sleep" to "睡眠，例如 1:00-8:00 / 7小时",
      "energy" to "精力状态",
      "fatigue" to "疲劳 / 困倦 / 头痛",
      "steps" to "步数",
      "exercise" to "运动分钟"
    )
    else -> listOf("behavior" to "具体做了什么", "notes" to "备注")
  }

  private fun layerHint(layer: String): String = when (layer) {
    "时间层面" -> "记录时间花在哪里：项目、开始/结束、专注度。"
    "行为层面" -> "记录可观察行为：做了什么、原因、实际量。"
    "情绪层面" -> "记录事件—情绪—强度—反应。"
    "认知层面" -> "记录情境—自动想法—后续行为。"
    "结果层面" -> "记录行为带来的短期结果和长期影响。"
    "环境层面" -> "记录地点、人、手机/物品等环境线索。"
    "身体状态层面" -> "记录睡眠、精力、疲劳、步数和运动。"
    else -> "记录一条行为观察。"
  }

  private fun normalizeLayer(raw: String?): String = when {
    raw?.contains("时间") == true -> "时间层面"
    raw?.contains("情绪") == true -> "情绪层面"
    raw?.contains("认知") == true -> "认知层面"
    raw?.contains("结果") == true -> "结果层面"
    raw?.contains("环境") == true -> "环境层面"
    raw?.contains("身体") == true -> "身体状态层面"
    raw?.contains("行为") == true -> "行为层面"
    else -> "行为层面"
  }

  private fun dp(value: Int): Int = (value * resources.displayMetrics.density + 0.5f).toInt()
}

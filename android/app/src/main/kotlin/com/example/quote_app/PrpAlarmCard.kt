package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import org.json.JSONObject

/** Pull-only slot inside the existing alarm UI. A receipt is never a completion. */
class PrpAlarmCard(context: Context, private val payload: JSONObject): LinearLayout(context) {
    private val handler=Handler(Looper.getMainLooper())
    private var registered=false
    private var current: PrpAlarmBridge.Hint?=null
    private val changed=object: BroadcastReceiver() { override fun onReceive(c:Context?,i:Intent?) { refresh() } }
    init { orientation=VERTICAL; tag="prp_native_card"; refresh() }
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if(!registered) {
            ContextCompat.registerReceiver(context,changed,IntentFilter(PrpAlarmBridge.ACTION_CHANGED),ContextCompat.RECEIVER_NOT_EXPORTED)
            registered=true
        }
    }
    override fun onDetachedFromWindow() {
        if(registered)try { context.unregisterReceiver(changed) }catch(_:Throwable){}
        registered=false
        PrpAlarmAudio.stop()
        super.onDetachedFromWindow()
    }
    fun refresh() {
        val value=PrpAlarmBridge.hint(context,payload)
        current=value
        removeAllViews()
        visibility=if(value==null)View.GONE else View.VISIBLE
        if(value==null)return
        setPadding(dp(12),dp(12),dp(12),dp(12));setBackgroundColor(Color.rgb(255,243,216))
        addView(TextView(context).apply {text="上次盖印的话 · 尚未验证";setTextColor(Color.rgb(86,86,139));typeface=Typeface.DEFAULT_BOLD})
        addView(TextView(context).apply {text="有效：${value.worked}";setTextColor(Color.rgb(50,124,120));textSize=16f})
        addView(TextView(context).apply {text=value.rule;setTextColor(Color.rgb(35,40,45));textSize=18f;setPadding(0,dp(6),0,dp(6))})
        val actions=LinearLayout(context).apply{orientation=HORIZONTAL}
        actions.addView(Button(context).apply {text="这次试试";tag="prp_native_adopt";setOnClickListener {
            if(PrpAlarmBridge.adopt(context,value)){text="已选择试一试，等结果再记账";isEnabled=false}
        }},LayoutParams(0,LayoutParams.WRAP_CONTENT,1f))
        if(value.voicePath.isNotBlank()&&PrpAlarmBridge.stillAllowed(context,value,voice=true))actions.addView(Button(context).apply {
            text="播放自己的提示";tag="prp_native_play";setOnClickListener {
                if(!PrpAlarmAudio.play(context,value))Toast.makeText(context,"录音暂不可用，请检查声音授权或文件。",Toast.LENGTH_SHORT).show()
            }
        },LayoutParams(0,LayoutParams.WRAP_CONTENT,1f))
        addView(actions)
        addView(TextView(context).apply {text="有真实结果后再记账；收到提醒不等于做到了。";setTextColor(Color.DKGRAY)})
        val outcomes=LinearLayout(context).apply{orientation=HORIZONTAL}
        for((textValue,outcome) in listOf("试过，有帮助" to "helped","试过，没挡住" to "repeated","这次先不用" to "ignored")) {
            outcomes.addView(Button(context).apply {text=textValue;textSize=13f;setOnClickListener {
                if(PrpAlarmBridge.report(context,value,outcome)) { PrpAlarmAudio.stop(); refresh() }
            }},LayoutParams(0,LayoutParams.WRAP_CONTENT,1f))
        }
        addView(outcomes)
        handler.post { if(current !== value || !PrpAlarmBridge.stillAllowed(context,value)) { visibility=View.GONE;PrpAlarmAudio.stop() } }
    }
    private fun dp(n:Int)=(n*resources.displayMetrics.density).toInt()
}

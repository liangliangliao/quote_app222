package com.example.quote_app

import android.app.Instrumentation
import android.content.ContentValues
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Bundle
import android.view.View
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Calendar
import kotlin.math.sin

/** Never compiled into release; refuses to modify anything except a disposable emulator. */
class PrpAcceptanceProbe: Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    private val evidence=JSONArray()
    private fun pass(name:String) { evidence.put(name) }
    private fun waitFor(message:String, condition:()->Boolean) {
        val end=System.currentTimeMillis()+8000
        while(!condition()&&System.currentTimeMillis()<end)Thread.sleep(50)
        check(condition()){message}
    }
    override fun onStart() {
        val result=Bundle()
        try {
            check(Build.HARDWARE in listOf("ranchu","goldfish")){"Disposable emulator only"}
            val ctx=targetContext.applicationContext
            val dir=File(ctx.applicationInfo.dataDir,"app_flutter")
            val fixture=JSONObject(File(dir,"prp_ci_fixture.json").readText())
            val presetId=fixture.getInt("preset_id")
            val database=File(dir,"quotes.db")
            check(database.isFile){"Flutter acceptance must complete first"}
            val db=SQLiteDatabase.openDatabase(database.path,null,SQLiteDatabase.OPEN_READWRITE)
            val p=JSONObject(db.rawQuery("SELECT value FROM notify_config WHERE key='prp.preferences.v1'",null).use {check(it.moveToFirst());it.getString(0)})
            p.put("enabled",true).put("recalls",true).put("recall_cap",3).put("native_reminders",true)
                .put("native_voice",true).put("voice",true)
            p.put("surfaces",p.optJSONObject("surfaces")?:JSONObject()).getJSONObject("surfaces").put("behavior",true)
            fun kv(key:String,value:String) { db.execSQL("INSERT OR REPLACE INTO notify_config(key,value) VALUES (?,?)",arrayOf(key,value)) }
            fun settings() { kv("prp.preferences.v1",p.toString());runOnMainSync{PrpAlarmBridge.stateChanged(ctx,JSONObject(p.toString()))} }
            db.execSQL("INSERT OR REPLACE INTO be_setting(key,value) VALUES ('quiet_start_hour','0')")
            db.execSQL("INSERT OR REPLACE INTO be_setting(key,value) VALUES ('quiet_end_hour','0')")
            db.execSQL("INSERT OR REPLACE INTO be_setting(key,value) VALUES ('muted_until_ms','0')")
            kv("prp.crisis_until_ms","0")
            val lessonId=9100001L
            val subject="habit:preset:$presetId"
            db.delete("prp_recall","subject_key=?",arrayOf(subject))
            db.delete("prp_lesson","id=?",arrayOf(lessonId.toString()))
            val voice=File(dir,"prp_voice/prp_ci.wav").apply{parentFile!!.mkdirs();writeBytes(wave(1000))}
            db.insertOrThrow("prp_lesson",null,ContentValues().apply {
                put("id",lessonId);put("subject_key",subject);put("source","behavior");put("category","拖延")
                put("state","sealed");put("created_ms",System.currentTimeMillis());put("sealed_ms",System.currentTimeMillis())
                put("worked","[\"把书放到桌上读了1页\"]");put("failed","[\"坐下后打开短视频\"]")
                put("trigger_text","CI 原生阅读预设");put("early_signal","准备阅读时打开短视频")
                put("if_cue","准备阅读时打开短视频");put("then_action","打开书读1页")
                put("quality",5);put("voice_path",voice.path)
            })
            val payload=JSONObject().put("type","behavior_preset_alarm").put("presetId",presetId)
                .put("presetName","CI 原生阅读预设").put("alarmId",97191001)
                .put("reminderHour",fixture.getInt("hour")).put("reminderMinute",fixture.getInt("minute"))
                .put("checkDateMs",PrpAlarmBridge.dayStart(System.currentTimeMillis()))
            fun count():Int=db.rawQuery("SELECT COUNT(*) FROM prp_recall",null).use{it.moveToFirst();it.getInt(0)}
            p.put("enabled",false);settings();val before=count()
            check(PrpAlarmBridge.hint(ctx,payload)==null);check(count()==before);pass("master_off_no_exposure")
            p.put("enabled",true).put("native_reminders",false);settings()
            check(PrpAlarmBridge.hint(ctx,payload)==null);check(count()==before);pass("native_opt_in_required")
            p.put("native_reminders",true).put("recall_cap",0);settings()
            check(PrpAlarmBridge.hint(ctx,payload)==null);pass("daily_budget_shared")
            p.put("recall_cap",3);settings()
            val hour=Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            db.execSQL("UPDATE be_setting SET value=? WHERE key='quiet_start_hour'",arrayOf(hour.toString()))
            db.execSQL("UPDATE be_setting SET value=? WHERE key='quiet_end_hour'",arrayOf(((hour+1)%24).toString()))
            check(PrpAlarmBridge.hint(ctx,payload)==null);pass("quiet_window")
            db.execSQL("UPDATE be_setting SET value='0' WHERE key IN ('quiet_start_hour','quiet_end_hour')")
            kv("prp.crisis_until_ms",(System.currentTimeMillis()+60000).toString())
            check(PrpAlarmBridge.hint(ctx,payload)==null);pass("crisis_ttl")
            kv("prp.crisis_until_ms","0")
            db.execSQL("UPDATE be_setting SET value=? WHERE key='muted_until_ms'",arrayOf((System.currentTimeMillis()+60000).toString()))
            check(PrpAlarmBridge.hint(ctx,payload)==null);pass("enemy_mute")
            db.execSQL("UPDATE be_setting SET value='0' WHERE key='muted_until_ms'")
            val unrelated=JSONObject(payload.toString()).put("presetId",presetId+999).put("presetName","去公园跑步二十分钟")
            check(PrpAlarmBridge.hint(ctx,unrelated)==null);pass("unrelated_context_hidden")
            val hint=PrpAlarmBridge.hint(ctx,payload)?:error("Expected sealed lesson")
            check(hint.lessonId==lessonId)
            check(PrpAlarmBridge.hint(ctx,payload)?.recallId==hint.recallId)
            check(count()==before+1);pass("service_overlay_form_share_one_exposure")
            check(PrpAlarmBridge.adopt(ctx,hint));check(PrpAlarmBridge.adopt(ctx,hint))
            check(db.rawQuery("SELECT COUNT(*) FROM prp_event WHERE recall_id=?",arrayOf(hint.recallId.toString())).use{it.moveToFirst();it.getInt(0)}==1)
            pass("adoption_idempotent_pending")
            check(PrpAlarmAudio.validClip(ctx,voice.path))
            val outside=File(ctx.filesDir,"outside.wav").apply{writeBytes(wave(1000))}
            check(!PrpAlarmAudio.validClip(ctx,outside.path))
            val longClip=File(voice.parentFile,"too_long.wav").apply{writeBytes(wave(17000))}
            check(!PrpAlarmAudio.validClip(ctx,longClip.path));pass("audio_owned_path_and_duration")

            val activity=startActivitySync(Intent(ctx,BehaviorPresetAlarmFormActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("payload",payload.toString()))
            waitForIdleSync();Thread.sleep(700)
            runOnMainSync {
                val card=activity.window.decorView.findViewWithTag<View>("prp_native_card")
                check(card!=null&&card.visibility==View.VISIBLE&&card.getGlobalVisibleRect(android.graphics.Rect())){"Native PRP card not visible"}
            }
            screenshot("native_01_on");pass("native_form_actual_view")
            BehaviorPresetAlarmSettings.set(ctx,null,null,.2f,false)
            runOnMainSync { check(PrpAlarmAudio.play(ctx,hint)) }
            waitFor("Local MediaPlayer did not start"){PrpAlarmAudio.isPlaying}
            pass("local_audio_played")
            p.put("enabled",false);settings()
            waitFor("Audio survived disabling"){!PrpAlarmAudio.isPlaying}
            waitForIdleSync()
            runOnMainSync {check(activity.window.decorView.findViewWithTag<View>("prp_native_card")?.visibility==View.GONE)}
            screenshot("native_02_off");pass("off_hides_card_and_stops_voice")
            p.put("enabled",true);settings();waitForIdleSync()
            runOnMainSync {
                BehaviorPresetAlarmRingingService.startRinging(ctx,97191001,payload.toString())
            }
            waitFor("Ringing service did not play the local PRP clip"){PrpAlarmAudio.isPlaying}
            pass("existing_ringing_service_audio")
            waitFor("Native overlay did not appear"){BehaviorPresetAlarmOverlay.isShowing()}
            waitFor("The actual overlay has no readable lesson"){hasText(uiAutomation.rootInActiveWindow,hint.rule)}
            screenshot("native_03_overlay");pass("native_overlay_actual_view")
            check(count()==before+1);pass("overlay_service_no_duplicate_exposure")
            runOnMainSync {BehaviorPresetAlarmRingingService.stopRinging(ctx)}
            waitFor("Ringing overlay did not stop"){!BehaviorPresetAlarmOverlay.isShowing()}
            check(PrpAlarmBridge.report(ctx,hint,"helped"));check(!PrpAlarmBridge.report(ctx,hint,"helped"))
            check(db.rawQuery("SELECT verified_cnt,repeated_cnt FROM prp_lesson WHERE id=?",arrayOf(lessonId.toString())).use{
                it.moveToFirst();it.getInt(0)==1&&it.getInt(1)==0})
            pass("explicit_result_once_no_false_failure")
            check(PrpAlarmBridge.hint(ctx,payload)==null);pass("settled_recall_not_reoffered")
            runOnMainSync {activity.finish();PrpAlarmAudio.stop()}
            val report=JSONObject().put("api_level",Build.VERSION.SDK_INT).put("hardware",Build.HARDWARE)
                .put("physical_device",false).put("passed",evidence).put("status","passed")
            File(ctx.filesDir,"prp-ci").apply{mkdirs()}.resolve("native-results.json").writeText(report.toString(2))
            db.close()
            result.putString("stream","PRP_NATIVE_ACCEPTANCE_PASS\n${report}\n")
            finish(-1,result)
        }catch(t:Throwable){result.putString("stream","PRP_NATIVE_ACCEPTANCE_FAILED:${t.javaClass.simpleName}:${t.message}\n");finish(1,result)}
    }
    private fun screenshot(name:String){
        val target=File(targetContext.filesDir,"prp-ci/$name.png").apply{parentFile!!.mkdirs()}
        val image=uiAutomation.takeScreenshot()?:error("No screenshot")
        target.outputStream().use{check(image.compress(android.graphics.Bitmap.CompressFormat.PNG,100,it))}
        image.recycle()
    }
    private fun hasText(node:android.view.accessibility.AccessibilityNodeInfo?, text:String):Boolean {
        if(node==null)return false
        if(node.isVisibleToUser&&node.text?.toString()==text)return true
        for(i in 0 until node.childCount)if(hasText(node.getChild(i),text))return true
        return false
    }
    private fun wave(milliseconds:Int):ByteArray{
        val count=22050*milliseconds/1000
        val buffer=ByteBuffer.allocate(44+count*2).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray()).putInt(36+count*2).put("WAVEfmt ".toByteArray())
        buffer.putInt(16).putShort(1).putShort(1).putInt(22050).putInt(44100).putShort(2).putShort(16)
        buffer.put("data".toByteArray()).putInt(count*2)
        for(i in 0 until count)buffer.putShort((sin(i*2*Math.PI*440/22050)*1000).toInt().toShort())
        return buffer.array()
    }
}

package com.kamillabs.kamiledu

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kamillabs.kamiledu/restart"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "restartApp") {
                restartApp()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun restartApp() {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_NEW_TASK)
        
        var pendingIntentFlags = PendingIntent.FLAG_CANCEL_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingIntentFlags = pendingIntentFlags or PendingIntent.FLAG_IMMUTABLE
        }
        
        val pendingIntent = PendingIntent.getActivity(this, 123456, intent, pendingIntentFlags)
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        alarmManager.set(AlarmManager.RTC, System.currentTimeMillis() + 500, pendingIntent)
        
        // Kill the process completely to force a cold start for Shorebird
        exitProcess(0)
    }
}

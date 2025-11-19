package com.example.angers_mobile_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.angers_mobile_app/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialIntent") {
                val intent = intent
                if (intent != null && intent.hasExtra("event_id")) {
                    val eventId = intent.getStringExtra("event_id")
                    val openEventDetails = intent.getBooleanExtra("open_event_details", false)
                    result.success(mapOf(
                        "event_id" to eventId,
                        "open_event_details" to openEventDetails
                    ))
                    // Réinitialiser l'intent pour éviter de le traiter plusieurs fois
                    intent.removeExtra("event_id")
                    intent.removeExtra("open_event_details")
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Notifier Flutter du nouvel intent
        try {
            val engine = flutterEngine
            if (engine != null) {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("onNewIntent", mapOf(
                    "event_id" to intent.getStringExtra("event_id"),
                    "open_event_details" to intent.getBooleanExtra("open_event_details", false)
                ))
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Erreur lors de la notification de l'intent: ${e.message}")
        }
    }
}

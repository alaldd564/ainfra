package com.example.maptest

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "tmap_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            if (call.method == "launchMapActivity") {
                val intent = Intent(this, MapActivity::class.java)
                startActivity(intent)
                result.success("OK")
            } else if (call.method == "launchMapActivityWithPublicTransitRoute") {
                val origin = call.argument<String>("origin")
                val destination = call.argument<String>("destination")

                val intent = Intent(this, MapActivity::class.java).apply {
                    putExtra("origin", origin)
                    putExtra("destination", destination)
                    putExtra("routeType", "publicTransit")
                }
                startActivity(intent)
                result.success("OK")
            } else {
                result.notImplemented()
            }
        }
    }
}
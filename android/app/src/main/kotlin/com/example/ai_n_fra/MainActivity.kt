package com.example.ai_n_fra

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity: FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val factory = TmapViewFactory(this)
        flutterEngine.platformViewsController.registry.registerViewFactory("tmap-view-type", factory)

        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
    }
}
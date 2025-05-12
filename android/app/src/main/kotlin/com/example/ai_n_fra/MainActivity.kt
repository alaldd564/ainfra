package com.example.ai_n_fra

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformViewRegistry

const val tmapViewType = "com.example.ai_n_fra/tmapView"
const val tmapMethodChannel = "com.example.ai_n_fra/tmapMethod"


class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine
            .platformViews
            .getSystemetahuiForViewId(tmapViewType) // viewType과 일치
            .create(
                context,
                flutterEngine.dartExecutor.binaryMessenger,
                StandardMessageCodec.INSTANCE,
                TMapPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )

    }
}
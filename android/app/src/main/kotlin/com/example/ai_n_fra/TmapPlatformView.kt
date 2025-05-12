package com.example.ai_n_fra

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import com.skt.Tmap.TMapView

class TmapPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    id: Int,
    private val apiKey: String?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val container: FrameLayout = FrameLayout(context)
    private val tMapView: TMapView
    private val methodChannel: MethodChannel

    init {
        methodChannel = MethodChannel(messenger, "com.example.ai_n_fra/tmap_view_$id")
        methodChannel.setMethodCallHandler(this)

        tMapView = TMapView(context)

        container.addView(tMapView)

        if (apiKey != null && apiKey.isNotEmpty()) {
            tMapView.setSKTMapApiKey(apiKey)
        } else {
            println("Tmap API Key is not provided!")
        }

        tMapView.setOnMapReadyListener(TMapView.OnMapReadyListener {
            println("Tmap map is ready!")
        })
    }

    override fun getView(): View {
        return container
    }

    override fun dispose() {
        tMapView.destroyMapView()
    }

    // Flutter로부터 호출된 메소드 처리
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            else -> result.notImplemented()
        }
    }
}
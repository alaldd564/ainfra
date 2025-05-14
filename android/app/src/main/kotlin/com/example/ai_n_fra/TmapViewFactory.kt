package com.example.ai_n_fra

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.skt.Tmap.TMapView

class TmapViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val params = args as? Map<String, Any>
        val apiKey = params?.get("apiKey") as? String

        return TmapPlatformView(context, messenger, id, apiKey)
    }
}
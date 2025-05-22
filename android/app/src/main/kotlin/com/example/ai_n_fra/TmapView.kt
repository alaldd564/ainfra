package com.example.ai_n_fra

import android.content.Context
import android.view.View
import com.skt.Tmap.TMapView
import io.flutter.plugin.platform.PlatformView

internal class TmapView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?
) : PlatformView {

    private val tmapView: TMapView

    init {
        tmapView = TMapView(context)

        tmapView.setSKTMapApiKey("38JSi1Qh2S1NQ5jG3KK9q5CAtK4f6s5a3fOma0RK") //TMAP App KEY

        val initialLatitude = creationParams?.get("initialLatitude") as? Double ?: 37.5665 // 예제 서울 시청 위도
        val initialLongitude = creationParams?.get("initialLongitude") as? Double ?: 126.9780 // 서울 시청 경도
        val initialZoom = creationParams?.get("initialZoom") as? Double ?: 11.0 // 줌 레벨

        tmapView.setCenterPoint(initialLongitude, initialLatitude)
        tmapView.setZoomLevel(initialZoom.toInt())

        tmapView.setMapType(TMapView.MAPTYPE_STANDARD)
        tmapView.setLanguage(TMapView.LANGUAGE_KOREAN)

    }

    override fun getView(): View {
        return tmapView
    }

    override fun dispose() {
    }
}
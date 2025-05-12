package ai_n_fra

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.View
import com.skt.tmap.TMapData
import com.skt.tmap.TMapMarkerItem
import com.skt.tmap.TMapPoint
import com.skt.tmap.TMapView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView

const val tmapMethodChannel = "com.example.ai_n_fra/tmapMethod"

internal class TMapPlatformView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
    binaryMessenger: BinaryMessenger
) : PlatformView, MethodCallHandler {

    private val tMapView: TMapView = TMapView(context).apply {
        setSKTMapApiKey("NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa")
        setOnMapReadyListener(object : TMapView.OnMapReadyListener {
            override fun onMapReady(p0: TMapView?) {
                println("✅ TMap is ready.")
            }
        })
    }

    private val methodChannel = MethodChannel(binaryMessenger, tmapMethodChannel).also {
        it.setMethodCallHandler(this)
    }

    private var currentLocationMarker: TMapMarkerItem? = null
    private var destinationMarker: TMapMarkerItem? = null
    private val tmapData = TMapData()

    override fun getView(): View = tMapView

    override fun dispose() {
        tMapView.removeTMapvariable()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setUserLocation" -> {
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                if (latitude != null && longitude != null) {
                    println("📍 위치 수신: $latitude, $longitude")
                    addCurrentLocationMarker(latitude, longitude)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "위도/경도가 null입니다.", null)
                }
            }

            "setDestination" -> {
                val destinationName = call.argument<String>("destinationName")
                if (!destinationName.isNullOrEmpty()) {
                    println("🎯 목적지 수신: $destinationName")
                    val destLat = 37.555955
                    val destLon = 126.972317
                    addDestinationMarker(destLat, destLon, destinationName)
                    setMapCenter(destLat, destLon)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "목적지 이름이 비어 있습니다.", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun setMapCenter(latitude: Double, longitude: Double) {
        if (!tMapView.isMapReady) return
        tMapView.setCenterPoint(longitude, latitude, true)
    }

    private fun addCurrentLocationMarker(latitude: Double, longitude: Double) {
        if (!tMapView.isMapReady) return

        val point = TMapPoint(latitude, longitude)
        currentLocationMarker?.let { tMapView.removeMarkerItem(it.id) }

        currentLocationMarker = TMapMarkerItem().apply {
            id = "current_location_marker"
            tMapPoint = point
            icon = BitmapFactory.decodeResource(tMapView.resources, android.R.drawable.ic_menu_mylocation)
            setPosition(0.5f, 1.0f)
            name = "현재 위치"
            setCalloutRect(10, 10, 10, 10)
        }

        tMapView.addMarkerItem(currentLocationMarker!!.id, currentLocationMarker)
        println("✅ 현재 위치 마커 표시 완료.")
    }

    private fun addDestinationMarker(latitude: Double, longitude: Double, name: String) {
        if (!tMapView.isMapReady) return

        val point = TMapPoint(latitude, longitude)
        destinationMarker?.let { tMapView.removeMarkerItem(it.id) }

        destinationMarker = TMapMarkerItem().apply {
            id = "destination_marker"
            tMapPoint = point
            icon = BitmapFactory.decodeResource(tMapView.resources, android.R.drawable.ic_menu_close_clear_cancel)
            setPosition(0.5f, 1.0f)
            this.name = name
            setCalloutRect(10, 10, 10, 10)
        }

        tMapView.addMarkerItem(destinationMarker!!.id, destinationMarker)
        println("✅ 목적지 마커 표시 완료: $name")
    }
}

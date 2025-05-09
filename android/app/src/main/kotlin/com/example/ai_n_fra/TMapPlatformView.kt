
package ai_n_fra

import android.content.Context
import android.graphics.BitmapFactory
import android.view.View
import com.skt.Tmap.TMapMarkerItem
import com.skt.Tmap.TMapPoint
import com.skt.Tmap.TMapView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import com.skt.Tmap.TMapData
import android.graphics.Bitmap
import android.graphics.Color

const val tmapMethodChannel = "com.example.ai_n_fra/tmapMethod"

internal class TMapPlatformView(context: Context, id: Int, creationParams: Map<String?, Any?>?, binaryMessenger: BinaryMessenger) : PlatformView, MethodCallHandler {
    private val tMapView: TMapView
    private val methodChannel: MethodChannel

    private var currentLocationMarker: TMapMarkerItem? = null
    private var destinationMarker: TMapMarkerItem? = null

    private val tmapData = TMapData()

    init {
        tMapView = TMapView(context)
        tMapView.setSKTMapApiKey("NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa")

        tMapView.setOnMapReadyListener(object : TMapView.OnMapReadyListener {
            override fun onMapReady(p0: TMapView?) {
                println("TMap Ready!")
                // Map is ready, now we can safely interact with it.
                // Initial centering and marker addition should happen here if
                // location was already obtained before the map was ready.
                // Flutter side calls setUserLocation/setDestination after view creation,
                // so this might just be for confirmation.
            }
        })

        methodChannel = MethodChannel(binaryMessenger, tmapMethodChannel)
        methodChannel.setMethodCallHandler(this)
    }

    override fun getView(): View {
        return tMapView // 생성한 TMapView 인스턴스 반환
    }

    override fun dispose() {
        tMapView.removeTMapvariable() // TMapView 자원 해제
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setUserLocation" -> {
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                if (latitude != null && longitude != null) {
                    println("Received current location from Flutter: Lat $latitude, Lon $longitude")
                    addCurrentLocationMarker(latitude, longitude) // 현재 위치 마커 추가
                    // 현재 위치 받을 때마다 지도를 이동할지 선택
                    // setMapCenter(latitude, longitude)
                    result.success(null) // 성공 응답
                } else {
                    result.error("INVALID_ARGUMENTS", "Latitude and longitude must not be null", null)
                }
            }
            "setDestination" -> {
                val destinationName = call.argument<String>("destinationName")
                if (destinationName != null && destinationName.isNotEmpty()) {
                    println("Received destination name from Flutter: $destinationName")
                    val destLat = 37.555955 // 서울역 위도 예시
                    val destLon = 126.972317 // 서울역 경도 예시

                    addDestinationMarker(destLat, destLon, destinationName)

                    setMapCenter(destLat, destLon) // 목적지 중심으로 이동 예시
                    
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "Destination name must not be null or empty", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    // 지도 중심 설정
    private fun setMapCenter(latitude: Double, longitude: Double) {
        if (!tMapView.isMapReady) return // MapReady 확인

        val tMapPoint = TMapPoint(latitude, longitude)
        // setCenterPoint(경도, 위도, 애니메이션 여부)
        tMapView.setCenterPoint(longitude, latitude, true)
        // tMapView.zoomLevel = 16 // 적절한 줌 레벨 설정
    }

    private fun addCurrentLocationMarker(latitude: Double, longitude: Double) {
        if (!tMapView.isMapReady) return // MapReady 확인

        val tMapPoint = TMapPoint(latitude, longitude)

        if (currentLocationMarker != null) {
            tMapView.removeMarkerItem(currentLocationMarker!!.id)
        }

        // 마커 생성
        val markerItem = TMapMarkerItem()
        markerItem.id = "current_location_marker" // 현재 위치 마커 고유 ID
        markerItem.tMapPoint = tMapPoint // 마커 위치

        val bitmap: Bitmap = BitmapFactory.decodeResource(tMapView.resources, android.R.drawable.ic_menu_mylocation)
        markerItem.icon = bitmap
        markerItem.setPosition(0.5f, 1.0f) // 아이콘 중심점 설정 (하단 중앙)
        markerItem.name = "현재 위치" // 마커 이름
        markerItem.setCalloutRect(10,10,10,10) // 정보창 여백

        // 지도에 마커 추가
        tMapView.addMarkerItem(markerItem.id, markerItem)
        currentLocationMarker = markerItem // 현재 마커 인스턴스 저장
        println("Current location marker added.")

        // 현재 위치 받을 때마다 지도를 해당 위치로 이동하는 코드(아래)
        // setMapCenter(latitude, longitude)
        // tMapView.zoomLevel = 16 // 줌 레벨 조정
    }

    // 목적지 마커를 지도에 추가하는 함수
    private fun addDestinationMarker(latitude: Double, longitude: Double, name: String) {
        if (!tMapView.isMapReady) return

        val tMapPoint = TMapPoint(latitude, longitude)

        if (destinationMarker != null) {
            tMapView.removeMarkerItem(destinationMarker!!.id)
        }

        val markerItem = TMapMarkerItem()
        markerItem.id = "destination_marker" // 목적지 마커 고유 ID
        markerItem.tMapPoint = tMapPoint // 마커 위치

        val bitmap = BitmapFactory.decodeResource(tMapView.resources, android.R.drawable.ic_menu_close_clear_cancel)
        markerItem.icon = bitmap
        markerItem.setPosition(0.5f, 1.0f) // 아이콘 중심점 설정
        markerItem.name = name // 마커 이름 (정보창 표시용)
        markerItem.setCalloutRect(10,10,10,10)

        // 지도 마커 추가
        tMapView.addMarkerItem(markerItem.id, markerItem)
        destinationMarker = markerItem // 목적지 마커 인스턴스 저장
        println("Destination marker added for: $name")

        setMapCenter(latitude, longitude)
    }
}
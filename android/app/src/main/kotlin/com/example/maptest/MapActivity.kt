package com.example.maptest

import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.speech.tts.TextToSpeech
import androidx.appcompat.app.AppCompatActivity
import com.skt.tmap.*
import com.skt.tmap.TMapData.TMapPathType
import com.skt.tmap.overlay.TMapMarkerItem
import io.flutter.plugin.common.MethodChannel
import java.util.*
import android.os.Handler
import android.os.Looper
import com.google.android.gms.location.*

class MapActivity : AppCompatActivity(), TextToSpeech.OnInitListener {

    private lateinit var tmapView: TMapView
    private val tmapData = TMapData()

    private lateinit var tts: TextToSpeech
    private var ttsReady = false

    private val handler = Handler(Looper.getMainLooper())

    private var isNearDestination = false
    private var endPoint: TMapPoint? = null
    private val waypoints = mutableListOf<TMapPoint>()

    private var currentWaypointIndex = 0

    // Flutter 플랫폼 채널 변수
    private val CHANNEL = "com.example.taxi/navigation"
    private lateinit var methodChannel: MethodChannel

    // 위치 권한 요청 코드
    private val LOCATION_PERMISSION_REQUEST_CODE = 1000

    // FusedLocationProviderClient 및 LocationCallback
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    /*
    // 시뮬레이터 (GPS 대신 테스트용 이동 위치)
    private val locationSimulator = object : Runnable {
        override fun run() {
            val currentLocation = tmapView.getLocationPoint()
            val simulatedLat = currentLocation.latitude + 0.0001
            val simulatedLng = currentLocation.longitude + 0.0001
            updateUserLocationOnMap(simulatedLat, simulatedLng)
            handler.postDelayed(this, 3000)
        }
    }
    */

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        tmapView = TMapView(this)
        tmapView.setSKTMapApiKey("NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa")
        setContentView(tmapView)

        tts = TextToSpeech(this, this)

        // Flutter 플랫폼 채널 초기화
        methodChannel = MethodChannel(
            (application as io.flutter.app.FlutterApplication).flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "startNavigationWithWaypoints") {
                val startLat = call.argument<Double>("startLat") ?: 0.0
                val startLng = call.argument<Double>("startLng") ?: 0.0
                val endLat = call.argument<Double>("endLat") ?: 0.0
                val endLng = call.argument<Double>("endLng") ?: 0.0
                val waypointsList = call.argument<List<Map<String, Double>>>("waypoints") ?: emptyList()

                val startPoint = TMapPoint(startLat, startLng)
                endPoint = TMapPoint(endLat, endLng)

                waypoints.clear()
                waypointsList.forEach {
                    val lat = it["lat"] ?: 0.0
                    val lng = it["lng"] ?: 0.0
                    waypoints.add(TMapPoint(lat, lng))
                }

                drawRouteWithWaypoints(startPoint, waypoints, endPoint!!)
                // handler.postDelayed(locationSimulator, 3000)  // 시뮬레이터 호출 제거

                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        checkLocationPermission()  // 권한 확인 및 위치 업데이트 시작
    }

    // 권한 체크 함수
    private fun checkLocationPermission() {
        if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(android.Manifest.permission.ACCESS_FINE_LOCATION),
                LOCATION_PERMISSION_REQUEST_CODE
            )
        } else {
            startLocationUpdates()
        }
    }

    // 권한 결과 콜백
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startLocationUpdates()
            } else {
                speak("위치 권한이 필요합니다.")
            }
        }
    }

    // 위치 업데이트 시작
    private fun startLocationUpdates() {
        val locationRequest = LocationRequest.create().apply {
            interval = 3000
            fastestInterval = 1000
            priority = LocationRequest.PRIORITY_HIGH_ACCURACY
        }

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.locations.forEach { location ->
                    val lat = location.latitude
                    val lng = location.longitude
                    updateUserLocationOnMap(lat, lng)
                }
            }
        }

        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
    }

    private fun drawRouteWithWaypoints(start: TMapPoint, waypoints: List<TMapPoint>, end: TMapPoint) {
        val fullRoute = mutableListOf<TMapPoint>()
        fullRoute.add(start)
        fullRoute.addAll(waypoints)
        fullRoute.add(end)

        // 경로 및 마커 표시
        for (i in 0 until fullRoute.size - 1) {
            val from = fullRoute[i]
            val to = fullRoute[i + 1]

            tmapData.findPathDataWithType(
                TMapPathType.PEDESTRIAN_PATH,
                from,
                to,
                object : TMapData.FindPathDataListenerCallback {
                    override fun onFindPathData(path: TMapPolyLine?) {
                        path?.let {
                            runOnUiThread {
                                tmapView.addTMapPolyLine("segment_$i", it)
                                if (i == 0) {
                                    tmapView.setCenterPoint(from.longitude, from.latitude)
                                    tmapView.zoomLevel = 17
                                }
                            }
                        }
                    }
                }
            )

            // 경유지 마커 추가 (start 제외)
            if (i in 1..waypoints.size) {
                val marker = TMapMarkerItem().apply {
                    tMapPoint = from
                    name = "경유지 $i"
                }
                tmapView.addTMapMarkerItem("waypoint_$i", marker)
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts.language = Locale.KOREAN
            tts.setSpeechRate(1.0f)
            ttsReady = true
        }
    }

    override fun onDestroy() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
        tts.stop()
        tts.shutdown()
        // handler.removeCallbacks(locationSimulator)  // 시뮬레이터 호출 중지 주석처리
        super.onDestroy()
    }

    private fun speak(text: String) {
        if (ttsReady) {
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
        }
    }

    private fun vibratePhone() {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        val effect = VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE)
        vibrator.vibrate(effect)
    }

    private fun updateUserLocationOnMap(lat: Double, lng: Double) {
        val userPoint = TMapPoint(lat, lng)

        val marker = TMapMarkerItem().apply {
            tMapPoint = userPoint
            name = "현재 위치"
        }

        tmapView.removeTMapMarkerItem("user")
        tmapView.addTMapMarkerItem("user", marker)
        tmapView.setCenterPoint(lng, lat)

        // 경유지 도달 체크
        if (currentWaypointIndex < waypoints.size) {
            val waypoint = waypoints[currentWaypointIndex]
            if (userPoint.distance(waypoint) < 30) {
                speak("경유지 ${currentWaypointIndex + 1}에 도착했습니다.")
                currentWaypointIndex++
            }
        }

        // 도착지 거리 계산
        endPoint?.let { dest ->
            val distance = userPoint.distance(dest)

            if (distance < 100 && !isNearDestination) {
                isNearDestination = true
                speak("목적지에 거의 도착했습니다.")
            }

            if (distance < 20) {
                speak("목적지에 도착했습니다.")
                vibratePhone()
            }
        }
    }
}

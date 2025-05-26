package com.example.ai_n_fra

import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

import com.skt.tmap.TMapView
import com.skt.tmap.MapPoint
import com.skt.tmap.TMapMarkerItem
import com.skt.tmap.overlay.TMapPolyLine
import com.skt.tmap.TMapData
import com.skt.tmap.data.TMapPathType
import com.skt.tmap.poi.TMapPOIItem
import com.skt.tmap.openapi.TMapPoint //해당 import 수정 필요


class MapActivity : AppCompatActivity() {
    private lateinit var tmapView: TMapView
    private val API_KEY = "NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        tmapView = TMapView(this)
        tmapView.setSKTMapApiKey(API_KEY)
        setContentView(tmapView)

        val routeType = intent.getStringExtra("routeType")
        val origin = intent.getStringExtra("origin")
        val destination = intent.getStringExtra("destination")

        if (routeType == "publicTransit" && !origin.isNullOrEmpty() && !destination.isNullOrEmpty()) {
            Log.d("MapActivity", "대중교통 길찾기 요청: $origin -> $destination")
            findPublicTransitPath(origin, destination)
        } else {
            Log.d("MapActivity", "기본 지도 로드됨")
        }
    }

    private fun findPublicTransitPath(origin: String, destination: String) {
        val tMapData = TMapData()

        tMapData.findLocationByName(origin) { originPoints: ArrayList<TMapPOIItem>? ->
            if (originPoints != null && originPoints.isNotEmpty()) {
                val startPoint = originPoints[0].getPOIPoint()
                if (startPoint == null) {
                    Log.e("MapActivity", "출발지 주소($origin)를 좌표로 변환 실패: getPOIPoint()가 null 반환")
                    showToast("출발지를 찾을 수 없습니다.")
                    return@findLocationByName
                }

                tMapData.findLocationByName(destination) { destinationPoints: ArrayList<TMapPOIItem>? ->
                    if (destinationPoints != null && destinationPoints.isNotEmpty()) {
                        val endPoint = destinationPoints[0].getPOIPoint()
                        if (endPoint == null) {
                            Log.e("MapActivity", "도착지 주소($destination)를 좌표로 변환 실패: getPOIPoint()가 null 반환")
                            showToast("도착지를 찾을 수 없습니다.")
                            return@findLocationByName
                        }

                        tMapData.findPathDataAllType(
                            TMapPathType.PUBLIC_TRANSIT_PATH,
                            startPoint,
                            endPoint
                        ) { polyLines: ArrayList<TMapPolyLine>? ->
                            if (polyLines != null && polyLines.isNotEmpty()) {
                                Log.d("MapActivity", "대중교통 길찾기 경로 ${polyLines.size}개 발견")

                                tmapView.removeAllTMapMarker()
                                tmapView.removeAllTMapPolyLine()

                                for (polyLine in polyLines) {
                                    tmapView.addTMapPolyLine(polyLine)
                                }

                                addMarker(startPoint, "start_marker", "출발지", R.drawable.map_point)
                                addMarker(endPoint, "end_marker", "도착지", R.drawable.map_point)

                                tmapView.setCenterPoint(
                                    (startPoint.longitude + endPoint.longitude) / 2,
                                    (startPoint.latitude + endPoint.latitude) / 2
                                )
                                tmapView.setZoomLevel(13)
                            } else {
                                Log.e("MapActivity", "대중교통 길찾기 결과 없음")
                                showToast("대중교통 길찾기 결과가 없습니다.")
                            }
                        }
                    } else {
                        Log.e("MapActivity", "도착지를 찾을 수 없습니다: $destination")
                        showToast("도착지를 찾을 수 없습니다.")
                    }
                }
            } else {
                Log.e("MapActivity", "출발지를 찾을 수 없습니다: $origin")
                showToast("출발지를 찾을 수 없습니다.")
            }
        }
    }

    private fun addMarker(point: TMapPoint, id: String, title: String, iconResId: Int) {
        val marker = TMapMarkerItem().apply {
            this.id = id
            this.name = title
            this.tMapPoint = MapPoint.fromLatLng(point.latitude, point.longitude)
            this.icon = BitmapFactory.decodeResource(resources, iconResId)
            this.canShowCallout = true
            this.calloutTitle = title
        }
        tmapView.addTMapMarkerItem(marker)
    }

    private fun showToast(message: String) {
        runOnUiThread {
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        }
    }
}
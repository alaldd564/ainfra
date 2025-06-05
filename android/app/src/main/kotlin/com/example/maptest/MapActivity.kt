package com.example.maptest

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.skt.tmap.TMapView

class MapActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val tmapView = TMapView(this)
        tmapView.setSKTMapApiKey("NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa") // 필수

        // Flutter에서 전달받은 위도, 경도 (기본값 서울 좌표)
        val latitude = intent.getDoubleExtra("latitude", 37.5665)  // 서울 위도
        val longitude = intent.getDoubleExtra("longitude", 126.9780) // 서울 경도

        // 지도 중심 좌표 설정
        tmapView.setCenterPoint(longitude, latitude, true)

        // 마커 생성
        val marker = com.skt.tmap.TMapMarkerItem()
        marker.position = com.skt.tmap.TMapPoint(latitude, longitude)
        marker.name = "현재 위치"
        marker.visible = true

        // 기본 마커 아이콘 설정 (원하는 이미지로 변경 가능)
        val bitmap = android.graphics.BitmapFactory.decodeResource(resources, R.drawable.marker_icon) // R.drawable.marker_icon: 마커 아이콘 이미지 리소스 필요
        marker.icon = bitmap

        // 마커 추가
        tmapView.addMarkerItem("current_location_marker", marker)

        setContentView(tmapView)
    }
}

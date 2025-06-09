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

        // 마커 관련 코드 제거 (마커 없이 지도만 표시)

        setContentView(tmapView)
    }
}

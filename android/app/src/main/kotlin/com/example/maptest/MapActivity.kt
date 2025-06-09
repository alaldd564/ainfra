package com.example.maptest

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.skt.tmap.TMapView

class MapActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val tmapView = TMapView(this)
        tmapView.setSKTMapApiKey("NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa")

        setContentView(tmapView) // ✅ 먼저 뷰를 attach 해줍니다

        // 위도/경도 가져오기
        val latitude = intent.getDoubleExtra("latitude", 37.5665)
        val longitude = intent.getDoubleExtra("longitude", 126.9780)

        // ✅ 뷰가 attach된 이후 안전하게 처리
        tmapView.post {
            tmapView.setCenterPoint(longitude, latitude, true)
        }
    }
}

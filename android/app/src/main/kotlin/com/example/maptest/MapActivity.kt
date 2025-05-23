package com.example.maptest

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.skt.tmap.TMapView

class MapActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val tmapView = TMapView(this)
        tmapView.setSKTMapApiKey("발급받은 API 키") // 필수
        setContentView(tmapView)
    }
}

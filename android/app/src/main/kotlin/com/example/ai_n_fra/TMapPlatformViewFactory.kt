// android/app/src/main/kotlin/ai_n_fra/TMapPlatformViewFactory.kt
package ai_n_fra // <--- ★★★ 이 부분을 본인의 실제 패키지 이름으로 변경하세요 ★★★

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.BinaryMessenger

// Flutter 코드의 viewType과 일치해야 합니다. (MainActivity.kt와도 일치)
// bottom_naviate_screen.dart 파일 상단에 정의된 상수와 동일해야 합니다.
const val tmapViewType = "com.example.tmap_demo/tmapView" // <--- ★★★ 이 문자열이 Flutter 코드의 tmapViewType 상수와 정확히 일치하는지 확인하세요 ★★★

class TMapPlatformViewFactory(private val binaryMessenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    // Factory는 PlatformView 인스턴스를 생성하는 역할만 합니다.
    // Flutter와의 MethodChannel 통신 처리는 TMapPlatformView 클래스 안에서 직접 하는 것이 일반적입니다.

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?

        // TMapPlatformView 클래스가 동일 패키지에 있다고 가정하고 인스턴스화합니다.
        // 만약 다른 패키지에 있다면 import 해주어야 합니다.
        val tmapView = TMapPlatformView(context, viewId, creationParams, binaryMessenger)

        // 생성된 뷰 인스턴스를 반환합니다.
        return tmapView
    }
}
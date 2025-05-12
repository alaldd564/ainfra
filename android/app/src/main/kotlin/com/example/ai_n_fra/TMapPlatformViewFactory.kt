package ai_n_fra // ← 이 패키지명은 실제 프로젝트에 맞춰야 해

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

const val tmapViewType = "com.example.ai_n_fra/tmapView" // Flutter 쪽과 동일해야 함

class TMapPlatformViewFactory(
    private val binaryMessenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String?, Any?> // 안전한 캐스팅
        return TMapPlatformView(context, viewId, creationParams, binaryMessenger)
    }
}

package com.imchatapp

import android.content.Context
import android.view.View
import io.flutter.plugin.platform.PlatformView
import com.tencent.qgame.animplayer.AnimView
import com.tencent.qgame.animplayer.inter.IAnimListener
import com.tencent.qgame.animplayer.AnimConfig
import com.tencent.qgame.animplayer.file.AssetsFileContainer
import com.tencent.qgame.animplayer.util.ScaleType
import android.widget.FrameLayout
import java.io.File

class VapPlayerView(
    context: Context,
    id: Int,
    creationParams: Map<String, Any?>?
) : PlatformView {
    private val animView: AnimView = AnimView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        setScaleType(ScaleType.FIT_CENTER)
    }

    init {
        animView.setAnimListener(object : IAnimListener {
            override fun onVideoConfigReady(config: AnimConfig): Boolean {
                return true
            }
            override fun onVideoStart() {}
            override fun onVideoRender(frameIndex: Int, config: AnimConfig?) {}
            override fun onVideoComplete() {}
            override fun onVideoDestroy() {}
            override fun onFailed(errorType: Int, errorMsg: String?) {}
        })

        val path = creationParams?.get("path") as? String
        if (path != null && path.isNotEmpty()) {
            play(path)
        }
    }

    override fun getView(): View = animView

    override fun dispose() {
        animView.stopPlay()
    }

    private fun play(path: String) {
        val file = File(path)
        if (file.exists()) {
            animView.startPlay(file)
        } else if (path.startsWith("assets://")) {
            val assetName = path.substring("assets://".length)
            animView.startPlay(AssetsFileContainer(animView.context.assets, assetName))
        } else {
            animView.startPlay(File(path))
        }
    }
}

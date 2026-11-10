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
    private val creationParams: Map<String, Any?>?
) : PlatformView {
    private var isDisposed = false
    private var isLooping = true
    private var currentPath: String? = null

    private val animView: AnimView = AnimView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        val fitStr = creationParams?.get("fit") as? String
        if (fitStr == "cover") {
            setScaleType(ScaleType.CENTER_CROP)
        } else if (fitStr == "fill") {
            setScaleType(ScaleType.FIT_XY)
        } else {
            setScaleType(ScaleType.FIT_CENTER)
        }
    }

    init {
        isLooping = creationParams?.get("loop") as? Boolean ?: true

        animView.setAnimListener(object : IAnimListener {
            override fun onVideoConfigReady(config: AnimConfig): Boolean {
                if (isLooping) {
                    animView.setLoop(Int.MAX_VALUE)
                }
                return true
            }

            override fun onVideoStart() {}
            override fun onVideoRender(frameIndex: Int, config: AnimConfig?) {}
            override fun onVideoComplete() {}
            override fun onVideoDestroy() {}
            override fun onFailed(errorType: Int, errorMsg: String?) {
                android.util.Log.e("VapPlayerView", "AnimView playback error ($errorType): $errorMsg")
            }
        })

        val path = creationParams?.get("path") as? String
        if (path != null && path.isNotEmpty()) {
            play(path)
        }
    }

    override fun getView(): View = animView

    override fun dispose() {
        isDisposed = true
        animView.stopPlay()
    }

    private fun play(path: String) {
        currentPath = path
        if (isDisposed) return
        val file = File(path)
        if (file.exists()) {
            animView.startPlay(file)
        } else if (path.startsWith("assets://")) {
            val assetName = path.substring("assets://".length)
            animView.startPlay(AssetsFileContainer(animView.context.assets, assetName))
        } else {
            animView.startPlay(File(path))
        }
        if (isLooping) {
            animView.setLoop(Int.MAX_VALUE)
        } else {
            animView.setLoop(1)
        }
    }
}

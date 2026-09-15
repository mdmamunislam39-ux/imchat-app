package com.imchatapp

import android.app.Activity
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import com.tencent.qgame.animplayer.AnimView
import com.tencent.qgame.animplayer.inter.IAnimListener
import com.tencent.qgame.animplayer.AnimConfig
import com.tencent.qgame.animplayer.file.AssetsFileContainer
import java.io.File

class VapPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var globalAnimView: AnimView? = null
    private val overlayViewId = View.generateViewId()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        channel = MethodChannel(binding.binaryMessenger, "imchat/vap")
        channel?.setMethodCallHandler(this)

        // Register the PlatformView Factory
        binding.platformViewRegistry.registerViewFactory(
            "imchat/vap_view",
            VapPlayerViewFactory()
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        flutterPluginBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("INVALID_ARGUMENT", "URL/Path is null", null)
                    return
                }
                playGlobalOverlay(url, result)
            }
            "stop" -> {
                stopGlobalOverlay(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun playGlobalOverlay(path: String, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        currentActivity.runOnUiThread {
            try {
                val rootLayout = currentActivity.findViewById<FrameLayout>(android.R.id.content)
                if (globalAnimView == null) {
                    globalAnimView = AnimView(currentActivity).apply {
                        id = overlayViewId
                        setScaleType(com.tencent.qgame.animplayer.util.ScaleType.FIT_CENTER)
                    }
                    val params = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                    rootLayout.addView(globalAnimView, params)
                }

                globalAnimView?.visibility = View.VISIBLE
                globalAnimView?.setAnimListener(object : IAnimListener {
                    override fun onVideoConfigReady(config: AnimConfig): Boolean {
                        return true
                    }

                    override fun onVideoStart() {}

                    override fun onVideoRender(frameIndex: Int, config: AnimConfig?) {}

                    override fun onVideoComplete() {
                        currentActivity.runOnUiThread {
                            globalAnimView?.visibility = View.GONE
                        }
                    }

                    override fun onVideoDestroy() {}
                    override fun onFailed(errorType: Int, errorMsg: String?) {}
                })

                val file = File(path)
                if (file.exists()) {
                    globalAnimView?.startPlay(file)
                } else if (path.startsWith("assets://")) {
                    val assetName = path.substring("assets://".length)
                    globalAnimView?.startPlay(AssetsFileContainer(globalAnimView!!.context.assets, assetName))
                } else {
                    globalAnimView?.startPlay(File(path))
                }
                result.success(true)
            } catch (e: Exception) {
                result.error("PLAY_ERROR", e.message, null)
            }
        }
    }

    private fun stopGlobalOverlay(result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }
        currentActivity.runOnUiThread {
            try {
                globalAnimView?.stopPlay()
                globalAnimView?.visibility = View.GONE
                result.success(true)
            } catch (e: Exception) {
                result.error("STOP_ERROR", e.message, null)
            }
        }
    }

    // Activity Lifecycle bindings
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

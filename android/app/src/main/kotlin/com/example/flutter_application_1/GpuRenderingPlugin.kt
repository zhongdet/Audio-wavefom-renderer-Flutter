package com.example.flutter_application_1

import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

object GpuRenderingPlugin {
    private var renderer: MediaCodecGpuRenderer? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var mainHandler: Handler? = null
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var isExporting = false

    fun registerWith(messenger: BinaryMessenger, activity: android.app.Activity) {
        mainHandler = Handler(Looper.getMainLooper())

        val methodChannel = MethodChannel(messenger, "com.example/gpu_renderer")
        val eventChannel = EventChannel(messenger, "com.example/export_progress")

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        methodChannel.setMethodCallHandler(object : MethodCallHandler {
            override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                handleCall(call, result)
            }
        })
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startExport" -> handleStartExport(call, result)
            "cancelExport" -> handleCancelExport(result)
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStartExport(call: MethodCall, result: MethodChannel.Result) {
        if (isExporting) {
            result.error("EXPORT_IN_PROGRESS", "An export is already running", null)
            return
        }

        val outputPath = call.argument<String>("outputPath") ?: run {
            result.error("INVALID_ARGS", "outputPath is null", null); return
        }
        val width = call.argument<Int>("width") ?: 1280
        val height = call.argument<Int>("height") ?: 720
        val fps = call.argument<Int>("fps") ?: 30
        val backgroundColor = (call.argument<Long>("backgroundColor") ?: 0xFF000000L).toInt()
        val barCount = call.argument<Int>("barCount") ?: 64
        val barWidth = (call.argument<Number>("barWidth")?.toFloat()) ?: 4f
        val barSpacing = (call.argument<Number>("barSpacing")?.toFloat()) ?: 10f
        val cornerRadius = (call.argument<Number>("cornerRadius")?.toFloat()) ?: 0f
        val barColorArgb = (call.argument<Long>("barColorArgb") ?: 0xFFFFFFFFL).toInt()
        val positiveHeightScale = (call.argument<Number>("positiveHeightScale")?.toFloat()) ?: 1f
        val negativeHeightScale = (call.argument<Number>("negativeHeightScale")?.toFloat()) ?: 1f

        val frameHeightsRaw = call.argument<Any>("frameHeights")

        val doubleArray: DoubleArray = when (frameHeightsRaw) {
            is DoubleArray -> frameHeightsRaw
            is List<*> -> frameHeightsRaw.mapNotNull { (it as? Number)?.toDouble() }.toDoubleArray()
            else -> {
                result.error("INVALID_ARGS", "frameHeights has unexpected type: ${frameHeightsRaw?.javaClass?.name}", null)
                return
            }
        }

        if (barCount <= 0 || doubleArray.size < barCount) {
            result.error("INVALID_ARGS", "Invalid barCount or empty frameHeights", null)
            return
        }

        val totalFrames = doubleArray.size / barCount

        isExporting = true

        backgroundThread = HandlerThread("export-renderer")
        backgroundThread!!.start()
        backgroundHandler = Handler(backgroundThread!!.looper)

        backgroundHandler!!.post {
            try {
                val gpuRenderer = MediaCodecGpuRenderer()
                renderer = gpuRenderer
                gpuRenderer.init(width, height, fps, outputPath)

                val floatHeights = FloatArray(barCount)
                val frameIntervalNs = 1000000000L / fps
                var currentPtsNs = 0L

                for (frameIndex in 0 until totalFrames) {
                    if (!isExporting) break

                    val baseIndex = frameIndex * barCount
                    for (j in 0 until barCount) {
                        floatHeights[j] = doubleArray[baseIndex + j].toFloat().coerceIn(0f, 1f)
                    }

                    gpuRenderer.renderFrame(
                        floatHeights, barCount, barWidth, barSpacing,
                        cornerRadius, backgroundColor, barColorArgb, currentPtsNs,
                        positiveHeightScale, negativeHeightScale,
                    )

                    currentPtsNs += frameIntervalNs

                    val progress = (frameIndex + 1).toDouble() / totalFrames
                    mainHandler!!.post { eventSink?.success(progress) }
                }

                gpuRenderer.finish()

                mainHandler!!.post {
                    result.success(outputPath)
                }
            } catch (e: Exception) {
                mainHandler!!.post {
                    result.error("EXPORT_ERROR", e.message, e.stackTraceToString())
                }
            } finally {
                renderer?.release()
                renderer = null
                cleanupThread()
                isExporting = false
            }
        }
    }

    private fun handleCancelExport(result: MethodChannel.Result) {
        isExporting = false
        renderer?.release()
        renderer = null
        cleanupThread()
        result.success(null)
    }

    private fun handleDispose(result: MethodChannel.Result) {
        isExporting = false
        renderer?.release()
        renderer = null
        cleanupThread()
        eventSink = null
        result.success(null)
    }

    private fun cleanupThread() {
        backgroundThread?.quitSafely()
        backgroundThread = null
        backgroundHandler = null
    }
}

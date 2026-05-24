package com.example.flutter_application_1

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.view.Surface
import java.nio.ByteBuffer

class MediaCodecGpuRenderer {

    private var encoder: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    private var trackIndex = -1
    private var muxerStarted = false
    private val bufferInfo = MediaCodec.BufferInfo()
    private val frameRect = RectF()
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    fun init(width: Int, height: Int, fps: Int, outputPath: String) {
        val bitRate = (width * height * fps * 0.07).toInt().coerceIn(500_000, 20_000_000)

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).also {
            it.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = it.createInputSurface()
            it.start()
        }

        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    fun renderFrame(
        barHeights: FloatArray,
        barCount: Int,
        barWidth: Float,
        barSpacing: Float,
        cornerRadius: Float,
        backgroundColor: Int,
        barColor: Int,
    ) {
        val surface = inputSurface ?: throw IllegalStateException("InputSurface not initialized")
        val canvas = acquireCanvas(surface)
            ?: throw IllegalStateException("Failed to acquire Canvas from input surface")

        try {
            canvas.drawColor(backgroundColor)

            val w = canvas.width.toFloat()
            val h = canvas.height.toFloat()
            val totalBarWidth = barCount * (barWidth + barSpacing) - barSpacing
            val offsetX = (w - totalBarWidth) / 2f
            val centerY = h / 2f
            val maxBarHeight = h * 0.9f

            barPaint.color = barColor
            barPaint.style = Paint.Style.FILL

            for (i in 0 until barCount) {
                val barH = (barHeights[i] * maxBarHeight).coerceAtLeast(0f)
                if (barH <= 0.5f) continue

                val left = i * (barWidth + barSpacing) + offsetX
                val top = centerY - barH / 2f
                val right = left + barWidth
                val bottom = top + barH

                if (cornerRadius > 0f) {
                    frameRect.set(left, top, right, bottom)
                    canvas.drawRoundRect(frameRect, cornerRadius, cornerRadius, barPaint)
                } else {
                    canvas.drawRect(left, top, right, bottom, barPaint)
                }
            }
        } finally {
            surface.unlockCanvasAndPost(canvas)
            drainEncoder(false)
        }
    }

    fun finish() {
        try {
            encoder?.signalEndOfInputStream()
        } catch (_: Exception) {}

        drainEncoder(true)
    }

    private fun drainEncoder(endOfStream: Boolean) {
        val encoder = encoder ?: return
        val timeoutUs = if (endOfStream) 50_000L else 10_000L

        while (true) {
            val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, timeoutUs)

            when (outputIndex) {
                MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) break
                }
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (!muxerStarted) {
                        trackIndex = muxer!!.addTrack(encoder.outputFormat)
                        muxer!!.start()
                        muxerStarted = true
                    }
                }
                MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED -> {}
                else -> {
                    if (outputIndex >= 0) {
                        val outputBuffer: ByteBuffer = encoder.getOutputBuffer(outputIndex) ?: run {
                            encoder.releaseOutputBuffer(outputIndex, false)
                            continue
                        }

                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                            bufferInfo.size = 0
                        }

                        if (bufferInfo.size > 0 && muxerStarted && trackIndex >= 0) {
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            muxer!!.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                        }

                        encoder.releaseOutputBuffer(outputIndex, false)

                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            return
                        }
                    }
                }
            }

            if (outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER) break
        }
    }

    fun release() {
        try {
            encoder?.stop()
        } catch (_: Exception) {}
        try {
            encoder?.release()
        } catch (_: Exception) {}

        try {
            muxer?.stop()
        } catch (_: Exception) {}
        try {
            muxer?.release()
        } catch (_: Exception) {}

        inputSurface = null
        encoder = null
        muxer = null
    }

    private fun acquireCanvas(surface: Surface): Canvas? {
        return if (Build.VERSION.SDK_INT >= 31) {
            surface.lockHardwareCanvas()
        } else {
            try {
                val method = Surface::class.java.getMethod("lockHardwareCanvas")
                method.invoke(surface) as? Canvas
            } catch (_: Exception) {
                surface.lockCanvas(null)
            }
        }
    }
}

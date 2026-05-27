package com.example.flutter_application_1

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.opengl.EGL14
import android.opengl.EGLExt
import android.opengl.GLES30
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface

class MediaCodecGpuRenderer {

  companion object {
    private const val EGL_RECORDABLE_ANDROID = 0x3142
    private const val BOUNDS_TEX_WIDTH = 512
    private const val BOUNDS_TEX_HEIGHT = 128
    private const val MAX_BARS = 128
  }

  private var encoder: MediaCodec? = null
  private var muxer: MediaMuxer? = null
  private var trackIndex = -1
  private var muxerStarted = false
  private val bufferInfo = MediaCodec.BufferInfo()

  private var eglDisplay: EGLDisplay? = null
  private var eglContext: EGLContext? = null
  private var eglSurface: EGLSurface? = null
  private var eglInitialized = false

  private var program = 0
  private var quadVbo = 0
  private var barTextureId = 0
  private var boundsTextureId = 0

  private var uResolutionLoc = -1
  private var uBarCountLoc = -1
  private var uBarTextureLoc = -1
  private var uBoundsTextureLoc = -1
  private var uBgColorLoc = -1
  private var aPositionLoc = -1

  private var width = 0
  private var height = 0

  private val vertexShaderSource =
    """
        #version 300 es
        in vec2 aPosition;
        void main() {
            gl_Position = vec4(aPosition, 0.0, 1.0);
        }
    """.trimIndent()

  private val fragmentShaderSource =
    """
        #version 300 es
        precision highp float;
        precision highp isampler2D;

        uniform vec2 uResolution;
        uniform int uBarCount;
        uniform sampler2D uBarTexture;
        uniform isampler2D uBoundsTexture;
        uniform vec4 uBgColor;
        out vec4 fragColor;

        float sdRoundedRect(vec2 p, vec2 b, float r) {
            vec2 q = abs(p - b * 0.5) - b * 0.5 + r;
            return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
        }

        void main() {
            ivec2 boundsCoord = ivec2(
                int((gl_FragCoord.x - 0.5) * float($BOUNDS_TEX_WIDTH) / uResolution.x),
                int((gl_FragCoord.y - 0.5) * float($BOUNDS_TEX_HEIGHT) / uResolution.y)
            );
            int barIdx = texelFetch(uBoundsTexture, boundsCoord, 0).r;

            if (barIdx < 0 || barIdx >= uBarCount) {
                fragColor = uBgColor;
                return;
            }

            vec4 bar0 = texelFetch(uBarTexture, ivec2(barIdx * 4 + 0, 0), 0);
            float bx = bar0.x;
            float by = bar0.y;
            float bw = bar0.z;
            float bh = bar0.w;

            vec2 local = vec2(gl_FragCoord.x - bx, gl_FragCoord.y - by);
            vec4 bar1 = texelFetch(uBarTexture, ivec2(barIdx * 4 + 1, 0), 0);
            vec4 bar2 = texelFetch(uBarTexture, ivec2(barIdx * 4 + 2, 0), 0);
            vec4 bar3 = texelFetch(uBarTexture, ivec2(barIdx * 4 + 3, 0), 0);
            float topR = bar2.x;
            float botR = bar2.z;
            float cornerMask = bar3.w;

            float d;
            if (cornerMask < 1.5) {
                // Upper bar: round top corners
                d = sdRoundedRect(local, vec2(bw, bh), topR);
            } else {
                // Lower bar: round bottom corners (flip Y before SDF)
                vec2 localFlipped = vec2(local.x, bh - local.y);
                d = sdRoundedRect(localFlipped, vec2(bw, bh), botR);
            }
            if (d < 0.0) {
                fragColor = vec4(bar1.rgb, bar1.a);
            } else {
                fragColor = uBgColor;
            }
        }
    """.trimIndent()

  fun init(width: Int, height: Int, fps: Int, outputPath: String) {
    this.width = width
    this.height = height

    val bitRate = (width * height * fps * 0.07).toInt().coerceIn(500_000, 20_000_000)
    val format =
      MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
        setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
        setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
      }

    val surface: Surface
    encoder =
      MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).also {
        it.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        surface = it.createInputSurface()
        it.start()
      }
    muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

    initEGL(surface)
    initGL()
  }

  private fun initEGL(inputSurface: Surface) {
    eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
    if (eglDisplay == null) throw RuntimeException("eglGetDisplay failed")

    val version = IntArray(2)
    if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1))
      throw RuntimeException("eglInitialize failed")

    val configAttribs =
      intArrayOf(
        EGL14.EGL_RED_SIZE, 8,
        EGL14.EGL_GREEN_SIZE, 8,
        EGL14.EGL_BLUE_SIZE, 8,
        EGL14.EGL_ALPHA_SIZE, 8,
        EGL14.EGL_DEPTH_SIZE, 0,
        EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
        EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
        EGL_RECORDABLE_ANDROID, 1,
        EGL14.EGL_NONE
      )

    val configs = arrayOfNulls<EGLConfig>(1)
    val numConfigs = IntArray(1)
    if (!EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0) || numConfigs[0] == 0)
      throw RuntimeException("eglChooseConfig failed")

    val eglConfig = configs[0]

    val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
    eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
    if (eglContext == null) {
      contextAttribs[1] = 2
      eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
    }
    if (eglContext == null) throw RuntimeException("eglCreateContext failed")

    val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
    eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, eglConfig, inputSurface, surfaceAttribs, 0)
    if (eglSurface == null) throw RuntimeException("eglCreateWindowSurface failed")

    if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext))
      throw RuntimeException("eglMakeCurrent failed")

    eglInitialized = true
  }

  private fun initGL() {
    val vertexShader = compileShader(GLES30.GL_VERTEX_SHADER, vertexShaderSource)
    val fragmentShader = compileShader(GLES30.GL_FRAGMENT_SHADER, fragmentShaderSource)

    program = GLES30.glCreateProgram()
    GLES30.glAttachShader(program, vertexShader)
    GLES30.glAttachShader(program, fragmentShader)
    GLES30.glLinkProgram(program)

    val linkStatus = IntArray(1)
    GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, linkStatus, 0)
    if (linkStatus[0] == 0) {
      val log = GLES30.glGetProgramInfoLog(program)
      throw RuntimeException("Shader link error: $log")
    }

    aPositionLoc = GLES30.glGetAttribLocation(program, "aPosition")
    uResolutionLoc = GLES30.glGetUniformLocation(program, "uResolution")
    uBarCountLoc = GLES30.glGetUniformLocation(program, "uBarCount")
    uBarTextureLoc = GLES30.glGetUniformLocation(program, "uBarTexture")
    uBoundsTextureLoc = GLES30.glGetUniformLocation(program, "uBoundsTexture")
    uBgColorLoc = GLES30.glGetUniformLocation(program, "uBgColor")

    val quadVerts = floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
    quadVbo = createVBO(quadVerts)

    val texBuf = IntArray(1)

    GLES30.glGenTextures(1, texBuf, 0)
    barTextureId = texBuf[0]
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, barTextureId)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_NEAREST)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_NEAREST)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)

    GLES30.glGenTextures(1, texBuf, 0)
    boundsTextureId = texBuf[0]
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, boundsTextureId)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_NEAREST)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_NEAREST)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
    GLES30.glTexImage2D(
      GLES30.GL_TEXTURE_2D, 0, GLES30.GL_R32I,
      BOUNDS_TEX_WIDTH, BOUNDS_TEX_HEIGHT, 0,
      GLES30.GL_RED_INTEGER, GLES30.GL_INT, null
    )
  }

  fun renderFrame(
    barHeights: FloatArray,
    barCount: Int,
    barWidth: Float,
    barSpacing: Float,
    cornerRadius: Float,
    backgroundColor: Int,
    barColor: Int,
    currentPtsNs: Long,
    positiveHeightScale: Float = 1f,
    negativeHeightScale: Float = 1f,
  ) {
    if (!eglInitialized) return
    GLES30.glViewport(0, 0, width, height)

    val bgA = ((backgroundColor shr 24) and 0xFF) / 255f
    val bgR = ((backgroundColor shr 16) and 0xFF) / 255f
    val bgG = ((backgroundColor shr 8) and 0xFF) / 255f
    val bgB = (backgroundColor and 0xFF) / 255f
    GLES30.glClearColor(bgR, bgG, bgB, bgA)
    GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)

    GLES30.glUseProgram(program)
    GLES30.glUniform2f(uResolutionLoc, width.toFloat(), height.toFloat())
    GLES30.glUniform1i(uBarCountLoc, barCount * 2)
    GLES30.glUniform4f(uBgColorLoc, bgR, bgG, bgB, bgA)

    val barA = ((barColor shr 24) and 0xFF) / 255f
    val barR = ((barColor shr 16) and 0xFF) / 255f
    val barG = ((barColor shr 8) and 0xFF) / 255f
    val barB = (barColor and 0xFF) / 255f

    val totalBarAreaWidth = barCount * (barWidth + barSpacing) - barSpacing
    val offsetX = (width - totalBarAreaWidth) / 2f
    val centerY = height / 2f
    val maxBarHeight = height * 0.9f

    val barData =
      ByteBuffer.allocateDirect(MAX_BARS * 8 * 4 * 4).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()

    for (i in 0 until barCount) {
      val topH = (barHeights[i] * maxBarHeight * positiveHeightScale).coerceAtLeast(0f)
      val bottomH = (barHeights[i] * maxBarHeight * negativeHeightScale).coerceAtLeast(0f)
      val x = i * (barWidth + barSpacing) + offsetX

      // Upper bar (bottom at centerY, grows upward)
      val topY = centerY - topH
      barData.put(x)
      barData.put(topY)
      barData.put(barWidth)
      barData.put(topH)

      barData.put(barR)
      barData.put(barG)
      barData.put(barB)
      barData.put(barA)

      barData.put(cornerRadius)
      barData.put(0f)
      barData.put(0f)
      barData.put(1f) // mask: 1 = round top corners

      barData.put(0f)
      barData.put(0f)
      barData.put(0f)
      barData.put(0f)

      // Lower bar (top at centerY, grows downward)
      barData.put(x)
      barData.put(centerY)
      barData.put(barWidth)
      barData.put(bottomH)

      barData.put(barR)
      barData.put(barG)
      barData.put(barB)
      barData.put(barA)

      barData.put(0f)
      barData.put(0f)
      barData.put(cornerRadius)
      barData.put(0f)

      barData.put(0f)
      barData.put(0f)
      barData.put(0f)
      barData.put(2f) // mask: 2 = round bottom corners
    }
    barData.position(0)

    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, barTextureId)
    GLES30.glTexImage2D(
      GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA32F,
      MAX_BARS * 8, 1, 0, GLES30.GL_RGBA, GLES30.GL_FLOAT, barData
    )

    buildBoundsTexture(barCount, barHeights, barWidth, barSpacing, maxBarHeight, offsetX, centerY, positiveHeightScale, negativeHeightScale)

    GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, barTextureId)
    GLES30.glUniform1i(uBarTextureLoc, 0)

    GLES30.glActiveTexture(GLES30.GL_TEXTURE1)
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, boundsTextureId)
    GLES30.glUniform1i(uBoundsTextureLoc, 1)

    GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, quadVbo)
    GLES30.glEnableVertexAttribArray(aPositionLoc)
    GLES30.glVertexAttribPointer(aPositionLoc, 2, GLES30.GL_FLOAT, false, 0, 0)
    GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
    GLES30.glDisableVertexAttribArray(aPositionLoc)

    EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, currentPtsNs)
    EGL14.eglSwapBuffers(eglDisplay, eglSurface)

    drainEncoder(false)
    if (!muxerStarted) ensureMuxerStarted()
  }

  private fun buildBoundsTexture(
    barCount: Int,
    barHeights: FloatArray,
    barWidth: Float,
    barSpacing: Float,
    maxBarHeight: Float,
    offsetX: Float,
    centerY: Float,
    positiveHeightScale: Float = 1f,
    negativeHeightScale: Float = 1f
  ) {
    val buf =
      ByteBuffer.allocateDirect(BOUNDS_TEX_WIDTH * BOUNDS_TEX_HEIGHT * 4)
        .order(ByteOrder.LITTLE_ENDIAN)
        .asIntBuffer()
    while (buf.hasRemaining()) buf.put(-1)
    buf.rewind()

    val scaleX = BOUNDS_TEX_WIDTH.toFloat() / width
    val scaleY = BOUNDS_TEX_HEIGHT.toFloat() / height

    for (i in 0 until barCount) {
      val topH = (barHeights[i] * maxBarHeight * positiveHeightScale).coerceAtLeast(0f)
      val bottomH = (barHeights[i] * maxBarHeight * negativeHeightScale).coerceAtLeast(0f)
      val barLeft = i * (barWidth + barSpacing) + offsetX
      val barRight = barLeft + barWidth

      // Upper bar rect: bottom at centerY, grows upward
      if (topH > 0.5f) {
        val upperBarTop = centerY - topH
        val upperBarBottom = centerY
        val minTYu = (upperBarTop * scaleY + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_HEIGHT - 1)
        val maxTYu = (upperBarBottom * scaleY + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_HEIGHT)
        val minTX = (barLeft * scaleX + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_WIDTH - 1)
        val maxTX = (barRight * scaleX + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_WIDTH)
        val upperIdx = i * 2
        for (ty in minTYu until maxTYu) {
          for (tx in minTX until maxTX) {
            buf.put(ty * BOUNDS_TEX_WIDTH + tx, upperIdx)
          }
        }
      }

      // Lower bar rect: top at centerY, grows downward
      if (bottomH > 0.5f) {
        val lowerBarTop = centerY
        val lowerBarBottom = centerY + bottomH
        val minTYl = (lowerBarTop * scaleY + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_HEIGHT - 1)
        val maxTYl = (lowerBarBottom * scaleY + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_HEIGHT)
        val minTX = (barLeft * scaleX + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_WIDTH - 1)
        val maxTX = (barRight * scaleX + 0.5f).toInt().coerceIn(0, BOUNDS_TEX_WIDTH)
        val lowerIdx = i * 2 + 1
        for (ty in minTYl until maxTYl) {
          for (tx in minTX until maxTX) {
            buf.put(ty * BOUNDS_TEX_WIDTH + tx, lowerIdx)
          }
        }
      }
    }

    buf.rewind()
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, boundsTextureId)
    GLES30.glTexSubImage2D(
      GLES30.GL_TEXTURE_2D, 0, 0, 0,
      BOUNDS_TEX_WIDTH, BOUNDS_TEX_HEIGHT,
      GLES30.GL_RED_INTEGER, GLES30.GL_INT, buf
    )
  }

  fun finish() {
    if (!muxerStarted) ensureMuxerStarted()
    try {
      encoder?.signalEndOfInputStream()
    } catch (_: Exception) {}
    drainEncoder(true)
  }

  private fun ensureMuxerStarted() {
    if (muxerStarted || encoder == null) return
    var retries = 0
    while (retries < 20 && !muxerStarted) {
      val outputIndex = encoder!!.dequeueOutputBuffer(bufferInfo, 5000L)
      when (outputIndex) {
        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
          if (!muxerStarted) {
            trackIndex = muxer!!.addTrack(encoder!!.outputFormat)
            muxer!!.start()
            muxerStarted = true
          }
        }
        MediaCodec.INFO_TRY_AGAIN_LATER -> {}
        MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED -> {}
        else -> {
          if (outputIndex >= 0) {
            encoder!!.releaseOutputBuffer(outputIndex, false)
          }
        }
      }
      if (!muxerStarted) retries++
    }
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
            val outputBuffer: ByteBuffer =
              encoder.getOutputBuffer(outputIndex) ?: run {
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
    // Skip EGL cleanup — the display is shared with Flutter's Impeller engine.
    // eglTerminate() would break Flutter's rendering, and destroy calls fail because
    // Impeller may have invalidated the handles. OS reclaims all resources on process end.

    try {
      GLES30.glDeleteBuffers(1, intArrayOf(quadVbo), 0)
      GLES30.glDeleteProgram(program)
      GLES30.glDeleteTextures(1, intArrayOf(barTextureId), 0)
      GLES30.glDeleteTextures(1, intArrayOf(boundsTextureId), 0)
    } catch (_: Exception) {}

    try { encoder?.stop() } catch (_: Exception) {}
    try { encoder?.release() } catch (_: Exception) {}
    if (muxerStarted) { try { muxer?.stop() } catch (_: Exception) {} }
    try { muxer?.release() } catch (_: Exception) {}

    eglInitialized = false
    eglDisplay = null
    eglSurface = null
    eglContext = null
    encoder = null
    muxer = null
    muxerStarted = false
  }

  private fun compileShader(type: Int, source: String): Int {
    val shader = GLES30.glCreateShader(type)
    GLES30.glShaderSource(shader, source)
    GLES30.glCompileShader(shader)
    val compiled = IntArray(1)
    GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, compiled, 0)
    if (compiled[0] == 0) {
      val log = GLES30.glGetShaderInfoLog(shader)
      throw RuntimeException("Shader compile error: $log")
    }
    return shader
  }

  private fun createVBO(data: FloatArray): Int {
    val vbo = IntArray(1)
    GLES30.glGenBuffers(1, vbo, 0)
    GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo[0])
    val buffer =
      ByteBuffer.allocateDirect(data.size * 4).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer().apply {
        put(data)
        position(0)
      }
    GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, data.size * 4, buffer, GLES30.GL_STATIC_DRAW)
    return vbo[0]
  }
}

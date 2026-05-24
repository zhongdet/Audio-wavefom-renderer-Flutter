package com.example.flutter_application_1

import android.app.Activity
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import java.nio.ByteBuffer
import java.nio.ByteOrder

class OffscreenGpuRenderer(private val activity: Activity) {
  companion object {
    private const val EGL_PBUFFER_WIDTH = 1280
    private const val EGL_PBUFFER_HEIGHT = 720
    const val MAX_BARS = 128
    private const val EGL_OPENGL_ES3_BIT = 0x0040
    private const val EGL_CONTEXT_CLIENT_VERSION = 0x3098
    private const val BOUNDS_TEX_WIDTH = 512
    private const val BOUNDS_TEX_HEIGHT = 128
  }

  private var eglDisplay: EGLDisplay? = null
  private var eglContext: EGLContext? = null
  private var eglSurface: EGLSurface? = null
  private var eglInitialized = false

  private var program: Int = 0
  private var quadVbo: Int = 0
  private var barTextureId: Int = 0
  private var boundsTextureId: Int = 0

  private var pixelBuffer: ByteBuffer? = null

  private var uResolutionLoc: Int = -1
  private var uBarCountLoc: Int = -1
  private var uBarTextureLoc: Int = -1
  private var uBoundsTextureLoc: Int = -1
  private var uBgColorLoc: Int = -1

  private var aPositionLoc: Int = -1

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
                int(gl_FragCoord.x * float($BOUNDS_TEX_WIDTH) / uResolution.x),
                int(gl_FragCoord.y * float($BOUNDS_TEX_HEIGHT) / uResolution.y)
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
            float r = bar2.x;

            float d = sdRoundedRect(local, vec2(bw, bh), r);
            if (d < 0.0) {
                fragColor = vec4(bar1.rgb, bar1.a);
            } else {
                fragColor = uBgColor;
            }
        }
    """.trimIndent()

  init {
    initEGL()
    initGL()
  }

  private fun initEGL() {
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
                    EGL14.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
                    EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                    EGL14.EGL_NONE
            )

    val configs = arrayOfNulls<EGLConfig>(1)
    val numConfigs = IntArray(1)
    if (!EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0) || numConfigs[0] == 0)
      throw RuntimeException("eglChooseConfig failed")

    val eglConfig = configs[0]!!

    val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
    eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, null, contextAttribs, 0)
    if (eglContext == null) throw RuntimeException("eglCreateContext failed")

    val surfaceAttribs =
            intArrayOf(
                    EGL14.EGL_WIDTH, EGL_PBUFFER_WIDTH,
                    EGL14.EGL_HEIGHT, EGL_PBUFFER_HEIGHT,
                    EGL14.EGL_NONE
            )
    eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, eglConfig, surfaceAttribs, 0)
    if (eglSurface == null) throw RuntimeException("eglCreatePbufferSurface failed")

    if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext))
      throw RuntimeException("eglMakeCurrent failed")

    eglInitialized = true
  }

  private fun initGL() {
    val vertexShader = compileShader(android.opengl.GLES30.GL_VERTEX_SHADER, vertexShaderSource)
    val fragmentShader =
            compileShader(android.opengl.GLES30.GL_FRAGMENT_SHADER, fragmentShaderSource)

    program = android.opengl.GLES30.glCreateProgram()
    android.opengl.GLES30.glAttachShader(program, vertexShader)
    android.opengl.GLES30.glAttachShader(program, fragmentShader)
    android.opengl.GLES30.glLinkProgram(program)

    val linkStatus = IntArray(1)
    android.opengl.GLES30.glGetProgramiv(
            program,
            android.opengl.GLES30.GL_LINK_STATUS,
            linkStatus,
            0
    )
    if (linkStatus[0] == 0) {
      val log = android.opengl.GLES30.glGetProgramInfoLog(program)
      throw RuntimeException("Shader link error: $log")
    }

    aPositionLoc = android.opengl.GLES30.glGetAttribLocation(program, "aPosition")
    uResolutionLoc = android.opengl.GLES30.glGetUniformLocation(program, "uResolution")
    uBarCountLoc = android.opengl.GLES30.glGetUniformLocation(program, "uBarCount")
    uBarTextureLoc = android.opengl.GLES30.glGetUniformLocation(program, "uBarTexture")
    uBoundsTextureLoc = android.opengl.GLES30.glGetUniformLocation(program, "uBoundsTexture")
    uBgColorLoc = android.opengl.GLES30.glGetUniformLocation(program, "uBgColor")

    val quadVerts = floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
    quadVbo = createVBO(quadVerts)

    val texBuf = IntArray(1)

    android.opengl.GLES30.glGenTextures(1, texBuf, 0)
    barTextureId = texBuf[0]
    android.opengl.GLES30.glBindTexture(android.opengl.GLES30.GL_TEXTURE_2D, barTextureId)
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_MIN_FILTER,
            android.opengl.GLES30.GL_NEAREST
    )
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_MAG_FILTER,
            android.opengl.GLES30.GL_NEAREST
    )
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_WRAP_S,
            android.opengl.GLES30.GL_CLAMP_TO_EDGE
    )
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_WRAP_T,
            android.opengl.GLES30.GL_CLAMP_TO_EDGE
    )

    android.opengl.GLES30.glGenTextures(1, texBuf, 0)
    boundsTextureId = texBuf[0]
    android.opengl.GLES30.glBindTexture(android.opengl.GLES30.GL_TEXTURE_2D, boundsTextureId)
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_MIN_FILTER,
            android.opengl.GLES30.GL_NEAREST
    )
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_MAG_FILTER,
            android.opengl.GLES30.GL_NEAREST
    )
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_WRAP_S,
            android.opengl.GLES30.GL_CLAMP_TO_EDGE
    )
    android.opengl.GLES30.glTexParameteri(
            android.opengl.GLES30.GL_TEXTURE_2D,
            android.opengl.GLES30.GL_TEXTURE_WRAP_T,
            android.opengl.GLES30.GL_CLAMP_TO_EDGE
    )
    android.opengl.GLES30.glTexImage2D(
            android.opengl.GLES30.GL_TEXTURE_2D,
            0,
            android.opengl.GLES30.GL_R32I,
            BOUNDS_TEX_WIDTH,
            BOUNDS_TEX_HEIGHT,
            0,
            android.opengl.GLES30.GL_RED_INTEGER,
            android.opengl.GLES30.GL_INT,
            null
    )
  }

  fun renderFrame(
          frameWidth: Int,
          frameHeight: Int,
          bgColorValue: Long,
          barData: ByteBuffer,
          barCount: Int,
          barHeights: FloatArray,
          barWidth: Float,
          barSpacing: Float
  ): ByteArray {
    android.opengl.GLES30.glViewport(0, 0, frameWidth, frameHeight)
    android.opengl.GLES30.glClearColor(0f, 0f, 0f, 0f)
    android.opengl.GLES30.glClear(android.opengl.GLES30.GL_COLOR_BUFFER_BIT)

    android.opengl.GLES30.glUseProgram(program)
    android.opengl.GLES30.glUniform2f(uResolutionLoc, frameWidth.toFloat(), frameHeight.toFloat())
    android.opengl.GLES30.glUniform1i(uBarCountLoc, barCount)

    val bgColorArgb = (bgColorValue and 0xFFFFFFFF).toInt()
    val bgA = ((bgColorArgb shr 24) and 0xFF) / 255f
    val bgR = ((bgColorArgb shr 16) and 0xFF) / 255f
    val bgG = ((bgColorArgb shr 8) and 0xFF) / 255f
    val bgB = (bgColorArgb and 0xFF) / 255f
    android.opengl.GLES30.glUniform4f(uBgColorLoc, bgR, bgG, bgB, bgA)

    barData.rewind()
    android.opengl.GLES30.glBindTexture(android.opengl.GLES30.GL_TEXTURE_2D, barTextureId)
    android.opengl.GLES30.glTexImage2D(
            android.opengl.GLES30.GL_TEXTURE_2D,
            0,
            android.opengl.GLES30.GL_RGBA32F,
            MAX_BARS * 4,
            1,
            0,
            android.opengl.GLES30.GL_RGBA,
            android.opengl.GLES30.GL_FLOAT,
            barData
    )

    buildBoundsTexture(frameWidth, frameHeight, barCount, barHeights, barWidth, barSpacing)

    android.opengl.GLES30.glActiveTexture(android.opengl.GLES30.GL_TEXTURE0)
    android.opengl.GLES30.glBindTexture(android.opengl.GLES30.GL_TEXTURE_2D, barTextureId)
    android.opengl.GLES30.glUniform1i(uBarTextureLoc, 0)

    android.opengl.GLES30.glActiveTexture(android.opengl.GLES30.GL_TEXTURE1)
    android.opengl.GLES30.glBindTexture(android.opengl.GLES30.GL_TEXTURE_2D, boundsTextureId)
    android.opengl.GLES30.glUniform1i(uBoundsTextureLoc, 1)

    android.opengl.GLES30.glBindBuffer(android.opengl.GLES30.GL_ARRAY_BUFFER, quadVbo)
    android.opengl.GLES30.glEnableVertexAttribArray(aPositionLoc)
    android.opengl.GLES30.glVertexAttribPointer(
            aPositionLoc,
            2,
            android.opengl.GLES30.GL_FLOAT,
            false,
            0,
            0
    )
    android.opengl.GLES30.glDrawArrays(android.opengl.GLES30.GL_TRIANGLE_STRIP, 0, 4)
    android.opengl.GLES30.glDisableVertexAttribArray(aPositionLoc)

    val bufferSize = frameWidth * frameHeight * 4
    val readBuffer: ByteBuffer
    if (pixelBuffer == null || pixelBuffer!!.capacity() != bufferSize) {
      readBuffer = ByteBuffer.allocateDirect(bufferSize).apply { order(ByteOrder.LITTLE_ENDIAN) }
      pixelBuffer = readBuffer
    } else {
      readBuffer = pixelBuffer!!
      readBuffer.rewind()
    }

    android.opengl.GLES30.glReadPixels(
            0,
            0,
            frameWidth,
            frameHeight,
            android.opengl.GLES30.GL_RGBA,
            android.opengl.GLES30.GL_UNSIGNED_BYTE,
            readBuffer
    )

    val pixels = ByteArray(bufferSize)
    readBuffer.rewind()
    readBuffer.get(pixels, 0, bufferSize)

    val flipped = ByteArray(bufferSize)
    val rowSize = frameWidth * 4
    for (y in 0 until frameHeight) {
      val srcRow = (frameHeight - 1 - y) * rowSize
      System.arraycopy(pixels, srcRow, flipped, y * rowSize, rowSize)
    }

    return flipped
  }

  private fun buildBoundsTexture(
          frameWidth: Int,
          frameHeight: Int,
          barCount: Int,
          barHeights: FloatArray,
          barWidth: Float,
          barSpacing: Float
  ) {
    val buf =
            ByteBuffer.allocate(BOUNDS_TEX_WIDTH * BOUNDS_TEX_HEIGHT * 4)
                    .order(ByteOrder.LITTLE_ENDIAN)
                    .asIntBuffer()
    while (buf.hasRemaining()) {
      buf.put(-1)
    }
    buf.rewind()

    val scaleX = BOUNDS_TEX_WIDTH.toFloat() / frameWidth
    val scaleY = BOUNDS_TEX_HEIGHT.toFloat() / frameHeight
    val centerY = frameHeight / 2f
    val totalBarAreaWidth = barCount * (barWidth + barSpacing) - barSpacing
    val offsetX = (frameWidth - totalBarAreaWidth) / 2f

    for (i in 0 until barCount) {
      val h = barHeights[i]
      if (h <= 0f) continue

      val barLeft = i * (barWidth + barSpacing) + offsetX
      val barRight = barLeft + barWidth
      val barTop = centerY - h / 2f
      val barBottom = centerY + h / 2f

      val minTX = (barLeft * scaleX).toInt().coerceIn(0, BOUNDS_TEX_WIDTH)
      val maxTX = (barRight * scaleX).toInt().coerceIn(0, BOUNDS_TEX_WIDTH)
      val minTY = (barTop * scaleY).toInt().coerceIn(0, BOUNDS_TEX_HEIGHT)
      val maxTY = (barBottom * scaleY).toInt().coerceIn(0, BOUNDS_TEX_HEIGHT)

      for (ty in minTY until maxTY) {
        for (tx in minTX until maxTX) {
          buf.put(ty * BOUNDS_TEX_WIDTH + tx, i)
        }
      }
    }

    buf.rewind()
    android.opengl.GLES30.glBindTexture(android.opengl.GLES30.GL_TEXTURE_2D, boundsTextureId)
    android.opengl.GLES30.glTexSubImage2D(
            android.opengl.GLES30.GL_TEXTURE_2D,
            0,
            0,
            0,
            BOUNDS_TEX_WIDTH,
            BOUNDS_TEX_HEIGHT,
            android.opengl.GLES30.GL_RED_INTEGER,
            android.opengl.GLES30.GL_INT,
            buf
    )
  }

  fun dispose() {
    android.opengl.GLES30.glDeleteBuffers(1, intArrayOf(quadVbo), 0)
    android.opengl.GLES30.glDeleteProgram(program)
    android.opengl.GLES30.glDeleteTextures(1, intArrayOf(barTextureId), 0)
    android.opengl.GLES30.glDeleteTextures(1, intArrayOf(boundsTextureId), 0)
  }

  private fun compileShader(type: Int, source: String): Int {
    val shader = android.opengl.GLES30.glCreateShader(type)
    android.opengl.GLES30.glShaderSource(shader, source)
    android.opengl.GLES30.glCompileShader(shader)
    val compiled = IntArray(1)
    android.opengl.GLES30.glGetShaderiv(
            shader,
            android.opengl.GLES30.GL_COMPILE_STATUS,
            compiled,
            0
    )
    if (compiled[0] == 0) {
      val log = android.opengl.GLES30.glGetShaderInfoLog(shader)
      throw RuntimeException("Shader compile error: $log")
    }
    return shader
  }

  private fun createVBO(data: FloatArray): Int {
    val vbo = IntArray(1)
    android.opengl.GLES30.glGenBuffers(1, vbo, 0)
    android.opengl.GLES30.glBindBuffer(android.opengl.GLES30.GL_ARRAY_BUFFER, vbo[0])
    val buffer =
            ByteBuffer.allocateDirect(data.size * 4)
                    .order(ByteOrder.LITTLE_ENDIAN)
                    .asFloatBuffer()
                    .apply {
                      put(data)
                      position(0)
                    }
    android.opengl.GLES30.glBufferData(
            android.opengl.GLES30.GL_ARRAY_BUFFER,
            data.size * 4,
            buffer,
            android.opengl.GLES30.GL_STATIC_DRAW
    )
    return vbo[0]
  }
}

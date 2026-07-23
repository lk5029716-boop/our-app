package com.smartmedia.app.engine

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

enum class TargetCapability {
    ACCEPTS_GIF,
    ACCEPTS_MP4_ONLY,
    ACCEPTS_NEITHER,
    UNKNOWN,
}

/**
 * Engine room: cache streaming download + FFmpeg H.264 packaging.
 *
 * Exact optimization command (product spec):
 * ffmpeg -y -stream_loop 3 -i input.gif -c:v libx264 -pix_fmt yuv420p
 *   -movflags faststart -vf scale='trunc(iw/2)*2:trunc(ih/2)*2' output.mp4
 */
class MediaEngine(private val context: Context) {

    companion object {
        private const val TAG = "SmartMediaEngine"
        private const val AUTHORITY_SUFFIX = ".fileprovider"
    }

    fun resolveCapability(mimeTypes: Array<String>): TargetCapability {
        if (mimeTypes.isEmpty()) return TargetCapability.UNKNOWN
        val lower = mimeTypes.map { it.lowercase() }
        val gif = lower.any {
            it == "image/gif" || it.contains("image/gif") || it == "image/*"
        }
        val mp4 = lower.any {
            it == "video/mp4" ||
                it.contains("video/mp4") ||
                it == "video/*" ||
                it.contains("mpeg")
        }
        return when {
            gif -> TargetCapability.ACCEPTS_GIF
            mp4 -> TargetCapability.ACCEPTS_MP4_ONLY
            else -> TargetCapability.ACCEPTS_NEITHER
        }
    }

    /**
     * Chunk-stream remote GIF into application secure internal sandbox cacheDir.
     */
    fun downloadToCache(gifUrl: String): File {
        val out = File(context.cacheDir, "sm_${UUID.randomUUID()}.gif")
        val conn = (URL(gifUrl).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 30_000
            instanceFollowRedirects = true
            requestMethod = "GET"
            setRequestProperty("User-Agent", "SmartMedia/1.0")
        }
        try {
            conn.connect()
            if (conn.responseCode !in 200..299) {
                throw IllegalStateException("HTTP ${conn.responseCode} for $gifUrl")
            }
            conn.inputStream.use { input ->
                FileOutputStream(out).use { output ->
                    val buf = ByteArray(16 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n <= 0) break
                        output.write(buf, 0, n)
                    }
                    output.flush()
                }
            }
        } finally {
            conn.disconnect()
        }
        Log.d(TAG, "Cached GIF → ${out.absolutePath} (${out.length()} bytes)")
        return out
    }

    /**
     * Local transcoding routine via ffmpeg-kit.
     * -stream_loop 3 loops short GIF so MP4 feels endless.
     * scale filter enforces even width/height for H.264.
     */
    fun transcodeGifToMp4(inputGif: File): File {
        require(inputGif.exists()) { "Input GIF missing: ${inputGif.path}" }
        val output = File(context.cacheDir, "sm_${UUID.randomUUID()}.mp4")

        // Exact product command string (paths substituted).
        val cmd = buildString {
            append("-y ")
            append("-stream_loop 3 ")
            append("-i \"${inputGif.absolutePath}\" ")
            append("-c:v libx264 ")
            append("-pix_fmt yuv420p ")
            append("-movflags faststart ")
            append("-vf scale='trunc(iw/2)*2:trunc(ih/2)*2' ")
            append("\"${output.absolutePath}\"")
        }

        Log.d(TAG, "FFmpeg: $cmd")
        val session = FFmpegKit.execute(cmd)
        if (!ReturnCode.isSuccess(session.returnCode)) {
            val fail = session.failStackTrace ?: session.allLogsAsString
            throw IllegalStateException("FFmpeg failed: $fail")
        }
        if (!output.exists() || output.length() == 0L) {
            throw IllegalStateException("FFmpeg produced empty output")
        }
        Log.d(TAG, "MP4 ready → ${output.absolutePath} (${output.length()} bytes)")
        return output
    }

    /** content:// URI — never expose raw file:// paths to external apps. */
    fun toContentUri(file: File): Uri {
        val authority = context.packageName + AUTHORITY_SUFFIX
        return FileProvider.getUriForFile(context, authority, file)
    }
}

package com.smartmedia.app

import android.os.Bundle
import com.smartmedia.app.ime.SmartMediaImeService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Flutter host + MethodChannel bridge to IME / MediaEngine.
 * Channel: com.smartmedia.app/keyboard_bridge
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.smartmedia.app/keyboard_bridge"
    }

    private val scope = CoroutineScope(Dispatchers.Main.immediate)
    private lateinit var engine: com.smartmedia.app.engine.MediaEngine

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        engine = com.smartmedia.app.engine.MediaEngine(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getContentMimeTypes" -> {
                    val mime = SmartMediaImeService.activeInstance
                        ?.currentMimeTypes()
                        ?: emptyList()
                    result.success(mime)
                }

                "downloadToCache" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("bad_args", "url required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            val file = withContext(Dispatchers.IO) {
                                engine.downloadToCache(url)
                            }
                            result.success(file.absolutePath)
                        } catch (t: Throwable) {
                            result.error("download_failed", t.message, null)
                        }
                    }
                }

                "transcodeGifToMp4" -> {
                    val input = call.argument<String>("inputPath")
                    if (input.isNullOrBlank()) {
                        result.error("bad_args", "inputPath required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            val out = withContext(Dispatchers.IO) {
                                engine.transcodeGifToMp4(java.io.File(input))
                            }
                            result.success(out.absolutePath)
                        } catch (t: Throwable) {
                            result.error("transcode_failed", t.message, null)
                        }
                    }
                }

                "commitContent" -> {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mimeType") ?: "image/gif"
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "path required", null)
                        return@setMethodCallHandler
                    }
                    val ime = SmartMediaImeService.activeInstance
                    if (ime != null) {
                        result.success(ime.bridgeCommit(path, mime))
                    } else {
                        // Outside IME session — open share as best effort.
                        result.success(
                            openShare(java.io.File(path), mime),
                        )
                    }
                }

                "openShareSheet" -> {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mimeType") ?: "video/mp4"
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "path required", null)
                        return@setMethodCallHandler
                    }
                    result.success(openShare(java.io.File(path), mime))
                }

                "writeDualPasteboard" -> {
                    // Android has no dual pasteboard model; no-op success.
                    result.success(false)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openShare(file: java.io.File, mime: String): Boolean {
        return try {
            val uri = engine.toContentUri(file)
            val send = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                type = mime
                putExtra(android.content.Intent.EXTRA_STREAM, uri)
                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(android.content.Intent.createChooser(send, "Share with SmartMedia"))
            true
        } catch (_: Throwable) {
            false
        }
    }
}

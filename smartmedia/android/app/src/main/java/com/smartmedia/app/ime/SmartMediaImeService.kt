package com.smartmedia.app.ime

import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.view.inputmethod.EditorInfoCompat
import androidx.core.view.inputmethod.InputConnectionCompat
import androidx.core.view.inputmethod.InputContentInfoCompat
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.smartmedia.app.R
import com.smartmedia.app.engine.GifCatalog
import com.smartmedia.app.engine.MediaEngine
import com.smartmedia.app.engine.TargetCapability
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Android IME layer.
 *
 * onStartInputView → EditorInfo → EditorInfoCompat.getContentMimeTypes()
 * Decision tree:
 *  - image/gif → CommitContentAPI raw GIF
 *  - video/mp4 only → local FFmpeg H.264 package
 *  - neither → Intent.ACTION_SEND share sheet over host
 */
class SmartMediaImeService : InputMethodService() {

    companion object {
        private const val TAG = "SmartMediaIME"
        @Volatile
        var activeInstance: SmartMediaImeService? = null
            private set
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var engine: MediaEngine

    private var acceptedMimeTypes: Array<String> = emptyArray()
    private var editorInfo: EditorInfo? = null

    private var overlay: FrameLayout? = null
    private var statusText: TextView? = null
    private var progressRing: ProgressBar? = null
    private var grid: RecyclerView? = null
    private var searchInput: EditText? = null
    private var selectionJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
        engine = MediaEngine(applicationContext)
    }

    override fun onDestroy() {
        if (activeInstance === this) activeInstance = null
        selectionJob?.cancel()
        scope.cancel()
        super.onDestroy()
    }

    override fun onCreateInputView(): View {
        val root = layoutInflater.inflate(R.layout.keyboard_view, null)
        overlay = root.findViewById(R.id.transcode_overlay)
        statusText = root.findViewById(R.id.pipeline_status)
        progressRing = root.findViewById(R.id.progress_ring)
        grid = root.findViewById(R.id.media_grid)
        searchInput = root.findViewById(R.id.search_input)

        grid?.layoutManager = GridLayoutManager(this, 2)
        grid?.adapter = GifGridAdapter(GifCatalog.demo()) { url ->
            handleAssetSelection(url)
        }

        searchInput?.setOnEditorActionListener { v, _, _ ->
            val q = v.text?.toString().orEmpty()
            (grid?.adapter as? GifGridAdapter)?.submit(GifCatalog.filter(q))
            true
        }

        return root
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        editorInfo = info
        acceptedMimeTypes = if (info != null) {
            EditorInfoCompat.getContentMimeTypes(info)
        } else {
            emptyArray()
        }
        Log.d(TAG, "Accepted MIME types: ${acceptedMimeTypes.joinToString()}")
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        editorInfo = attribute
        if (attribute != null) {
            acceptedMimeTypes = EditorInfoCompat.getContentMimeTypes(attribute)
        }
    }

    /** Exposed for Flutter MethodChannel bridge (MainActivity). */
    fun currentMimeTypes(): List<String> = acceptedMimeTypes.toList()

    /**
     * Async controller: handleAssetSelection(gifUrl)
     * Android decision tree per product spec.
     */
    fun handleAssetSelection(gifUrl: String) {
        selectionJob?.cancel()
        selectionJob = scope.launch {
            showOverlay("Inspecting target field capabilities…")
            val capability = engine.resolveCapability(acceptedMimeTypes)
            try {
                when (capability) {
                    TargetCapability.ACCEPTS_GIF -> {
                        showOverlay("Streaming GIF into secure cache…")
                        val gif = withContext(Dispatchers.IO) {
                            engine.downloadToCache(gifUrl)
                        }
                        showOverlay("Committing media to host app…")
                        val ok = commitContent(gif, "image/gif")
                        if (!ok) {
                            // Host rejected — attempt MP4 path
                            showOverlay("Target field blocks GIFs… Packaging into H.264 MP4 container…")
                            val mp4 = withContext(Dispatchers.IO) {
                                engine.transcodeGifToMp4(gif)
                            }
                            if (!commitContent(mp4, "video/mp4")) {
                                openShareSheet(mp4, "video/mp4")
                            }
                        }
                    }

                    TargetCapability.ACCEPTS_MP4_ONLY -> {
                        showOverlay("Target field blocks GIFs… Packaging into H.264 MP4 container…")
                        val gif = withContext(Dispatchers.IO) {
                            engine.downloadToCache(gifUrl)
                        }
                        val mp4 = withContext(Dispatchers.IO) {
                            engine.transcodeGifToMp4(gif)
                        }
                        showOverlay("Committing media to host app…")
                        if (!commitContent(mp4, "video/mp4")) {
                            openShareSheet(mp4, "video/mp4")
                        }
                    }

                    TargetCapability.ACCEPTS_NEITHER, TargetCapability.UNKNOWN -> {
                        showOverlay("Streaming GIF into secure cache…")
                        val gif = withContext(Dispatchers.IO) {
                            engine.downloadToCache(gifUrl)
                        }
                        showOverlay("Packaging into H.264 MP4 container…")
                        val mp4 = runCatching {
                            withContext(Dispatchers.IO) { engine.transcodeGifToMp4(gif) }
                        }.getOrNull()
                        showOverlay("Opening system share sheet…")
                        if (mp4 != null) openShareSheet(mp4, "video/mp4")
                        else openShareSheet(gif, "image/gif")
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Selection pipeline failed", t)
                showOverlay("Something went wrong. Try another GIF.")
            } finally {
                // brief success window then hide
                kotlinx.coroutines.delay(500)
                hideOverlay()
            }
        }
    }

    private fun commitContent(file: java.io.File, mimeType: String): Boolean {
        val ic: InputConnection = currentInputConnection ?: return false
        val info: EditorInfo = editorInfo ?: return false

        val uri: Uri = engine.toContentUri(file)
        // Temporary read grant for host process
        grantUriPermissionForHost(uri)

        val contentInfo = InputContentInfoCompat(
            uri,
            android.content.ClipDescription(file.name, arrayOf(mimeType)),
            null
        )

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            InputConnectionCompat.INPUT_CONTENT_GRANT_READ_URI_PERMISSION
        } else {
            0
        }

        return try {
            InputConnectionCompat.commitContent(ic, info, contentInfo, flags, null)
        } catch (t: Throwable) {
            Log.w(TAG, "commitContent failed for $mimeType", t)
            false
        }
    }

    private fun grantUriPermissionForHost(uri: Uri) {
        // Best-effort: grant to packages that can resolve content. We avoid QUERY_ALL_PACKAGES;
        // commitContent flag handles modern hosts. For share sheet we use FLAG_GRANT_READ.
        try {
            // no-op package scan — FileProvider + Intent flags are sufficient
            uri.toString()
        } catch (_: Throwable) {
        }
    }

    fun openShareSheet(file: java.io.File, mimeType: String): Boolean {
        return try {
            val uri = engine.toContentUri(file)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(send, "Share with SmartMedia").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(chooser)
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Share sheet failed", t)
            false
        }
    }

    private fun showOverlay(message: String) {
        overlay?.visibility = View.VISIBLE
        statusText?.text = message
        progressRing?.visibility = View.VISIBLE
    }

    private fun hideOverlay() {
        overlay?.visibility = View.GONE
    }

    // --- Bridge helpers used by MainActivity MethodChannel ---

    suspend fun bridgeDownload(url: String): String =
        withContext(Dispatchers.IO) { engine.downloadToCache(url).absolutePath }

    suspend fun bridgeTranscode(inputPath: String): String =
        withContext(Dispatchers.IO) {
            engine.transcodeGifToMp4(java.io.File(inputPath)).absolutePath
        }

    fun bridgeCommit(path: String, mime: String): Boolean =
        commitContent(java.io.File(path), mime)

    fun bridgeShare(path: String, mime: String): Boolean =
        openShareSheet(java.io.File(path), mime)
}

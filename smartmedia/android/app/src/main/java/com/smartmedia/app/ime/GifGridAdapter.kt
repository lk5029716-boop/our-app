package com.smartmedia.app.ime

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.smartmedia.app.engine.GifCatalog
import java.util.concurrent.Executors

class GifGridAdapter(
    private var items: List<GifCatalog.Item>,
    private val onSelect: (String) -> Unit,
) : RecyclerView.Adapter<GifGridAdapter.VH>() {

    fun submit(next: List<GifCatalog.Item>) {
        items = next
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val density = parent.resources.displayMetrics.density
        val card = FrameLayout(parent.context).apply {
            layoutParams = ViewGroup.MarginLayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (140 * density).toInt(),
            ).apply {
                setMargins(
                    (4 * density).toInt(),
                    (4 * density).toInt(),
                    (4 * density).toInt(),
                    (4 * density).toInt(),
                )
            }
            background = GradientDrawable().apply {
                cornerRadius = 12 * density
                setColor(Color.parseColor("#1A1A24"))
            }
            clipToOutline = true
        }
        val image = ImageView(parent.context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            scaleType = ImageView.ScaleType.CENTER_CROP
            setBackgroundColor(Color.parseColor("#1A1A24"))
        }
        val badge = TextView(parent.context).apply {
            text = "GIF"
            setTextColor(Color.WHITE)
            textSize = 10f
            setPadding(
                (7 * density).toInt(),
                (3 * density).toInt(),
                (7 * density).toInt(),
                (3 * density).toInt(),
            )
            background = GradientDrawable().apply {
                cornerRadius = 6 * density
                setColor(Color.parseColor("#99000000"))
            }
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = android.view.Gravity.BOTTOM or android.view.Gravity.END
                setMargins(0, 0, (8 * density).toInt(), (8 * density).toInt())
            }
        }
        card.addView(image)
        card.addView(badge)
        return VH(card, image)
    }

    override fun onBindViewHolder(holder: VH, position: Int) {
        val item = items[position]
        holder.image.setImageDrawable(null)
        holder.image.tag = item.url
        // Lightweight async preview without external image lib dependency in IME.
        Executors.newSingleThreadExecutor().execute {
            try {
                val conn = java.net.URL(item.preview).openConnection()
                conn.connect()
                val bmp = android.graphics.BitmapFactory.decodeStream(conn.getInputStream())
                holder.image.post {
                    if (holder.image.tag == item.url) {
                        holder.image.setImageBitmap(bmp)
                    }
                }
            } catch (_: Exception) {
            }
        }
        holder.itemView.setOnClickListener { onSelect(item.url) }
    }

    override fun getItemCount(): Int = items.size

    class VH(view: View, val image: ImageView) : RecyclerView.ViewHolder(view)
}

package com.smartmedia.app.engine

/**
 * Lightweight offline catalog for the native IME surface.
 * Flutter layer uses GifSearchService for live Giphy/Tenor queries.
 */
object GifCatalog {
    data class Item(
        val id: String,
        val title: String,
        val url: String,
        val preview: String = url,
    )

    fun demo(): List<Item> = listOf(
        Item("1", "Happy dance", "https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif"),
        Item("2", "Thumbs up", "https://media.giphy.com/media/111ebonMs90YLu/giphy.gif"),
        Item("3", "Mind blown", "https://media.giphy.com/media/26u4cqiYI30juCOGY/giphy.gif"),
        Item("4", "Cat vibes", "https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif"),
        Item("5", "Celebrate", "https://media.giphy.com/media/g9582DNuQppxC/giphy.gif"),
        Item("6", "High five", "https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif"),
        Item("7", "Coffee time", "https://media.giphy.com/media/3oKIPnAiaMCws8nOsE/giphy.gif"),
        Item("8", "Wow", "https://media.giphy.com/media/5VKbvrjxpVJCM/giphy.gif"),
    )

    fun filter(query: String): List<Item> {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return demo()
        return demo().filter { it.title.lowercase().contains(q) }
    }
}

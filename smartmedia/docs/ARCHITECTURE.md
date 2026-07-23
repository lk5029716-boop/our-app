# SmartMedia Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Host App Text Field                        │
└──────────────▲──────────────────────────────▲───────────────┘
               │ CommitContent / Paste        │ Share Sheet
┌──────────────┴──────────────┐  ┌────────────┴───────────────┐
│     Android IME Service     │  │  iOS UIInputViewController │
│  EditorInfo MIME inspect    │  │  Dual UIPasteboard write   │
└──────────────┬──────────────┘  └────────────┬───────────────┘
               │                              │
               └──────────────┬───────────────┘
                              ▼
                 ┌────────────────────────┐
                 │  handleAssetSelection  │
                 │  (Dart / Kotlin/Swift) │
                 └────────────┬───────────┘
                              ▼
                 ┌────────────────────────┐
                 │      MediaEngine       │
                 │  cache stream download │
                 │  FFmpeg H.264 package  │
                 └────────────────────────┘
```

## Decision tree (Android)

```
mimeTypes = EditorInfoCompat.getContentMimeTypes(info)
if image/gif ∈ mimeTypes:
    download → commitContent(image/gif)
else if video/mp4 ∈ mimeTypes:
    download → ffmpeg → commitContent(video/mp4)
else:
    download → [ffmpeg] → ACTION_SEND
```

## Decision tree (iOS)

```
download GIF
transcode → MP4 (best effort)
UIPasteboard.items = [{ gif UTType, mpeg4 UTType }]
on failure → UIActivityViewController
```

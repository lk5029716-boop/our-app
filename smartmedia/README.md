# SmartMedia

Cross-platform mobile app + system keyboard extension that searches open-source GIFs, inspects the host input field’s media capabilities, and **transcodes GIFs to H.264 MP4 on-the-fly** when the target app blocks native GIF sharing.

| Layer | Stack |
|-------|--------|
| Companion UI | Flutter (Dart) — ultra-dark glassmorphism keyboard preview |
| Android IME | `InputMethodService` + Commit Content API + `FileProvider` |
| iOS Keyboard | `UIInputViewController` + dual `UIPasteboard` (GIF + MPEG-4) |
| Engine | `ffmpeg-kit` (Android) / FFmpeg Kit or AVFoundation fallback (iOS) |

---

## Repository layout

```
smartmedia/
├── pubspec.yaml                          # Flutter deps
├── lib/
│   ├── main.dart                         # Companion app shell
│   ├── theme/smartmedia_theme.dart       # #0B0B0F + indigo/violet glass
│   ├── models/gif_asset.dart             # Assets + pipeline states
│   ├── services/
│   │   ├── gif_search_service.dart       # Giphy / Tenor / demo catalog
│   │   └── platform_bridge.dart          # MethodChannel bridge
│   ├── controllers/
│   │   └── asset_selection_controller.dart  # handleAssetSelection()
│   └── ui/
│       ├── keyboard_view.dart
│       └── widgets/                      # header, search, grid, overlay
├── android/
│   └── app/
│       ├── build.gradle                  # ffmpeg-kit-min
│       └── src/main/
│           ├── AndroidManifest.xml       # IME + FileProvider, no dangerous perms
│           ├── java/com/smartmedia/app/
│           │   ├── MainActivity.kt       # Flutter MethodChannel
│           │   ├── engine/MediaEngine.kt # download + FFmpeg
│           │   └── ime/
│           │       ├── SmartMediaImeService.kt
│           │       └── GifGridAdapter.kt
│           └── res/xml/
│               ├── method.xml            # IME metadata
│               └── file_paths.xml        # cache-only FileProvider
└── ios/
    ├── Podfile
    ├── Runner/
    │   ├── Info.plist
    │   ├── AppDelegate.swift
    │   └── MediaEngineIOS.swift
    └── SmartMediaKeyboard/
        ├── Info.plist                    # RequestsOpenAccess = true
        ├── KeyboardViewController.swift
        └── MediaEngineIOS.swift
```

---

## Capability matrix

### Android

1. `onStartInputView` → `EditorInfoCompat.getContentMimeTypes(editorInfo)`
2. **`image/gif`** → stream GIF to `cacheDir` → `InputConnectionCompat.commitContent`
3. **GIF blocked, `video/mp4` ok** → FFmpeg package → commit `video/mp4`
4. **Neither** → `Intent.ACTION_SEND` share sheet (`content://` via FileProvider)

### iOS

1. Download GIF to temporary sandbox
2. Transcode to MP4
3. **Dual-write** `kUTTypeGIF` / `UTType.gif` **and** `kUTTypeMPEG4` / `UTType.mpeg4Movie` on `UIPasteboard.general`
4. Failure → `UIActivityViewController`

---

## FFmpeg command (exact)

```bash
ffmpeg -y -stream_loop 3 -i input.gif \
  -c:v libx264 -pix_fmt yuv420p -movflags faststart \
  -vf scale='trunc(iw/2)*2:trunc(ih/2)*2' \
  output.mp4
```

- `-stream_loop 3` — short GIF loops so MP4 feels continuous  
- `scale=trunc(iw/2)*2:…` — even dimensions required by H.264  

---

## Security / Play Store

| Requirement | Implementation |
|-------------|----------------|
| No `QUERY_ALL_PACKAGES` | Not declared |
| No broad storage | Only `cacheDir` / temp; no `READ/WRITE_EXTERNAL_STORAGE` |
| No `file://` leaks | `FileProvider` → `content://` + `FLAG_GRANT_READ_URI_PERMISSION` |
| Network | HTTPS only (`network_security_config`) |

---

## Theme

| Token | Value |
|-------|--------|
| Background | `#0B0B0F` |
| Indigo | `#6366F1` |
| Violet | `#8B5CF6` |
| Muted text | `#9CA3AF` |
| Glass blur | `backdrop-filter` / `ImageFilter.blur(12)` |

---

## Setup

### Prerequisites

- Flutter 3.19+
- Android Studio / Xcode 15+
- (Optional) `GIPHY_API_KEY` / `TENOR_API_KEY`

### Run companion app

```bash
cd smartmedia
flutter pub get
flutter run
```

With live GIF search:

```bash
flutter run --dart-define=GIPHY_API_KEY=your_key
```

### Enable Android keyboard

1. Install debug APK  
2. **Settings → System → Languages & input → On-screen keyboard → Manage keyboards → SmartMedia**  
3. Switch to SmartMedia in any text field  

### Enable iOS keyboard

1. Open `ios/Runner.xcworkspace` in Xcode  
2. Add **Keyboard Extension** target `SmartMediaKeyboard` if not already linked; set App Group `group.com.smartmedia.app`  
3. Enable **Full Access** for network + pasteboard  
4. **Settings → General → Keyboard → Keyboards → Add New Keyboard → SmartMedia**  

### Optional FFmpeg Kit on iOS

Uncomment in `ios/Podfile`:

```ruby
pod 'ffmpeg-kit-ios-min', '6.0'
```

Then `cd ios && pod install`. Without the pod, `MediaEngineIOS` uses an AVFoundation H.264 fallback.

---

## MethodChannel API

Channel: `com.smartmedia.app/keyboard_bridge`

| Method | Args | Returns |
|--------|------|---------|
| `getContentMimeTypes` | — | `List<String>` |
| `downloadToCache` | `url` | local path |
| `transcodeGifToMp4` | `inputPath` | MP4 path |
| `commitContent` | `path`, `mimeType` | `bool` |
| `writeDualPasteboard` | `gifPath`, `mp4Path?` | `bool` |
| `openShareSheet` | `path`, `mimeType` | `bool` |

Core Dart entry:

```dart
await controller.handleAssetSelection(gifUrl);
```

---

## License

Project scaffold for product development. GIF content remains subject to upstream provider terms (Giphy / Tenor / demo hosts).

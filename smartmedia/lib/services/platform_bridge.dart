import 'package:flutter/services.dart';
import '../models/gif_asset.dart';

/// Method-channel bridge to Android IME / iOS keyboard extension hosts.
class PlatformBridge {
  PlatformBridge({
    MethodChannel? channel,
  }) : _channel = channel ??
            const MethodChannel('com.smartmedia.app/keyboard_bridge');

  final MethodChannel _channel;

  /// Query MIME types the focused editor accepts (Android EditorInfo).
  Future<List<String>> getContentMimeTypes() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getContentMimeTypes',
      );
      return raw?.map((e) => e.toString()).toList() ?? const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  TargetCapability resolveCapability(List<String> mimeTypes) {
    if (mimeTypes.isEmpty) return TargetCapability.unknown;

    final lower = mimeTypes.map((m) => m.toLowerCase()).toList();
    final gif = lower.any(
      (m) => m == 'image/gif' || m.contains('image/gif') || m == 'image/*',
    );
    final mp4 = lower.any(
      (m) =>
          m == 'video/mp4' ||
          m.contains('video/mp4') ||
          m == 'video/*' ||
          m.contains('mpeg'),
    );

    if (gif) return TargetCapability.acceptsGif;
    if (mp4) return TargetCapability.acceptsMp4Only;
    return TargetCapability.acceptsNeither;
  }

  /// Commit raw GIF via Android CommitContentAPI or iOS pasteboard write.
  Future<bool> commitGif({
    required String localPath,
    required String mimeType,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('commitContent', {
        'path': localPath,
        'mimeType': mimeType,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Dual-write GIF + MP4 onto iOS pasteboard (kUTTypeGIF + kUTTypeMPEG4).
  Future<bool> writeDualPasteboard({
    required String gifPath,
    required String? mp4Path,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('writeDualPasteboard', {
        'gifPath': gifPath,
        'mp4Path': mp4Path,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Local FFmpeg transcode in native sandbox (exact CLI from spec).
  Future<String?> transcodeGifToMp4(String gifPath) async {
    try {
      final out = await _channel.invokeMethod<String>('transcodeGifToMp4', {
        'inputPath': gifPath,
      });
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Stream-download remote GIF into cacheDir / temporary directory.
  Future<String?> downloadToCache(String url) async {
    try {
      final path = await _channel.invokeMethod<String>('downloadToCache', {
        'url': url,
      });
      return path;
    } catch (_) {
      return null;
    }
  }

  /// System share sheet fallback (ACTION_SEND / UIActivityViewController).
  Future<bool> openShareSheet({
    required String path,
    required String mimeType,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openShareSheet', {
        'path': path,
        'mimeType': mimeType,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

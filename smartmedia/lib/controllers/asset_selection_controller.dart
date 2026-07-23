import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/gif_asset.dart';
import '../services/gif_search_service.dart';
import '../services/platform_bridge.dart';

/// Core async decision tree: capability check → GIF commit | H.264 transcode | share.
class AssetSelectionController extends ChangeNotifier {
  AssetSelectionController({
    GifSearchService? searchService,
    PlatformBridge? bridge,
  })  : _search = searchService ?? GifSearchService(),
        _bridge = bridge ?? PlatformBridge();

  final GifSearchService _search;
  final PlatformBridge _bridge;

  List<GifAsset> assets = const [];
  bool loading = false;
  bool engineActive = true;
  String query = '';
  String? error;

  PipelineState pipeline = PipelineState.idle;
  double progress = 0;
  bool overlayVisible = false;
  String? lastError;

  Timer? _searchDebounce;

  Future<void> bootstrap() async {
    await loadTrending();
  }

  Future<void> loadTrending() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      assets = await _search.searchTrending();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void onQueryChanged(String value) {
    query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      _runSearch(value);
    });
    notifyListeners();
  }

  Future<void> _runSearch(String value) async {
    loading = true;
    notifyListeners();
    try {
      assets = await _search.search(value);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Primary entry: automated matrix check + delivery path.
  Future<void> handleAssetSelection(String gifUrl) async {
    if (overlayVisible) return;

    overlayVisible = true;
    progress = 0.05;
    pipeline = PipelineState.checkingTarget;
    lastError = null;
    notifyListeners();

    try {
      final mimeTypes = await _bridge.getContentMimeTypes();
      final capability = _bridge.resolveCapability(mimeTypes);

      progress = 0.15;
      notifyListeners();

      // iOS: dual-write GIF + MP4 so host picks supported type on paste.
      if (!kIsWeb && Platform.isIOS) {
        await _iosDualWritePath(gifUrl);
        return;
      }

      switch (capability) {
        case TargetCapability.acceptsGif:
        case TargetCapability.unknown:
          // Prefer direct GIF when supported or capability unknown (best effort).
          await _directGifPath(gifUrl, preferShareOnFail: capability == TargetCapability.unknown);
          break;
        case TargetCapability.acceptsMp4Only:
          pipeline = PipelineState.blocksGifs;
          progress = 0.22;
          notifyListeners();
          await Future<void>.delayed(const Duration(milliseconds: 280));
          await _transcodePath(gifUrl);
          break;
        case TargetCapability.acceptsNeither:
          await _fallbackSharePath(gifUrl);
          break;
      }
    } catch (e) {
      pipeline = PipelineState.error;
      lastError = e.toString();
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 2));
      _closeOverlay();
    }
  }

  Future<void> _directGifPath(
    String gifUrl, {
    bool preferShareOnFail = false,
  }) async {
    pipeline = PipelineState.downloading;
    progress = 0.35;
    notifyListeners();

    final local = await _bridge.downloadToCache(gifUrl);
    if (local == null) {
      throw Exception('Failed to cache GIF');
    }

    pipeline = PipelineState.committing;
    progress = 0.75;
    notifyListeners();

    final ok = await _bridge.commitGif(localPath: local, mimeType: 'image/gif');
    if (!ok) {
      if (preferShareOnFail) {
        await _openShare(local, 'image/gif');
        return;
      }
      // Host rejected GIF — try MP4 path.
      pipeline = PipelineState.blocksGifs;
      progress = 0.4;
      notifyListeners();
      await _transcodePath(gifUrl, cachedGifPath: local);
      return;
    }

    pipeline = PipelineState.success;
    progress = 1;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _closeOverlay();
  }

  Future<void> _transcodePath(
    String gifUrl, {
    String? cachedGifPath,
  }) async {
    pipeline = PipelineState.downloading;
    progress = 0.4;
    notifyListeners();

    final gifPath = cachedGifPath ?? await _bridge.downloadToCache(gifUrl);
    if (gifPath == null) {
      throw Exception('Failed to stream GIF into secure cache');
    }

    pipeline = PipelineState.packaging;
    progress = 0.55;
    notifyListeners();

    final mp4Path = await _bridge.transcodeGifToMp4(gifPath);
    if (mp4Path == null) {
      // Transcode failure → share raw GIF via system sheet.
      await _openShare(gifPath, 'image/gif');
      return;
    }

    pipeline = PipelineState.committing;
    progress = 0.85;
    notifyListeners();

    final ok =
        await _bridge.commitGif(localPath: mp4Path, mimeType: 'video/mp4');
    if (!ok) {
      await _openShare(mp4Path, 'video/mp4');
      return;
    }

    pipeline = PipelineState.success;
    progress = 1;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _closeOverlay();
  }

  Future<void> _iosDualWritePath(String gifUrl) async {
    pipeline = PipelineState.downloading;
    progress = 0.35;
    notifyListeners();

    final gifPath = await _bridge.downloadToCache(gifUrl);
    if (gifPath == null) throw Exception('Failed to cache GIF');

    pipeline = PipelineState.packaging;
    progress = 0.55;
    notifyListeners();

    final mp4Path = await _bridge.transcodeGifToMp4(gifPath);

    pipeline = PipelineState.committing;
    progress = 0.85;
    notifyListeners();

    final ok = await _bridge.writeDualPasteboard(
      gifPath: gifPath,
      mp4Path: mp4Path,
    );

    if (!ok) {
      await _openShare(mp4Path ?? gifPath, mp4Path != null ? 'video/mp4' : 'image/gif');
      return;
    }

    pipeline = PipelineState.success;
    progress = 1;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _closeOverlay();
  }

  Future<void> _fallbackSharePath(String gifUrl) async {
    pipeline = PipelineState.downloading;
    progress = 0.4;
    notifyListeners();
    final local = await _bridge.downloadToCache(gifUrl);
    if (local == null) throw Exception('Download failed');

    // Prefer MP4 for broader compatibility in share targets.
    pipeline = PipelineState.packaging;
    progress = 0.6;
    notifyListeners();
    final mp4 = await _bridge.transcodeGifToMp4(local);
    await _openShare(mp4 ?? local, mp4 != null ? 'video/mp4' : 'image/gif');
  }

  Future<void> _openShare(String path, String mime) async {
    pipeline = PipelineState.sharingFallback;
    progress = 0.9;
    notifyListeners();
    await _bridge.openShareSheet(path: path, mimeType: mime);
    pipeline = PipelineState.success;
    progress = 1;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _closeOverlay();
  }

  void _closeOverlay() {
    overlayVisible = false;
    pipeline = PipelineState.idle;
    progress = 0;
    notifyListeners();
  }

  void dismissOverlay() => _closeOverlay();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }
}

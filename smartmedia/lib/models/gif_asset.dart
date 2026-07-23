class GifAsset {
  const GifAsset({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.gifUrl,
    required this.width,
    required this.height,
  });

  final String id;
  final String title;
  final String previewUrl;
  final String gifUrl;
  final int width;
  final int height;

  double get aspectRatio =>
      width > 0 && height > 0 ? width / height : 1.0;

  factory GifAsset.fromGiphy(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};
    final original = images['original'] as Map<String, dynamic>? ?? {};
    final fixed = images['fixed_width'] as Map<String, dynamic>? ?? original;
    final preview = images['fixed_width_downsampled'] as Map<String, dynamic>? ??
        fixed;

    return GifAsset(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'GIF',
      previewUrl: preview['url'] as String? ?? fixed['url'] as String? ?? '',
      gifUrl: original['url'] as String? ?? fixed['url'] as String? ?? '',
      width: int.tryParse('${fixed['width'] ?? original['width'] ?? 200}') ??
          200,
      height:
          int.tryParse('${fixed['height'] ?? original['height'] ?? 200}') ??
              200,
    );
  }

  factory GifAsset.fromTenor(Map<String, dynamic> json) {
    final media = (json['media_formats'] as Map<String, dynamic>?) ?? {};
    final gif = media['gif'] as Map<String, dynamic>? ?? {};
    final tiny = media['tinygif'] as Map<String, dynamic>? ?? gif;
    final dims = (tiny['dims'] as List?)?.cast<num>() ??
        (gif['dims'] as List?)?.cast<num>() ??
        [200, 200];

    return GifAsset(
      id: json['id'] as String? ?? '',
      title: json['content_description'] as String? ?? 'GIF',
      previewUrl: tiny['url'] as String? ?? '',
      gifUrl: gif['url'] as String? ?? tiny['url'] as String? ?? '',
      width: dims.isNotEmpty ? dims[0].toInt() : 200,
      height: dims.length > 1 ? dims[1].toInt() : 200,
    );
  }
}

enum TargetCapability {
  acceptsGif,
  acceptsMp4Only,
  acceptsNeither,
  unknown,
}

enum PipelineState {
  idle,
  checkingTarget,
  blocksGifs,
  downloading,
  packaging,
  committing,
  sharingFallback,
  success,
  error,
}

extension PipelineStateMessage on PipelineState {
  String get message {
    switch (this) {
      case PipelineState.idle:
        return '';
      case PipelineState.checkingTarget:
        return 'Inspecting target field capabilities…';
      case PipelineState.blocksGifs:
        return 'Target field blocks GIFs…';
      case PipelineState.downloading:
        return 'Streaming GIF into secure cache…';
      case PipelineState.packaging:
        return 'Packaging into H.264 MP4 container…';
      case PipelineState.committing:
        return 'Committing media to host app…';
      case PipelineState.sharingFallback:
        return 'Opening system share sheet…';
      case PipelineState.success:
        return 'Delivered successfully.';
      case PipelineState.error:
        return 'Something went wrong. Try another GIF.';
    }
  }
}

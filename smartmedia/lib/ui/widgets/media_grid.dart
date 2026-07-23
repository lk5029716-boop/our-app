import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/gif_asset.dart';
import '../../theme/smartmedia_theme.dart';

class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.assets,
    required this.onSelect,
    this.loading = false,
  });

  final List<GifAsset> assets;
  final ValueChanged<GifAsset> onSelect;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && assets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: SMColors.indigo),
      );
    }
    if (assets.isEmpty) {
      return const Center(
        child: Text(
          'No GIFs found',
          style: TextStyle(color: SMColors.muted),
        ),
      );
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        return _GifCard(asset: asset, onTap: () => onSelect(asset));
      },
    );
  }
}

class _GifCard extends StatelessWidget {
  const _GifCard({required this.asset, required this.onTap});

  final GifAsset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: asset.aspectRatio.clamp(0.55, 1.8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: SMColors.surfaceElevated,
                  child: CachedNetworkImage(
                    imageUrl: asset.previewUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SMColors.violet,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: SMColors.muted,
                    ),
                  ),
                ),
                // GIF badge — bottom-right
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: SMColors.badgeBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: SMColors.glassBorder),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        color: SMColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

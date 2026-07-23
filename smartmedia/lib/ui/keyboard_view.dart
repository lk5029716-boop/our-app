import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/asset_selection_controller.dart';
import '../theme/smartmedia_theme.dart';
import 'widgets/keyboard_header.dart';
import 'widgets/media_grid.dart';
import 'widgets/search_capsule.dart';
import 'widgets/transcode_overlay.dart';

/// Full keyboard surface: sticky header, search capsule, 2-col masonry grid.
class KeyboardView extends StatefulWidget {
  const KeyboardView({super.key});

  @override
  State<KeyboardView> createState() => _KeyboardViewState();
}

class _KeyboardViewState extends State<KeyboardView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AssetSelectionController>();

    return ColoredBox(
      color: SMColors.background,
      child: Stack(
        children: [
          Column(
            children: [
              KeyboardHeader(
                engineActive: ctrl.engineActive,
                onSettings: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enable SmartMedia keyboard in system settings.',
                      ),
                      backgroundColor: SMColors.surfaceElevated,
                    ),
                  );
                },
              ),
              SearchCapsule(
                controller: _searchCtrl,
                onChanged: ctrl.onQueryChanged,
              ),
              if (ctrl.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    ctrl.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              Expanded(
                child: MediaGrid(
                  assets: ctrl.assets,
                  loading: ctrl.loading,
                  onSelect: (asset) =>
                      ctrl.handleAssetSelection(asset.gifUrl),
                ),
              ),
            ],
          ),
          TranscodeOverlay(
            visible: ctrl.overlayVisible,
            state: ctrl.pipeline,
            progress: ctrl.progress,
            onCancel: ctrl.dismissOverlay,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/smartmedia_theme.dart';

class KeyboardHeader extends StatelessWidget {
  const KeyboardHeader({
    super.key,
    required this.engineActive,
    this.onSettings,
  });

  final bool engineActive;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 0,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      opacity: 0.72,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                SMColors.accentGradient.createShader(bounds),
            child: const Text(
              'SmartMedia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          _EnginePulse(active: engineActive),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_rounded, color: SMColors.muted),
          ),
        ],
      ),
    );
  }
}

class _EnginePulse extends StatefulWidget {
  const _EnginePulse({required this.active});
  final bool active;

  @override
  State<_EnginePulse> createState() => _EnginePulseState();
}

class _EnginePulseState extends State<_EnginePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const Text(
        'Engine: Idle',
        style: TextStyle(color: SMColors.muted, fontSize: 12),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = 0.45 + (_c.value * 0.55);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SMColors.enginePulse.withOpacity(t),
                boxShadow: [
                  BoxShadow(
                    color: SMColors.enginePulse.withOpacity(t * 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Engine: Active',
              style: TextStyle(
                color: SMColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/asset_selection_controller.dart';
import 'theme/smartmedia_theme.dart';
import 'ui/keyboard_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SMColors.background,
    ),
  );
  runApp(const SmartMediaApp());
}

class SmartMediaApp extends StatelessWidget {
  const SmartMediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AssetSelectionController()..bootstrap(),
      child: MaterialApp(
        title: 'SmartMedia',
        debugShowCheckedModeBanner: false,
        theme: SMTheme.dark(),
        home: const HomeShell(),
      ),
    );
  }
}

/// Companion app shell — onboarding + live keyboard preview surface.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SMColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        SMColors.accentGradient.createShader(b),
                    child: const Text(
                      'SmartMedia',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open-source GIF keyboard with on-the-fly H.264 packaging '
                    'when the host app blocks native GIFs.',
                    style: TextStyle(color: SMColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  GlassContainer(
                    padding: const EdgeInsets.all(12),
                    child: const Row(
                      children: [
                        Icon(Icons.keyboard_alt_outlined,
                            color: SMColors.indigo),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'After install: System Settings → Keyboards → '
                            'enable SmartMedia. Full Access required for '
                            'network search & transcode.',
                            style: TextStyle(
                              color: SMColors.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: KeyboardView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

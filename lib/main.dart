import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'appliances/appliance_controller.dart';
import 'atv/atv_controller.dart';
import 'i18n/strings.dart';
import 'ui/onboarding_screen.dart';
import 'ui/pairing_screen.dart';
import 'ui/remote_screen.dart';
import 'ui/splash_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait — a remote shouldn't rotate.
  SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  runApp(const AtvRemoteApp());
}

class AtvRemoteApp extends StatelessWidget {
  const AtvRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AtvController()..load()),
        ChangeNotifierProvider(create: (_) => ApplianceController()..load()),
      ],
      child: MaterialApp(
        title: 'TV Remote',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AtvController>();
    final Widget screen;
    if (c.loading) {
      screen = const SplashScreen(key: ValueKey('splash'));
    } else if (!c.onboarded) {
      screen = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (c.stage == AppStage.remote) {
      screen = const RemoteScreen(key: ValueKey('remote'));
    } else {
      screen = const PairingScreen(key: ValueKey('pairing'));
    }
    // Wrap in Localized so the whole tree gets strings + correct text direction.
    return Localized(
      lang: c.lang,
      child: _switcher(screen),
    );
  }

  Widget _switcher(Widget screen) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: screen,
    );
  }
}

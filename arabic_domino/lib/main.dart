import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/preferences_service.dart';
import 'services/sfx_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  await PreferencesService.instance.init();
  await SfxService.instance.init();
  runApp(const DominoApp());
}

class DominoApp extends StatelessWidget {
  const DominoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PreferencesService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'دومينو',
          debugShowCheckedModeBanner: false,
          themeMode: PreferencesService.instance.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}

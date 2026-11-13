import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/onyx_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('notes');
  await Hive.openBox('settings');

  await NotificationService.initNotifications();

  runApp(const MyNotesApp());
}

class MyNotesApp extends StatefulWidget {
  const MyNotesApp({super.key});

  @override
  State<MyNotesApp> createState() => _MyNotesAppState();
}

class _MyNotesAppState extends State<MyNotesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await NotificationService.clearActiveNotificationsOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settingsBox, _) {
        final bool isDark = OnyxSettings.isDark;
        final pal = OnyxPalette.of(isDark);

        return MaterialApp(
          title: 'ONYX Luxury Notes',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: pal.scaffoldBg,
            primaryColor: pal.accent,
            fontFamily: 'Tahoma',
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: pal.textPrimary),
              centerTitle: true,
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: pal.accent,
              selectionColor: pal.accent.withOpacity(0.30),
              selectionHandleColor: pal.accent,
            ),
          ),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

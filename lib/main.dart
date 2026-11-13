import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/onyx_theme.dart';
import 'widgets/luxury_3d_glass.dart';

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
  late bool _sessionUnlocked;
  final TextEditingController _appPinController = TextEditingController();
  String? _pinError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionUnlocked = !OnyxSettings.appLockEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appPinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await NotificationService.clearActiveNotificationsOnResume();
    }
  }

  void _tryUnlockApp() {
    if (_appPinController.text.trim() == OnyxSettings.vaultPin) {
      setState(() {
        _sessionUnlocked = true;
        _pinError = null;
        _appPinController.clear();
      });
    } else {
      setState(() => _pinError = 'الرقم السري غير صحيح');
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
          title: 'ملاحظاتي',
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
              child: Stack(
                children: [
                  child!,
                  if (!_sessionUnlocked)
                    Scaffold(
                      backgroundColor: pal.scaffoldBg,
                      body: OnyxBackdrop(
                        palette: pal,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Onyx3DGlassCard(
                              isHighlighted: true,
                              enableShimmer: true,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 46,
                                    color: pal.textPrimary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'التطبيق مقفل',
                                    style: TextStyle(
                                      color: pal.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'أدخل الرقم السري للمتابعة',
                                    style: TextStyle(
                                      color: pal.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _appPinController,
                                    obscureText: true,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: pal.textPrimary,
                                      fontSize: 22,
                                      letterSpacing: 6,
                                    ),
                                    onSubmitted: (_) => _tryUnlockApp(),
                                    decoration: InputDecoration(
                                      hintText: '••••',
                                      hintStyle:
                                          TextStyle(color: pal.textMuted),
                                      errorText: _pinError,
                                      filled: true,
                                      fillColor: pal.inputFill,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide:
                                            BorderSide(color: pal.glassBorder),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Onyx3DButton(
                                      label: 'فتح التطبيق',
                                      icon: Icons.lock_open,
                                      onPressed: _tryUnlockApp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

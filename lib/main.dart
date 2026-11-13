import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/home_screen.dart';
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
  late final bool _wasLockedOnBoot;
  late bool _sessionUnlocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasLockedOnBoot = OnyxSettings.appLockEnabled;
    _sessionUnlocked = !_wasLockedOnBoot;
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
              child: child!,
            );
          },
          home: _sessionUnlocked
              ? (_wasLockedOnBoot
                  ? const HomeScreen(key: ValueKey('home_unlocked'))
                  : const SplashScreen(key: ValueKey('splash_boot')))
              : _AppLockScreen(
                  key: const ValueKey('app_lock_gate'),
                  onUnlocked: () => setState(() => _sessionUnlocked = true),
                ),
        );
      },
    );
  }
}

class _AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const _AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<_AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<_AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  String? _pinError;
  bool _obscure = true;
  int _attemptNonce = 0;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _resetInput({String? error}) {
    _pinController.clear();
    setState(() {
      _pinError = error;
      _attemptNonce++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocus.requestFocus();
    });
  }

  void _tryUnlock() {
    if (_pinController.text.trim() == OnyxSettings.vaultPin) {
      widget.onUnlocked();
    } else {
      _resetInput(error: 'الرقم السري غير صحيح، أعد المحاولة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: OnyxBackdrop(
        palette: pal,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
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
                    const SizedBox(height: 18),
                    TextField(
                      key: ValueKey(_attemptNonce),
                      controller: _pinController,
                      focusNode: _pinFocus,
                      obscureText: _obscure,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const <String>[],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 22,
                        letterSpacing: 6,
                      ),
                      onChanged: (_) {
                        if (_pinError != null) {
                          setState(() => _pinError = null);
                        }
                      },
                      onSubmitted: (_) => _tryUnlock(),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: TextStyle(color: pal.textMuted),
                        errorText: _pinError,
                        prefixIcon: IconButton(
                          tooltip: _obscure ? 'إظهار' : 'إخفاء',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: pal.textMuted,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'مسح',
                          icon: Icon(
                            Icons.close,
                            color: pal.textMuted,
                            size: 20,
                          ),
                          onPressed: () => _resetInput(),
                        ),
                        filled: true,
                        fillColor: pal.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: pal.glassBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: Onyx3DButton(
                        label: 'فتح التطبيق',
                        icon: Icons.lock_open,
                        onPressed: _tryUnlock,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

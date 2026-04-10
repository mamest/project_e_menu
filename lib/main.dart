import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_localizations.dart';

import 'pages/restaurant_list_page.dart';

/// Supported language codes in the app.
const List<String> kSupportedLocales = ['en', 'de'];

/// Global locale notifier. `null` means "follow the system locale".
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl != null &&
      supabaseKey != null &&
      supabaseUrl.isNotEmpty &&
      supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  }

  // Load persisted locale preference before first frame.
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('app_locale');
  if (saved != null && kSupportedLocales.contains(saved)) {
    appLocaleNotifier.value = Locale(saved);
  }

  runApp(const MyApp());
}

/// Persist and apply a new locale. Pass `null` to follow the system locale.
Future<void> setAppLocale(Locale? locale) async {
  final prefs = await SharedPreferences.getInstance();
  if (locale == null) {
    await prefs.remove('app_locale');
  } else {
    await prefs.setString('app_locale', locale.languageCode);
  }
  appLocaleNotifier.value = locale;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    appLocaleNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    appLocaleNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Menu',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // null → Flutter uses the device/browser locale automatically.
      locale: appLocaleNotifier.value,
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
          primary: Colors.deepPurple,
          secondary: const Color(0xFF8B5CF6),
          tertiary: const Color(0xFF6D28D9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.deepPurple.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.deepPurple.shade50,
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        useMaterial3: true,
      ),
      home: const RestaurantListPage(),
    );
  }
}

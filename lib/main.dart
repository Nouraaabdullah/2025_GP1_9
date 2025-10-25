// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🟣 Background updaters
import 'screens/update_monthly_record_service.dart';
import 'screens/category_summary_service.dart';
import 'utils/auth_helpers.dart'; // for getProfileId(context)

// ✅ Screens
import 'screens/Registeration/welcome_screen.dart';
import 'screens/Registeration/login_screen.dart';
import 'screens/Registeration/signup_screen.dart';
import 'screens/profile/profile_main.dart';
import 'screens/profile/edit_profile/edit_profile.dart';
import 'screens/Savings/savings_page.dart';
import 'screens/dashboard/dashboard_page.dart';
import 'screens/Registeration/profile_setup/setup_name_screen.dart';
import 'screens/Registeration/profile_setup/setup_income_screen.dart';
import 'screens/Registeration/profile_setup/setup_expenses_screen.dart';
import 'screens/Registeration/profile_setup/setup_balance_screen.dart';
import 'screens/Registeration/profile_setup/setup_complete_screen.dart';
import 'screens/Registeration/profile_setup/setup_categories_screen.dart';
import 'screens/Registeration/profile_setup/add_edit_category_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xvnkuqqzlstzwgeecijn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh2bmt1cXF6bHN0endnZWVjaWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2ODI2NzYsImV4cCI6MjA3NjI1ODY3Nn0.o9qiOIa4WWNMxvF92uyojCPtDS4NGz5qyMBhwki8MDQ',
  );

  runApp(const SurraApp());
}

class SurraApp extends StatefulWidget {
  const SurraApp({super.key});

  @override
  State<SurraApp> createState() => _SurraAppState();
}

class _SurraAppState extends State<SurraApp> {
  final _supabase = Supabase.instance.client;

  User? _user;
  bool _isLoading = true;
  bool _servicesStarted = false;

  @override
  void initState() {
    super.initState();
    _getInitialSession();
  }

  Future<void> _getInitialSession() async {
    try {
      final session = _supabase.auth.currentSession;
      setState(() {
        _user = session?.user;
        _isLoading = false;
      });

      // ✅ If already logged in, ensure services start once
      if (session?.user != null) {
        debugPrint('🟢 User already logged in – ensuring background updaters start once.');
        await _ensureMonthlyAndCategoryServices(context);
      }

      // 🔹 Handle login/logout transitions
      _supabase.auth.onAuthStateChange.listen((event) async {
        final session = event.session;
        if (session != null) {
          await _ensureMonthlyAndCategoryServices(context);
        } else {
          UpdateMonthlyRecordService.stop();
          UpdateCategorySummaryService.stop();
          _servicesStarted = false;
          debugPrint('🔴 Updaters stopped after logout');
        }
      });
    } catch (e) {
      setState(() {
        _user = null;
        _isLoading = false;
      });
      debugPrint('❌ Error initializing session: $e');
    }
  }

  /// Ensures that Monthly + Category summary updaters start exactly once
  Future<void> _ensureMonthlyAndCategoryServices(BuildContext context) async {
    if (_servicesStarted) {
      debugPrint('⚙️ Updaters already running – skipping duplicate start.');
      return;
    }
    _servicesStarted = true;

    String? profileId;
    int retries = 0;

    // 🔁 Try up to 5 times to get profile (in case context not ready yet)
    while (profileId == null && retries < 5) {
      profileId = await getProfileId(context);
      if (profileId == null) {
        debugPrint('[main.dart] ⚠️ Profile not ready (retry $retries)');
        await Future.delayed(const Duration(seconds: 1));
        retries++;
      }
    }

    if (profileId == null) {
      debugPrint('[main.dart] ❌ Failed to fetch profile ID after retries.');
      _servicesStarted = false;
      return;
    }

    // 🟢 Guarantee a record exists before realtime starts
    await UpdateMonthlyRecordService.startWithoutContext(profileId);
    debugPrint('🟢 Ensured monthly record exists for $profileId');

    // 🟢 Start live background updaters
    await UpdateMonthlyRecordService.start(context);
    await UpdateCategorySummaryService.start(context);

    debugPrint('✅ Background updaters started successfully.');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF1D1B32),
          body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF7959F5)),
          ),
        ),
      );
    }

    final bool isLoggedIn = _user != null;
    final String initialRoute = isLoggedIn ? '/dashboard' : '/welcome';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Surra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7959F5)),
        scaffoldBackgroundColor: const Color(0xFF1D1B32),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      initialRoute: initialRoute,
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const DashboardPage(),
        '/profile': (context) => const ProfileMainPage(),
        '/editProfile': (context) => const EditProfilePage(),
        '/savings': (context) => const SavingsPage(),
        '/setupName': (context) => const SetupNameScreen(),
        '/setupIncome': (context) => const SetupIncomeScreen(),
        '/setupExpenses': (context) => const SetupExpensesScreen(),
        '/setupBalance': (context) => const SetupBalanceScreen(),
        '/setupComplete': (context) => const SetupCompleteScreen(),
        '/setupCategories': (context) => SetupCategoriesScreen(),
        '/addEditCategory': (context) => const AddEditCategoryPage(),
      },
    );
  }
}

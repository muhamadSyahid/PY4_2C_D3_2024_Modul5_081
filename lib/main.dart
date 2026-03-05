import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logbook_app_081/features/auth/login_view.dart';
import 'package:logbook_app_081/features/onboarding/onboarding_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await dotenv.load(fileName: ".env");
  bool isDone = prefs.getBool('is_onboarding_done') ?? false;
  runApp(MyApp(isDone: isDone));
  // runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final bool isDone;
  const MyApp({super.key, required this.isDone});
  // const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isDone ? const LoginView() : const OnboardingView(),
      // home: const OnboardingView(),
    );
  }
}

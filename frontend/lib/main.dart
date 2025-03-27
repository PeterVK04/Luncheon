import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/create_account_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_creation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LuncheonApp());
}

class LuncheonApp extends StatelessWidget {
  const LuncheonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luncheon',
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/create-account': (context) => const CreateAccountPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/profile-creation': (context) => const ProfileCreationPage(),
      },
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/create_account_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_creation_page.dart';
import 'pages/profile_view_page.dart';
import 'pages/friendship_matching_page.dart';
import 'pages/professional_matching_page.dart';
import 'pages/travel_matching_page.dart';
import 'pages/dating_matching_page.dart';
import 'pages/messaging_page.dart'; 
import 'pages/conversations_list_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
      // Always try to initialize. If it’s already been done (auto-init or a
      // previous call), we’ll catch & ignore that specific exception.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform.copyWith(
          storageBucket: 'luncheon-7278b.appspot.com',
        ),
      );
    } on FirebaseException catch (e) {
      // FirebaseException.code for a second init is either 'duplicate-app'
      // or 'already-initialized' depending on platform—so just check for both.
      if (e.code != 'duplicate-app' && e.code != 'already-initialized') {
        // If it’s some other problem, rethrow.
        rethrow;
      }
      // Otherwise: do nothing. We know the default app is already up.
    }
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
        '/profile-view': (context) => const ProfileViewPage(),
        '/profile-creation': (context) => const ProfileCreationPage(),
        '/friendship-matching': (ctx) => const FriendshipMatchingPage(),
        '/professional-matching': (ctx) => const ProfessionalMatchingPage(),
        '/travel-matching': (ctx) => const TravelMatchingPage(),
        '/dating-matching': (ctx) => const DatingMatchingPage(),
        '/conversations': (ctx) => const ConversationsListPage(),
        '/chat':          (ctx) {
          final otherUid = ModalRoute.of(ctx)!.settings.arguments as String;
          return MessagingPage(otherUid: otherUid);
        },
      },
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

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
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Luncheon',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/create-account'),
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

   void _handleLogin() async {
  final email = _usernameController.text.trim();
  final password = _passwordController.text;

  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    Navigator.pushReplacementNamed(context, '/home');
  } catch (e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text('Error: ${e.toString()}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Try Again')),
        ],
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _handleLogin,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Home', style: TextStyle(fontSize: 32))),
    );
  }
}



class _CreateAccountPageState extends State<CreateAccountPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreed = false;

  bool get _canSubmit =>
      _usernameController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _agreed;

  void _handleCreateAccount() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: username,
        password: password,
      );
      Navigator.pushReplacementNamed(context, '/home');

    }
    
    catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Create Account Failed'),
          content: Text('Error: ${e.toString()}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Try Again')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (val) => setState(() => _agreed = val ?? false),
                ),
                const Expanded(
                  child: Text('I agree to Luncheon’s terms and conditions'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _canSubmit ? _handleCreateAccount : null,
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
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
    // After account creation, navigate to the profile creation page
    Navigator.pushReplacementNamed(context, '/profile-creation');
  } catch (e) {
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

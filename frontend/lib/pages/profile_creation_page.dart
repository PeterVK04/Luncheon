// pages/profile_creation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileCreationPage extends StatefulWidget {
  const ProfileCreationPage({super.key});

  @override
  State<ProfileCreationPage> createState() => _ProfileCreationPageState();
}

class _ProfileCreationPageState extends State<ProfileCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _professionController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime? _birthday;

  // Opens a date picker and sets the birthday.
  Future<void> _selectBirthday() async {
    final initialDate = DateTime(2000, 1, 1);
    final newDate = await showDatePicker(
      context: context,
      initialDate: _birthday ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (newDate != null) {
      setState(() {
        _birthday = newDate;
      });
    }
  }

  // Validator for the short bio to ensure it's less than 128 words.
  String? _validateBio(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a short bio';
    }
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length >= 128) {
      return 'Bio must be less than 128 words';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      if (_birthday == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your birthday')),
        );
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullName': _fullNameController.text.trim(),
          'profession': _professionController.text.trim(),
          'birthday': _birthday!.toIso8601String(),
          'bio': _bioController.text.trim(),
        });
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _professionController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Complete your profile',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _professionController,
                decoration: const InputDecoration(
                  labelText: 'Profession',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter your profession' : null,
              ),
              const SizedBox(height: 16),
              // Birthday field using a gesture detector to show the date picker.
              GestureDetector(
                onTap: _selectBirthday,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Birthday',
                      hintText: _birthday != null
                          ? '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}'
                          : 'Select your birthday',
                    ),
                    validator: (_) => _birthday == null ? 'Select your birthday' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Short Bio',
                  hintText: 'Tell us something about yourself (less than 128 words)',
                ),
                maxLines: 5,
                validator: _validateBio,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
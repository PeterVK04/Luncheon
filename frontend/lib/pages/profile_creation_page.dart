import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

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

  // --- Photo picking & cropping state ---
  final ImagePicker _picker = ImagePicker();
  final CropController _cropController = CropController();
  final List<Uint8List> _photos = [];

  // --- Determine user position ---
  Future<Position> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled.');
    }
    LocationPermission status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
      if (status == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    if (status == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  // Opens a date picker and sets the birthday.
  Future<void> _selectBirthday() async {
    final initialDate = DateTime(2000, 1, 1);
    final newDate = await showDatePicker(
      context: context,
      initialDate: _birthday ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (newDate != null) setState(() => _birthday = newDate);
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

  // Pick image, show in-app cropper, store result in _photos.
  Future<void> _pickAndCropImage() async {
    if (_photos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only upload up to 5 photos.')),
      );
      return;
    }

    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final rawData = await picked.readAsBytes();

    // Show crop dialog, get cropped bytes back
    final Uint8List? cropped = await showDialog<Uint8List>(
      context: context,
      builder: (_) => _CropDialog(
        rawImage: rawData,
        controller: _cropController,
      ),
    );

    if (cropped != null) {
      setState(() => _photos.add(cropped));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthday')),
      );
      return;
    }
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one photo')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1) Determine and save location
    Position pos;
    try {
      pos = await _determinePosition();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: \$e')),
      );
      return;
    }

    // 2) Upload photos
    final storage = FirebaseStorage.instance;
    final rootRef = storage.ref();
    final List<String> photoUrls = [];

    for (var i = 0; i < _photos.length; i++) {
      final childPath = 'users/\${user.uid}/photos/photo_\$i.jpg';
      final fileRef = rootRef.child(childPath);
      try {
        final uploadTask = fileRef.putData(
          _photos[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final snapshot = await uploadTask;
        photoUrls.add(await snapshot.ref.getDownloadURL());
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo #\$i: \${e.code}')),
        );
        return;
      }
    }

    // 3) Write Firestore user document with all data
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'fullName': _fullNameController.text.trim(),
      'profession': _professionController.text.trim(),
      'birthday': _birthday!.toIso8601String(),
      'bio': _bioController.text.trim(),
      'photoUrls': photoUrls,
      'location': {'lat': pos.latitude, 'lng': pos.longitude},
    }, SetOptions(merge: true));

    // 4) Navigate on success
    Navigator.pushReplacementNamed(context, '/home');
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
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _professionController,
                decoration: const InputDecoration(labelText: 'Profession'),
                validator: (v) => v == null || v.isEmpty ? 'Enter your profession' : null,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _selectBirthday,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Birthday',
                      hintText: _birthday != null
                          ? '\${_birthday!.month}/\${_birthday!.day}/\${_birthday!.year}'
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
              const Text(
                'Upload Photo(s) (1–5):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bytes in _photos)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => setState(() => _photos.remove(bytes)),
                        ),
                      ],
                    ),
                  if (_photos.length < 5)
                    GestureDetector(
                      onTap: _pickAndCropImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.add_a_photo),
                      ),
                    ),
                ],
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

class _CropDialog extends StatelessWidget {
  final Uint8List rawImage;
  final CropController controller;
  const _CropDialog({required this.rawImage, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: Crop(
              image: rawImage,
              controller: controller,
              onCropped: (result) {
                if (result is CropSuccess) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pop(result.croppedImage);
                  });
                } else if (result is CropFailure) {
                  debugPrint('❌ Crop failed: \${result.cause}');
                }
              },
              aspectRatio: 1.0,
              withCircleUi: false,
              baseColor: Colors.black12,
              maskColor: Colors.black45,
              cornerDotBuilder: (size, index) => const DotControl(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => controller.crop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

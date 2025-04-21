// pages/home_page.dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridButtonWidth = screenWidth * 0.45;
    // Increase profile button width by 50%: originally screenWidth/5 (20%), now 30%
    final profileButtonWidth = screenWidth * 0.30;
    // Messaging button same width as profile button
    final messagingButtonWidth = profileButtonWidth;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Stack(
        children: [
          // 4-button grid slightly above center
          Align(
            alignment: const Alignment(0, -0.3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: gridButtonWidth,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/friendship-matching'),
                        child: const Text('Friendship'),
                      ),
                    ),
                    SizedBox(
                      width: gridButtonWidth,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/professional-matching'),
                        child: const Text('Professional'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: gridButtonWidth,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/travel-matching'),
                        child: const Text('Travel'),
                      ),
                    ),
                    SizedBox(
                      width: gridButtonWidth,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/dating-matching'),
                        child: const Text('Dating'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Profile View button at bottom-right
          Positioned(
            bottom: 16,
            right: 16,
            child: SizedBox(
              width: profileButtonWidth,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/profile-view'),
                child: const Text('Profile'),
              ),
            ),
          ),

          // Messaging button at bottom-left
          Positioned(
            bottom: 16,
            left: 16,
            child: SizedBox(
              width: messagingButtonWidth,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/messaging'),
                child: const Text('Messaging'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

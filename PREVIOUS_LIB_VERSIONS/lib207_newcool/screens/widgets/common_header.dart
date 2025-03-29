// lib/widgets/common_header.dart
import 'package:flutter/material.dart';
import 'package:lucid_dream_trainer/screens/settings/settings_screen.dart';
import 'package:lucid_dream_trainer/screens/tutorial/tutorial_screen.dart';

class CommonHeader extends StatelessWidget implements PreferredSizeWidget {
  const CommonHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Make the header transparent so we can see the global background
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Lucid Now',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.help_outline, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TutorialScreen(),
            ),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

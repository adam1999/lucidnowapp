// lib/screens/profile/widgets/profile_pic_selector.dart

import 'package:flutter/material.dart';

class ProfilePicSelector extends StatelessWidget {
  final Function(int) onSelect;
  final int currentSelection;

  const ProfilePicSelector({
    super.key,
    required this.onSelect,
    required this.currentSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D36).withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Your Avatar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final number = index + 1;
                return GestureDetector(
                  onTap: () {
                    onSelect(number);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D36).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: currentSelection == number
                          ? Border.all(color: Colors.purple, width: 2)
                          : null,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/userpp/$number.png',
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
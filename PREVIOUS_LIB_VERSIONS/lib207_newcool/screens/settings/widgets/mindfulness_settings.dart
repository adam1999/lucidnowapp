// Create a new file (or add to your settings widgets) called mindfulness_settings.dart:

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../training/main_training_page.dart'; // For MindfulnessBlock

class MindfulnessSettingsDialog extends StatefulWidget {
  final MindfulnessBlock block;
  final Function(MindfulnessBlock) onBlockUpdated;

  const MindfulnessSettingsDialog({
    Key? key,
    required this.block,
    required this.onBlockUpdated,
  }) : super(key: key);

  @override
  State<MindfulnessSettingsDialog> createState() => _MindfulnessSettingsDialogState();
}

class _MindfulnessSettingsDialogState extends State<MindfulnessSettingsDialog> {
  late int durationMinutes;
  late int cues;

  static const int minDuration = 1;
  static const int maxDuration = 30;
  static const int defaultDuration = 5;

  static const int minCues = 0;
  static const int maxCues = 100;
  static const int defaultCues = 10;

  @override
  void initState() {
    super.initState();
    // Initialize from the current block settings (or use defaults)
    durationMinutes = widget.block.senseDuration.inMinutes;
    cues = defaultCues;
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      durationMinutes = prefs.getInt('mindfulness_duration') ?? defaultDuration;
      cues = prefs.getInt('mindfulness_cues') ?? defaultCues;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mindfulness_duration', durationMinutes);
    await prefs.setInt('mindfulness_cues', cues);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2D2D36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mindfulness Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Cycle Length Slider
            Text(
              'Cycle Length: $durationMinutes min',
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(
              value: durationMinutes.toDouble(),
              min: minDuration.toDouble(),
              max: maxDuration.toDouble(),
              divisions: maxDuration - minDuration,
              activeColor: const Color(0xFF5E5DE3),
              inactiveColor: const Color(0xFF403E49),
              label: '$durationMinutes',
              onChanged: (value) {
                setState(() {
                  durationMinutes = value.round();
                });
              },
            ),
            const SizedBox(height: 24),
            // Cues Slider
            Text(
              'Number of Cues: $cues',
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(
              value: cues.toDouble(),
              min: minCues.toDouble(),
              max: maxCues.toDouble(),
              divisions: maxCues - minCues,
              activeColor: const Color(0xFF5E5DE3),
              inactiveColor: const Color(0xFF403E49),
              label: '$cues',
              onChanged: (value) {
                setState(() {
                  cues = value.round();
                });
              },
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    setState(() {
                      durationMinutes = defaultDuration;
                      cues = defaultCues;
                    });
                    await _saveSettings();
                  },
                  child: Text(
                    'Reset to Default',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E5DE3),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    await _saveSettings();
                    // Create an updated MindfulnessBlock with the new settings.
                    final updatedBlock = MindfulnessBlockCustom(
                      durationMinutes: durationMinutes,
                      cues: cues,
                    );
                    widget.onBlockUpdated(updatedBlock);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Create a new class for a customizable Mindfulness block.
class MindfulnessBlockCustom extends MindfulnessBlock {
  final int customDurationMinutes;
  final int customCues;

  MindfulnessBlockCustom({required int durationMinutes, required int cues})
      : customDurationMinutes = durationMinutes,
        customCues = cues,
        super() {
    // Optionally, you can update additional properties here.
    // For example, if you want to use customCues in your cue scheduling,
    // update your global maxMindfulnessCues in your state:
    // (Assume you call: setState(() { maxMindfulnessCues = customCues; }); in your TrainingScreen state.)
  }

  @override
  Duration get senseDuration => Duration(minutes: customDurationMinutes);
}

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

class _MindfulnessSettingsDialogState extends State<MindfulnessSettingsDialog> with SingleTickerProviderStateMixin {
  late int durationMinutes;
  late int cues;
  late AnimationController _animationController;
  late Animation<double> _animation;

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
    
    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
    
    _loadSavedSettings();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
  
  Widget _buildSliderSetting(String title, String value, double sliderValue, double min, double max, int divisions, Function(double) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E5DE3).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF5E5DE3),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: const Color(0xFF5E5DE3),
              inactiveTrackColor: const Color(0xFF403E49),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF5E5DE3).withOpacity(0.2),
            ),
            child: Slider(
              value: sliderValue,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeTransition(
        opacity: _animation,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2D2D36),
                    Color(0xFF252531),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with gradient underline
                    Column(
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
                        const SizedBox(height: 6),
                        Container(
                          width: 120,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5E5DE3), Colors.purple],
                            ),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    // Cycle Length Slider
                    _buildSliderSetting(
                      'Cycle Length',
                      '$durationMinutes min',
                      durationMinutes.toDouble(),
                      minDuration.toDouble(),
                      maxDuration.toDouble(),
                      maxDuration - minDuration,
                      (value) {
                        setState(() {
                          durationMinutes = value.round();
                        });
                      },
                    ),
                    
                    // Cues Slider
                    _buildSliderSetting(
                      'Number of Cues',
                      cues.toString(),
                      cues.toDouble(),
                      minCues.toDouble(),
                      maxCues.toDouble(),
                      maxCues - minCues,
                      (value) {
                        setState(() {
                          cues = value.round();
                        });
                      },
                    ),
                    
                    // Information card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(top: 8, bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.blue.withOpacity(0.8),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Mindfulness Training',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cues will be played randomly during your session to help maintain awareness.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () async {
                            setState(() {
                              durationMinutes = defaultDuration;
                              cues = defaultCues;
                            });
                            await _saveSettings();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text(
                            'Reset to Default',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5E5DE3),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
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
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Close button positioned on top
            Positioned(
              right: -10,
              top: -10,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF403E49),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
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

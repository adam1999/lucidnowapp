// lib/screens/settings/widgets/sleep_settings.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../training/main_training_page.dart'; // Ensure this import is correct for your Block model
import 'package:lucid_dream_trainer/services/purchases_service.dart';
import 'package:lucid_dream_trainer/translations/app_translations.dart';
import 'package:provider/provider.dart';
import 'package:lucid_dream_trainer/providers/settings_provider.dart';

class SleepPhaseSettingsDialog extends StatefulWidget {
  final Block block;
  final Function(Block) onBlockUpdated;
  final Function(int) onSleepPhaseDelayChanged;
  final int currentDelay;

  const SleepPhaseSettingsDialog({
    Key? key,
    required this.block,
    required this.onBlockUpdated,
    required this.onSleepPhaseDelayChanged,
    required this.currentDelay,
  }) : super(key: key);

  @override
  State<SleepPhaseSettingsDialog> createState() => _SleepPhaseSettingsDialogState();
}

class _SleepPhaseSettingsDialogState extends State<SleepPhaseSettingsDialog> with SingleTickerProviderStateMixin {
  late int cycles;
  late int sleepTimeMinutes;
  late Duration senseDuration;
  late bool useRem1;
  late bool useRem2;
  late bool useRem3;
  late bool useRem4;
  late bool useRem5;
  late bool useRem6;
  late bool useRem7;
  late int signalsPerPhase;
  late int signalLapse;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Sleep time limits (in minutes)
  static const int minSleepTime = 120; // 2h minimum
  static const int maxSleepTime = 600; // 11h maximum
  static const int defaultSleepTime = 480; // 8h default
  static const int defaultSignalsPerPhase = 5;
  static const int defaultSignalLapse = 420; // 7 minutes in seconds

  @override
  void initState() {
    super.initState();
    cycles = widget.block.cycles;
    sleepTimeMinutes = widget.block.sleepPhaseDelay ?? defaultSleepTime;
    senseDuration = widget.block.senseDuration;
    useRem1 = widget.block.useRem1;
    useRem2 = widget.block.useRem2;
    useRem3 = widget.block.useRem3;
    useRem4 = widget.block.useRem4;
    useRem5 = widget.block.useRem5;
    useRem6 = widget.block.useRem6;
    useRem7 = widget.block.useRem7;
    signalsPerPhase = widget.block.signalsPerPhase;
    signalLapse = widget.block.senseDuration.inSeconds;
    
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

  void _resetToDefault() {
    setState(() {
      sleepTimeMinutes = defaultSleepTime;
      signalsPerPhase = defaultSignalsPerPhase;
      signalLapse = defaultSignalLapse;
      useRem1 = false;
      useRem2 = false;
      useRem3 = true;
      useRem4 = true;
      useRem5 = true;
      useRem6 = false;
      useRem7 = false;
    });
  }

  String _formatTimeInHoursMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}min';
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String blockKey = 'block_${widget.block.name}';
    setState(() {
      cycles = prefs.getInt('${blockKey}_cycles') ?? cycles;
      sleepTimeMinutes = prefs.getInt('${blockKey}_delay') ?? sleepTimeMinutes;
      if (sleepTimeMinutes < minSleepTime) sleepTimeMinutes = minSleepTime;
      if (sleepTimeMinutes > maxSleepTime) sleepTimeMinutes = maxSleepTime;
      signalLapse = prefs.getInt('${blockKey}_signal_lapse') ?? signalLapse;
      senseDuration = Duration(seconds: signalLapse);
      useRem1 = prefs.getBool('${blockKey}_useRem1') ?? useRem1;
      useRem2 = prefs.getBool('${blockKey}_useRem2') ?? useRem2;
      useRem3 = prefs.getBool('${blockKey}_useRem3') ?? useRem3;
      useRem4 = prefs.getBool('${blockKey}_useRem4') ?? useRem4;
      useRem5 = prefs.getBool('${blockKey}_useRem5') ?? useRem5;
      useRem6 = prefs.getBool('${blockKey}_useRem6') ?? useRem6;
      useRem7 = prefs.getBool('${blockKey}_useRem7') ?? useRem7;
      signalsPerPhase = prefs.getInt('${blockKey}_signals_per_phase') ?? signalsPerPhase;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String blockKey = 'block_${widget.block.name}';
    await prefs.setInt('${blockKey}_cycles', cycles);
    await prefs.setInt('${blockKey}_duration', senseDuration.inSeconds);
    await prefs.setInt('${blockKey}_delay', sleepTimeMinutes);
    await prefs.setBool('${blockKey}_useRem1', useRem1);
    await prefs.setBool('${blockKey}_useRem2', useRem2);
    await prefs.setBool('${blockKey}_useRem3', useRem3);
    await prefs.setBool('${blockKey}_useRem4', useRem4);
    await prefs.setBool('${blockKey}_useRem5', useRem5);
    await prefs.setBool('${blockKey}_useRem6', useRem6);
    await prefs.setBool('${blockKey}_useRem7', useRem7);
    await prefs.setInt('${blockKey}_signals_per_phase', signalsPerPhase);
    await prefs.setInt('${blockKey}_signal_lapse', signalLapse);
  }

  Widget _buildRemToggleButton(String label, String time, bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: value 
              ? const Color(0xFF5E5DE3).withOpacity(0.15) 
              : const Color(0xFF403E49).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value 
                ? const Color(0xFF5E5DE3) 
                : Colors.white.withOpacity(0.1),
            width: value ? 1.5 : 1,
          ),
          boxShadow: value ? [
            BoxShadow(
              color: const Color(0xFF5E5DE3).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white.withOpacity(0.6),
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: value ? const Color(0xFF5E5DE3) : Colors.white.withOpacity(0.3),
                fontSize: 12,
                fontWeight: value ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title with gradiant underline
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sleep Phase Settings',
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

                    // Signals Per Phase Slider
                    _buildSliderSetting(
                      'Signals per REM phase',
                      signalsPerPhase.toString(),
                      signalsPerPhase.toDouble(),
                      1,
                      10,
                      9,
                      (value) {
                        setState(() {
                          signalsPerPhase = value.round();
                        });
                      },
                    ),

                    // Time Between Signals Slider
                    _buildSliderSetting(
                      'Time between signals',
                      '${(signalLapse / 60).toStringAsFixed(1)} min',
                      signalLapse.toDouble(),
                      10, // 30 seconds minimum
                      900, // 15 minutes maximum
                      29,
                      (value) {
                        setState(() {
                          signalLapse = value.round();
                        });
                      },
                    ),

                    // REM Phase Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REM Phases',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // REM Toggle Buttons in rows of 3
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRemToggleButton('REM 1', '1h 15m', useRem1, (value) => setState(() => useRem1 = value)),
                            _buildRemToggleButton('REM 2', '2h 45m', useRem2, (value) => setState(() => useRem2 = value)),
                            _buildRemToggleButton('REM 3', '4h 00m', useRem3, (value) => setState(() => useRem3 = value)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRemToggleButton('REM 4', '5h 15m', useRem4, (value) => setState(() => useRem4 = value)),
                            _buildRemToggleButton('REM 5', '6h 30m', useRem5, (value) => setState(() => useRem5 = value)),
                            _buildRemToggleButton('REM 6', '8h 00m', useRem6, (value) => setState(() => useRem6 = value)),
                          ],
                        ),
                        Center(
                          child: _buildRemToggleButton('REM 7', '9h 35m', useRem7, (value) => setState(() => useRem7 = value)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _resetToDefault,
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
                            // Check if user has premium before saving custom settings
                            final hasPremium = await PurchasesService.isPremiumActive();
                            
                            if (!hasPremium) {
                              // If not premium, show paywall
                              final purchased = await PurchasesService.showPaywallIfNeeded(
                                context, 
                                Provider.of<SettingsProvider>(context, listen: false).currentLanguage
                              );
                              
                              if (!purchased) {
                                // User didn't purchase premium, inform them
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppTranslations.translate(
                                      'premiumRequiredForCustomSettings', 
                                      Provider.of<SettingsProvider>(context, listen: false).currentLanguage
                                    )),
                                    backgroundColor: Colors.red.shade700,
                                    duration: const Duration(seconds: 3),
                                  )
                                );
                                return;
                              }
                            }
                            
                            // User has premium (or just purchased), save settings
                            await _saveSettings();
                            final updatedBlock = Block(
                              name: widget.block.name,
                              cycles: cycles,
                              senseDuration: Duration(seconds: signalLapse),
                              cues: true,
                              prompts: false,
                              afterBlockCue: false,
                              sleepPhase: true,
                              sleepPhaseDelay: sleepTimeMinutes,
                              useRem1: useRem1,
                              useRem2: useRem2,
                              useRem3: useRem3,
                              useRem4: useRem4,
                              useRem5: useRem5,
                              useRem6: useRem6,
                              useRem7: useRem7,
                              signalsPerPhase: signalsPerPhase,
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
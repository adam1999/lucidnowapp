// lib/screens/settings/widgets/sleep_settings.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../training/main_training_page.dart'; // Ensure this import is correct for your Block model

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

class _SleepPhaseSettingsDialogState extends State<SleepPhaseSettingsDialog> {
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
    _loadSavedSettings();
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: value ? const Color(0xFF5E5DE3) : const Color(0xFF403E49),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value ? const Color(0xFF5E5DE3) : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: value ? Colors.white : Colors.white.withOpacity(0.5),
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  color: value ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2D2D36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sleep Phase Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Sleep Duration Slider
                Text(
                  'Sleep Duration: ${_formatTimeInHoursMinutes(sleepTimeMinutes)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: sleepTimeMinutes.toDouble(),
                  min: minSleepTime.toDouble(),
                  max: maxSleepTime.toDouble(),
                  divisions: (maxSleepTime - minSleepTime) ~/ 15,
                  activeColor: const Color(0xFF5E5DE3),
                  inactiveColor: const Color(0xFF403E49),
                  onChanged: (value) {
                    setState(() {
                      sleepTimeMinutes = value.round();
                    });
                    widget.onSleepPhaseDelayChanged(value.round());
                  },
                ),
                const SizedBox(height: 24),

                // Signals Per Phase Slider
                Text(
                  'Signals per REM phase: $signalsPerPhase',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: signalsPerPhase.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: const Color(0xFF5E5DE3),
                  inactiveColor: const Color(0xFF403E49),
                  onChanged: (value) {
                    setState(() {
                      signalsPerPhase = value.round();
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Time Between Signals Slider
                Text(
                  'Time between signals: ${(signalLapse / 60).toStringAsFixed(1)} min',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: signalLapse.toDouble(),
                  min: 30, // 30 seconds minimum
                  max: 900, // 15 minutes maximum
                  divisions: 29,
                  activeColor: const Color(0xFF5E5DE3),
                  inactiveColor: const Color(0xFF403E49),
                  onChanged: (value) {
                    setState(() {
                      signalLapse = value.round();
                    });
                  },
                ),
                const SizedBox(height: 32),

                // REM Phase Selection
                const Text(
                  'REM Phases',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // REM Toggle Buttons
                _buildRemToggleButton('REM 1', '1h 15min', useRem1, (value) => setState(() => useRem1 = value)),
                _buildRemToggleButton('REM 2', '2h 45min', useRem2, (value) => setState(() => useRem2 = value)),
                _buildRemToggleButton('REM 3', '4h 00min', useRem3, (value) => setState(() => useRem3 = value)),
                _buildRemToggleButton('REM 4', '5h 15min', useRem4, (value) => setState(() => useRem4 = value)),
                _buildRemToggleButton('REM 5', '6h 30min', useRem5, (value) => setState(() => useRem5 = value)),
                _buildRemToggleButton('REM 6', '8h 00min', useRem6, (value) => setState(() => useRem6 = value)),
                _buildRemToggleButton('REM 7', '9h 35min', useRem7, (value) => setState(() => useRem7 = value)),

                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _resetToDefault,
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
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Close button
          Positioned(
            right: 16,
            top: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF403E49),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
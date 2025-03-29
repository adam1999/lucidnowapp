// In block_settings.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../training/main_training_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockSettings {
  final int minCycles;
  final int maxCycles;
  final int minSenseDuration;
  final int maxSenseDuration;
  final int defaultCycles;
  final int defaultSenseDuration;

  const BlockSettings({
    required this.minCycles,
    required this.maxCycles,
    required this.minSenseDuration,
    required this.maxSenseDuration,
    required this.defaultCycles,
    required this.defaultSenseDuration,
  });
}

class BlockSettingsDialog extends StatefulWidget {
  final Block block;
  final Function(Block) onBlockUpdated;
  final Block defaultBlock;

  const BlockSettingsDialog({
    super.key,
    required this.block,
    required this.onBlockUpdated,
    required this.defaultBlock,
  });

  @override
  State<BlockSettingsDialog> createState() => _BlockSettingsDialogState();
}

class _BlockSettingsDialogState extends State<BlockSettingsDialog> {
  late int cycles;
  late Duration senseDuration;
  late BlockSettings settings;

  // Block settings configuration
  static const Map<String, BlockSettings> blockConfigs = {
    '1 - Cues Only': BlockSettings(
      minCycles: 1,
      maxCycles: 12,
      minSenseDuration: 2,
      maxSenseDuration: 180,
      defaultCycles: 6,
      defaultSenseDuration: 60,
    ),
    '2 - Cues & Prompts': BlockSettings(
      minCycles: 1,
      maxCycles: 20,
      minSenseDuration: 2,
      maxSenseDuration: 180,
      defaultCycles: 12,
      defaultSenseDuration: 60,
    ),
    '3 - Cues Only': BlockSettings(
      minCycles: 1,
      maxCycles: 12,
      minSenseDuration: 2,
      maxSenseDuration: 180,
      defaultCycles: 6,
      defaultSenseDuration: 60,
    ),
  };

  @override
  void initState() {
    super.initState();
    String blockNumber = widget.block.name.split(' - ')[0];
    String configKey = blockConfigs.keys.firstWhere(
      (key) => key.startsWith(blockNumber),
      orElse: () => blockConfigs.keys.first // Fallback to first valid key
    );
    settings = blockConfigs[configKey]!;
    cycles = widget.block.cycles;
    senseDuration = widget.block.senseDuration;
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final blockKey = 'block_${widget.block.name}';
    setState(() {
      cycles = prefs.getInt('${blockKey}_cycles') ?? widget.block.cycles;
      senseDuration = Duration(seconds: prefs.getInt('${blockKey}_duration') ?? 
                                      widget.block.senseDuration.inSeconds);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final blockKey = 'block_${widget.block.name}';
    await prefs.setInt('${blockKey}_cycles', cycles);
    await prefs.setInt('${blockKey}_duration', senseDuration.inSeconds);
  }

  Future<void> _resetToDefault() async {
    setState(() {
      cycles = settings.defaultCycles;
      senseDuration = Duration(seconds: settings.defaultSenseDuration);
    });
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            color: const Color(0xFF252531).withOpacity(0.7),
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                // Main content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32), // Space for the close button
                    Text(
                      'Block Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Number of Cycles (${settings.minCycles}-${settings.maxCycles})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    Slider(
                      value: cycles.toDouble(),
                      min: settings.minCycles.toDouble(),
                      max: settings.maxCycles.toDouble(),
                      divisions: settings.maxCycles - settings.minCycles,
                      label: cycles.toString(),
                      activeColor: const Color(0xFF5E5DE3),
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        setState(() {
                          cycles = value.toInt();
                        });
                      },
                    ),
                    Text(
                      'Time per Sense (${settings.minSenseDuration}-${settings.maxSenseDuration} seconds)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    Slider(
                      value: senseDuration.inSeconds.toDouble(),
                      min: settings.minSenseDuration.toDouble(),
                      max: settings.maxSenseDuration.toDouble(),
                      divisions: settings.maxSenseDuration - settings.minSenseDuration,
                      label: '${senseDuration.inSeconds}s',
                      activeColor: const Color(0xFF5E5DE3),
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        setState(() {
                          senseDuration = Duration(seconds: value.toInt());
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await _resetToDefault();
                          },
                          child: const Text(
                            'Reset to Default',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF252531),
                          ),
                          onPressed: () async {
                            await _saveSettings();
                            final updatedBlock = Block(
                              name: widget.block.name,
                              cycles: cycles,
                              senseDuration: senseDuration,
                              cues: widget.block.cues,
                              prompts: widget.block.prompts,
                              afterBlockCue: widget.block.afterBlockCue,
                              sleepPhase: widget.block.sleepPhase,
                              sleepPhaseDelay: widget.block.sleepPhaseDelay,
                            );
                            widget.onBlockUpdated(updatedBlock);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
                // Close ("x") button at top right
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
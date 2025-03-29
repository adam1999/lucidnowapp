// In block_settings.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../../lib__/services/purchases_service.dart';
import '../../training/main_training_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../lib_200/translations/app_translations.dart';
import 'package:provider/provider.dart';
import '../../../../lib_200/providers/settings_provider.dart';

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

class _BlockSettingsDialogState extends State<BlockSettingsDialog> with SingleTickerProviderStateMixin {
  late int cycles;
  late Duration senseDuration;
  late BlockSettings settings;
  late AnimationController _animationController;
  late Animation<double> _animation;

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
                    // Title with gradient underline
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.block.name} Settings',
                          style: const TextStyle(
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
                    
                    // Cycles slider
                    _buildSliderSetting(
                      'Number of Cycles',
                      cycles.toString(),
                      cycles.toDouble(),
                      settings.minCycles.toDouble(),
                      settings.maxCycles.toDouble(),
                      settings.maxCycles - settings.minCycles,
                      (value) {
                        setState(() {
                          cycles = value.round();
                        });
                      },
                    ),
                    
                    // Time per sense slider
                    _buildSliderSetting(
                      'Time per Sense',
                      '${senseDuration.inSeconds}s',
                      senseDuration.inSeconds.toDouble(),
                      settings.minSenseDuration.toDouble(),
                      settings.maxSenseDuration.toDouble(),
                      settings.maxSenseDuration - settings.minSenseDuration,
                      (value) {
                        setState(() {
                          senseDuration = Duration(seconds: value.round());
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Duration summary card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
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
                          const Text(
                            'Training Summary',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Duration:',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${(cycles * senseDuration.inSeconds) ~/ 60} min ${(cycles * senseDuration.inSeconds) % 60} sec',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                                Provider.of<SettingsProvider>(context, listen: false).currentLanguage ?? 'en'
                              );
                              
                              if (!purchased) {
                                // User didn't purchase premium, inform them
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppTranslations.translate(
                                      'premiumRequiredForCustomSettings', 
                                      Provider.of<SettingsProvider>(context, listen: false).currentLanguage ?? 'en'
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
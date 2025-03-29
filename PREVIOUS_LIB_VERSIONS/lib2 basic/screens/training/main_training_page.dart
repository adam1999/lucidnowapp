import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../lib_200/models/dream.dart';
import '../../../lib_200/models/mindfulness_score.dart';
import '../../../lib_200/models/sleep_session.dart';
import '../../../lib_200/models/training_session.dart';
import '../../../lib_200/providers/settings_provider.dart';
import '../../../lib_200/screens/journal/dream_edit_screen.dart';
import '../../../lib_200/screens/settings/widgets/block_settings.dart';
import '../../../lib_200/screens/settings/widgets/mindfulness_settings.dart';
import '../../../lib_200/screens/settings/widgets/sleep_settings.dart';
import '../../../lib_200/screens/widgets/common_header.dart';
import '../../../lib_200/services/background_service.dart';
import '../../../lib_200/services/user_stats_service.dart';
import '../../../lib_200/translations/app_translations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Global timer for mindfulness cues
Timer? mindfulnessCueTimer;

class TrainingScreen extends StatefulWidget {
  final Function(bool)? onBlackOverlayChanged;

  const TrainingScreen({
    super.key,
    this.onBlackOverlayChanged,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final audioPlayer = AudioPlayer();
  final beepPlayer = AudioPlayer();
  final scrollController = ScrollController();

  // Settings
  bool backgroundAudioEnabled = true;
  bool keepScreenOn = true;
  double soundVolume = 0.5;
  int sleepPhaseDelayMinutes = 20;

  // Protocol State
  bool isProtocolRunning = false;
  bool isProtocolPaused = false;
  int totalProtocolDuration = 0;
  double elapsedProtocolTime = 0.0;
  Timer? protocolTimer;

  // Mindfulness Training State (separate from sleep protocol)
  bool isMindfulnessRunning = false;
  bool isMindfulnessPaused = false;
  int mindfulnessBlockIndex = -1;
  Timer? mindfulnessTimer;

  // Progress Tracking
  int currentBlockIndex = 0;
  int currentCycleIndex = 0;
  List<Block> blocks = [];

  String currentPhase = '';
  List<Block> defaultBlocks = [];
  bool isBlackOverlay = false;

  late SettingsProvider _settings;
  late BackgroundService _backgroundService;

  bool _sleepSessionSaved = false;

  int mindfulnessCueCount = 0;
  int maxMindfulnessCues = 10;

  // Add new variables for sleep and wake times
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 0); // Default 11 PM
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);   // Default 7 AM

  @override
  void initState() {
    super.initState();
    _backgroundService = BackgroundService();
    _initializeBackgroundService();
    _settings = Provider.of<SettingsProvider>(context, listen: false);
    
    backgroundAudioEnabled = _settings.backgroundAudioEnabled;
    keepScreenOn = _settings.keepScreenOn;
    sleepPhaseDelayMinutes = _settings.sleepPhaseDelayMinutes;
    soundVolume = _settings.soundVolume; // Get sound volume from settings

    _initializeAudio();
    _keepScreenOn(keepScreenOn);
    WidgetsBinding.instance.addObserver(this);

    // Load saved block settings from SharedPreferences.
    _loadSavedBlockSettings().then((_) {
      // Replace the first block with MindfulnessBlock that has access to this state
      if (blocks.isNotEmpty && blocks[0] is MindfulnessBlock) {
        blocks[0] = MindfulnessBlock(parentState: this);
      }
    });
  }

  Future<void> _initializeBackgroundService() async {
    await _backgroundService.initializeService();
  }

  Future<void> _loadSavedBlockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    // Define sleep phase name consistently
    final sleepPhaseName = AppTranslations.translate('cuesPlayedInDreams', _settings.currentLanguage);
    final sleepPhaseKey = 'block_$sleepPhaseName';

    setState(() {
      blocks = [
        // Pre-training block 1 (Cues and Prompts)
        Block(
          name: '${AppTranslations.translate('cuesAndPrompts', settings.currentLanguage)}',
          cycles: prefs.getInt('block_${AppTranslations.translate('cuesAndPrompts', settings.currentLanguage)}_cycles') ?? 12,
          senseDuration: Duration(
            seconds: prefs.getInt('block_${AppTranslations.translate('cuesAndPrompts', settings.currentLanguage)}_duration') ?? 60,
          ),
          cues: true,
          prompts: true,
          afterBlockCue: true,
        ),
        // Pre-training block 2 (Cues Only)
        Block(
          name: '${AppTranslations.translate('cuesOnly', settings.currentLanguage)}',
          cycles: prefs.getInt('block_${AppTranslations.translate('cuesOnly', settings.currentLanguage)}_cycles') ?? 6,  // Removed _2
          senseDuration: Duration(
            seconds: prefs.getInt('block_${AppTranslations.translate('cuesOnly', settings.currentLanguage)}_duration') ?? 60,  // Removed _2
          ),
          cues: true,
          prompts: false,
          afterBlockCue: true,
        ),
        // Sleep phase block - Use consistent sleepPhaseKey for loading
        Block(
          name: sleepPhaseName,
          cycles: prefs.getInt('${sleepPhaseKey}_cycles') ?? 4,
          senseDuration: Duration(
            seconds: prefs.getInt('${sleepPhaseKey}_signal_lapse') ?? 20,
          ),
          cues: true,
          prompts: false,
          afterBlockCue: false,
          sleepPhase: true,
          sleepPhaseDelay: prefs.getInt('${sleepPhaseKey}_delay') ?? sleepPhaseDelayMinutes,
          useRem1: prefs.getBool('${sleepPhaseKey}_useRem1') ?? true,
          useRem2: prefs.getBool('${sleepPhaseKey}_useRem2') ?? true,
          useRem3: prefs.getBool('${sleepPhaseKey}_useRem3') ?? true,
          useRem4: prefs.getBool('${sleepPhaseKey}_useRem4') ?? true,
          useRem5: prefs.getBool('${sleepPhaseKey}_useRem5') ?? true,
          useRem6: prefs.getBool('${sleepPhaseKey}_useRem6') ?? true,
          useRem7: prefs.getBool('${sleepPhaseKey}_useRem7') ?? true,
          signalsPerPhase: prefs.getInt('${sleepPhaseKey}_signals_per_phase') ?? 3,
        ),
      ];

      _computeBlockDurations();
      _initializeDefaultBlocks();
    });
  }

  Widget _buildMindfulnessOverlay() {
    if (!isProtocolRunning ||
        currentBlockIndex != 0 ||
        blocks.isEmpty ||
        !(blocks[0] is MindfulnessBlock)) {
      return const SizedBox.shrink();
    }
    final mindfulnessBlock = blocks[0] as MindfulnessBlock;
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF1A1A1A),
        child: SafeArea(
          child: Column(
            children: [
              // Progress bar and stats at top.
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      height: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          // Use custom duration.
                          value: mindfulnessBlock.elapsedTime /
                              mindfulnessBlock.senseDuration.inSeconds,
                          backgroundColor: const Color(0xFF403E49),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5E5DE3)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppTranslations.translate('breathCount', _settings.currentLanguage)}: ${mindfulnessBlock.currentBreath}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '${AppTranslations.translate('successRate', _settings.currentLanguage)}: ${mindfulnessBlock.successRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Lost count button.
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.15,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      mindfulnessBlock.currentBreath = 1;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.refresh,
                            color: Colors.white70,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppTranslations.translate('lostCount', _settings.currentLanguage),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Breath counting buttons.
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (mindfulnessBlock.currentBreath < 10) {
                            setState(() {
                              mindfulnessBlock.currentBreath++;
                            });
                          } else {
                            setState(() {
                              mindfulnessBlock.recordCycleResult(false);
                              mindfulnessBlock.currentBreath = 1;
                            });
                          }
                        },
                        child: Container(
                          color: Colors.black26,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.touch_app,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppTranslations.translate('tapForBreaths', _settings.currentLanguage),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (mindfulnessBlock.currentBreath == 10) {
                            setState(() {
                              mindfulnessBlock.recordCycleResult(true);
                              mindfulnessBlock.currentBreath = 1;
                            });
                          } else {
                            setState(() {
                              mindfulnessBlock.recordCycleResult(false);
                              mindfulnessBlock.currentBreath = 1;
                            });
                          }
                        },
                        child: Container(
                          color: Colors.black38,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.touch_app,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppTranslations.translate('tapForBreathTen', _settings.currentLanguage),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initializeDefaultBlocks() {
    defaultBlocks = blocks
        .map((block) => Block(
              name: block.name,
              cycles: block.cycles,
              senseDuration: block.senseDuration,
              cues: block.cues,
              prompts: block.prompts,
              afterBlockCue: block.afterBlockCue,
              sleepPhase: block.sleepPhase,
              sleepPhaseDelay: block.sleepPhaseDelay,
            ))
        .toList();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    beepPlayer.dispose();
    scrollController.dispose();
    _keepScreenOn(false);
    protocolTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toggleControls() {
    // This method is no longer needed but kept as a no-op for compatibility
  }

  Future<void> skipToNextCycle() async {
    if (!isProtocolRunning || isProtocolPaused) return;
    if (currentBlockIndex >= blocks.length) return;

    final currentBlock = blocks[currentBlockIndex];

    if (!currentBlock.sleepPhase) {
      setState(() {
        // For Mindfulness block, complete the entire block
        if (currentBlock is MindfulnessBlock) {
          currentBlock.elapsedTime = currentBlock.senseDuration.inSeconds.toDouble();
          currentBlock.completedSteps = currentBlock.cycles;
          _saveMindfulnessScore(currentBlock);
          mindfulnessCueTimer?.cancel();
          
          // Find next enabled block
          int nextIndex = currentBlockIndex + 1;
          while (nextIndex < blocks.length) {
            bool isEnabled = blocks[nextIndex] is MindfulnessBlock ? true :
                            blocks[nextIndex].sleepPhase;
            if (isEnabled) break;
            nextIndex++;
          }
          currentBlockIndex = nextIndex;
          currentCycleIndex = 0;
          return;
        }

        // For other non-sleep blocks, skip to next cycle
        double timeToComplete = currentBlock.senseDuration.inSeconds - 
          (currentBlock.elapsedTime % currentBlock.senseDuration.inSeconds);
        
        currentBlock.elapsedTime += timeToComplete;
        currentBlock.completedSteps = (currentBlock.elapsedTime / currentBlock.senseDuration.inSeconds).floor();
        
        if (currentBlock.elapsedTime >= currentBlock.totalDuration.toDouble()) {
          currentBlock.elapsedTime = currentBlock.totalDuration.toDouble();
          currentBlock.completedSteps = currentBlock.cycles;
          
          // Find next enabled block
          int nextIndex = currentBlockIndex + 1;
          while (nextIndex < blocks.length) {
            bool isEnabled = blocks[nextIndex] is MindfulnessBlock ? true :
                            blocks[nextIndex].sleepPhase;
            if (isEnabled) break;
            nextIndex++;
          }
          currentBlockIndex = nextIndex;
          currentCycleIndex = 0;
        }
      });

      // Trigger sounds if needed
      if (currentBlock.cues) {
        await _handleCycleCompletion(currentBlock);
      }
    } else {
      // Sleep phase code remains the same
      double newElapsed = currentBlock.elapsedTime + 300;
      if (newElapsed >= currentBlock.totalDuration.toDouble()) {
        newElapsed = currentBlock.totalDuration.toDouble();
        setState(() {
          currentBlock.elapsedTime = newElapsed;
        });
        if (!_sleepSessionSaved) {
          _sleepSessionSaved = true;
          setState(() {
            isProtocolRunning = false;
          });
          protocolTimer?.cancel();
          await _checkForTriggers(currentBlock);
          final sleepSession = SleepSession(
            id: const Uuid().v4(),
            date: DateTime.now(),
            duration: currentBlock.totalDuration,
          );
          await UserStatsService().saveSleepSession(sleepSession);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Congrat!'),
              content: const Text('Your sleep session has been recorded.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() {
          currentBlock.elapsedTime = newElapsed;
        });
        await _checkForTriggers(currentBlock);
      }
    }
  }

  Widget _buildFloatingControls() {
    // This method will be empty as we've relocated the controls
    return const SizedBox.shrink();
  }

  void _computeBlockDurations() {
    for (var block in blocks) {
      block.elapsedTime = 0;
      if (block.sleepPhase) {
        // Use the calculated sleep duration instead of sleepPhaseDelay
        block.totalDuration = calculateSleepDuration() * 60;
      } else {
        block.totalDuration = block.cycles * block.senseDuration.inSeconds;
      }
    }
    totalProtocolDuration = computeTotalProtocolDuration();
  }


  Future<void> _initializeAudio() async {
    await audioPlayer.setVolume(soundVolume);
    await beepPlayer.setVolume(soundVolume);
  }

  void _keepScreenOn(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('Error toggling wakelock: $e');
    }
  }

  Future<void> playPrompt() async {
    if (backgroundAudioEnabled) {
      // Check if either protocol or mindfulness training is running and not paused
      bool shouldPlay = (isProtocolRunning && !isProtocolPaused) || 
                        (isMindfulnessRunning && !isMindfulnessPaused);
      
      if (!shouldPlay) return;
      
      // Update volume from settings before playing
      await audioPlayer.setVolume(_settings.voiceVolume);
      
      // Construct the voice prompt file path based on language and voice type
      final String language = _settings.currentLanguage; // 'en', 'fr', or 'es'
      final String voiceType = _settings.voiceType; // 'men' or 'women'
      final String promptFile = 'voiceprompts/${language}_${voiceType}.mp3';
      
      // Play the language-specific voice prompt or fallback to default
      try {
        await audioPlayer.play(AssetSource(promptFile));
      } catch (e) {
        // Fallback to default prompt if the specific file is not found
        debugPrint('Error playing voice prompt: $e, falling back to default');
        await audioPlayer.play(AssetSource('prompt.mp3'));
      }
      
      // Add completion listener to handle protocol state changes
      audioPlayer.onPlayerComplete.listen((event) {
        bool shouldContinue = (isProtocolRunning && !isProtocolPaused) || 
                             (isMindfulnessRunning && !isMindfulnessPaused);
        
        if (!shouldContinue) {
          audioPlayer.stop();
        }
      });
    }
  }

  Future<void> playBeep() async {
    if (!backgroundAudioEnabled) return;
    // Construct the asset path using the sound trigger selected in settings.
    final soundFile = 'soundtriggers/${_settings.soundTrigger}';
    
    // Update volume from settings before playing
    await beepPlayer.setVolume(_settings.soundVolume);
    
    for (int i = 0; i < 2; i++) {
      await beepPlayer.play(AssetSource(soundFile));
      if (i == 0) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }


  int computeTotalProtocolDuration() {
    int totalDuration = 0;
    for (var block in blocks) {
      totalDuration += block.totalDuration;
    }
    return totalDuration;
  }

  void _scheduleNextMindfulnessCue() {
    if (!isProtocolRunning || blocks.isEmpty || !(blocks[0] is MindfulnessBlock)) return;
    final mindfulnessBlock = blocks[0] as MindfulnessBlock;
    final totalDurationSeconds = mindfulnessBlock.senseDuration.inSeconds;
    if (mindfulnessBlock.elapsedTime >= totalDurationSeconds) return;

    // Calculate remaining cues and remaining time
    int remainingCues = maxMindfulnessCues - mindfulnessCueCount;
    int remainingTime = totalDurationSeconds - mindfulnessBlock.elapsedTime.toInt();
    if (remainingCues <= 0 || remainingTime <= 0) return;

    // Compute delay with random variation
    double baseDelay = remainingTime / remainingCues;
    double randomFactor = 0.5 + Random().nextDouble(); // random value in [0.5, 1.5)
    int delaySeconds = (baseDelay * randomFactor).round().clamp(1, remainingTime);

    mindfulnessCueTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (isProtocolRunning && mindfulnessBlock.elapsedTime < totalDurationSeconds) {
        await triggerCue();
        mindfulnessCueCount++;
        _scheduleNextMindfulnessCue();
      }
    });
  }

  Future<void> _saveMindfulnessScore(MindfulnessBlock block) async {
    final int score = block.successRate.round();
    final mindfulnessScore = MindfulnessScore(date: DateTime.now(), score: score);
    await UserStatsService().saveMindfulnessScore(mindfulnessScore);
  }


  Future<void> startProtocol() async {
    // Initialize background service if not running
    if (!isProtocolRunning) {
    await _backgroundService.startBackgroundService();
    await _backgroundService.startSilentAudio();
    }

    // Reset mindfulness cue counters if needed
    if (blocks.isNotEmpty && blocks[0] is MindfulnessBlock) {
      mindfulnessCueCount = 0;
      if (blocks[0] is MindfulnessBlockCustom) {
        maxMindfulnessCues = (blocks[0] as MindfulnessBlockCustom).customCues;
      } else {
        maxMindfulnessCues = 10;
      }
    }

    setState(() {
      _sleepSessionSaved = false;
      isProtocolRunning = true;
      isProtocolPaused = false;
      
      // Reset the current block
      if (currentBlockIndex < blocks.length) {
        blocks[currentBlockIndex].elapsedTime = 0;
        blocks[currentBlockIndex].completedSteps = 0;
        
        // Reset trigger flags for sleep phase
        if (blocks[currentBlockIndex].sleepPhase) {
          blocks[currentBlockIndex].triggersFired = List.filled(blocks[currentBlockIndex].triggerTimes.length, false);
        }
      }
    });

    await _backgroundService.updateServiceData({
      'currentPhase': currentPhase,
      'isRunning': true,
      'elapsedTime': elapsedProtocolTime,
    });

    // Start or continue the timer
    if (protocolTimer == null || !protocolTimer!.isActive) {
    protocolTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!isProtocolPaused) {
        setState(() {
          elapsedProtocolTime += 0.1;
          if (elapsedProtocolTime >= totalProtocolDuration) {
            protocolTimer?.cancel();
          }
        });
      }
    });
    }

    // Main protocol execution loop
    while (isProtocolRunning && currentBlockIndex < blocks.length) {
      await _waitWhilePaused();
      if (!isProtocolRunning) break;
      
      var currentBlock = blocks[currentBlockIndex];
      
      // Execute the current block
        if (currentBlock is MindfulnessBlock) {
        _scheduleNextMindfulnessCue();
      }
      
      // Wait for block completion or interruption
      while (currentBlock.elapsedTime < currentBlock.totalDuration && isProtocolRunning) {
        await _waitWhilePaused();
        if (!isProtocolRunning) break;
            
            setState(() {
          if (!isProtocolPaused) {
            currentBlock.elapsedTime += 0.1;
          }
        });
        
        // Check for triggers after updating time
        if (!isProtocolPaused && currentBlock.sleepPhase) {
          await _checkForTriggers(currentBlock);
        }
        
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Move to next block
      if (isProtocolRunning) {
        currentBlockIndex++;
      }
    }
  }

  Future<void> _runSleepPhaseDelay(Block block) async {
    int delaySeconds = sleepPhaseDelayMinutes * 60;
    for (int i = 0; i < delaySeconds; i++) {
      await _waitWhilePaused();
      if (!isProtocolRunning) return;
      await Future.delayed(const Duration(seconds: 1));
      await _incrementBlockElapsedTime(1);
    }
  }

  Future<void> pauseProtocol() async {
    setState(() {
      isProtocolPaused = true;
      currentPhase = AppTranslations.translate('protocolPaused', _settings.currentLanguage);
    });
    // Stop audio playback when paused
    await audioPlayer.stop();
    await beepPlayer.stop();
  }

  void resumeProtocol() {
    setState(() {
      isProtocolPaused = false;
    });
  }

  Future<void> stopProtocol() async {
    setState(() {
      isProtocolRunning = false;
      isProtocolPaused = false;
      currentPhase = AppTranslations.translate('protocolStopped', _settings.currentLanguage);
    });
    // Stop all audio playback when stopping
    await audioPlayer.stop();
    await beepPlayer.stop();
    await _backgroundService.stopBackgroundService();
    protocolTimer?.cancel();
    mindfulnessCueTimer?.cancel();
  }

  void _updatePhase(String phase) {
    setState(() {
      currentPhase = phase;
    });
    _backgroundService.updateServiceData({
      'currentPhase': phase,
      'isRunning': isProtocolRunning,
      'elapsedTime': elapsedProtocolTime,
    });
  }

  Future<void> startBlock(Block block) async {
    setState(() {
      currentPhase = 'Starting ${block.name}';
      block.completedSteps = 0;
    });

    // For Mindfulness Training blocks (non-MindfulnessBlock type)
    if (!block.sleepPhase && !(block is MindfulnessBlock)) {
    for (int cycle = currentCycleIndex; cycle < block.cycles; cycle++) {
      currentCycleIndex = cycle;
      await _waitWhilePaused();
      if (!isProtocolRunning) return;
        
        // Wait for the duration of one cycle
      await _waitWithPauseCheck(block.senseDuration);
      if (!isProtocolRunning) return;
        
      setState(() {
        block.completedSteps = cycle + 1;
      });
        
        // Play cues and prompts after each cycle
      if (block.cues) {
        await triggerCue();
        if (block.prompts) {
          await playPrompt();
        }
      }
    }
    currentCycleIndex = 0;
      
      // After completing this block, move to the next non-sleep block if available
      if (isProtocolRunning) {
        int nextIndex = currentBlockIndex + 1;
        while (nextIndex < blocks.length) {
          if (!blocks[nextIndex].sleepPhase) {
            setState(() {
              currentBlockIndex = nextIndex;
            });
            await startBlock(blocks[nextIndex]);
            break;
          }
          nextIndex++;
        }
      }
    }
  }

  Future<void> startSleepPhase(Block block) async {
    final remTimes = [
      if (block.useRem3) {'startMin': 240, 'durationMin': 30},
      if (block.useRem4) {'startMin': 315, 'durationMin': 45},
      if (block.useRem5) {'startMin': 390, 'durationMin': 60},
    ];

    for (var rem in remTimes) {
      final startSeconds = rem['startMin']! * 60;
      final durationSeconds = rem['durationMin']! * 60;
      while (block.elapsedTime < startSeconds) {
        await _waitWhilePaused();
        if (!isProtocolRunning) return;
        await Future.delayed(const Duration(seconds: 1));
        await _incrementBlockElapsedTime(1);
      }
      for (int signal = 0; signal < block.signalsPerPhase; signal++) {
        await _waitWhilePaused();
        if (!isProtocolRunning) return;
        await triggerCue();
        final lapseSeconds = block.senseDuration.inSeconds;
        for (int i = 0; i < lapseSeconds; i++) {
          await _waitWhilePaused();
          if (!isProtocolRunning) return;
          await Future.delayed(const Duration(seconds: 1));
          await _incrementBlockElapsedTime(1);
        }
      }
    }
  }

  Future<void> _waitWithPauseCheck(Duration duration) async {
    final totalMilliseconds = duration.inMilliseconds;
    const updateInterval = 100;
    final steps = totalMilliseconds ~/ updateInterval;
    for (int i = 0; i < steps; i++) {
      await _waitWhilePaused();
      if (!isProtocolRunning) return;
      await Future.delayed(const Duration(milliseconds: updateInterval));
      await _incrementBlockElapsedTime(updateInterval / 1000);
    }
  }

  Future<void> _waitWhilePaused() async {
    while (isProtocolPaused) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _checkForTriggers(Block block) async {
    if (!block.sleepPhase) return;
    double elapsedMinutes = block.elapsedTime / 60.0;
    for (int i = 0; i < block.triggerTimes.length; i++) {
      if (!block.triggersFired[i] && elapsedMinutes >= block.triggerTimes[i]) {
        // Play the cue sound.
        await triggerCue();
        block.triggersFired[i] = true;
      }
    }
  }

  Future<void> _incrementBlockElapsedTime(double seconds) async {
    if (!isProtocolRunning || currentBlockIndex >= blocks.length) return;
    setState(() {
      blocks[currentBlockIndex].elapsedTime = (blocks[currentBlockIndex].elapsedTime + seconds)
          .clamp(0.0, blocks[currentBlockIndex].totalDuration.toDouble());
    });
    
    await _checkForTriggers(blocks[currentBlockIndex]);
    
    final currentBlock = blocks[currentBlockIndex];
    if (currentBlock.sleepPhase &&
        currentBlock.elapsedTime >= currentBlock.totalDuration.toDouble() &&
        !_sleepSessionSaved) {
      _sleepSessionSaved = true;
      setState(() {
        isProtocolRunning = false;
      });
      protocolTimer?.cancel();
      final sleepSession = SleepSession(
        id: const Uuid().v4(),
        date: DateTime.now(),
        duration: currentBlock.totalDuration,
      );
      await UserStatsService().saveSleepSession(sleepSession);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Congrat!'),
          content: const Text('Your sleep session has been recorded.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> triggerCue() async {
    if (backgroundAudioEnabled) {
      await playBeep();
    }
  }

  String formatCountdown(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$secs";
  }

  void restartProtocol() {
    stopProtocol();
    startFromBlock(0);
  }

  void _updateBlock(int index, Block updatedBlock) {
    setState(() {
      final currentElapsedTime = blocks[index].elapsedTime;
      final currentCompletedSteps = blocks[index].completedSteps;
      blocks[index] = updatedBlock;
      if (updatedBlock.sleepPhase && updatedBlock.sleepPhaseDelay != null) {
        sleepPhaseDelayMinutes = updatedBlock.sleepPhaseDelay!;
      }
      if (isProtocolRunning && index == currentBlockIndex) {
        blocks[index].elapsedTime = currentElapsedTime;
        blocks[index].completedSteps = currentCompletedSteps;
      }
      _computeBlockDurations();
      if (isProtocolRunning) {
        totalProtocolDuration = computeTotalProtocolDuration();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context);
    if (settings.backgroundAudioEnabled != backgroundAudioEnabled) {
      backgroundAudioEnabled = settings.backgroundAudioEnabled;
    }
    if (settings.keepScreenOn != keepScreenOn) {
      keepScreenOn = settings.keepScreenOn;
      _keepScreenOn(keepScreenOn);
    }
    if (settings.sleepPhaseDelayMinutes != sleepPhaseDelayMinutes) {
      sleepPhaseDelayMinutes = settings.sleepPhaseDelayMinutes;
      _computeBlockDurations();
    }
  }

  Widget _buildCycleStepsProgress(Block block, bool isCompleted) {
    return SizedBox(
      height: 8,
      child: Row(
        children: List.generate(block.cycles, (cycleIndex) {
          final startTime = cycleIndex * block.senseDuration.inSeconds;
          final endTime = startTime + block.senseDuration.inSeconds;
          double progressFill = 0.0;
          
          // If block is completed, show empty progress
          if (isCompleted) {
            progressFill = 0.0;
          } else if (block.elapsedTime >= endTime) {
            progressFill = 1.0;
          } else if (block.elapsedTime > startTime) {
            progressFill = (block.elapsedTime - startTime) / block.senseDuration.inSeconds;
          }
          
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: cycleIndex < block.cycles - 1 ? 4.0 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progressFill,
                  backgroundColor: const Color(0xFF403E49),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5E5DE3)),
                  minHeight: 20,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSleepPhaseProgress(Block block) {
      // Use calculated sleep duration instead of sleep phase delay
      final double totalSleepTime = calculateSleepDuration().toDouble();
    final List<Map<String, dynamic>> remCyclesBaseline = [
      {'remNumber': 1, 'start': 75.0, 'duration': 15.0, 'active': block.useRem1},
      {'remNumber': 2, 'start': 165.0, 'duration': 15.0, 'active': block.useRem2},
      {'remNumber': 3, 'start': 240.0, 'duration': 30.0, 'active': block.useRem3},
      {'remNumber': 4, 'start': 315.0, 'duration': 45.0, 'active': block.useRem4},
      {'remNumber': 5, 'start': 390.0, 'duration': 60.0, 'active': block.useRem5},
      {'remNumber': 6, 'start': 480.0, 'duration': 75.0, 'active': block.useRem6},
      {'remNumber': 7, 'start': 575.0, 'duration': 25.0, 'active': block.useRem7},
    ];  
      // Calculate progress based on elapsed time and total sleep duration in minutes
    final progress = (block.elapsedTime / (totalSleepTime * 60)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Legend for the progress bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(0.3),
                            Colors.red.withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppTranslations.translate('probableDreamPhases', _settings.currentLanguage),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppTranslations.translate('cues', _settings.currentLanguage),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        SizedBox(
          height: 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              double getPosition(double minutes) =>
                  (minutes / totalSleepTime) * constraints.maxWidth;

              return Stack(
                children: [
                  // Base progress bar background
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      color: const Color(0xFF403E49),
                    ),
                  ),
                  // Progress indicator
                  Container(
                    height: 8,
                    width: progress * constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E5DE3).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // REM phases with blur effects
                  for (var rem in remCyclesBaseline)
                    if ((rem['start'] as double) < totalSleepTime)
                      Positioned(
                        left: getPosition(rem['start'] as double) - 15,
                        width: getPosition((rem['duration'] as double)) + 30,
                        child: Stack(
                          children: [
                            // Outer blur (widest, lowest opacity)
                            ClipRect(
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.withOpacity(0),
                                        Colors.red.withOpacity(0.1),
                                        Colors.red.withOpacity(0.1),
                                        Colors.red.withOpacity(0),
                                      ],
                                      stops: const [0.0, 0.2, 0.8, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            // Middle blur
                            ClipRect(
                                child: Container(
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.withOpacity(0),
                                        Colors.red.withOpacity(0.2),
                                        Colors.red.withOpacity(0.2),
                                        Colors.red.withOpacity(0),
                                      ],
                                      stops: const [0.0, 0.2, 0.8, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            // Core REM indicator
                            Container(
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.withOpacity(0.2),
                                    Colors.red.withOpacity(0.4),
                                    Colors.red.withOpacity(0.4),
                                    Colors.red.withOpacity(0.2),
                                  ],
                                  stops: const [0.0, 0.3, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  // Signal markers
                  for (var rem in remCyclesBaseline)
                    if (rem['active'] == true)
                      ...List.generate(block.signalsPerPhase, (i) {
                        final double timeBetween = block.senseDuration.inSeconds / 60.0;
                        double triggerTime = (rem['start'] as double) + (timeBetween * i);
                        if (triggerTime > totalSleepTime) return Container();
                        return Positioned(
                          left: getPosition(triggerTime),
                          child: Container(
                            width: 2,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                ],
              );
            },
          ),
        ),
          const SizedBox(height: 4),
            SizedBox(
            height: 30,
              child: LayoutBuilder(
                builder: (context, constraints) {
                // Calculate number of hour markers based on total sleep time
                  int tickCount = (totalSleepTime / 60).ceil() + 1;
                
                // Calculate time markers
                List<TimeOfDay> timeMarkers = [];
                for (int i = 0; i < tickCount; i++) {
                  int sleepMinutes = _sleepTime.hour * 60 + _sleepTime.minute + (i * 60);
                  int hours = (sleepMinutes ~/ 60) % 24;
                  int minutes = sleepMinutes % 60;
                  timeMarkers.add(TimeOfDay(hour: hours, minute: minutes));
                }
                
                  return Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    for (int i = 0; i < timeMarkers.length; i++)
                        Positioned(
                          left: (i * 60 / totalSleepTime) * constraints.maxWidth,
                          top: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 2,
                                height: 8,
                                color: Colors.white,
                              ),
                            const SizedBox(height: 2),
                              Text(
                              '${i}h',
                              style: const TextStyle(color: Colors.white70, fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeMarkers[i].format(context),
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ],
                              ),
                            ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSleepRecapBlock(BuildContext context, Block block) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF252531).withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(20.0),
            child: _buildSleepRecapContent(context, block),
          ),
        ),
    );
  }

  Widget _buildSleepRecapContent(BuildContext context, Block block) {
    final sleepDuration = calculateSleepDuration();
    final double timeBetween = block.senseDuration.inSeconds / 60.0;
    final List<Map<String, dynamic>> remCycles = [
      {'remNumber': 1, 'start': 75.0,  'duration': 15.0, 'active': block.useRem1},
      {'remNumber': 2, 'start': 165.0, 'duration': 15.0, 'active': block.useRem2},
      {'remNumber': 3, 'start': 240.0, 'duration': 30.0, 'active': block.useRem3},
      {'remNumber': 4, 'start': 315.0, 'duration': 45.0, 'active': block.useRem4},
      {'remNumber': 5, 'start': 390.0, 'duration': 60.0, 'active': block.useRem5},
      {'remNumber': 6, 'start': 480.0, 'duration': 75.0, 'active': block.useRem6},
      {'remNumber': 7, 'start': 575.0, 'duration': 25.0, 'active': block.useRem7},
    ];

    double targetLucidLength = 0.0;
    int totalTriggers = 0;

    int computeTriggers(double remStart, double timeBetween, int signalsPerPhase, double limit) {
      int count = 0;
      for (int i = 0; i < signalsPerPhase; i++) {
        double t = remStart + (timeBetween * i);
        if (t <= limit) count++;
      }
      return count;
    }

    for (var rem in remCycles) {
      final double start = rem['start'] as double;
      final double duration = rem['duration'] as double;
      if (start < sleepDuration) {
        if (rem['active'] == true) {
          targetLucidLength += duration;
          totalTriggers += computeTriggers(start, timeBetween, block.signalsPerPhase, sleepDuration.toDouble());
        }
      }
    }

    String fmt(double minutes) {
      if (minutes < 60) {
        return '${minutes.round()} min';
      } else {
        int hrs = (minutes / 60).floor();
        int mins = (minutes % 60).round();
        return '${hrs}h ${mins}min';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First row: Time selection and New Dream button
        Row(
          children: [
            // Time selection buttons (left side)
            Expanded(
              flex: 3,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2D2D36), Color(0xFF403E49)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Sleep Time
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(context, true),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _sleepTime.format(context),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppTranslations.translate('sleep', _settings.currentLanguage),
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
        Container(
                      width: 1,
                      height: 40,
                      color: Colors.white24,
                    ),
                    // Wake Time
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(context, false),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _wakeTime.format(context),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppTranslations.translate('wake', _settings.currentLanguage),
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // New Dream button (right side)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _handleAddDream(context),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.book_outlined,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTranslations.translate('newDream', _settings.currentLanguage),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Night Recap Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF252531).withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
          color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.translate('recap', _settings.currentLanguage),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.translate('sleepDuration', _settings.currentLanguage),
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
        Text(
                          fmt(sleepDuration.toDouble()),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.translate('targetLucidDream', _settings.currentLanguage),
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fmt(targetLucidLength),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.notifications,
                color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalTriggers ${AppTranslations.translate('cuesScheduled', _settings.currentLanguage)}',
                    style: const TextStyle(
                fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
              ),
        ),
      ],
    );
  }

  Widget _buildRecapBox(String title, String value, {Color? background, Gradient? gradient}) {
    final decoration = gradient != null
        ? BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : BoxDecoration(
            color: background ?? const Color(0xFF403E49).withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: decoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelectionBox(String title, TimeOfDay time, VoidCallback onTap, {Gradient? gradient}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Split blocks into sections
    final mindfulnessBlocks = blocks.whereType<MindfulnessBlock>().toList();
    final preSleepPhaseBlocks = blocks.where((b) => 
      !(b is MindfulnessBlock) && 
      !b.sleepPhase
    ).toList();
    final sleepPhaseBlocks = blocks.where((b) => b.sleepPhase).toList();

    // Calculate total training duration in minutes
    int totalTrainingSeconds = 0;
    for (var block in preSleepPhaseBlocks) {
      totalTrainingSeconds += block.totalDuration;
    }
    String trainingDurationText = '';
    if (totalTrainingSeconds >= 60) {
      int minutes = totalTrainingSeconds ~/ 60;
      trainingDurationText = '$minutes min';
    } else {
      trainingDurationText = '$totalTrainingSeconds sec';
    }

    return Stack(
      children: [
        // Add a background container that matches your app's gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF06070F),
                Color(0xFF100B1A),
                Color(0xFF1C1326),
                Color(0xFF2F1D34),
              ],
              stops: [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: 120.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intensive Mindfulness Section
                    if (mindfulnessBlocks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                              AppTranslations.translate('intensiveMindfulness', _settings.currentLanguage),
                            textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ),
                      ),
                      _buildBlockCard(
                            mindfulnessBlocks.first,
                            currentBlockIndex == blocks.indexOf(mindfulnessBlocks.first),
                            blocks.indexOf(mindfulnessBlocks.first),
                          ),
                      const SizedBox(height: 24),
                    ],

                    // Buttons row (Start Sleeping and Training placed side by side)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Start Sleeping Button
                                Container(
                                  width: 160,
                                  height: 160,
                                  child: ElevatedButton(
                                    onPressed: _handleStartSleeping,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.withOpacity(0.1),
                                      foregroundColor: Colors.teal,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(16),
                                      elevation: 0,
                                      side: BorderSide(
                                        color: Colors.teal.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          !isProtocolRunning && !isProtocolPaused ? Icons.bedtime :
                                          !isProtocolPaused ? Icons.pause : Icons.play_arrow,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          !isProtocolRunning && !isProtocolPaused ? AppTranslations.translate('startSleeping', _settings.currentLanguage) :
                                          !isProtocolPaused ? AppTranslations.translate('pause', _settings.currentLanguage) : AppTranslations.translate('resume', _settings.currentLanguage),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 24), // Space between buttons
                                
                                // Training Button (smaller, circular with icon above text)
                                Container(
                                  width: 110, // Smaller than Start Sleeping button
                                  height: 110, // Smaller than Start Sleeping button
                                  child: ElevatedButton(
                                    onPressed: _handleMindfulnessTraining,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.withOpacity(0.1),
                                      foregroundColor: Colors.blue,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                      elevation: 0,
                                      side: BorderSide(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          !isMindfulnessRunning && !isMindfulnessPaused ? Icons.self_improvement :
                                          !isMindfulnessPaused ? Icons.pause : Icons.play_arrow,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          !isMindfulnessRunning && !isMindfulnessPaused ? AppTranslations.translate('training', _settings.currentLanguage) :
                                          !isMindfulnessPaused ? AppTranslations.translate('pause', _settings.currentLanguage) : AppTranslations.translate('resume', _settings.currentLanguage),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Control buttons row
                      Padding(
                              padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0, bottom: 6.0),
                        child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                                  // Column for Sleep controls
                                  SizedBox(
                                    width: 160,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Sleep protocol controls
                                        if (isProtocolRunning && !isProtocolPaused) ...[
                                          IconButton(
                                            icon: const Icon(Icons.stop, color: Colors.white),
                                            iconSize: 32,
                                            onPressed: _handleStop,
                                          ),
                                          const SizedBox(width: 16),
                                          IconButton(
                                            icon: const Icon(Icons.fast_forward, color: Colors.white),
                                            iconSize: 32,
                                            onPressed: skipToNextCycle,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  // Spacer equal to gap between main buttons
                                  const SizedBox(width: 24),
                                  
                                  // Column for Mindfulness controls
                                  SizedBox(
                                    width: 110,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Mindfulness training controls
                                        if (isMindfulnessRunning && !isMindfulnessPaused) ...[
                                          IconButton(
                                            icon: const Icon(Icons.stop, color: Colors.white),
                                            iconSize: 32,
                                            onPressed: _handleStopMindfulness,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Sleep Phase Section (Now Night Preview)
                    if (sleepPhaseBlocks.isNotEmpty) ...[
                      Column(
                        children: [
                          for (var block in sleepPhaseBlocks)
                            _buildBlockCard(
                              block,
                              currentBlockIndex == blocks.indexOf(block),
                              blocks.indexOf(block),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Pre-sleep phase Section (Mindfulness Training changed to Training)
                    if (preSleepPhaseBlocks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Text(
                                AppTranslations.translate('training', _settings.currentLanguage),
                                textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                              const SizedBox(width: 8),
                              Text(
                                '($trainingDurationText)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                      // Display Cues & Prompts and Cues Only side by side
                      if (preSleepPhaseBlocks.length >= 2) ...[
                        Row(
                            children: [
                            Expanded(
                              child: _buildBlockCard(
                                preSleepPhaseBlocks[0],
                                currentBlockIndex == blocks.indexOf(preSleepPhaseBlocks[0]),
                                blocks.indexOf(preSleepPhaseBlocks[0]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildBlockCard(
                                preSleepPhaseBlocks[1],
                                currentBlockIndex == blocks.indexOf(preSleepPhaseBlocks[1]),
                                blocks.indexOf(preSleepPhaseBlocks[1]),
                              ),
                            ),
                          ],
                        ),
                        // Include any additional blocks after the first two if they exist
                        for (int i = 2; i < preSleepPhaseBlocks.length; i++)
                          _buildBlockCard(
                            preSleepPhaseBlocks[i],
                            currentBlockIndex == blocks.indexOf(preSleepPhaseBlocks[i]),
                            blocks.indexOf(preSleepPhaseBlocks[i]),
                          ),
                      ] else if (preSleepPhaseBlocks.isNotEmpty) ...[
                        // If there's only one block, display it normally
                              for (var block in preSleepPhaseBlocks)
                                _buildBlockCard(
                                  block,
                                  currentBlockIndex == blocks.indexOf(block),
                                  blocks.indexOf(block),
                                ),
                            ],
                      const SizedBox(height: 16),
                    ],

                    // Sleep Recap Block (now after the Training section)
                    if (sleepPhaseBlocks.isNotEmpty) ...[
                      for (var block in sleepPhaseBlocks)
                        _buildSleepRecapBlock(context, block),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildMindfulnessOverlay(),
        if (isBlackOverlay)
          GestureDetector(
            onTap: _handleBlackOverlayTap,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
      ],
    );
  }

  Widget _buildBlockCard(Block block, bool isActive, int index) {
    // Check if block is completed (for non-sleep phase blocks)
    bool isCompleted = !block.sleepPhase && 
                      block.elapsedTime >= block.totalDuration;
    
    // A block should be highlighted if it's running but not completed
    bool isSleepActive = isProtocolRunning && 
                         currentBlockIndex == index && 
                         !isCompleted;
                         
    bool isMindfulnessActive = isMindfulnessRunning && 
                              mindfulnessBlockIndex == index && 
                              !isCompleted;
    
    bool shouldHighlight = isSleepActive || isMindfulnessActive;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
        transform: Matrix4.identity()..scale(shouldHighlight ? 1.02 : 1.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF252531).withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              border: shouldHighlight ? 
                    Border.all(color: Colors.white70, width: 2) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0, bottom: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  if (block.sleepPhase)
                    _buildSleepPhaseProgress(block)
                  else
                    _buildCycleStepsProgress(block, isCompleted),
                    const SizedBox(height: 15),
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            block.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () => _showBlockSettings(context, block, index),
                        ),
                      ],
                    ),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBlockTap(int blockIndex) {
    if (isProtocolRunning) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2D2D36),
            title: const Text(
              'Start from this block?',
              style: TextStyle(color: Colors.white70),
            ),
            content: const Text(
              'Current protocol progress will be reset and will start from this block.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Start'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[300],
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _startFromSelectedBlock(blockIndex);
                },
              ),
            ],
          );
        },
      );
    } else {
      _startFromSelectedBlock(blockIndex);
    }
  }

  void _startFromSelectedBlock(int blockIndex) {
    if (isProtocolRunning) {
      stopProtocol();
    }
    startFromBlock(blockIndex);
  }

  void startFromBlock(int blockIndex) {
    if (blockIndex >= blocks.length) return;

    setState(() {
      currentBlockIndex = blockIndex;
      currentCycleIndex = 0;
      
      // Only reset the block we're starting
      blocks[blockIndex].elapsedTime = 0.0;
      blocks[blockIndex].completedSteps = 0;
      if (blocks[blockIndex] is MindfulnessBlock) {
        (blocks[blockIndex] as MindfulnessBlock).reset();
      }
      // Reset trigger flags for sleep phase block
      if (blocks[blockIndex].sleepPhase) {
        blocks[blockIndex].triggersFired = List.filled(blocks[blockIndex].triggerTimes.length, false);
      }
      
      // Calculate total duration including currently running blocks
      totalProtocolDuration = 0;
      for (var block in blocks) {
        totalProtocolDuration += block.totalDuration;
      }
    });
    
    startProtocol();
  }

  void _handleStop() async {
    // Show confirmation dialog
    final bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D36),
          title: const Text(
            'Stop Protocol?',
            style: TextStyle(color: Colors.white70),
          ),
          content: const Text(
            'Are you sure you want to stop the protocol? All progress will be lost.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Stop'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[300],
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // Only stop if user confirmed
    if (shouldStop == true) {
      stopProtocol();
      setState(() {
        elapsedProtocolTime = 0.0;
        currentBlockIndex = 0;
        currentCycleIndex = 0;
        isProtocolRunning = false;
        isProtocolPaused = false;
        for (var b in blocks) {
          b.elapsedTime = 0.0;
          b.completedSteps = 0;
          if (b is MindfulnessBlock) {
            b.reset();  // Reset mindfulness stats
          }
        }
      });
    }
  }

  void _handleStartSleeping() async {
    // If protocol is already running, handle pause/resume normally
    if (isProtocolRunning) {
      if (!isProtocolPaused) {
        pauseProtocol();
      } else {
        resumeProtocol();
      }
      return;
    }
    
    // StartSleeping no longer requires premium - just start the protocol
    try {
      // Just make sure RevenueCat is initialized (for potential future settings changes)
      
      // Start the sleep protocol with no paywall
      print("Starting sleep protocol - premium no longer required for basic functionality");
      startFromBlock(blocks.indexWhere((b) => b.sleepPhase));
      
    } catch (e) {
      print("Error in starting sleep protocol: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red.shade700,
        )
      );
    }
  }

  void _handleMindfulnessTraining() async {
    // Find the first Mindfulness Training block (non-MindfulnessBlock type)
    int mindfulnessIndex = blocks.indexWhere((b) => 
      !(b is MindfulnessBlock) && 
      !b.sleepPhase && 
      b.cues  // Make sure it's a block with cues enabled
    );
    
    if (mindfulnessIndex == -1) return;  // No suitable block found
    
    // If already running, toggle pause
    if (isMindfulnessRunning) {
      setState(() {
        isMindfulnessPaused = !isMindfulnessPaused;
        
        if (isMindfulnessPaused) {
          // Pause audio when paused
          audioPlayer.pause();
          beepPlayer.pause();
        }
      });
      return;
    }
    
    // Initialize if needed
    if (!isProtocolRunning && !isMindfulnessRunning) {
      await _backgroundService.startBackgroundService();
      await _backgroundService.startSilentAudio();
    }
    
    setState(() {
      // Reset only the mindfulness block
      blocks[mindfulnessIndex].elapsedTime = 0;
      blocks[mindfulnessIndex].completedSteps = 0;
      
      // Start mindfulness training
      isMindfulnessRunning = true;
      isMindfulnessPaused = false;
      mindfulnessBlockIndex = mindfulnessIndex;
    });
    
    // Start the block in a separate timer
    mindfulnessTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!isMindfulnessPaused && mindfulnessBlockIndex >= 0) {
        setState(() {
          final block = blocks[mindfulnessBlockIndex];
          block.elapsedTime += 0.1;
          
          // Check for cycle completion
          int newCompletedSteps = (block.elapsedTime / block.senseDuration.inSeconds).floor();
          if (newCompletedSteps > block.completedSteps) {
            block.completedSteps = newCompletedSteps;
            // Trigger cue at the end of each cycle
            if (block.cues) {
              // Use microtask to handle async operation outside setState
              Future.microtask(() => _handleCycleCompletion(block));
            }
          }
          
          // Check for training completion
          if (block.elapsedTime >= block.totalDuration.toDouble()) {
            block.elapsedTime = block.totalDuration.toDouble();
            block.completedSteps = block.cycles;
            
            // Check if this is the "Cues & Prompts" block (index 0)
            if (block.prompts && mindfulnessBlockIndex == 0) {
              // Find the "Cues Only" block (index 1)
              int cuesOnlyIndex = 1; // Assuming it's always at index 1
              
              // Reset the "Cues Only" block
              blocks[cuesOnlyIndex].elapsedTime = 0;
              blocks[cuesOnlyIndex].completedSteps = 0;
              
              // Switch to the "Cues Only" block automatically
              mindfulnessBlockIndex = cuesOnlyIndex;
            } else {
              // This was the last block ("Cues Only"), so training is complete
              isMindfulnessRunning = false;
              mindfulnessBlockIndex = -1;
              timer.cancel();
              
              // Record the training session
              _recordTrainingSession();
            }
          }
        });
      }
    });
  }

  // Record training session to user stats
  void _recordTrainingSession() async {
    final totalDurationSeconds = blocks[0].cycles * blocks[0].senseDuration.inSeconds +
                                 blocks[1].cycles * blocks[1].senseDuration.inSeconds;
    
    final trainingSession = TrainingSession(
      id: const Uuid().v4(),
      date: DateTime.now(),
      duration: totalDurationSeconds,
      completed: true,
    );
    
    // Save training session
    await UserStatsService().saveTrainingSession(trainingSession);
    
    // Show a small notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.translate('trainingSessionRecorded', _settings.currentLanguage)),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF5E5DE3),
      ),
    );
  }

  void _handleBlackOverlayTap() {
    setState(() {
      isBlackOverlay = false;
      widget.onBlackOverlayChanged?.call(false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }

  void _showBlockSettings(BuildContext context, Block block, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        if (block is MindfulnessBlock) {
          return MindfulnessSettingsDialog(
            block: block,
            onBlockUpdated: (updatedBlock) => _updateBlock(index, updatedBlock),
          );
        } else if (block.sleepPhase) {
          return SleepPhaseSettingsDialog(
            block: block,
            onBlockUpdated: (updatedBlock) => _updateBlock(index, updatedBlock),
            onSleepPhaseDelayChanged: (value) => _updateBlock(index, block),
            currentDelay: sleepPhaseDelayMinutes,
          );
        } else {
          return BlockSettingsDialog(
            block: block,
            defaultBlock: defaultBlocks[index],
            onBlockUpdated: (updatedBlock) => _updateBlock(index, updatedBlock),
          );
        }
      },
    );
  }

  // Add method to show time picker
  Future<void> _selectTime(BuildContext context, bool isSleepTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isSleepTime ? _sleepTime : _wakeTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF252531),
              hourMinuteTextColor: Colors.white,
              dayPeriodTextColor: Colors.white,
              dialHandColor: const Color(0xFF5E5DE3),
              dialBackgroundColor: const Color(0xFF403E49),
              dialTextColor: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5E5DE3),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isSleepTime) {
          _sleepTime = picked;
        } else {
          _wakeTime = picked;
        }
        // Recalculate sleep duration for all sleep phase blocks
        _computeBlockDurations();
      });
    }
  }

  // Add method to calculate sleep duration in minutes
  int calculateSleepDuration() {
    int sleepMinutes = _sleepTime.hour * 60 + _sleepTime.minute;
    int wakeMinutes = _wakeTime.hour * 60 + _wakeTime.minute;
    
    // If wake time is earlier than sleep time, add 24 hours
    if (wakeMinutes <= sleepMinutes) {
      wakeMinutes += 24 * 60;
    }
    
    return wakeMinutes - sleepMinutes;
  }

  // Methods for handling independent Mindfulness Training
  void _handleStopMindfulness() async {
    // Show confirmation dialog
    final bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D36),
          title: Text(
            AppTranslations.translate('stopMindfulnessTraining', _settings.currentLanguage),
            style: const TextStyle(color: Colors.white70),
          ),
          content: Text(
            AppTranslations.translate('stopMindfulnessConfirm', _settings.currentLanguage),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: Text(AppTranslations.translate('cancel', _settings.currentLanguage)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(AppTranslations.translate('stop', _settings.currentLanguage)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[300],
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // Only stop if user confirmed
    if (shouldStop == true) {
      _stopMindfulnessTraining();
    }
  }

  void _stopMindfulnessTraining() {
                      setState(() {
      isMindfulnessRunning = false;
      isMindfulnessPaused = false;
      mindfulnessBlockIndex = -1;
      
      // Find and reset the mindfulness block
      int index = blocks.indexWhere((b) => 
        !(b is MindfulnessBlock) && 
        !b.sleepPhase && 
        b.cues
      );
      
      if (index >= 0) {
        blocks[index].elapsedTime = 0.0;
        blocks[index].completedSteps = 0;
      }
    });
    
    mindfulnessTimer?.cancel();
    mindfulnessTimer = null;
  }

  void _handleSkipMindfulness() async {
    if (!isMindfulnessRunning || isMindfulnessPaused) return;
    
    // Find the mindfulness block
    int index = blocks.indexWhere((b) => 
      !(b is MindfulnessBlock) && 
      !b.sleepPhase && 
      b.cues
    );
    
    if (index < 0) return;
    
    Block currentBlock = blocks[index];
    
    setState(() {
      // Skip to next cycle
      double timeToComplete = currentBlock.senseDuration.inSeconds - 
        (currentBlock.elapsedTime % currentBlock.senseDuration.inSeconds);
      
      currentBlock.elapsedTime += timeToComplete;
      currentBlock.completedSteps = (currentBlock.elapsedTime / currentBlock.senseDuration.inSeconds).floor();
      
      if (currentBlock.elapsedTime >= currentBlock.totalDuration.toDouble()) {
        currentBlock.elapsedTime = currentBlock.totalDuration.toDouble();
        currentBlock.completedSteps = currentBlock.cycles;
        
        // Training completed
        isMindfulnessRunning = false;
        mindfulnessBlockIndex = -1;
        mindfulnessTimer?.cancel();
      }
    });

    // Trigger sounds if needed
    if (currentBlock.cues) {
      await _handleCycleCompletion(currentBlock);
    }
  }

  // Add new dream from training page
  Future<void> _handleAddDream(BuildContext context) async {
    // Navigate to the DreamEditScreen to create a new dream
    final dreamEntry = await Navigator.push<DreamEntry>(
      context,
      MaterialPageRoute(
        builder: (context) => const DreamEditScreen(),
      ),
    );

    // If dream was created, save it to Firestore
    if (dreamEntry != null) {
      // Save dream using UserStatsService
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('dreams')
              .doc(dreamEntry.id)
              .set(dreamEntry.toJson());
              
          // Create a notification to the journal page to refresh
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('dream_journal_refresh', DateTime.now().toIso8601String());
              
          // Show confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.translate('dreamSaved', _settings.currentLanguage)),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF5E5DE3),
            ),
          );
        } catch (e) {
          debugPrint('Error saving dream: $e');
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.translate('errorSavingDream', _settings.currentLanguage)),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Handle cycle completion with proper audio playback
  Future<void> _handleCycleCompletion(Block block) async {
    await triggerCue();
    if (block.prompts) {
      await playPrompt();
    }
  }
}

class Block {
  final String name;
  final int cycles;
  final Duration senseDuration;
  final bool cues;
  final bool prompts;
  final bool afterBlockCue;
  final bool sleepPhase;
  final int? sleepPhaseDelay;

  final bool useRem1;
  final bool useRem2;
  final bool useRem3;
  final bool useRem4;
  final bool useRem5;
  final bool useRem6;
  final bool useRem7;
  final int signalsPerPhase;

  int totalDuration = 0;
  double elapsedTime = 0.0;
  int totalSteps = 0;
  int completedSteps = 0;

  // Trigger times (in minutes) and tracking for sleep phase
  List<double> triggerTimes = [];
  List<bool> triggersFired = [];

  Block({
    required this.name,
    required this.cycles,
    required this.senseDuration,
    this.cues = false,
    this.prompts = false,
    this.afterBlockCue = false,
    this.sleepPhase = false,
    this.sleepPhaseDelay,
    this.useRem1 = true,
    this.useRem2 = true,
    this.useRem3 = true,
    this.useRem4 = true,
    this.useRem5 = true,
    this.useRem6 = true,
    this.useRem7 = true,
    this.signalsPerPhase = 3,
  }) {
    if (sleepPhase) {
      totalSteps = cycles;
      totalDuration = (sleepPhaseDelay ?? 450) * 60;
      _computeTriggerTimes();
    } else {
      totalSteps = cycles;
      totalDuration = cycles * senseDuration.inSeconds;
    }
  }

  // Compute trigger times for sleep-phase blocks.
  void _computeTriggerTimes() {
    // Define the baseline REM settings (in minutes).
    final List<Map<String, dynamic>> remCyclesBaseline = [
      {'start': 75.0, 'active': useRem1},
      {'start': 165.0, 'active': useRem2},
      {'start': 240.0, 'active': useRem3},
      {'start': 315.0, 'active': useRem4},
      {'start': 390.0, 'active': useRem5},
      {'start': 480.0, 'active': useRem6},
      {'start': 575.0, 'active': useRem7},
    ];

    // Calculate timeBetween in minutes: we assume senseDuration is in seconds.
    double timeBetween = senseDuration.inSeconds / 60.0;

    // For each active REM setting, schedule a number of triggers.
    List<double> times = [];
    for (var rem in remCyclesBaseline) {
      if (rem['active'] == true) {
        for (int i = 0; i < signalsPerPhase; i++) {
          double t = (rem['start'] as double) + (timeBetween * i);
          times.add(t);
        }
      }
    }
    times.sort();
    triggerTimes = times;
    // Initially, none of the triggers have fired.
    triggersFired = List.filled(times.length, false);
  }

  int get currentCycle => completedSteps.clamp(0, cycles);
}

class MindfulnessBlock extends Block {
  final int durationMinutes = 5;
  int completedCycles = 0;  // Count of successful full cycles (1-10)
  int totalCycles = 0;      // Total cycle attempts
  int currentBreath = 1;    // Current breath in sequence
  final _TrainingScreenState? parentState;  // Reference to parent state
  
  MindfulnessBlock({this.parentState})
      : super(
          name: 'Breath Counting', // Using a hardcoded string for now - TODO: fix translation
          cycles: 1,
          senseDuration: const Duration(minutes: 5),
          cues: true,  // Enable cues by default
          prompts: true,  // Enable prompts by default
          afterBlockCue: true,  // Enable after block cue
        );

  // Calculate success rate as a percentage
  double get successRate {
    if (totalCycles == 0) return 0.0;
    return (completedCycles / totalCycles) * 100;
  }

  // Record the result of a breath counting cycle and trigger cues/prompts
  Future<void> recordCycleResult(bool isCorrect) async {
    totalCycles++;
    if (isCorrect) {
      completedCycles++;
      // Play cue and prompt after successful cycle
      if (cues && parentState != null) {
        await parentState!._handleCycleCompletion(this);
      }
    }
  }

  // Reset the block state
  void reset() {
    completedCycles = 0;
    totalCycles = 0;
    currentBreath = 1;
  }
}
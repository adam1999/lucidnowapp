import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucid_dream_trainer/models/mindfulness_score.dart';
import 'package:lucid_dream_trainer/models/sleep_session.dart';
import 'package:lucid_dream_trainer/providers/settings_provider.dart';
import 'package:lucid_dream_trainer/screens/settings/widgets/block_settings.dart';
import 'package:lucid_dream_trainer/screens/settings/widgets/mindfulness_settings.dart';
import 'package:lucid_dream_trainer/screens/settings/widgets/sleep_settings.dart';
import 'package:lucid_dream_trainer/services/background_service.dart';
import 'package:lucid_dream_trainer/translations/app_translations.dart';
import 'package:provider/provider.dart';
import '../../models/training_session.dart';
import '../widgets/common_header.dart';
import '../../services/user_stats_service.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

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
  final ScrollController scrollController = ScrollController();

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

  // Progress Tracking
  int currentBlockIndex = 0;
  int currentCycleIndex = 0;
  List<Block> blocks = [];

  String currentPhase = '';
  List<Block> defaultBlocks = [];
  bool isBlackOverlay = false;

  late SettingsProvider _settings;
  late BackgroundService _backgroundService;

  bool _isControlsExpanded = false;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsScaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _sleepSessionSaved = false;

  int mindfulnessCueCount = 0;
  int maxMindfulnessCues = 10;

  @override
  void initState() {
    super.initState();
    _backgroundService = BackgroundService();
    _initializeBackgroundService();
    _settings = Provider.of<SettingsProvider>(context, listen: false);
    backgroundAudioEnabled = _settings.backgroundAudioEnabled;
    keepScreenOn = _settings.keepScreenOn;
    sleepPhaseDelayMinutes = _settings.sleepPhaseDelayMinutes;

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

    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsScaleAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controlsAnimationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _initializeBackgroundService() async {
    await _backgroundService.initializeService();
  }

  Future<void> _loadSavedBlockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

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
        // Sleep phase block
        Block(
          name: '${AppTranslations.translate('sleepPhase', settings.currentLanguage)}',
          cycles: prefs.getInt('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_cycles') ?? 4,
          senseDuration: Duration(
            seconds: prefs.getInt('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_signal_lapse') ?? 20,
          ),
          cues: true,
          prompts: false,
          afterBlockCue: false,
          sleepPhase: true,
          sleepPhaseDelay: prefs.getInt('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_delay') ?? sleepPhaseDelayMinutes,
          useRem1: prefs.getBool('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_useRem1') ?? true,
          useRem2: prefs.getBool('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_useRem2') ?? true,
          useRem3: prefs.getBool('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_useRem3') ?? true,
          useRem4: prefs.getBool('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_useRem4') ?? true,
          useRem5: prefs.getBool('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_useRem5') ?? true,
          useRem6: prefs.getBool('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_useRem6') ?? true,
          useRem7: prefs.getBool('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_useRem7') ?? true,
          signalsPerPhase: prefs.getInt('block_${AppTranslations.translate('sleepPhase', settings.currentLanguage)}_signals_per_phase') ?? 3,
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
                          'Breath: ${mindfulnessBlock.currentBreath}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          'Success: ${mindfulnessBlock.successRate.toStringAsFixed(1)}%',
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
                            'Lost Count',
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
                                  'Tap for Breaths 1-9',
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
                                  'Tap for Breath 10',
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
    _controlsAnimationController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _isControlsExpanded = !_isControlsExpanded;
      if (_isControlsExpanded) {
        _controlsAnimationController.forward();
      } else {
        _controlsAnimationController.reverse();
      }
    });
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
        await triggerCue();
        if (currentBlock.prompts) {
          await playPrompt();
        }
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
    return Positioned(
      bottom: 130,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Sleeping Button (Main button)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: AnimatedBuilder(
                    animation: _controlsAnimationController,
                    builder: (context, child) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isControlsExpanded ? 16 : 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2 * _controlsAnimationController.value),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2 * _controlsAnimationController.value),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isControlsExpanded)
                              ScaleTransition(
                                scale: _controlsScaleAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: IconButton(
                                    icon: const Icon(Icons.stop, color: Colors.white),
                                    iconSize: 36,
                                    onPressed: _handleStop,
                                  ),
                                ),
                              ),
                            AnimatedPadding(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.symmetric(
                                horizontal: _isControlsExpanded ? 12 : 0,
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5E5DE3),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  elevation: _isControlsExpanded ? 4 : 8,
                                ),
                                onPressed: _handleStartSleeping,
                                icon: Icon(
                                  !isProtocolRunning && !isProtocolPaused ? Icons.nightlight_round :
                                  !isProtocolPaused ? Icons.pause : Icons.play_arrow,
                                  size: 36,
                                ),
                                label: Text(
                                  !isProtocolRunning && !isProtocolPaused ? 'Start Training' :
                                  !isProtocolPaused ? 'Pause' : 'Resume',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            if (_isControlsExpanded)
                              ScaleTransition(
                                scale: _controlsScaleAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: IconButton(
                                    icon: const Icon(Icons.fast_forward, color: Colors.white),
                                    iconSize: 36,
                                    onPressed: isProtocolRunning && !isProtocolPaused ? skipToNextCycle : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Mindfulness Training button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E5DE3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
              onPressed: _handleMindfulnessTraining,
              icon: const Icon(Icons.self_improvement, size: 24),
              label: const Text(
                'Training',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _computeBlockDurations() {
    for (var block in blocks) {
      block.elapsedTime = 0;
      if (block.sleepPhase) {
        // Use only the sleepPhaseDelay (in minutes) to compute totalDuration.
        block.totalDuration = (block.sleepPhaseDelay ?? sleepPhaseDelayMinutes) * 60;
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
      // Check if protocol is still running before playing
      if (!isProtocolRunning || isProtocolPaused) return;
      await audioPlayer.play(AssetSource('prompt.mp3'));
      
      // Add completion listener to handle protocol state changes
      audioPlayer.onPlayerComplete.listen((event) {
        if (!isProtocolRunning || isProtocolPaused) {
          audioPlayer.stop();
        }
      });
    }
  }

  Future<void> playBeep() async {
    if (!backgroundAudioEnabled) return;
    // Construct the asset path using the sound trigger selected in settings.
    final soundFile = 'soundtriggers/${_settings.soundTrigger}';
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
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
      final double totalSleepTime = block.sleepPhaseDelay?.toDouble() ?? 450.0;
      final List<Map<String, dynamic>> remCyclesBaseline = [
        {'remNumber': 1, 'start': 75.0, 'duration': 15.0, 'active': block.useRem1},
        {'remNumber': 2, 'start': 165.0, 'duration': 15.0, 'active': block.useRem2},
        {'remNumber': 3, 'start': 240.0, 'duration': 30.0, 'active': block.useRem3},
        {'remNumber': 4, 'start': 315.0, 'duration': 45.0, 'active': block.useRem4},
        {'remNumber': 5, 'start': 390.0, 'duration': 60.0, 'active': block.useRem5},
        {'remNumber': 6, 'start': 480.0, 'duration': 75.0, 'active': block.useRem6},
        {'remNumber': 7, 'start': 575.0, 'duration': 25.0, 'active': block.useRem7},
      ];
      final progress = (block.elapsedTime / (totalSleepTime * 60)).clamp(0.0, 1.0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                int tickCount = (totalSleepTime / 60).ceil() + 1;
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
                    for (int i = 0; i < tickCount; i++)
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
                            const SizedBox(height: 4),
                            Text(
                              '${i}h',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
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
    final double sleepTime = block.sleepPhaseDelay?.toDouble() ?? 450.0;
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

    double totalRemEstimation = 0.0;
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
      if (start < sleepTime) {
        totalRemEstimation += duration;
        if (rem['active'] == true) {
          targetLucidLength += duration;
          totalTriggers += computeTriggers(start, timeBetween, block.signalsPerPhase, sleepTime);
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
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.0,
          children: [
            _buildRecapBox(
              "Sleep Duration",
              fmt(sleepTime),
              background: const Color(0xFF403E49).withOpacity(0.6),
            ),
            _buildRecapBox(
              "Total REM estimation",
              fmt(totalRemEstimation),
              background: const Color(0xFF403E49).withOpacity(0.6),
            ),
            _buildRecapBox(
              "Triggers count",
              "$totalTriggers",
              background: const Color(0xFF403E49).withOpacity(0.6),
            ),
            _buildRecapBox(
              "Target Lucid Dream length",
              fmt(targetLucidLength),
              gradient: const LinearGradient(
                colors: [Color(0xFF5E5DE3), Color(0xFF7E7DE3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 1,
          width: double.infinity,
          color: Colors.white.withOpacity(0.1),
        ),
        const SizedBox(height: 12),
        Text(
          "Sleep Recap",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
          )
        : BoxDecoration(
            color: background ?? const Color(0xFF403E49).withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
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

  @override
  Widget build(BuildContext context) {
    // Split blocks into sections
    final mindfulnessBlocks = blocks.whereType<MindfulnessBlock>().toList();
    final preSleepPhaseBlocks = blocks.where((b) => 
      !(b is MindfulnessBlock) && 
      !b.sleepPhase
    ).toList();
    final sleepPhaseBlocks = blocks.where((b) => b.sleepPhase).toList();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const CommonHeader(),
          body: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: 200.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intensive Mindfulness Section
                    if (mindfulnessBlocks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                        child: Text(
                          'Intensive Mindfulness',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
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

                    // Sleep Phase Section (Now Night Preview)
                    if (sleepPhaseBlocks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                        child: Text(
                          'Night Preview',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          for (var block in sleepPhaseBlocks) ...[
                            _buildBlockCard(
                              block,
                              currentBlockIndex == blocks.indexOf(block),
                              blocks.indexOf(block),
                            ),
                            const SizedBox(height: 8),
                            _buildSleepRecapBlock(context, block),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Pre-sleep phase Section
                    if (preSleepPhaseBlocks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                        child: Text(
                          'Mindfulness Training',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          for (var block in preSleepPhaseBlocks)
                            _buildBlockCard(
                              block,
                              currentBlockIndex == blocks.indexOf(block),
                              blocks.indexOf(block),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildMindfulnessOverlay(),
        _buildFloatingControls(),
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
    bool shouldHighlight = isProtocolRunning && 
                         block.elapsedTime > 0 && 
                         !isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: GestureDetector(
        onTap: () => _handleBlockTap(index),
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
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (block.sleepPhase)
                      _buildSleepPhaseProgress(block)
                    else
                      _buildCycleStepsProgress(block, isCompleted),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            block.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 14,
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
    setState(() {
      _isControlsExpanded = true;
    });
    _controlsAnimationController.forward();
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
      setState(() {
        _isControlsExpanded = false;
      });
      await _controlsAnimationController.reverse();
    }
  }

  void _handleStartSleeping() {
    if (!isProtocolRunning) {
      _toggleControls();
      startFromBlock(blocks.indexWhere((b) => b.sleepPhase));
    } else if (!isProtocolPaused) {
      pauseProtocol();
    } else {
      resumeProtocol();
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
    
    // Initialize if not running
    if (!isProtocolRunning) {
      await _backgroundService.startBackgroundService();
      await _backgroundService.startSilentAudio();
    }
    
    // Store the current state of any running blocks
    Map<int, double> runningBlockStates = {};
    for (int i = 0; i < blocks.length; i++) {
      if (blocks[i].elapsedTime > 0) {
        runningBlockStates[i] = blocks[i].elapsedTime;
      }
    }
    
    setState(() {
      // Reset only the mindfulness block
      blocks[mindfulnessIndex].elapsedTime = 0;
      blocks[mindfulnessIndex].completedSteps = 0;
      
      // Restore other running blocks
      runningBlockStates.forEach((index, time) {
        if (index != mindfulnessIndex) {
          blocks[index].elapsedTime = time;
        }
      });
      
      isProtocolRunning = true;
      isProtocolPaused = false;
      currentBlockIndex = mindfulnessIndex;
      currentCycleIndex = 0;
    });
    
    // Start the block
    await startBlock(blocks[mindfulnessIndex]);
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
          name: 'Breath Counting',
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
        await parentState!.triggerCue();
        if (prompts) {
          await parentState!.playPrompt();
        }
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
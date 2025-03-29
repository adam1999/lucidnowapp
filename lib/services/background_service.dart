// background_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart' as audio;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

// Top-level functions for background service
@pragma('vm:entry-point')
void _onStartBackground(ServiceInstance service) {
  BackgroundService._onStartStatic(service);
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer audioPlayer = AudioPlayer(); // used for trigger sounds
  final AudioPlayer silentPlayer = AudioPlayer(); // used to keep audio session active
  static const platform = MethodChannel('torch_control');

  String selectedSound = "melody1.mp3";

  Future<void> initializeService() async {
    final session = await audio.AudioSession.instance;
    await session.configure(const audio.AudioSessionConfiguration(
      avAudioSessionCategory: audio.AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: audio.AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: audio.AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: audio.AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: audio.AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    ));
    await session.setActive(true);

    // Prepare trigger audio player.
    await audioPlayer.setReleaseMode(ReleaseMode.stop);
    await audioPlayer.setSource(AssetSource('soundtriggers/$selectedSound'));

    // Prepare silent audio player to loop a silent audio file.
    await silentPlayer.setReleaseMode(ReleaseMode.loop);
    await silentPlayer.setVolume(0.001);
    await silentPlayer.setSource(AssetSource('silence.wav'));

    final service = FlutterBackgroundService();
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStartBackground,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStartBackground,
        autoStart: false,
        isForegroundMode: true,
      ),
    );

    // Initialize notification settings for both platforms
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Using app icon as notification icon
    
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
      android: initializationSettingsAndroid, // Added Android settings
    );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Start silent audio to keep the app active in background.
    await startSilentAudio();
  }

  Future<void> startSilentAudio() async {
    try {
      await silentPlayer.play(AssetSource('silence.wav'));
    } catch (e) {
      debugPrint('Error starting silent audio: $e');
    }
  }

  Future<void> stopSilentAudio() async {
    try {
      await silentPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping silent audio: $e');
    }
  }

  // Static implementation of onStart for background service
  @pragma('vm:entry-point')
  static void _onStartStatic(ServiceInstance service) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('triggerCue').listen((event) async {
      if (event != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        final String sense = data['sense'] as String;
        if (sense == 'Vision') {
          try {
            await platform.invokeMethod('startFlashing');
          } catch (e) {
            debugPrint('Error triggering flash: $e');
          }
        } else if (sense == 'Hearing') {
          try {
            await _instance.audioPlayer.play(AssetSource('soundtriggers/${_instance.selectedSound}'));
          } catch (e) {
            debugPrint('Error playing audio: $e');
          }
        }
        _showNotification('Triggering cue: $sense');
      }
    });

    service.on('stopCues').listen((event) async {
      try {
        await platform.invokeMethod('stopFlashing');
        await _instance.audioPlayer.stop();
      } catch (e) {
        debugPrint('Error stopping cues: $e');
      }
    });

    service.on('update').listen((event) {
      if (event != null) {
        _handleProtocolUpdate(event);
      }
    });

    service.on('updateSound').listen((event) {
      if (event != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        _instance.selectedSound = data['sound'] as String;
      }
    });
  }

  static void _handleProtocolUpdate(Map<String, dynamic>? event) {
    if (event == null) return;
    _showNotification('Protocol running: ${event['currentPhase']}');
  }

  static void _showNotification(String message) {
    _instance.flutterLocalNotificationsPlugin.show(
      888,
      'Lucid Dream Training',
      message,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'lucid_dream_channel',
          'Lucid Dream Notifications',
          channelDescription: 'Notifications for lucid dream training',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> startBackgroundService() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  Future<void> stopBackgroundService() {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    service.invoke('stopCues');
    stopSilentAudio();
    return Future.value();
  }

  Future<void> triggerBackgroundCue(String sense) {
    final service = FlutterBackgroundService();
    service.invoke('triggerCue', {'sense': sense});
    return Future.value();
  }

  Future<void> updateServiceData(Map<String, dynamic> data) {
    final service = FlutterBackgroundService();
    service.invoke('update', data);
    return Future.value();
  }

  Future<void> updateSelectedSound(String sound) async {
    selectedSound = sound;
    final service = FlutterBackgroundService();
    service.invoke('updateSound', {'sound': sound});
  }
}

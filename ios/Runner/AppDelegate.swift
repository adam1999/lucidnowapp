import Flutter
import UIKit
import AVFoundation
import BackgroundTasks
import MediaPlayer
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
    // Audio related properties
    private var backgroundAudioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Background task properties
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    
    // Flash related properties
    private var shouldFlash = false
    private var captureSession: AVCaptureSession?
    private var isFlashActive = false
    private var torchQueue = DispatchQueue(label: "com.tardam.lucidnow.torchQueue")
    
    // Vibration properties
    private var vibrationTimer: Timer?
    private var isVibrating = false
    private let vibrationFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private var vibrationPattern: [TimeInterval] = [0.3, 0.2, 0.3] // On, Off, On durations

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "torch_control",
            binaryMessenger: controller.binaryMessenger
        )
        
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }
            switch call.method {
            case "turnOn":
                self.toggleTorch(true)
                result(nil)
            case "turnOff":
                self.toggleTorch(false)
                result(nil)
            case "startFlashing":
                self.startBackgroundFlashing()
                result(nil)
            case "stopFlashing":
                self.stopBackgroundFlashing()
                result(nil)
            case "startVibration":
                self.startVibrationSequence()
                result(nil)
            case "stopVibration":
                self.stopVibration()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)
            setupBackgroundAudio()
            vibrationFeedbackGenerator.prepare()
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.tardam.lucidnow.flashTask",
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundTask(task as! BGProcessingTask)
        }

        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupBackgroundAudio() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.backgroundAudioPlayer?.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.backgroundAudioPlayer?.pause()
            return .success
        }
        
        if let audioUrl = Bundle.main.url(forResource: "silence", withExtension: "wav") {
            do {
                backgroundAudioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
                backgroundAudioPlayer?.numberOfLoops = -1
                backgroundAudioPlayer?.prepareToPlay()
            } catch {
                print("Failed to setup background audio: \(error)")
            }
        }
    }
    
    private func toggleTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }

    private func startVibrationSequence() {
        isVibrating = true
        
        // First vibration
        vibrationFeedbackGenerator.impactOccurred()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        // Schedule second vibration after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isVibrating else { return }
            self.vibrationFeedbackGenerator.impactOccurred()
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    private func stopVibration() {
        isVibrating = false
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    private func startBackgroundFlashing() {
        shouldFlash = true
        setupCaptureSession()
        startBackgroundTask()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.flashSequence()
        }
        RunLoop.current.add(backgroundTimer!, forMode: .common)
        backgroundAudioPlayer?.play()
    }

    private func setupCaptureSession() {
        guard captureSession == nil else { return }
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .low
        
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            captureSession?.addInput(input)
            
            let output = AVCaptureVideoDataOutput()
            if captureSession?.canAddOutput(output) ?? false {
                captureSession?.addOutput(output)
            }
            
            captureSession?.startRunning()
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {
            print("Camera config error: \(error)")
        }
    }

    private func stopBackgroundFlashing() {
        shouldFlash = false
        isFlashActive = false
        captureSession?.stopRunning()
        captureSession = nil
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }

    private func flashSequence() {
        torchQueue.async { [weak self] in
            guard let device = AVCaptureDevice.default(for: .video),
                  device.hasTorch else { return }
            
            do {
                try device.lockForConfiguration()
                try device.setTorchModeOn(level: 1.0)
                Thread.sleep(forTimeInterval: 0.5)
                device.torchMode = .off
                device.unlockForConfiguration()
            } catch {
                print("Flash error: \(error)")
            }
        }
    }
    
    private func startBackgroundTask() {
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.stopBackgroundFlashing()
            self?.stopVibration()
        }
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        scheduleBackgroundTask()
        
        task.expirationHandler = { [weak self] in
            self?.stopBackgroundFlashing()
            self?.stopVibration()
            task.setTaskCompleted(success: false)
        }
        
        if shouldFlash || isVibrating {
            startBackgroundTask()
            if shouldFlash {
                flashSequence()
            }
            if isVibrating {
                startVibrationSequence()
            }
        }
        
        task.setTaskCompleted(success: true)
    }
    
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.tardam.lucidnow.flashTask")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule task: \(error)")
        }
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        backgroundAudioPlayer?.play()
        if shouldFlash || isVibrating {
            startBackgroundTask()
        }
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        if shouldFlash {
            startBackgroundFlashing()
        }
        if isVibrating {
            startVibrationSequence()
        }
    }
}
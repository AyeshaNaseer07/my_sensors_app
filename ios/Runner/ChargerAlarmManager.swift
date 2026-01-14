import UIKit
import AVFoundation
import Flutter
import UserNotifications

class ChargerAlarmManager: NSObject, AVAudioPlayerDelegate {
    
    // MARK: - Properties
    private var alarmPlayer: AVAudioPlayer?
    private var silentPlayer: AVAudioPlayer?
    private var isAlarmArmed = false
    private var isCharging = true
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    var eventSink: FlutterEventSink?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Init
    init(methodChannel: FlutterMethodChannel, eventChannel: FlutterEventChannel) {
        self.methodChannel = methodChannel
        self.eventChannel = eventChannel
        super.init()
        setupMethodChannel()
        setupEventChannel()
        setupAudioSession()
        requestNotificationPermission()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio Session Configured")
        } catch {
            print("❌ Audio Session Error: \(error)")
        }
    }
    
    // MARK: - Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("✅ Notification Permission Granted")
            } else if let error = error {
                print("❌ Notification Error: \(error)")
            }
        }
    }
    
    // MARK: - Method Channel Setup
    private func setupMethodChannel() {
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "armAlarm":
                self?.armAlarm()
                result("Charger Alarm Armed")
                
            case "disarmAlarm":
                self?.disarmAlarm()
                result("Charger Alarm Disarmed")
                
            case "getChargerStatus":
                let isCharging = self?.isCharging ?? true
                result(isCharging)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Event Channel Setup
    private func setupEventChannel() {
        let streamHandler = ChargerStatusStreamHandler(manager: self)
        eventChannel.setStreamHandler(streamHandler)
        print("✅ Event Channel Setup Complete")
    }
    
    // MARK: - Public Methods
    func setup() {
        enableBatteryMonitoring()
        print("✅ Charger Manager Setup Complete")
    }
    
    func armAlarm() {
        isAlarmArmed = true
        startSilentAudio()
        beginBackgroundTask()
        print("✅ Charger Alarm Armed")
    }
    
    func disarmAlarm() {
        isAlarmArmed = false
        stopAlarm()
        stopSilentAudio()
        endBackgroundTask()
        print("✅ Charger Alarm Disarmed")
    }
    
    func handleBackground() {
        if isAlarmArmed {
            beginBackgroundTask()
            startSilentAudio()
        }
    }
    
    func handleForeground() {
        if isAlarmArmed {
            startSilentAudio()
        }
    }
    
    // MARK: - Background Task Management
    private func beginBackgroundTask() {
        if backgroundTask != .invalid {
            return
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        print("✅ Background Task Started")
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("✅ Background Task Ended")
        }
    }
    
    // MARK: - Battery Monitoring
    private func enableBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        print("✅ Battery Monitoring Enabled")
    }
    
    @objc private func batteryStateChanged() {
        let state = UIDevice.current.batteryState
        let wasCharging = isCharging
        isCharging = (state == .charging || state == .full)
        
        // Send status to Flutter via EventChannel
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(self?.isCharging ?? true)
        }
        
        if isAlarmArmed {
        // ✅ ONLY trigger when UNPLUGGED (wasCharging true, isCharging false)
        if wasCharging && !isCharging {
            print("🔌 Unplugged from charger")
            playAlarm()
        }
    }
    
    print("🔋 Battery State: \(state.rawValue), Charging: \(isCharging)")
}
    
    // MARK: - Audio Playback
    private func playAlarm() {
        guard alarmPlayer?.isPlaying != true else { return }
        guard let url = Bundle.main.url(forResource: "fire_alarm", withExtension: "mp3") else {
            print("❌ Fire alarm audio file not found")
            return
        }
        
        do {
            alarmPlayer = try AVAudioPlayer(contentsOf: url)
            alarmPlayer?.delegate = self
            alarmPlayer?.numberOfLoops = -1
            alarmPlayer?.volume = 1.0
            alarmPlayer?.play()
            
            beginBackgroundTask()
            print("⚡ Charger Alarm Playing!")
        } catch {
            print("❌ Charger alarm error: \(error)")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isAlarmArmed && alarmPlayer == player {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.playAlarm()
            }
        }
    }
    
    private func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        endBackgroundTask()
    }
    
    private func startSilentAudio() {
        guard silentPlayer?.isPlaying != true else { return }
        guard let url = Bundle.main.url(forResource: "silent_alarm", withExtension: "mp3") else {
            print("❌ Silent audio file not found")
            return
        }
        
        do {
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1
            silentPlayer?.volume = 0.001
            silentPlayer?.play()
            print("✅ Silent audio started (background keepalive)")
        } catch {
            print("❌ Silent audio error: \(error)")
        }
    }
    
    private func stopSilentAudio() {
        silentPlayer?.stop()
        silentPlayer = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAlarm()
    }
}

// MARK: - Charger Status Stream Handler
class ChargerStatusStreamHandler: NSObject, FlutterStreamHandler {
    private let manager: ChargerAlarmManager
    
    init(manager: ChargerAlarmManager) {
        self.manager = manager
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        manager.eventSink = events
        print("✅ Charger EventChannel Listener Attached")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        manager.eventSink = nil
        print("✅ Charger EventChannel Listener Detached")
        return nil
    }
}
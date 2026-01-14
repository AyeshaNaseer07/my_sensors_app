import Foundation
import AVFoundation
import Network
import Flutter
import UserNotifications

class WifiAlarmManager: NSObject, AVAudioPlayerDelegate {
    
    // MARK: - Properties
    private var alarmPlayer: AVAudioPlayer?
    private var silentPlayer: AVAudioPlayer?
    private let wifiMonitor = NWPathMonitor()
    private var alarmEnabled = false
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    var eventSink: FlutterEventSink?
    private var lastWifiStatus: NWPath.Status = .unsatisfied
    private var isCurrentlyConnected = false
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
            case "activateAlarm":
                self?.activateAlarm()
                result("Wi‑Fi Alarm Activated")
                
            case "deactivateAlarm":
                self?.deactivateAlarm()
                result("Wi‑Fi Alarm Deactivated")
                
            case "getWifiStatus":
                let isConnected = self?.isCurrentlyConnected ?? false
                result(isConnected)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Event Channel Setup
    private func setupEventChannel() {
        let streamHandler = WifiStatusStreamHandler(manager: self)
        eventChannel.setStreamHandler(streamHandler)
        print("✅ Event Channel Setup Complete")
    }
    
    // MARK: - Public Methods
    func setup() {
        startWifiMonitoring()
        print("✅ WiFi Alarm Manager Setup Complete")
    }
    
    func activateAlarm() {
        alarmEnabled = true
        startSilentAudio()
        beginBackgroundTask()
        print("✅ Wi-Fi Alarm Activated")
    }
    
    func deactivateAlarm() {
        alarmEnabled = false
        stopAlarm()
        stopSilentAudio()
        endBackgroundTask()
        print("✅ Wi-Fi Alarm Deactivated")
    }
    
    func handleBackground() {
        if alarmEnabled {
            beginBackgroundTask()
            startSilentAudio()
        }
    }
    
    func handleForeground() {
        if alarmEnabled {
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
    
    // MARK: - Wi-Fi Monitoring
    private func startWifiMonitoring() {
        wifiMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleWifiStateChange(path)
            }
        }
        wifiMonitor.start(queue: DispatchQueue.global(qos: .background))
        print("✅ Wi-Fi Monitoring Started")
    }
    
    private func handleWifiStateChange(_ path: NWPath) {
        let isConnected = path.status == .satisfied && path.usesInterfaceType(.wifi)
        
        print("📡 WiFi Status - Connected: \(isConnected), AlarmEnabled: \(alarmEnabled)")
        
        // Send status to Flutter via EventChannel
        eventSink?(isConnected)
        
        // Trigger alarm on BOTH connect and disconnect
        if alarmEnabled {
            // On disconnect
            if isCurrentlyConnected && !isConnected {
                print("🚨 WiFi Disconnected - Playing Alarm")
                playAlarm()
            }
            // On connect
            else if !isCurrentlyConnected && isConnected {
                print("🚨 WiFi Connected - Playing Alarm")
                playAlarm()
            }
        }
        
        isCurrentlyConnected = isConnected
        lastWifiStatus = path.status
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
            alarmPlayer?.numberOfLoops = -1 // Infinite loop
            alarmPlayer?.volume = 1.0
            alarmPlayer?.play()
            
            beginBackgroundTask()
            print("🚨 Wi-Fi Alarm Playing!")
        } catch {
            print("❌ Wi-Fi alarm error: \(error)")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if alarmEnabled && alarmPlayer == player {
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
            silentPlayer?.volume = 0.001 // Nearly silent
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
}

// MARK: - WiFi Status Stream Handler
class WifiStatusStreamHandler: NSObject, FlutterStreamHandler {
    private let manager: WifiAlarmManager
    
    init(manager: WifiAlarmManager) {
        self.manager = manager
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        manager.eventSink = events
        print("✅ EventChannel Listener Attached")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        manager.eventSink = nil
        print("✅ EventChannel Listener Detached")
        return nil
    }
}
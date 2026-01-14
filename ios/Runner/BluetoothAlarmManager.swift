import Foundation
import AVFoundation
import CoreBluetooth
import Flutter
import UserNotifications

class BluetoothAlarmManager: NSObject, CBCentralManagerDelegate, AVAudioPlayerDelegate {
    
    // MARK: - Properties
    private var alarmPlayer: AVAudioPlayer?
    private var silentPlayer: AVAudioPlayer?
    private var alarmEnabled = false
    private var centralManager: CBCentralManager?
    private var connectedPeripheralCount = 0
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
            case "activateAlarm":
                self?.activateAlarm()
                result("Bluetooth Alarm Activated")
                
            case "deactivateAlarm":
                self?.deactivateAlarm()
                result("Bluetooth Alarm Deactivated")
                
            case "getBluetoothStatus":
                let status = self?.connectedPeripheralCount ?? 0
                result(status > 0)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Event Channel Setup
    private func setupEventChannel() {
        let streamHandler = BluetoothStatusStreamHandler(manager: self)
        eventChannel.setStreamHandler(streamHandler)
        print("✅ Event Channel Setup Complete")
    }
    
    // MARK: - Public Methods
    func setup() {
        startBluetoothMonitoring()
        print("✅ Bluetooth Manager Setup Complete")
    }
    
    func activateAlarm() {
        alarmEnabled = true
        startBluetoothMonitoring()
        startSilentAudio()
        beginBackgroundTask()
        print("✅ Bluetooth Alarm Activated")
    }
    
    func deactivateAlarm() {
        alarmEnabled = false
        stopAlarm()
        stopSilentAudio()
        stopBluetoothMonitoring()
        endBackgroundTask()
        print("✅ Bluetooth Alarm Deactivated")
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
    
    // MARK: - Bluetooth Monitoring
    private func startBluetoothMonitoring() {
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .background))
    }
    
    private func stopBluetoothMonitoring() {
        centralManager?.stopScan()
        centralManager = nil
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            print("✅ Bluetooth powered on, scanning started...")
            
            let connectedPeripherals = central.retrieveConnectedPeripherals(withServices: [])
            for peripheral in connectedPeripherals {
                print("🔗 Already connected: \(peripheral.name ?? "Unknown")")
                if alarmEnabled { playAlarm() }
                central.connect(peripheral, options: nil)
            }
            
        default:
            print("ℹ️ Bluetooth state changed: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheralCount += 1
        print("🔗 Device Connected: \(peripheral.name ?? "Unknown")")
        
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(self?.connectedPeripheralCount ?? 0 > 0)
        }
        
        if alarmEnabled { playAlarm() }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheralCount = max(connectedPeripheralCount - 1, 0)
        print("🔌 Device Disconnected: \(peripheral.name ?? "Unknown")")
        
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(self?.connectedPeripheralCount ?? 0 > 0)
        }
        
        if alarmEnabled { playAlarm() }
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
            print("🚨 Bluetooth Alarm Playing!")
        } catch {
            print("❌ Bluetooth alarm error: \(error)")
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

}

// MARK: - Bluetooth Status Stream Handler
class BluetoothStatusStreamHandler: NSObject, FlutterStreamHandler {
    private let manager: BluetoothAlarmManager
    
    init(manager: BluetoothAlarmManager) {
        self.manager = manager
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        manager.eventSink = events
        print("✅ Bluetooth EventChannel Listener Attached")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        manager.eventSink = nil
        print("✅ Bluetooth EventChannel Listener Detached")
        return nil
    }
}

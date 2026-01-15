import UIKit
import Flutter
import LocalAuthentication

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var wifiAlarmManager: WifiAlarmManager?
    private var bluetoothAlarmManager: BluetoothAlarmManager?
    private var chargerAlarmManager: ChargerAlarmManager?
    private var audioDetectorService: AudioDetectorService?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)
        
        let controller = window?.rootViewController as! FlutterViewController

        initializeWifiManager(controller: controller)
        initializeBluetoothManager(controller: controller)
        initializeChargerManager(controller: controller)
        initializeAudioDetector(controller: controller)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

   
    private func initializeWifiManager(controller: FlutterViewController) {
        let wifiMethodChannel = FlutterMethodChannel(
            name: "wifi.alarm/channel",
            binaryMessenger: controller.binaryMessenger
        )
        
        let wifiEventChannel = FlutterEventChannel(
            name: "wifi.alarm/status",
            binaryMessenger: controller.binaryMessenger
        )
        
        wifiAlarmManager = WifiAlarmManager(methodChannel: wifiMethodChannel, eventChannel: wifiEventChannel)
        wifiAlarmManager?.setup()
    }

    private func initializeBluetoothManager(controller: FlutterViewController) {
        let bluetoothMethodChannel = FlutterMethodChannel(
            name: "bluetooth.alarm/channel",
            binaryMessenger: controller.binaryMessenger
        )
        
        let bluetoothEventChannel = FlutterEventChannel(
            name: "bluetooth.alarm/status",
            binaryMessenger: controller.binaryMessenger
        )
        
        bluetoothAlarmManager = BluetoothAlarmManager(methodChannel: bluetoothMethodChannel, eventChannel: bluetoothEventChannel)
        bluetoothAlarmManager?.setup()
    }

    private func initializeChargerManager(controller: FlutterViewController) {
        let chargerMethodChannel = FlutterMethodChannel(
            name: "charger.alarm/channel",
            binaryMessenger: controller.binaryMessenger
        )
        
        let chargerEventChannel = FlutterEventChannel(
            name: "charger.alarm/status",
            binaryMessenger: controller.binaryMessenger
        )
        
        chargerAlarmManager = ChargerAlarmManager(methodChannel: chargerMethodChannel, eventChannel: chargerEventChannel)
        chargerAlarmManager?.setup()
    }

    private func initializeAudioDetector(controller: FlutterViewController) {
        let detectorChannel = FlutterMethodChannel(
            name: "com.clapwhistle.alarm/detector",
            binaryMessenger: controller.binaryMessenger
        )
        
        audioDetectorService = AudioDetectorService(methodChannel: detectorChannel)
        audioDetectorService?.startBackgroundDetection()
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        wifiAlarmManager?.handleBackground()
        bluetoothAlarmManager?.handleBackground()
        chargerAlarmManager?.handleBackground()
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        wifiAlarmManager?.handleForeground()
        bluetoothAlarmManager?.handleForeground()
        chargerAlarmManager?.handleForeground()
    }

    deinit {
        audioDetectorService?.stopBackgroundDetection()
    }
}

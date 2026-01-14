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
        initializeBiometricChannel(controller: controller)
        initializeCameraChannel(controller: controller)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func initializeBiometricChannel(controller: FlutterViewController) {
        let biometricChannel = FlutterMethodChannel(
            name: "com.example.biometric/authenticate",
            binaryMessenger: controller.binaryMessenger
        )
        
        biometricChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "authenticate":
                let reason = call.arguments as? String ?? "Authenticate to continue"
                BiometricHandler.shared.authenticate(reason: reason) { success in
                    result(success)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func initializeCameraChannel(controller: FlutterViewController) {
        let cameraChannel = FlutterMethodChannel(
            name: "com.example.camera/capture",
            binaryMessenger: controller.binaryMessenger
        )
        
        cameraChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "captureSelfie":
                NativeCameraHandler.shared.captureSelfieDirect { success in
                    result(success)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
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

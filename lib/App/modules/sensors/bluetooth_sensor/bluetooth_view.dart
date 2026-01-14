import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BluetoothAlarmPage extends StatefulWidget {
  const BluetoothAlarmPage({super.key});

  @override
  State<BluetoothAlarmPage> createState() => _BluetoothAlarmPageState();
}

class _BluetoothAlarmPageState extends State<BluetoothAlarmPage> {
  static const methodChannel = MethodChannel("bluetooth.alarm/channel");
  static const eventChannel = EventChannel("bluetooth.alarm/status");

  bool isDeviceConnected = false;
  bool isAlarmActive = false;
  StreamSubscription? _bluetoothSubscription;

  @override
  void initState() {
    super.initState();
    setupListeners();
    getInitialBluetoothStatus();
  }

  // Get initial Bluetooth status
  Future<void> getInitialBluetoothStatus() async {
    try {
      final bool status = await methodChannel.invokeMethod(
        "getBluetoothStatus",
      );
      setState(() {
        isDeviceConnected = status;
      });
    } on PlatformException catch (e) {
      debugPrint("Error getting Bluetooth status: ${e.message}");
    }
  }

  // Listen to Bluetooth status changes from native
  void setupListeners() {
    _bluetoothSubscription = eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        setState(() {
          isDeviceConnected = event as bool;
        });
        debugPrint("Bluetooth Status Updated: $isDeviceConnected");

        // Show in-app notification
        showCustomNotification(
          "Bluetooth Alert",
          event ? "Device Connected" : "Device Disconnected",
        );
      },
      onError: (dynamic error) {
        debugPrint("EventChannel Error: $error");
      },
    );
  }

  void showCustomNotification(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$title: $message"),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> toggleAlarm() async {
    try {
      if (isAlarmActive) {
        await methodChannel.invokeMethod("deactivateAlarm");
        setState(() {
          isAlarmActive = false;
        });
      } else {
        await methodChannel.invokeMethod("activateAlarm");
        setState(() {
          isAlarmActive = true;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Error toggling Bluetooth alarm: ${e.message}");
    }
  }

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bluetooth Anti-Theft Alarm"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              elevation: 6,
              color: isAlarmActive ? Colors.redAccent : Colors.green,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Icon(
                      isDeviceConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: Colors.white,
                      size: 60.sp,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isDeviceConnected
                          ? "Device Connected"
                          : "Device Disconnected",
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    ElevatedButton(
                      onPressed: toggleAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: isAlarmActive
                            ? Colors.redAccent
                            : Colors.green,
                        padding: EdgeInsets.symmetric(
                          horizontal: 50.w,
                          vertical: 15.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                      ),
                      child: Text(
                        isAlarmActive ? "DE-ACTIVATE" : "ACTIVATE",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30.h),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    "📱 Alarm Rule",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Alarm triggers when your Bluetooth device connects or disconnects, even in background.",
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

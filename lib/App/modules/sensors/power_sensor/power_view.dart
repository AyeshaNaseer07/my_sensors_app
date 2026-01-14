import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChargerAlarmPage extends StatefulWidget {
  const ChargerAlarmPage({super.key});

  @override
  State<ChargerAlarmPage> createState() => _ChargerAlarmPageState();
}

class _ChargerAlarmPageState extends State<ChargerAlarmPage> {
  static const methodChannel = MethodChannel('charger.alarm/channel');
  static const eventChannel = EventChannel('charger.alarm/status');

  bool isArmed = false;
  bool isDeviceCharging = true;
  StreamSubscription? _chargerSubscription;

  @override
  void initState() {
    super.initState();
    setupListeners();
    getInitialChargerStatus();
  }

  // Get initial charger status
  Future<void> getInitialChargerStatus() async {
    try {
      final bool status = await methodChannel.invokeMethod("getChargerStatus");
      setState(() {
        isDeviceCharging = status;
      });
    } on PlatformException catch (e) {
      debugPrint("Error getting charger status: ${e.message}");
    }
  }

  // Listen to charger status changes from native
  void setupListeners() {
    _chargerSubscription = eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final bool charging = event as bool;

        setState(() {
          isDeviceCharging = charging;
        });

        debugPrint("Charger Status Updated: $charging");

        // ✅ ONLY trigger when UNPLUGGED (isArmed && !charging)
        if (isArmed && !charging) {
          _triggerChargerAlarm();
        }
      },
      onError: (dynamic error) {
        debugPrint("EventChannel Error: $error");
      },
    );
  }

  void _triggerChargerAlarm() {
    showCustomNotification(
      "⚠️ Charger Unplugged!",
      "Your charger has been removed",
    );

    // Play alarm sound
    methodChannel.invokeMethod("armAlarm");
  }

  void showCustomNotification(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$title: $message"),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Toggle arm/disarm
  Future<void> toggleAlarm() async {
    try {
      if (isArmed) {
        await methodChannel.invokeMethod('disarmAlarm');
        setState(() {
          isArmed = false;
        });
      } else {
        await methodChannel.invokeMethod('armAlarm');
        setState(() {
          isArmed = true;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Error toggling charger alarm: ${e.message}");
    }
  }

  @override
  void dispose() {
    _chargerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Charger Alarm"),
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
              color: isArmed ? Colors.redAccent : Colors.green,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Icon(
                      isDeviceCharging
                          ? Icons.battery_charging_full
                          : Icons.battery_alert,
                      color: Colors.white,
                      size: 60.sp,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isDeviceCharging ? "Charging" : "Not Charging",
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
                        foregroundColor: isArmed
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
                        isArmed ? "DE-ACTIVATE" : "ACTIVATE",
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
                    "Get alerted immediately if your phone charger is unplugged.",
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

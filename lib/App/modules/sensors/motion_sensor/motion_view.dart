import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:ui_design/App/service/alarm_service.dart';

class MotionSensorView extends StatefulWidget {
  const MotionSensorView({super.key});

  @override
  State<MotionSensorView> createState() => _MotionSensorViewState();
}

class _MotionSensorViewState extends State<MotionSensorView> {
  late StreamSubscription accelSub;
  static const iosAlarmChannel = MethodChannel("ios_alarm");

  bool isArmed = false;
  bool alarmTriggered = false;

  double x = 0.0, y = 0.0, z = 0.0;
  double baseX = 0.0, baseY = 0.0, baseZ = 0.0;

  final double thresholdX = 10.0;
  final double thresholdY = 10.0;
  final double thresholdZ = 10.0;

  @override
  void initState() {
    super.initState();
    AlarmService();

    // iOS background motion trigger listener
    iosAlarmChannel.setMethodCallHandler((call) async {
      if (call.method == "motionDetected") {
        setState(() {
          alarmTriggered = true;
        });
        AlarmService().playAlarm();
      }
    });

    // Local accelerometer listener only for UI updates when screen ON

    // ignore: deprecated_member_use
    accelSub = accelerometerEvents.listen((event) {
      setState(() {
        x = event.x;
        y = event.y;
        z = event.z;
      });

      if (!isArmed || alarmTriggered) return;

      double dx = (x - baseX).abs();
      double dy = (y - baseY).abs();
      double dz = (z - baseZ).abs();

      if (dx > thresholdX || dy > thresholdY || dz > thresholdZ) {
        alarmTriggered = true;
        AlarmService().playAlarm();
      }
    });
  }

  void toggleAlarm() async {
    setState(() {
      isArmed = !isArmed;
      alarmTriggered = false;
    });

    if (isArmed) {
      baseX = x;
      baseY = y;
      baseZ = z;

      // Call iOS to start background audio + motion monitoring
      await iosAlarmChannel.invokeMethod("startAlarmService");
    } else {
      AlarmService().stopAlarm();
      await iosAlarmChannel.invokeMethod("stopAlarmService");
    }
  }

  @override
  void dispose() {
    accelSub.cancel();
    iosAlarmChannel.invokeMethod("stopAlarmService");
    AlarmService().stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Motion Sensor Anti Theft Alarm"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
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
                      isArmed ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 60,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isArmed
                          ? (alarmTriggered
                                ? "ALARM TRIGGERED!"
                                : "ALARM ACTIVATED")
                          : "ALARM DEACTIVATED",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    ElevatedButton(
                      onPressed: toggleAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        isArmed ? "DE-ACTIVATE" : "ACTIVATE",
                        style: TextStyle(
                          color: isArmed ? Colors.redAccent : Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40.h),
            const Text(
              "Motion Sensor Values",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: axisTile("X", x, thresholdX, Colors.blue)),
                Expanded(child: axisTile("Y", y, thresholdY, Colors.green)),
                Expanded(child: axisTile("Z", z, thresholdZ, Colors.red)),
              ],
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
                    "Arm the alarm and keep your phone in pocket. Motion above thresholds will trigger alarm.",
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

  Widget axisTile(String axis, double value, double threshold, Color color) {
    return Column(
      children: [
        Text(axis),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(fontSize: 18, color: color),
        ),
        Text(
          "Threshold: $threshold",
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }
}

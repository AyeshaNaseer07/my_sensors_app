import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:headphones_detection/headphones_detection.dart';
import 'package:ui_design/App/service/alarm_service.dart';

class HeadphoneSensorPage extends StatefulWidget {
  const HeadphoneSensorPage({super.key});

  @override
  State<HeadphoneSensorPage> createState() => _HeadphoneSensorPageState();
}

class _HeadphoneSensorPageState extends State<HeadphoneSensorPage> {
  bool headphonesConnected = false;
  bool isArmed = false;
  bool alarmTriggered = false;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    AlarmService();
    _startPollingHeadphones();
  }

  void _startPollingHeadphones() async {
    // Check initial state
    try {
      headphonesConnected = await HeadphonesDetection.isHeadphonesConnected();
      setState(() {});
    } catch (e) {
      debugPrint("Headphones detection error: $e");
    }

    // Poll every 500ms
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        bool isConnected = await HeadphonesDetection.isHeadphonesConnected();
        if (isConnected != headphonesConnected) {
          // State changed: plug/unplug
          setState(() => headphonesConnected = isConnected);

          if (isArmed && !alarmTriggered) {
            alarmTriggered = true;
            AlarmService().playAlarm();
          }
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  void toggleAlarm() {
    setState(() {
      isArmed = !isArmed;

      if (!isArmed) {
        AlarmService().stopAlarm();
        alarmTriggered = false;
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    AlarmService().stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Headphone Sensor")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              headphonesConnected ? Icons.headphones : Icons.headset_off,
              size: 100.sp,
              color: headphonesConnected ? Colors.blue : Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              "Status: ${headphonesConnected ? "Connected" : "Disconnected"}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              elevation: 6,
              color: isArmed ? Colors.redAccent : Colors.blueAccent,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: [
                    Icon(
                      isArmed ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 60.sp,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isArmed ? "ALARM ARMED" : "ALARM DISARMED",
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
                          color: isArmed ? Colors.redAccent : Colors.blueAccent,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),
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
                    "The alarm will trigger only when the headphones are plugged in or plugged out.",
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

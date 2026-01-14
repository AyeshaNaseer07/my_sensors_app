import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:ui_design/App/service/alarm_service.dart';

class ProximitySensorView extends StatefulWidget {
  const ProximitySensorView({super.key});

  @override
  State<ProximitySensorView> createState() => _ProximitySensorViewState();
}

class _ProximitySensorViewState extends State<ProximitySensorView> {
  bool isArmed = false; // <- must be declared here
  bool isNear = false;
  bool alarmTriggered = false;

  StreamSubscription<int>? _proximitySub;

  @override
  void initState() {
    super.initState();
    // Initialize the alarm service
    AlarmService().init();
    _startProximityListener();
  }

  void _startProximityListener() {
    _proximitySub = ProximitySensor.events.listen((int event) {
      bool near = (event > 0);

      if (!isArmed) return; // only react if armed

      setState(() => isNear = near);

      // Trigger alarm only once
      if (near && !alarmTriggered) {
        AlarmService().playAlarm();
        alarmTriggered = true; // alarm is now triggered
      }

      // DO NOT stop alarm when far
      // Previously: else { AlarmService().stopAlarm(); }
    });
  }

  void toggleAlarm() {
    setState(() => isArmed = !isArmed);

    if (!isArmed) {
      // Stop alarm and reset trigger
      AlarmService().stopAlarm();
      alarmTriggered = false;
    }
  }

  @override
  void dispose() {
    _proximitySub?.cancel();
    AlarmService().stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pocket Theft Alarm"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                      isArmed ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 60.sp,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isArmed ? "ALARM ACTIVATED" : "ALARM DEACTIVATED",
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
                          color: isArmed ? Colors.redAccent : Colors.green,
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
                    "Save your phone from pickpockets as soon as someone tries to steal it.",
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

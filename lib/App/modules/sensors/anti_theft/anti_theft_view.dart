import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';
import 'package:ui_design/App/service/alarm_service.dart';
import 'package:ui_design/App/modules/selfie_click/lock_screen_view.dart';

class AntiTheftView extends StatefulWidget {
  const AntiTheftView({super.key});

  @override
  State<AntiTheftView> createState() => _AntiTheftViewState();
}

class _AntiTheftViewState extends State<AntiTheftView> {
  // Common flags
  bool isArmed = false;
  bool alarmTriggered = false;
  bool _isLoading = false;

  // Proximity sensor
  bool isNear = false;
  StreamSubscription<int>? _proximitySub;

  // Motion sensor
  late StreamSubscription _accelSub;
  double x = 0.0, y = 0.0, z = 0.0;
  double baseX = 0.0, baseY = 0.0, baseZ = 0.0;

  final double thresholdX = 10.0;
  final double thresholdY = 10.0;
  final double thresholdZ = 10.0;

  // iOS background motion channel
  static const iosAlarmChannel = MethodChannel("ios_alarm");

  @override
  void initState() {
    super.initState();
    AlarmService();

    iosAlarmChannel.setMethodCallHandler((call) async {
      if (call.method == "motionDetected" && isArmed && !alarmTriggered) {
        _triggerAlarm();
      }
    });

    // Proximity sensor listener
    _startProximityListener();

    // Local accelerometer listener for foreground motion detection
    // ignore: deprecated_member_use
    _accelSub = accelerometerEvents.listen((event) {
      x = event.x;
      y = event.y;
      z = event.z;

      if (!isArmed || alarmTriggered) return;

      double dx = (x - baseX).abs();
      double dy = (y - baseY).abs();
      double dz = (z - baseZ).abs();

      if (dx > thresholdX || dy > thresholdY || dz > thresholdZ) {
        _triggerAlarm();
      }
      setState(() {});
    });
  }

  void _startProximityListener() {
    _proximitySub = ProximitySensor.events.listen((event) {
      if (!isArmed) return;
      isNear = event > 0;
      if (isNear && !alarmTriggered) {
        _triggerAlarm();
      }
      setState(() {});
    });
  }

  void _triggerAlarm() {
    alarmTriggered = true;
    AlarmService().playAlarm();
    setState(() {});
  }

  Future<void> _activateAlarm() async {
    try {
      debugPrint("🔓 Activating anti-theft alarm (no auth required)...");

      setState(() {
        _isLoading = true;
      });

      // Set motion base values
      baseX = x;
      baseY = y;
      baseZ = z;

      // Start iOS background service with timeout
      try {
        await iosAlarmChannel
            .invokeMethod("startAlarmService")
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint(
                  "⚠️ iOS method timeout, but continuing with local activation",
                );
                return null;
              },
            );
      } catch (e) {
        debugPrint("⚠️ iOS method error: $e, but continuing");
      }

      if (mounted) {
        setState(() {
          isArmed = true;
          alarmTriggered = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error activating alarm: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _deactivateAlarm() async {
    try {
      debugPrint("🔐 Deactivating anti-theft alarm (requires auth)...");

      if (!mounted) return;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => LockScreen(
          isDeactivationMode: true,
          onUnlock: () {
            debugPrint("✅ onUnlock callback triggered");
          },
        ),
      );

      if (!mounted) return;

      if (result == true) {
        debugPrint("🔓 Auth successful - deactivating anti-theft alarm");

        setState(() {
          _isLoading = true;
        });

        try {
          // Stop alarm
          AlarmService().stopAlarm();

          // Stop iOS service with timeout
          try {
            await iosAlarmChannel
                .invokeMethod("stopAlarmService")
                .timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    debugPrint(
                      "⚠️ iOS method timeout, but continuing with deactivation",
                    );
                    return null;
                  },
                );
          } catch (e) {
            debugPrint("⚠️ iOS method error: $e, but continuing");
          }

          if (!mounted) return;

          setState(() {
            isArmed = false;
            alarmTriggered = false;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Anti-theft alarm deactivated successfully"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          debugPrint("❌ Error: $e");

          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } else {
        debugPrint("❌ Auth failed / dialog dismissed");
      }
    } catch (e, stack) {
      debugPrint("💥 Error in deactivation flow: $e");
      debugPrint("$stack");

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _proximitySub?.cancel();
    _accelSub.cancel();
    AlarmService().stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Anti-theft Sensor"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Alarm Card
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
                                : "ALARM ACTIVATED ")
                          : "ALARM DEACTIVATED",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (isArmed ? _deactivateAlarm : _activateAlarm),
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
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  isArmed ? Colors.redAccent : Colors.green,
                                ),
                              ),
                            )
                          : Text(
                              isArmed ? "DE-ACTIVATE" : "ACTIVATE",
                              style: TextStyle(
                                color: isArmed
                                    ? Colors.redAccent
                                    : Colors.green,
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

            // Motion Sensor Display
            const Text(
              "Motion Sensor Values",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _axisTile("X", x, thresholdX, Colors.blue),
                _axisTile("Y", y, thresholdY, Colors.green),
                _axisTile("Z", z, thresholdZ, Colors.red),
              ],
            ),
            SizedBox(height: 40.h),
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
                    "📱 Alarm Rules",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    " Proximity: Move hand near sensor when screen is on → Alarm triggers."
                    "\n"
                    " Motion: Keep phone in pocket or on table. Sudden movement triggers alarm when screen is on and locked both.",
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

  Widget _axisTile(String axis, double value, double threshold, Color color) {
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

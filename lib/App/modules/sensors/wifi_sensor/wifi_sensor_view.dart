import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ui_design/App/modules/selfie_click/lock_screen_view.dart';

class WifiAlarmPage extends StatefulWidget {
  const WifiAlarmPage({super.key});

  @override
  State<WifiAlarmPage> createState() => _WifiAlarmPageState();
}

class _WifiAlarmPageState extends State<WifiAlarmPage> {
  static const methodChannel = MethodChannel("wifi.alarm/channel");
  static const eventChannel = EventChannel("wifi.alarm/status");

  bool isConnected = false;
  bool isAlarmPlaying = false;
  bool isArmed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    setupListeners();
    getInitialWifiStatus();
  }

  Future<void> getInitialWifiStatus() async {
    try {
      final bool status = await methodChannel.invokeMethod("getWifiStatus");
      if (mounted) {
        setState(() {
          isConnected = status;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Error getting WiFi status: ${e.message}");
    }
  }

  void setupListeners() {
    eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (mounted) {
          setState(() {
            isConnected = event as bool;
          });
        }
        debugPrint("WiFi Status Updated: $isConnected");
      },
      onError: (dynamic error) {
        debugPrint("EventChannel Error: $error");
      },
    );
  }

  Future<void> _activateAlarm() async {
    try {
      debugPrint("🔓 Activating alarm (no auth required)...");

      setState(() {
        _isLoading = true;
      });

      await methodChannel.invokeMethod("activateAlarm");

      if (mounted) {
        setState(() {
          isArmed = true;
          isAlarmPlaying = true;
          _isLoading = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Error activating alarm: ${e.message}");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
      }
    }
  }

  Future<void> _deactivateAlarm() async {
    try {
      debugPrint("🔐 Deactivating alarm (requires auth)...");

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
        debugPrint("🔓 Auth successful - deactivating alarm");

        setState(() {
          _isLoading = true;
        });

        try {
          await methodChannel.invokeMethod("deactivateAlarm");

          if (!mounted) return;

          setState(() {
            isArmed = false;
            isAlarmPlaying = false;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Alarm deactivated successfully"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } on PlatformException catch (e) {
          debugPrint("❌ Native error: ${e.message}");

          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wi-Fi Sensor Alarm"),
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
              color: isAlarmPlaying ? Colors.redAccent : Colors.green,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 60.sp,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isConnected ? "Wi-Fi Connected" : "Wi-Fi Disconnected",
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 30.h),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (isArmed ? _deactivateAlarm : _activateAlarm),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 4,
                        padding: EdgeInsets.symmetric(
                          horizontal: 50.w,
                          vertical: 15.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20.h,
                              width: 20.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  isArmed ? Colors.redAccent : Colors.green,
                                ),
                              ),
                            )
                          : Text(
                              isArmed ? "🔐 DEACTIVATE" : "🔓 ACTIVATE",
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: isArmed
                                    ? Colors.redAccent
                                    : Colors.green,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
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
                    "✅ Activation: No authentication required\n"
                    "\n"
                    "🔐 Deactivation: Requires biometric/passcode",
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

  @override
  void dispose() {
    super.dispose();
  }
}

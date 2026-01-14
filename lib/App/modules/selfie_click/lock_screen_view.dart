import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback? onUnlock;
  final bool isDeactivationMode;
  final int initialFailedAttempts;
  final DateTime? initialLockedUntil;

  const LockScreen({
    super.key,
    this.onUnlock,
    this.isDeactivationMode = false,
    this.initialFailedAttempts = 0,
    this.initialLockedUntil,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const biometricChannel = MethodChannel(
    'com.example.biometric/authenticate',
  );
  static const cameraChannel = MethodChannel('com.example.camera/capture');

  bool _isAuthenticating = false;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  final int LOCK_DURATION_MINUTES = 1;
  final int MAX_FAILED_ATTEMPTS = 1;

  @override
  void initState() {
    super.initState();
    // Initialize from parent state if provided
    _failedAttempts = widget.initialFailedAttempts;
    _lockedUntil = widget.initialLockedUntil;

    // Auto-trigger auth in deactivation mode
    if (widget.isDeactivationMode) {
      Future.delayed(const Duration(milliseconds: 500), _authenticateUser);
    }
  }

  Future<void> _authenticateUser() async {
    // Check if locked
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      _showLockedDialog();
      return;
    }

    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final String reason = widget.isDeactivationMode
          ? 'Authenticate to deactivate alarm'
          : 'Unlock your app';

      debugPrint('📱 Calling native biometric...');

      final bool authenticated =
          await biometricChannel.invokeMethod<bool>('authenticate', reason) ??
          false;

      if (!mounted) return;

      debugPrint('✅ Auth result: $authenticated');

      if (authenticated) {
        _failedAttempts = 0;
        _lockedUntil = null;

        // ✅ Capture selfie in BACKGROUND (don't block UI)
        if (widget.isDeactivationMode) {
          debugPrint('📸 RIGHT ATTEMPT - Capturing selfie (background)...');
          _captureTestSelfie(); // ⬅️ NO await - runs in background silently
        }

        // Call onUnlock callback IMMEDIATELY
        if (widget.onUnlock != null) {
          widget.onUnlock!();
        }

        // Pop dialog IMMEDIATELY (don't wait for camera)
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // Authentication failed
        _failedAttempts++;
        debugPrint('❌ Failed attempt $_failedAttempts/$MAX_FAILED_ATTEMPTS');

        if (!mounted) return;

        // ✅ FIX: Capture unauthorized selfie in BACKGROUND
        _captureUnauthorizedSelfie(); // ⬅️ NO await

        // Check if max attempts reached
        if (_failedAttempts >= MAX_FAILED_ATTEMPTS) {
          debugPrint(
            '🔒 Max attempts reached. Locking for $LOCK_DURATION_MINUTES minutes...',
          );
          _lockedUntil = DateTime.now().add(
            Duration(minutes: LOCK_DURATION_MINUTES),
          );
          _showLockedDialog();
        } else {
          // Show remaining attempts
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed. ${MAX_FAILED_ATTEMPTS - _failedAttempts} attempts remaining',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showLockedDialog() {
    final remainingTime = _lockedUntil!.difference(DateTime.now());
    final minutes = remainingTime.inMinutes;
    final seconds = remainingTime.inSeconds % 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔒 App Locked'),
        content: Text(
          'Too many failed attempts.\n\n'
          'Try again in: $minutes:${seconds.toString().padLeft(2, '0')} minutes',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Background unauthorized capture (no await needed)
  Future<void> _captureUnauthorizedSelfie() async {
    try {
      debugPrint('🎥 Capturing unauthorized selfie (background)...');
      await cameraChannel.invokeMethod<bool>('captureSelfie');
      debugPrint('✅ Unauthorized selfie captured in background');
    } catch (e) {
      debugPrint('❌ Unauthorized capture error: $e');
    }
  }

  // Background selfie capture on right attempt (no await needed)
  Future<void> _captureTestSelfie() async {
    try {
      debugPrint('🎥 Capturing selfie (background)...');
      await cameraChannel.invokeMethod<bool>('captureSelfie');
      debugPrint('✅ Selfie captured in background');
    } catch (e) {
      debugPrint('❌ Capture error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        return !widget.isDeactivationMode;
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade900,
                const Color.fromARGB(255, 101, 164, 219),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.white),
                const SizedBox(height: 30),
                const Text(
                  'Authentication Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.isDeactivationMode
                      ? 'Authenticate to deactivate alarm'
                      : 'Unlock your app',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 50),
                if (_isAuthenticating)
                  Column(
                    children: const [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        'Authenticating...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _authenticateUser,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Authenticate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                        ),
                      ),
                      if (_failedAttempts > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Failed: $_failedAttempts/$MAX_FAILED_ATTEMPTS\n'
                              'Remaining: ${MAX_FAILED_ATTEMPTS - _failedAttempts}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (!widget.isDeactivationMode)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockTimer;

  // ignore: non_constant_identifier_names
  final int LOCK_DURATION_MINUTES = 1;
  // ignore: non_constant_identifier_names
  final int MAX_FAILED_ATTEMPTS = 3;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      _authenticateUser();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _authenticateUser() async {
    // Check agar locked hai
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      _showLockedDialog();
      return;
    }

    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      print('═══════════════════════════════════════');
      print('🔴 ATTEMPT ${_failedAttempts + 1}/$MAX_FAILED_ATTEMPTS');
      print('═══════════════════════════════════════');
      print('📱 Starting Face ID...');

      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your app using biometric',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        // ✅ Success - authorized person unlocked
        print('✅✅✅ AUTHORIZED - UNLOCKING APP ✅✅✅');
        if (mounted) {
          _failedAttempts = 0;
          _lockedUntil = null;
          _lockTimer?.cancel();
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // ❌ Face ID failed - capture selfie
        print('❌ UNAUTHORIZED - Face ID failed');
        print('🎥 Capturing selfie...');
        await _captureUnauthorizedSelfie();
        _failedAttempts++;

        print('✅ Selfie #$_failedAttempts captured');
        print('❌ Failed attempts: $_failedAttempts/$MAX_FAILED_ATTEMPTS');
        print('═══════════════════════════════════════');

        if (_failedAttempts >= MAX_FAILED_ATTEMPTS) {
          print('🔒 MAX ATTEMPTS REACHED - APP LOCKED');
          _lockedUntil = DateTime.now().add(
            Duration(minutes: LOCK_DURATION_MINUTES),
          );
          _showLockedDialog();
          _startLockTimer();
        } else {
          if (mounted) {
            setState(() {
              _isAuthenticating = false;
            });
          }
        }
      }
    } catch (e) {
      // ✅ Exception means Face ID failed (UserCancelled, etc)
      print('❌ Auth error: $e');
      print('🎥 Capturing selfie...');
      await _captureUnauthorizedSelfie();
      _failedAttempts++;

      print('✅ Selfie #$_failedAttempts captured');
      print('❌ Failed attempts: $_failedAttempts/$MAX_FAILED_ATTEMPTS');

      if (_failedAttempts >= MAX_FAILED_ATTEMPTS) {
        print('🔒 MAX ATTEMPTS REACHED - APP LOCKED');
        _lockedUntil = DateTime.now().add(
          Duration(minutes: LOCK_DURATION_MINUTES),
        );
        _showLockedDialog();
        _startLockTimer();
      } else {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
      }
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_lockedUntil != null && DateTime.now().isAfter(_lockedUntil!)) {
        _lockTimer?.cancel();
        setState(() {
          _failedAttempts = 0;
          _lockedUntil = null;
        });
        // ✅ Close dialog
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
        // ✅ FIXED: Call authenticate again
        if (mounted) {
          _authenticateUser();
        }
      } else {
        setState(() {});
      }
    });
  }

  void _showLockedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('🔒 App Locked'),
            content: _buildLockedContent(setDialogState),
            actions: [
              TextButton(
                onPressed: () {
                  final remainingTime = _lockedUntil!.difference(
                    DateTime.now(),
                  );
                  if (remainingTime.inSeconds <= 0) {
                    // ✅ Time finished - allow retry
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {
                        _failedAttempts = 0;
                        _lockedUntil = null;
                        _lockTimer?.cancel();
                      });
                      _authenticateUser();
                    }
                  } else {
                    // ❌ Still locked
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Still locked. Try again in ${remainingTime.inSeconds} seconds',
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Try Again'),
              ),
              TextButton(onPressed: () {}, child: const Text('OK')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLockedContent(Function setDialogState) {
    // ✅ Update countdown every second
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _lockedUntil != null) {
        setDialogState(() {});
      }
    });

    final currentRemaining = _lockedUntil!.difference(DateTime.now());
    final mins = currentRemaining.inMinutes;
    final secs = currentRemaining.inSeconds % 60;

    return Text(
      'Too many failed attempts.\n\n'
      'Try again in: $mins:${secs.toString().padLeft(2, '0')} minutes',
      style: const TextStyle(fontSize: 16),
    );
  }

  Future<void> _captureUnauthorizedSelfie() async {
    print('🎥 Starting selfie capture...');
    CameraController? cameraController;

    try {
      // Step 1: Request camera permission
      print('📱 Requesting camera permission...');
      final status = await Permission.camera.request();
      print('Permission status: $status');

      if (!status.isGranted) {
        print('❌ Camera permission NOT granted');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Camera permission denied!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      print('✅ Camera permission granted');

      // Step 2: Get available cameras
      print('📷 Getting available cameras...');
      final cameras = await availableCameras();
      print('Available cameras: ${cameras.length}');

      if (cameras.isEmpty) {
        print('❌ No cameras available');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      print('✅ Front camera found');

      // Step 3: Initialize camera
      print('🔧 Initializing camera...');
      cameraController = CameraController(frontCamera, ResolutionPreset.high);

      await cameraController.initialize();
      print('✅ Camera initialized successfully');

      // Step 4: Wait and capture
      print('⏳ Waiting 2 seconds before capture...');
      await Future.delayed(Duration(seconds: 2));

      print('📸 Taking picture...');
      final XFile image = await cameraController.takePicture();
      print('✅ Picture taken: ${image.path}');

      // Step 5: Save the image
      await _saveUnauthorizedAttempt(File(image.path));
      print('✅ Selfie capture complete!');
    } catch (e) {
      print('❌ Capture error: $e');
    } finally {
      // Step 6: Dispose camera
      if (cameraController != null) {
        try {
          await cameraController.dispose();
          print('✅ Camera disposed');
        } catch (e) {
          print('Error disposing camera: $e');
        }
      }
    }
  }

  Future<void> _saveUnauthorizedAttempt(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'unauthorized_$timestamp.jpg';
      final dirPath = '${appDir.path}/unauthorized_attempts';
      final filePath = '$dirPath/$fileName';

      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      await imageFile.copy(filePath);
      print('✅ Selfie saved: $filePath');
    } catch (e) {
      print('❌ Error saving: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.white),
              SizedBox(height: 30),
              Text(
                'MyGetX App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Unlock with Face ID',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              SizedBox(height: 50),
              if (_isAuthenticating)
                Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'Authenticating...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _authenticateUser,
                      icon: Icon(Icons.fingerprint),
                      label: Text('Unlock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    if (_failedAttempts > 0)
                      Text(
                        'Failed attempts: $_failedAttempts/$MAX_FAILED_ATTEMPTS',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/attempts');
                      },
                      child: Text(
                        'View Unauthorized Attempts',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

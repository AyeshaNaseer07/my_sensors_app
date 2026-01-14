import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioDetector {
  static const MethodChannel _channel = MethodChannel(
    'com.clapwhistle.alarm/detector',
  );

  bool _isListening = false;
  // ignore: unused_field
  double _sensitivity = 0.5;

  Function()? onClapDetected;
  Function()? onWhistleDetected;

  AudioDetector() {
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onClapDetected':
          debugPrint('👏 Clap detected from native iOS!');
          onClapDetected?.call();
          break;
        case 'onWhistleDetected':
          debugPrint('🎵 Whistle detected from native iOS!');
          onWhistleDetected?.call();
          break;
      }
    });
  }

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      debugPrint("Mic permission: $status"); // now "granted" display

      // for DEBUG paste here
      debugPrint("Mic permission: $status");

      return status.isGranted;
    } catch (e) {
      log("error while request permission for microphone $e");

      return true;
    }
  }

  Future<void> startListening(double sensitivity) async {
    if (_isListening) return;

    _sensitivity = sensitivity;

    try {
      final result = await _channel.invokeMethod('startBackgroundDetection', {
        'sensitivity': sensitivity,
      });

      if (result == true) {
        _isListening = true;
        debugPrint('✅ Background detection started (Native iOS)');
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to start detection: ${e.message}');
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _channel.invokeMethod('stopBackgroundDetection');
      _isListening = false;
      debugPrint('✅ Background detection stopped');
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to stop detection: ${e.message}');
    }
  }

  Future<void> updateSensitivity(double sensitivity) async {
    _sensitivity = sensitivity;

    if (_isListening) {
      try {
        await _channel.invokeMethod('updateSensitivity', {
          'sensitivity': sensitivity,
        });
        debugPrint('✅ Sensitivity updated: ${(sensitivity * 100).round()}%');
      } on PlatformException catch (e) {
        debugPrint('❌ Failed to update sensitivity: ${e.message}');
      }
    }
  }

  bool get isListening => _isListening;

  void dispose() {
    stopListening();
  }
}

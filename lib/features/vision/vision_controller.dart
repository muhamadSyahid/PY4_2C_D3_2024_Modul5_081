import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dto/detection_result.dart';

class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  bool isInitialized = false;
  bool isInitializing = true;
  bool isOverlayEnabled = true;
  bool isTorchOn = false;
  bool hasCameraAccessIssue = false;
  String? errorMessage;
  List<DetectionResult> _currentResults = const [];
  final ValueNotifier<List<DetectionResult>> resultsNotifier =
      ValueNotifier<List<DetectionResult>>(const []);
  Timer? _mockAnimationTimer;
  final Random _random = Random();
  bool _isDisposed = false;
  Offset _displayCenter = const Offset(0.5, 0.5);
  Offset _targetCenter = const Offset(0.5, 0.5);
  double _displayScore = 0.82;
  double _targetScore = 0.9;
  double _displayWidthFactor = 0.22;
  double _displayHeightFactor = 0.22;
  double _targetWidthFactor = 0.22;
  double _targetHeightFactor = 0.22;
  String _displayLabel = 'D40 POTHOLE';
  String _targetLabel = 'D40 POTHOLE';
  DateTime _lastTargetUpdate = DateTime.now();

  List<DetectionResult> get currentResults => _currentResults;

  VisionController() {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    if (_isDisposed) {
      return;
    }

    isInitializing = true;
    hasCameraAccessIssue = false;
    errorMessage = null;
    notifyListeners();

    try {
      final PermissionStatus permissionStatus =
          await Permission.camera.request();
      if (!permissionStatus.isGranted) {
        isInitialized = false;
        isTorchOn = false;
        isInitializing = false;
        hasCameraAccessIssue = true;
        errorMessage = permissionStatus.isPermanentlyDenied
            ? 'No Camera Access. Permission is permanently denied.'
            : 'No Camera Access. Camera permission is required to start vision.';
        notifyListeners();
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        isInitialized = false;
        isTorchOn = false;
        isInitializing = false;
        hasCameraAccessIssue = true;
        errorMessage = 'No camera detected on device.';
        notifyListeners();
        return;
      }

      await _releaseCamera(permanent: false);

      controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();
      await controller!.setFlashMode(FlashMode.off);
      isInitialized = true;
      isTorchOn = false;
      isInitializing = false;
      errorMessage = null;
      _startMockDetection();
    } catch (e) {
      isInitialized = false;
      isTorchOn = false;
      isInitializing = false;
      hasCameraAccessIssue = true;
      errorMessage = 'Failed to initialize camera: $e';
    }
    notifyListeners();
  }

  Future<void> toggleTorch() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    try {
      final bool nextState = !isTorchOn;
      await cameraController
          .setFlashMode(nextState ? FlashMode.torch : FlashMode.off);
      isTorchOn = nextState;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to change torch mode: $e';
      notifyListeners();
    }
  }

  void toggleOverlay() {
    isOverlayEnabled = !isOverlayEnabled;
    notifyListeners();
  }

  Future<void> openPermissionSettings() async {
    await openAppSettings();
  }

  static const Duration _mockDetectionInterval = Duration(seconds: 3);
  static const Duration _mockAnimationFrame = Duration(milliseconds: 16);
  static const double _trackingSmoothing = 0.25;
  static const double _maxStepPerFrame = 0.03;

  void _startMockDetection() {
    _mockAnimationTimer?.cancel();

    _displayCenter = _nextCenter();
    _targetCenter =
        _nextCenter(around: _displayCenter, dxMax: 0.18, dyMax: 0.16);
    _displayScore = _nextScore();
    _targetScore = _nextScore();
    _displayLabel = 'D40 POTHOLE';
    _targetLabel = _displayLabel;
    _displayWidthFactor = 0.22;
    _displayHeightFactor = 0.22;
    _targetWidthFactor = _displayWidthFactor;
    _targetHeightFactor = _displayHeightFactor;
    _lastTargetUpdate = DateTime.now();

    _updateAnimatedDetection(DateTime.now());
    _mockAnimationTimer = Timer.periodic(_mockAnimationFrame, (_) {
      _updateAnimatedDetection(DateTime.now());
    });
  }

  Offset _nextCenter(
      {Offset? around, double dxMax = 0.1, double dyMax = 0.08}) {
    if (around == null) {
      final double centerX = 0.2 + _random.nextDouble() * 0.6;
      final double centerY = 0.24 + _random.nextDouble() * 0.52;
      return Offset(centerX, centerY);
    }

    final double nextX =
        (around.dx + ((_random.nextDouble() * 2) - 1) * dxMax).clamp(0.2, 0.8);
    final double nextY = (around.dy + ((_random.nextDouble() * 2) - 1) * dyMax)
        .clamp(0.24, 0.76);
    return Offset(nextX, nextY);
  }

  double _nextScore() {
    return 0.72 + _random.nextDouble() * 0.24;
  }

  void _simulateDetectionTick() {
    final bool isCrack = _random.nextBool();

    // Simulated RDD-2022 classes for road-surface damage only.
    _targetLabel = isCrack ? 'D00 LONGITUDINAL CRACK' : 'D40 POTHOLE';
    _targetCenter =
        _nextCenter(around: _targetCenter, dxMax: 0.18, dyMax: 0.16);

    if (isCrack) {
      _targetWidthFactor = 0.13;
      _targetHeightFactor = 0.36;
    } else {
      _targetWidthFactor = 0.22;
      _targetHeightFactor = 0.24;
    }

    _targetScore = _nextScore();
  }

  void _updateAnimatedDetection(DateTime now) {
    if (_isDisposed) {
      return;
    }

    final Duration elapsedSinceTarget = now.difference(_lastTargetUpdate);
    if (elapsedSinceTarget >= _mockDetectionInterval) {
      _simulateDetectionTick();
      _lastTargetUpdate = now;

      debugPrint(
        'Mock detection scaling -> label=$_targetLabel, center=(${_targetCenter.dx.toStringAsFixed(2)}, ${_targetCenter.dy.toStringAsFixed(2)}), '
        'widthFactor=${_targetWidthFactor.toStringAsFixed(2)}, heightFactor=${_targetHeightFactor.toStringAsFixed(2)}, '
        'score=${_targetScore.toStringAsFixed(2)}',
      );
    }

    final double dx =
        (_targetCenter.dx - _displayCenter.dx) * _trackingSmoothing;
    final double dy =
        (_targetCenter.dy - _displayCenter.dy) * _trackingSmoothing;
    final double clampedDx = dx.clamp(-_maxStepPerFrame, _maxStepPerFrame);
    final double clampedDy = dy.clamp(-_maxStepPerFrame, _maxStepPerFrame);
    _displayCenter = Offset(
      (_displayCenter.dx + clampedDx).clamp(0.2, 0.8),
      (_displayCenter.dy + clampedDy).clamp(0.24, 0.76),
    );

    _displayScore = _displayScore + (_targetScore - _displayScore) * 0.22;
    _displayWidthFactor =
        _displayWidthFactor + (_targetWidthFactor - _displayWidthFactor) * 0.22;
    _displayHeightFactor = _displayHeightFactor +
        (_targetHeightFactor - _displayHeightFactor) * 0.22;
    _displayLabel = _targetLabel;

    _currentResults = [
      DetectionResult(
        normalizedCenter: _displayCenter,
        normalizedWidth: _displayWidthFactor,
        normalizedHeight: _displayHeightFactor,
        label: _displayLabel,
        score: _displayScore,
      ),
    ];
    resultsNotifier.value = _currentResults;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_releaseCamera(permanent: false));
    } else if (state == AppLifecycleState.resumed && !_isDisposed) {
      initCamera();
    }
  }

  Future<void> _releaseCamera({required bool permanent}) async {
    _mockAnimationTimer?.cancel();
    _mockAnimationTimer = null;
    isTorchOn = false;
    _currentResults = const [];
    resultsNotifier.value = const [];

    final CameraController? cameraController = controller;
    controller = null;
    isInitialized = false;
    isInitializing = false;

    if (permanent) {
      _isDisposed = true;
    }

    if (cameraController == null) {
      return;
    }

    try {
      if (cameraController.value.isStreamingImages) {
        await cameraController.stopImageStream();
      }
    } catch (_) {}

    try {
      await cameraController.dispose();
    } catch (_) {}

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> shutdown() {
    return _releaseCamera(permanent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    _mockAnimationTimer?.cancel();
    _mockAnimationTimer = null;

    final CameraController? cameraController = controller;
    controller = null;
    isInitialized = false;
    isInitializing = false;
    isTorchOn = false;
    _currentResults = const [];
    resultsNotifier.value = const [];

    if (cameraController != null) {
      unawaited(() async {
        try {
          if (cameraController.value.isStreamingImages) {
            await cameraController.stopImageStream();
          }
        } catch (_) {}

        try {
          await cameraController.dispose();
        } catch (_) {}
      }());
    }

    resultsNotifier.dispose();
    super.dispose();
  }
}

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:logbook_app_081/features/vision/dto/detection_result.dart';
import 'package:logbook_app_081/features/vision/damage_painter.dart';
import 'package:logbook_app_081/features/vision/vision_controller.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  late VisionController _visionController;
  static const double _portraitViewportRatio = 9 / 16;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _visionController = VisionController();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _visionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _visionController.shutdown();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Smart-Patrol Vision'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListenableBuilder(
            listenable: _visionController,
            builder: (context, child) {
              if (_visionController.hasCameraAccessIssue) {
                return _buildNoCameraAccessState();
              }

              if (!_visionController.isInitialized) {
                return _buildLoadingState();
              }

              return Center(
                child: AspectRatio(
                  aspectRatio: _portraitViewportRatio,
                  child: _buildVisionStack(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVisionStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_visionController.controller!.value.previewSize != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _visionController.controller!.value.previewSize!.height,
              height: _visionController.controller!.value.previewSize!.width,
              child: CameraPreview(_visionController.controller!),
            ),
          )
        else
          CameraPreview(_visionController.controller!),
        if (_visionController.isOverlayEnabled)
          Positioned.fill(
            child: RepaintBoundary(
              child: ValueListenableBuilder<List<DetectionResult>>(
                valueListenable: _visionController.resultsNotifier,
                builder: (context, results, _) {
                  return CustomPaint(
                    painter: DamagePainter(results),
                  );
                },
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'torch-btn',
                backgroundColor:
                    _visionController.isTorchOn ? Colors.amber : Colors.white,
                foregroundColor:
                    _visionController.isTorchOn ? Colors.black : Colors.black87,
                onPressed: _visionController.toggleTorch,
                child: Icon(
                  _visionController.isTorchOn
                      ? Icons.flash_on
                      : Icons.flash_off,
                ),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.small(
                heroTag: 'overlay-btn',
                backgroundColor: _visionController.isOverlayEnabled
                    ? Colors.blueAccent
                    : Colors.white,
                foregroundColor: _visionController.isOverlayEnabled
                    ? Colors.white
                    : Colors.black87,
                onPressed: _visionController.toggleOverlay,
                child: Icon(
                  _visionController.isOverlayEnabled
                      ? Icons.layers
                      : Icons.layers_clear,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: Colors.cyanAccent,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Menghubungkan ke Sensor Visual...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCameraAccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'No Camera Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _visionController.errorMessage ??
                  'Aplikasi membutuhkan izin kamera untuk mode Smart-Patrol Vision.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _visionController.openPermissionSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _visionController.initCamera,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

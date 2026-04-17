import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';
import '../models/scan_history_model.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_result_sheet.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late MobileScannerController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isScanModeQR = true;
  bool _isProcessingOCR = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final mlkit.BarcodeScanner _barcodeScanner = mlkit.BarcodeScanner();
  final ImagePicker _picker = ImagePicker();
  
  double _zoomFactor = 0.0;
  bool _isFlashOn = false;
  
  DateTime? _lastDetectedAt;
  String? _lastDetectedCode;
  bool _isPulseActive = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.unrestricted,
      formats: [BarcodeFormat.qrCode],
    );
    _audioPlayer.setSource(AssetSource('audio/beep.mp3'));
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndProcessOCR() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isProcessingOCR = true);
    _controller.stop();

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in image')),
          );
        }
      } else {
        _handleScanSuccess(recognizedText.text, isOCR: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOCR = false);
        _controller.start();
      }
    }
  }

  Future<void> _pickImageAndScanQR() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isProcessingOCR = true);
    _controller.stop();

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final List<mlkit.Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
      
      if (barcodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR Code or Barcode found in image')),
          );
        }
      } else {
        final code = barcodes.first.rawValue;
        if (code != null) {
          _handleScanSuccess(code, isOCR: false, isGallery: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOCR = false);
        _controller.start();
      }
    }
  }

  void _triggerSuccessFeedback(HistoryProvider provider) {
    // Visual Pulse
    setState(() => _isPulseActive = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isPulseActive = false);
    });

    // Audio Feedback (Non-blocking)
    if (provider.isSoundEnabled) {
      _audioPlayer.stop().then((_) => _audioPlayer.resume());
    }

    // Double-Tap Haptic Pattern (Non-blocking)
    if (provider.isHapticEnabled) {
      _triggerDoubleTapHaptic();
    }
  }

  Future<void> _triggerDoubleTapHaptic() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        // Debounce: ignore same code if detected within 1 second
        final now = DateTime.now();
        if (code == _lastDetectedCode && 
            _lastDetectedAt != null && 
            now.difference(_lastDetectedAt!).inSeconds < 3) {
          return;
        }
        
        _lastDetectedCode = code;
        _lastDetectedAt = now;
        _handleScanSuccess(code);
      }
    }
  }

  void _handleScanSuccess(String code, {bool isOCR = false, bool isGallery = false}) {
    if (!isOCR && !isGallery && !_controller.value.isRunning) return;
    
    final provider = context.read<HistoryProvider>();

    // Premium Feedback
    if (!isOCR) {
      _triggerSuccessFeedback(provider);
    }

    // Determine result type
    String resultType = isOCR ? 'text' : 'text';
    if (!isOCR) {
      final codeLow = code.toLowerCase();
      if (codeLow.startsWith('wifi:')) {
        resultType = 'wifi';
      } else if (codeLow.startsWith('upi://') || codeLow.contains('paypal.me') || 
                 codeLow.startsWith('bitcoin:') || codeLow.startsWith('ethereum:')) {
        resultType = 'payment';
      } else if (codeLow.contains('begin:vevent') || codeLow.contains('begin:vcalendar')) {
        resultType = 'event';
      } else if (Uri.tryParse(code)?.hasScheme ?? false) {
        resultType = 'url';
      } else if (RegExp(r'^\+?[0-9]{7,15}$').hasMatch(code)) {
        resultType = 'phone';
      } else if (code.contains('@') && code.contains('.')) {
        resultType = 'email';
      }
    }

    final scan = ScanHistory(
      content: code,
      type: isOCR ? 'ocr' : (isGallery ? 'gallery' : (_isScanModeQR ? 'qr' : 'barcode')),
      resultType: resultType,
      scannedAt: DateTime.now(),
      isGenerated: false,
      category: isOCR ? 'Other' : provider.getRecommendedCategory(code, resultType),
    );

    if (provider.isBatchMode && !isOCR && !isGallery) {
      provider.addScan(scan);
      return;
    }

    _controller.stop();
    provider.addScan(scan);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanResultSheet(
        content: code,
        type: scan.type,
        resultType: resultType,
      ),
    ).then((_) {
      if (mounted) _controller.start();
    });
  }

  void _showBatchPreview(BuildContext context, HistoryProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Batch', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: provider.batchScans.isEmpty
                  ? const Center(child: Text('No scans in batch'))
                  : ListView.builder(
                      itemCount: provider.batchScans.length,
                      itemBuilder: (context, index) {
                        final scan = provider.batchScans[index];
                        return ListTile(
                          title: Text(scan.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(DateFormat('hh:mm:ss a').format(scan.scannedAt)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () => provider.removeFromBatch(index),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Feature Guide', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.layers_outlined, color: AppTheme.textSecondary),
              title: Text('Batch Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Scan multiple items in sequence and save them all at once.'),
            ),
            const ListTile(
              leading: Icon(Icons.image_outlined, color: AppTheme.textSecondary),
              title: Text('Gallery Scan', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Import QR codes or Barcodes directly from your photos.'),
            ),
            const ListTile(
              leading: Icon(Icons.text_fields_outlined, color: AppTheme.textSecondary),
              title: Text('OCR Text Recognition', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Extract text from any image using smart OCR technology.'),
            ),
            const ListTile(
              leading: Icon(Icons.translate, color: AppTheme.textSecondary),
              title: Text('Offline Translation', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Translate scanned text directly into Bengali.'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;
        
        // Define ROI (Region of Interest) - 250x250 centered perfectly in the widget
        const double roiSize = 250.0;
        final Rect windowRect = Rect.fromCenter(
          center: Offset(screenWidth / 2, screenHeight / 2),
          width: roiSize,
          height: roiSize,
        );

        return Stack(
          children: [
            GestureDetector(
              onScaleUpdate: (details) {
                if (details.scale > 1.0) {
                  _zoomFactor = (_zoomFactor + 0.01).clamp(0.0, 1.0);
                } else if (details.scale < 1.0) {
                  _zoomFactor = (_zoomFactor - 0.01).clamp(0.0, 1.0);
                }
                _controller.setZoomScale(_zoomFactor);
              },
              child: RepaintBoundary(
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  scanWindow: windowRect,
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ScannerShroudPainter(
                    windowRect: windowRect,
                  ),
                ),
              ),
            ),
            // Neon Brackets & Line
            Center(
              child: SizedBox(
                width: roiSize,
                height: roiSize,
                child: Stack(
                  children: [
                    // Pulse Animation for Brackets
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: ScannerBracketsPainter(
                                pulse: _isPulseActive ? 1.0 : 0.0,
                                color: AppTheme.accent,
                              ),
                            );
                          },
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02), duration: 1200.ms, curve: Curves.easeInOut),
                      ),
                    ),
                    // Neon Scan Line (Isolated RepaintBoundary)
                    RepaintBoundary(
                      child: Container(
                        width: roiSize,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accent.withValues(alpha: 0),
                              AppTheme.accent,
                              AppTheme.accent.withValues(alpha: 0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.4), // Reduced blur alpha for performance
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: 0, end: roiSize, duration: 2500.ms, curve: Curves.easeInOut),
                    ),
                  ],
                ),
              ),
            ),
            if (_isProcessingOCR)
              const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            
            // Top Overlay: Mode Switcher & Help
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spare space for balance
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(true, 'QR Code'),
                        _buildModeButton(false, 'Barcode'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.white, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showHelpGuide(context);
                    },
                  ),
                ],
              ),
            ),

            // Top-Sub Overlay: Batch Toggle (Fixed Position)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSmallToggle(
                      icon: Icons.layers_outlined,
                      label: 'Batch',
                      isActive: provider.isBatchMode,
                      onTap: () => provider.toggleBatchMode(),
                    ),
                    if (provider.isBatchMode && provider.batchScans.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _showBatchPreview(context, provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 10),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.list_alt, size: 16, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                '${provider.batchScans.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Overlay: Action Controls (Fixed)
            Positioned(
              bottom: 40,
              left: 40,
              right: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleButton(
                    icon: _isFlashOn ? Icons.flashlight_off_outlined : Icons.flashlight_on_outlined,
                    onPressed: () {
                      _controller.toggleTorch();
                      setState(() => _isFlashOn = !_isFlashOn);
                    },
                  ),
                  Row(
                    children: [
                      _buildCircleButton(
                        icon: Icons.text_fields_outlined,
                        onPressed: _pickImageAndProcessOCR,
                      ),
                      const SizedBox(width: 20),
                      _buildCircleButton(
                        icon: Icons.image_outlined,
                        onPressed: _pickImageAndScanQR,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom-Sub Overlay: Batch Save Button (Animated Float Overlay)
            if (provider.isBatchMode && provider.batchScans.isNotEmpty)
              Positioned(
                bottom: 120,
                left: 40,
                right: 40,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => provider.saveBatch(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('SAVE BATCH RESULTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSmallToggle({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent.withValues(alpha: 0.2) : Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppTheme.accent : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? AppTheme.accent : Colors.white70),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? AppTheme.accent : Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(bool isQR, String label) {
    bool selected = _isScanModeQR == isQR;
    return GestureDetector(
      onTap: () async {
        if (_isScanModeQR == isQR) return;
        HapticFeedback.selectionClick();

        // Safety Delay & Reset to prevent White Screen / Hardware Lock
        final oldController = _controller;
        
        setState(() {
          _isScanModeQR = isQR;
          // Temporarily set controller to a paused state or stop it
        });

        try {
          await oldController.stop();
          await oldController.dispose();
        } catch (e) {
          debugPrint('Controller dispose error: $e');
        }

        // Small hardware reset buffer
        await Future.delayed(const Duration(milliseconds: 150));

        if (!mounted) return;

        setState(() {
          _controller = MobileScannerController(
            detectionSpeed: DetectionSpeed.unrestricted,
            formats: isQR ? [BarcodeFormat.qrCode] : [
              BarcodeFormat.code128,
              BarcodeFormat.ean13,
              BarcodeFormat.ean8,
              BarcodeFormat.code39,
              BarcodeFormat.upcA,
              BarcodeFormat.upcE,
            ],
            torchEnabled: _isFlashOn,
            autoStart: true,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class ScannerBracketsPainter extends CustomPainter {
  final double pulse;
  final Color color;
  ScannerBracketsPainter({required this.pulse, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8 + (pulse * 0.2))
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);

    const double l = 40.0;
    const double r = 24.0;

    // Top Left
    canvas.drawPath(Path()..moveTo(0, l)..lineTo(0, r)..quadraticBezierTo(0, 0, r, 0)..lineTo(l, 0), paint);
    // Top Right
    canvas.drawPath(Path()..moveTo(size.width - l, 0)..lineTo(size.width - r, 0)..quadraticBezierTo(size.width, 0, size.width, r)..lineTo(size.width, l), paint);
    // Bottom Left
    canvas.drawPath(Path()..moveTo(0, size.height - l)..lineTo(0, size.height - r)..quadraticBezierTo(0, size.height, r, size.height)..lineTo(l, size.height), paint);
    // Bottom Right
    canvas.drawPath(Path()..moveTo(size.width - l, size.height)..lineTo(size.width - r, size.height)..quadraticBezierTo(size.width, size.height, size.width, size.height - r)..lineTo(size.width, size.height - l), paint);
  }

  @override
  bool shouldRepaint(ScannerBracketsPainter oldDelegate) => pulse != oldDelegate.pulse;
}

class ScannerShroudPainter extends CustomPainter {
  final Rect windowRect;
  ScannerShroudPainter({required this.windowRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final windowPath = Path()..addRRect(RRect.fromRectAndRadius(windowRect, const Radius.circular(24)));
    
    final shroudPath = Path.combine(PathOperation.difference, backgroundPath, windowPath);
    
    canvas.drawPath(
      shroudPath,
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );

    // Subtle inner glow on ROI edge
    canvas.drawRRect(
      RRect.fromRectAndRadius(windowRect, const Radius.circular(24)),
      Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
    );
  }

  @override
  bool shouldRepaint(ScannerShroudPainter oldDelegate) => windowRect != oldDelegate.windowRect;
}

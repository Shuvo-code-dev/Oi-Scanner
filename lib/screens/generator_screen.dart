import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../theme/app_theme.dart';
import 'package:gal/gal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _wifiSsidController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String _selectedType = 'URL';
  String _wifiSecurity = 'WPA';
  bool _isGenerated = false;
  final List<String> _types = ['URL', 'Text', 'Phone', 'Email', 'WiFi'];
  final GlobalKey _qrKey = GlobalKey();

  Color _qrColor = Colors.black;
  final List<Color> _colors = [Colors.black, AppTheme.accent, Colors.blue, Colors.deepPurple, Colors.teal];

  @override
  void dispose() {
    _textController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onInputChange() {
    if (_isGenerated) {
      setState(() {
        _isGenerated = false;
      });
    }
  }

  String _getQrData() {
    final text = _textController.text;
    switch (_selectedType) {
      case 'Phone':
        return 'TEL:${_phoneController.text}';
      case 'Email':
        return 'mailto:${_emailController.text}';
      case 'WiFi':
        return 'WIFI:T:$_wifiSecurity;S:${_wifiSsidController.text};P:${_wifiPasswordController.text};;';
      case 'URL':
        if (text.isEmpty) return '';
        if (!text.startsWith('http')) return 'https://$text';
        return text;
      default:
        return text;
    }
  }

  Widget _buildDynamicForm() {
    switch (_selectedType) {
      case 'WiFi':
        return Column(
          children: [
            _buildField(_wifiSsidController, 'Network Name (SSID)', Icons.wifi),
            const SizedBox(height: 12),
            _buildField(_wifiPasswordController, 'Password', Icons.lock_outline, obscure: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _wifiSecurity,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  items: ['WPA', 'WEP', 'None'].map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) {
                    _onInputChange();
                    setState(() => _wifiSecurity = val!);
                  },
                ),
              ),
            ),
          ],
        );
      case 'Phone':
        return _buildField(_phoneController, 'Phone Number', Icons.phone, keyboard: TextInputType.phone);
      case 'Email':
        return _buildField(_emailController, 'Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress);
      case 'URL':
        return _buildField(_textController, 'Enter URL (e.g. google.com)', Icons.link, keyboard: TextInputType.url);
      default:
        return _buildField(_textController, 'Enter Text', Icons.edit_outlined, maxLines: 3);
    }
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {bool obscure = false, TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLines: maxLines,
      onChanged: (_) => _onInputChange(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: AppTheme.accent),
      ),
    );
  }

  Future<void> _shareQrCode() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(buffer);

      await Share.shareXFiles([XFile(path)], text: 'Generated QR Code via Oi QR Scanner');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR code: $e')),
      );
    }
  }

  Future<void> _saveQrCode() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(buffer);

      // Check for permission and save
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      
      await Gal.putImage(path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code saved to gallery!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving QR code: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 24),
              _buildGlassForm(),
              const SizedBox(height: 32),
              _buildGenerateButton(),
              if (_isGenerated) ...[
                const SizedBox(height: 32),
                _buildColorSelector(),
                const SizedBox(height: 40),
                _buildGlassQrPreview(),
                const SizedBox(height: 40),
                _buildActionButtons(),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _types.map((type) {
          bool selected = _selectedType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(type),
              onSelected: (val) {
                HapticFeedback.selectionClick();
                _onInputChange();
                setState(() => _selectedType = type);
              },
              selectedColor: AppTheme.accent,
              checkmarkColor: Colors.black,
              labelStyle: TextStyle(
                color: selected ? Colors.black : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppTheme.surface.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGlassForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: _buildDynamicForm(),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.heavyImpact();
        FocusScope.of(context).unfocus();
        setState(() => _isGenerated = true);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text('GENERATE QR CODE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    )
    .animate(onPlay: (c) => c.repeat())
    .shimmer(duration: 3.seconds, delay: 2.seconds, color: Colors.white.withValues(alpha: 0.3));
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Custom Color', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: _colors.map((color) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _qrColor = color);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _qrColor == color ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: [
                    if (_qrColor == color)
                      BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildGlassQrPreview() {
    return Center(
      child: RepaintBoundary(
        key: _qrKey,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: QrImageView(
            data: _getQrData(),
            version: QrVersions.auto,
            size: 200.0,
            gapless: false,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: _qrColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: _qrColor,
            ),
          ),
        ),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _shareQrCode,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saveQrCode,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Save'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppTheme.accent,
              side: const BorderSide(color: AppTheme.accent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

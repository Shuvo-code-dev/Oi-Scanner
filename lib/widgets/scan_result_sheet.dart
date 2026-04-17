import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import '../theme/app_theme.dart';
import '../providers/history_provider.dart';

class ScanResultSheet extends StatefulWidget {
  final String content;
  final String type;
  final String resultType;

  const ScanResultSheet({
    super.key,
    required this.content,
    required this.type,
    required this.resultType,
  });

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  String? _translatedText;
  bool _isTranslating = false;

  Future<void> _translateText(String sourceText) async {
    setState(() => _isTranslating = true);
    try {
      final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
      final List<IdentifiedLanguage> possibleLanguages = await languageIdentifier.identifyPossibleLanguages(sourceText);
      await languageIdentifier.close();

      String sourceLanguage = TranslateLanguage.english.bcpCode;
      if (possibleLanguages.isNotEmpty) {
        sourceLanguage = possibleLanguages.first.languageTag;
      }

      final onDeviceTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.values.firstWhere((e) => e.bcpCode == sourceLanguage, orElse: () => TranslateLanguage.english),
        targetLanguage: TranslateLanguage.bengali,
      );

      final response = await onDeviceTranslator.translateText(sourceText);
      await onDeviceTranslator.close();
      
      if (mounted) {
        setState(() {
          _translatedText = response;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e')),
        );
      }
    }
  }

  ({IconData icon, Color color, String label, String description}) _analyzeSafety() {
    final content = widget.content.toLowerCase();
    
    if (widget.resultType != 'url') {
      return (
        icon: Icons.verified_user_outlined,
        color: AppTheme.accent,
        label: 'Verified Format',
        description: 'This ${widget.resultType} format follows standard structures.',
      );
    }

    if (content.startsWith('https://')) {
      final shorteners = ['bit.ly', 't.co', 'goo.gl', 'tinyurl.com', 'is.gd', 'buff.ly', 'rebrand.ly'];
      if (shorteners.any((s) => content.contains(s))) {
        return (
          icon: Icons.warning_amber_rounded,
          color: Colors.orangeAccent,
          label: 'URL Masked',
          description: 'This is a shortened URL. The actual destination is hidden.',
        );
      }
      return (
        icon: Icons.security,
        color: Colors.greenAccent,
        label: 'Secure Link',
        description: 'This link uses modern encryption (HTTPS).',
      );
    }

    if (content.startsWith('http://')) {
      return (
        icon: Icons.gpp_maybe_rounded,
        color: Colors.redAccent,
        label: 'Insecure Link',
        description: 'Caution: This site uses unencrypted HTTP protocol.',
      );
    }

    return (
      icon: Icons.help_outline,
      color: Colors.grey,
      label: 'Unknown',
      description: 'Unable to verify the safety profile of this content.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final safety = _analyzeSafety();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      snap: true,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStatusHeader(safety),
                  const SizedBox(height: 24),
                  _buildContentCard(),
                  const SizedBox(height: 32),
                  _buildActionButtons(context, context.read<HistoryProvider>()),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(({IconData icon, Color color, String label, String description}) safety) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: safety.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: safety.color.withValues(alpha: 0.3)),
          ),
          child: Icon(safety.icon, color: safety.color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Shield',
                style: TextStyle(color: safety.color, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11),
              ),
              Text(
                safety.label,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.resultType.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SCANNED CONTENT', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          SelectableText(
            widget.content,
            style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          if (_translatedText != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white12),
            ),
            const Text('TRANSLATION (BENGALI)', style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 8),
            Text(_translatedText!, style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, HistoryProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            if (widget.resultType == 'url')
              Expanded(child: _buildNeumorphicButton(onPressed: () => _launchURL(widget.content), icon: Icons.open_in_new_rounded, label: 'Open Link', isPrimary: true)),
            if (widget.resultType == 'phone')
              Expanded(child: _buildNeumorphicButton(onPressed: () => _launchURL('tel:${widget.content}'), icon: Icons.call_rounded, label: 'Call Now', isPrimary: true)),
            if (widget.resultType == 'payment')
              Expanded(child: _buildNeumorphicButton(onPressed: () => _launchURL(widget.content), icon: Icons.payments_rounded, label: 'Pay Now', isPrimary: true)),
            if (widget.resultType == 'event')
              Expanded(child: _buildNeumorphicButton(onPressed: () => _launchURL('https://www.google.com/calendar/render?action=TEMPLATE&text=Scanned%20Event&details=${Uri.encodeComponent(widget.content)}'), icon: Icons.calendar_today_rounded, label: 'Schedule', isPrimary: true)),
            if (widget.resultType == 'wifi')
              Expanded(
                child: _buildNeumorphicButton(
                  onPressed: () async {
                    final success = await provider.connectToWiFi(widget.content);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Connected to WiFi' : 'Failed to connect')));
                    }
                  },
                  icon: Icons.wifi_rounded,
                  label: 'Connect WiFi',
                  isPrimary: true,
                ),
              ),
            if (widget.resultType == 'text' || widget.resultType == 'email')
              Expanded(child: _buildNeumorphicButton(onPressed: () => _copyToClipboard(context, widget.content), icon: Icons.copy_rounded, label: 'Copy Text', isPrimary: true)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildNeumorphicButton(onPressed: () => Share.share(_translatedText ?? widget.content), icon: Icons.share_rounded, label: 'Share')),
            if (widget.type == 'ocr' && _translatedText == null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildNeumorphicButton(
                  onPressed: _isTranslating ? () {} : () => _translateText(widget.content),
                  icon: Icons.translate_rounded,
                  label: _isTranslating ? 'Translating...' : 'Translate',
                ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(child: _buildNeumorphicButton(onPressed: () => Navigator.pop(context), icon: Icons.close_rounded, label: 'Dismiss')),
          ],
        ),
      ],
    );
  }

  Widget _buildNeumorphicButton({required VoidCallback onPressed, required IconData icon, required String label, bool isPrimary = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.accent : AppTheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
          ],
          border: Border.all(
            color: isPrimary ? AppTheme.accent : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.black : Colors.white70, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

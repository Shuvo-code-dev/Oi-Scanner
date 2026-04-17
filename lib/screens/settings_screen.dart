import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import 'policy_web_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final langProvider = context.watch<LanguageProvider>();
    const String appVersion = '1.0.0';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionHeader('System Feedback'),
              _buildFeedbackToggles(provider),
              const SizedBox(height: 32),
              _buildSectionHeader('Security'),
              SwitchListTile(
                title: const Text('Biometric Lock'),
                subtitle: const Text('Require fingerprint to view history'),
                value: provider.isBiometricEnabled,
                onChanged: (val) async {
                  if (val) {
                    final success = await provider.authenticate();
                    if (success) {
                      provider.isBiometricEnabled = true;
                    }
                  } else {
                    provider.isBiometricEnabled = false;
                  }
                },
                activeThumbColor: AppTheme.accent,
                activeTrackColor: AppTheme.accent.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Preferences'),
              ListTile(
                title: const Text('Language / ভাষা'),
                subtitle: Text(
                  langProvider.currentLanguage == 'bn' ? 'বাংলা' : 'English',
                ),
                leading: const Icon(Icons.language, color: AppTheme.accent),
                onTap: () {
                  final newLang = langProvider.currentLanguage == 'en'
                      ? 'bn'
                      : 'en';
                  langProvider.setLanguage(newLang);
                },
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Support & Legal'),
              ListTile(
                title: const Text('Rate & Review'),
                subtitle: const Text('Help us grow on Play Store'),
                leading: const Icon(Icons.star_outline, color: AppTheme.accent),
                onTap: () => _launchUrl(
                  'https://play.google.com/store/apps/details?id=com.oiapplications.oiqrscanner',
                ),
              ),
              ListTile(
                title: const Text('Our More Apps'),
                subtitle: const Text('Explore more from Oi Applications'),
                leading: const Icon(
                  Icons.apps_outlined,
                  color: AppTheme.accent,
                ),
                onTap: () => _launchUrl(
                  'https://play.google.com/store/apps/dev?id=5209526810797458542',
                ),
              ),
              ListTile(
                title: const Text('Share App'),
                subtitle: const Text('Spread the word with friends'),
                leading: const Icon(
                  Icons.share_outlined,
                  color: AppTheme.accent,
                ),
                onTap: () async => await Share.share(
                  'Check out Oi QR Scanner! Fast, secure and feature-rich. Download here: https://play.google.com/store/apps/details?id=com.oiapplications.oiqrscanner',
                ),
              ),
              const Divider(height: 32, color: Colors.white10),
              ListTile(
                title: const Text('Privacy Policy'),
                leading: const Icon(Icons.privacy_tip_outlined),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PolicyWebView(
                        title: 'Privacy Policy',
                        url:
                            'https://shuvo-code-dev.github.io/oi-qr-scanner-policy/',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'Powered By Oi Applications',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Version $appVersion',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackToggles(HistoryProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Sound Feedback'),
            subtitle: const Text('Futuristic "Cyber-Chime" on success'),
            value: provider.isSoundEnabled,
            onChanged: (val) => provider.isSoundEnabled = val,
            activeThumbColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withValues(alpha: 0.5),
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.white10,
          ),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Premium "Double-Tap" tactile feel'),
            value: provider.isHapticEnabled,
            onChanged: (val) => provider.isHapticEnabled = val,
            activeThumbColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

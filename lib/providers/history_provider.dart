import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/scan_history_model.dart';
import '../database/database_helper.dart';
import '../utils/wifi_util.dart';

class HistoryProvider with ChangeNotifier {
  List<ScanHistory> _history = [];
  bool _isLoading = false;
  
  // Phase 2 State
  bool isBatchMode = false;
  List<ScanHistory> batchScans = [];
  bool _isBiometricEnabled = false;
  bool _isSoundEnabled = true;
  bool _isHapticEnabled = true;

  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isHapticEnabled => _isHapticEnabled;

  set isBiometricEnabled(bool value) {
    _isBiometricEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  set isSoundEnabled(bool value) {
    _isSoundEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  set isHapticEnabled(bool value) {
    _isHapticEnabled = value;
    _saveSettings();
    notifyListeners();
  }
  final LocalAuthentication _auth = LocalAuthentication();

  List<ScanHistory> get history => _history;
  bool get isLoading => _isLoading;

  HistoryProvider() {
    _loadSettings();
    loadHistory();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool('sound_enabled') ?? true;
    _isHapticEnabled = prefs.getBool('haptic_enabled') ?? true;
    _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _isSoundEnabled);
    await prefs.setBool('haptic_enabled', _isHapticEnabled);
    await prefs.setBool('biometric_enabled', _isBiometricEnabled);
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();
    _history = await DatabaseHelper.instance.getAllScans();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addScan(ScanHistory scan) async {
    if (isBatchMode) {
      // Prevent sequential duplicates
      if (batchScans.isNotEmpty && batchScans.last.content == scan.content) {
        return;
      }
      batchScans.add(scan);
      notifyListeners();
      return;
    }

    await DatabaseHelper.instance.insertScan(scan);
    await loadHistory();
  }

  Future<void> saveBatch() async {
    for (var scan in batchScans) {
      await DatabaseHelper.instance.insertScan(scan);
    }
    batchScans.clear();
    isBatchMode = false;
    await loadHistory();
    notifyListeners();
  }

  Future<void> toggleFavorite(ScanHistory scan) async {
    final updatedScan = ScanHistory(
      id: scan.id,
      content: scan.content,
      type: scan.type,
      resultType: scan.resultType,
      scannedAt: scan.scannedAt,
      isGenerated: scan.isGenerated,
      isFavorite: !scan.isFavorite,
      category: scan.category,
    );
    await DatabaseHelper.instance.updateScan(updatedScan);
    await loadHistory();
  }

  Future<void> deleteScan(int id) async {
    await DatabaseHelper.instance.deleteScan(id);
    await loadHistory();
  }

  Future<void> clearHistory() async {
    await DatabaseHelper.instance.deleteAllScans();
    await loadHistory();
  }

  // WiFi Logic
  Future<bool> connectToWiFi(String content) async {
    final wifiInfo = WiFiUtil.parseWiFi(content);
    if (wifiInfo.isEmpty) return false;
    return await WiFiUtil.connectToWiFi(
      wifiInfo['ssid']!,
      wifiInfo['password'],
      wifiInfo['security'],
    );
  }

  // Export Logic
  Future<String?> exportToCSV() async {
    List<List<dynamic>> rows = [
      ['ID', 'Content', 'Type', 'Result Type', 'Date', 'Is Favorite', 'Category']
    ];
    for (var scan in _history) {
      rows.add([
        scan.id,
        scan.content,
        scan.type,
        scan.resultType,
        scan.scannedAt.toIso8601String(),
        scan.isFavorite ? 'Yes' : 'No',
        scan.category,
      ]);
    }
    String csv = const ListToCsvConverter().convert(rows);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/scan_history_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csv);
      return path;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  Future<String?> exportToPDF() async {
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Oi QR Scanner - Scan History', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                  pw.Text('Generated: $dateStr', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Content', 'Type', 'Result', 'Date', 'Category'],
              data: _history.map((s) => [
                s.content,
                s.type.toUpperCase(),
                s.resultType.toUpperCase(),
                DateFormat('MM-dd HH:mm').format(s.scannedAt),
                s.category,
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
            ),
          ];
        },
      ),
    );

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/scan_history_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      return path;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  // Biometric Auth
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Secure your scan history',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (e) {
      return false;
    }
  }

  void toggleBatchMode() {
    isBatchMode = !isBatchMode;
    if (!isBatchMode) batchScans.clear();
    notifyListeners();
  }

  void removeFromBatch(int index) {
    batchScans.removeAt(index);
    notifyListeners();
  }

  String getRecommendedCategory(String content, String resultType) {
    if (resultType == 'url') return 'Web';
    if (resultType == 'phone') return 'Contact';
    if (resultType == 'email') return 'Work';
    if (resultType == 'wifi') return 'Network';
    if (resultType == 'payment') return 'Finance';
    if (resultType == 'event') return 'Events';
    return 'Other';
  }
}

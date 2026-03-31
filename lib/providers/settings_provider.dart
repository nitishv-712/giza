// lib/providers/settings_provider.dart

import 'package:flutter/foundation.dart';
import '../db/hive_helper.dart';

class SettingsProvider extends ChangeNotifier {
  final _db = HiveHelper.instance;

  bool _autoDownload = false;
  bool _downloadOnWifiOnly = true;
  bool _showNotifications = true;
  String _audioQuality = 'best';

  bool get autoDownload => _autoDownload;
  bool get downloadOnWifiOnly => _downloadOnWifiOnly;
  bool get showNotifications => _showNotifications;
  String get audioQuality => _audioQuality;

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    _autoDownload = _db.getSetting<bool>('auto_download') ?? false;
    _downloadOnWifiOnly = _db.getSetting<bool>('wifi_only') ?? true;
    _showNotifications = _db.getSetting<bool>('notifications') ?? true;
    _audioQuality = _db.getSetting<String>('audio_quality') ?? 'best';
    notifyListeners();
  }

  Future<void> setAutoDownload(bool value) async {
    _autoDownload = value;
    await _db.setSetting('auto_download', value);
    notifyListeners();
  }

  Future<void> setDownloadOnWifiOnly(bool value) async {
    _downloadOnWifiOnly = value;
    await _db.setSetting('wifi_only', value);
    notifyListeners();
  }

  Future<void> setShowNotifications(bool value) async {
    _showNotifications = value;
    await _db.setSetting('notifications', value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    _audioQuality = value;
    await _db.setSetting('audio_quality', value);
    notifyListeners();
  }

  Future<void> clearCache() async {
    // TODO: Implement actual cache clearing
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _db.clearHistory();
    notifyListeners();
  }

  String getQualityLabel() {
    switch (_audioQuality) {
      case 'best':
        return 'Best Available';
      case 'high':
        return 'High (320 kbps)';
      case 'medium':
        return 'Medium (192 kbps)';
      case 'low':
        return 'Low (128 kbps)';
      default:
        return 'Best Available';
    }
  }
}

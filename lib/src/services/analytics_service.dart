import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// App-wide analytics (screen views + custom events).
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logScreen(String name) async {
    try {
      await _analytics.logScreenView(screenName: name);
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics screen: $e');
    }
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics event: $e');
    }
  }

  // ── Cloud Gallery events ──────────────────────────────────────────────

  Future<void> logConnectAccount(String provider) =>
      logEvent('connect_account', {'provider': provider});

  Future<void> logDisconnectAccount(String provider) =>
      logEvent('disconnect_account', {'provider': provider});

  Future<void> logUpload({required String source, required String target}) =>
      logEvent('media_upload', {'source': source, 'target': target});

  Future<void> logDownload({required String source}) =>
      logEvent('media_download', {'source': source});

  Future<void> logOpenMedia({required String source, required String type}) =>
      logEvent('open_media', {'source': source, 'type': type});

  Future<void> logFilterChange(String filter) =>
      logEvent('filter_change', {'filter': filter});

  Future<void> logSlideshowStart() => logEvent('slideshow_start');

  Future<void> logThemeChange(bool isDark) =>
      logEvent('theme_change', {'mode': isDark ? 'dark' : 'light'});
}

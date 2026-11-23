import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backup/offsite_backup.dart';
import '../db/bakery_order_repository.dart';
import '../screens/bakery_orders_screen.dart';
import 'app_lock.dart';

/// Bakery: roz notification — "Aaj ke cake orders" (late + aaj + kal ki ginti aur baqi wusooli).
/// Tap par Cake Orders screen khulti hai.
///
/// * Subah [alertHour] baje ke baad din mein ek baar; shaam [eveningHour] ke baad dobara sirf agar kal ke
///   orders hon (tayyari yaad dilane ke liye).
/// * Foreground (app khulte waqt) aur Android WorkManager (backup_background.dart) dono [checkAndNotify] chalate hain.
/// * Sirf Android; koi bhi ghalti app ko nahi rokti.
/// * Isi plugin se OffsiteBackup ka reminder bhi dikhta hai (ek hi init / tap handler).
class DueAlertService {
  DueAlertService._();

  static const keyEnabled = 'due_alert_enabled'; // default: on
  static const keyLastDate = 'order_alert_last_date';
  static const keyLastEveningDate = 'order_alert_last_evening_date';
  static const alertHour = 8; // subah 8 baje ke baad
  static const eveningHour = 18; // shaam 6 baje ke baad
  static const _payload = 'bakery_orders';
  static const _channelId = 'order_alerts';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static FlutterLocalNotificationsPlugin get plugin => _plugin;
  static bool get supported => _supported;

  /// `onTap` sirf foreground isolate mein dena hai (screen kholne ke liye).
  static Future<void> init({bool withTap = false}) async {
    if (!_supported || _inited) return;
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: withTap ? (r) => _open(r.payload) : null,
    );
    _inited = true;
  }

  /// App band thi aur notification se khuli — pehle frame ke baad sahi screen kholo.
  static Future<void> handleLaunch() async {
    if (!_supported) return;
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp == true) _open(d?.notificationResponse?.payload);
    } catch (_) {}
  }

  static void _open(String? payload) {
    if (payload == OffsiteBackup.payload) {
      WidgetsBinding.instance.addPostFrameCallback((_) => OffsiteBackup.shareLatest());
      return;
    }
    if (payload != _payload) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLock.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const BakeryOrdersScreen()));
    });
  }

  static String _dateKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Notification ka matn (pure — test ke liye).
  static String bodyFor(BakeryOrderCounts c) {
    final parts = <String>[];
    if (c.late > 0) parts.add('${c.late} order late');
    if (c.dueToday > 0) parts.add('aaj ${c.dueToday} dene hain');
    if (c.dueTomorrow > 0) parts.add('kal ${c.dueTomorrow}');
    if (c.ready > 0) parts.add('${c.ready} tayyar');
    final head = parts.isEmpty ? 'Koi order aaj / kal ka nahi' : parts.join(' • ');
    final bal = c.balanceDue > 0 ? '. Wusooli baqi: Rs ${c.balanceDue.round()}' : '';
    return '$head$bal. Tap karke orders dekhein.';
  }

  /// Din mein notification dikhao. true = dikhayi gayi.
  static Future<bool> checkAndNotify({DateTime? now, bool force = false}) async {
    if (!_supported) return false;
    try {
      final t = now ?? DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final today = _dateKey(t);
      final evening = t.hour >= eveningHour;
      if (!force) {
        if (prefs.getBool(keyEnabled) == false) return false;
        if (t.hour < alertHour) return false;
        if (evening) {
          if (prefs.getString(keyLastEveningDate) == today) return false;
        } else if (prefs.getString(keyLastDate) == today) {
          return false;
        }
      }
      final c = await BakeryOrderRepository.instance.counts(now: t);
      // Subah: late / aaj ho to. Shaam: sirf kal ke orders ki tayyari.
      final show = evening ? c.dueTomorrow > 0 : (c.late + c.dueToday) > 0;
      if (!show && !force) {
        await prefs.setString(evening ? keyLastEveningDate : keyLastDate, today);
        return false;
      }
      final body = bodyFor(c);
      await init();
      await _plugin.show(
        7301,
        evening ? 'Kal ke cake orders — tayyari' : 'Aaj ke cake orders',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Order reminders',
            channelDescription: 'Cake / custom orders ki delivery yaad dihani',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        payload: _payload,
      );
      await prefs.setString(evening ? keyLastEveningDate : keyLastDate, today);
      return true;
    } catch (_) {
      return false;
    }
  }
}

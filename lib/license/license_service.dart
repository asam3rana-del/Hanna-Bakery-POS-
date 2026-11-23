import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'license_keys.dart';

/// Offline license (internet ki zaroorat nahi).
///
/// * Har installation ka **Device ID** (12 harf, jaise `HB7K-2M9Q-X4TZ`) — License screen par nazar aata hai.
/// * Developer us Device ID se **license key** banata hai (tools/license/hanna_license.js), jo Ed25519 se sign
///   hoti hai. App sirf public key se check karti hai — key ki nakal doosre device par kaam nahi karti, aur
///   key mein ek harf bhi badla to rad.
/// * Key mein: device, dukaan ka naam, plan, issue date, expiry (khali = lifetime).
/// * Naye install par [trialDays] din ka trial. Trial / license khatam => app sirf License screen dikhati hai
///   (data mehfooz rehta hai; activate karte hi sab wapas).
/// * Ghari peeche ki gayi ho (date ghuma kar trial / expiry barhana) to app ruk jati hai jab tak sahi date na ho.
///
/// Device ID aur trial ka waqt SharedPreferences + secure storage dono mein (ek mit jaye to doosre se wapas).
enum LicenseState { active, trial, expired, trialOver, clockTampered }

class LicenseInfo {
  final String deviceId;
  final String shop;
  final String plan;
  final DateTime issued;

  /// null = lifetime. License is din ke aakhir tak chalta hai.
  final DateTime? expiry;
  final String key;
  const LicenseInfo({
    required this.deviceId,
    required this.shop,
    required this.plan,
    required this.issued,
    required this.expiry,
    required this.key,
  });

  bool get lifetime => expiry == null;

  /// Expiry ke din ke baad ka pehla lamha.
  DateTime? get endsAt => expiry == null ? null : DateTime(expiry!.year, expiry!.month, expiry!.day + 1);
}

class LicenseStatus {
  final LicenseState state;
  final LicenseInfo? info;
  final int daysLeft; // trial ya license ke baqi din (lifetime = -1)
  const LicenseStatus(this.state, {this.info, this.daysLeft = 0});

  bool get allowed => state == LicenseState.active || state == LicenseState.trial;

  /// 7 din ya kam baqi — yaad dihani dikhao.
  bool get warn => allowed && daysLeft >= 0 && daysLeft <= 7;
}

class LicenseException implements Exception {
  final String message;
  const LicenseException(this.message);
  @override
  String toString() => message;
}

class LicenseService {
  LicenseService._();

  static const trialDays = 7;

  static const _kDevice = 'lic_device_id';
  static const _kFirstRun = 'lic_first_run';
  static const _kLastSeen = 'lic_last_seen';
  static const _kKey = 'lic_key';

  /// Kitni der peeche ki ghari bardasht (timezone / chhoti ghalti).
  static const _clockSlack = Duration(hours: 6);

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// MaterialApp isay sunta hai — activate / expire par poori app dobara banti hai.
  static final ValueNotifier<LicenseStatus> notifier =
      ValueNotifier(const LicenseStatus(LicenseState.trial, daysLeft: trialDays));

  static LicenseStatus get current => notifier.value;

  static String? _deviceId;

  // ---------------------------------------------------------------- storage helpers

  static Future<String?> _secRead(String k) async {
    try {
      final v = await _secure.read(key: k);
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _secWrite(String k, String v) async {
    try {
      await _secure.write(key: k, value: v);
    } catch (_) {}
  }

  static Future<void> _secDelete(String k) async {
    try {
      await _secure.delete(key: k);
    } catch (_) {}
  }

  /// Dono jagah se parho; ek mein ho to doosri mein bhi likh do.
  static Future<String?> _read(SharedPreferences p, String k) async {
    final a = p.getString(k);
    final b = await _secRead(k);
    final v = (a != null && a.isNotEmpty) ? a : b;
    if (v != null) {
      if (a != v) await p.setString(k, v);
      if (b != v) await _secWrite(k, v);
    }
    return v;
  }

  static Future<void> _write(SharedPreferences p, String k, String v) async {
    await p.setString(k, v);
    await _secWrite(k, v);
  }

  // ---------------------------------------------------------------- device id

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // I, O, 0, 1 nahi (ghalat parhe jate hain)

  static String _newDeviceId() {
    final r = Random.secure();
    final raw = List.generate(12, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    return formatDeviceId(raw);
  }

  /// "abcd efgh-1234" -> "ABCD-EFGH-1234" (12 harf), warna khali.
  static String formatDeviceId(String s) {
    final n = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (n.length != 12) return '';
    return '${n.substring(0, 4)}-${n.substring(4, 8)}-${n.substring(8, 12)}';
  }

  static Future<String> deviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    final p = await SharedPreferences.getInstance();
    var id = await _read(p, _kDevice);
    if (id == null || formatDeviceId(id).isEmpty) {
      id = _newDeviceId();
      await _write(p, _kDevice, id);
    }
    _deviceId = id;
    return id;
  }

  // ---------------------------------------------------------------- verify (pure)

  static List<int> _b64url(String s) {
    final pad = (4 - s.length % 4) % 4;
    return base64Url.decode(s + '=' * pad);
  }

  static DateTime? _date(Object? v) {
    if (v is! String || v.isEmpty) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
    if (m == null) return null;
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  /// Key ka signature aur format check (device / date NAHI). Ghalat ho to [LicenseException].
  static Future<LicenseInfo> parseAndVerify(String key, {String publicKeyB64 = licensePublicKeyB64}) async {
    final k = key.trim().replaceAll(RegExp(r'\s+'), '');
    final parts = k.split('.');
    if (parts.length != 3 || parts[0] != licensePrefix) {
      throw const LicenseException('License key ghalat hai (poori key paste karein)');
    }
    final List<int> payloadBytes;
    final List<int> sig;
    try {
      payloadBytes = _b64url(parts[1]);
      sig = _b64url(parts[2]);
    } catch (_) {
      throw const LicenseException('License key ghalat hai');
    }
    final algo = Ed25519();
    final pub = SimplePublicKey(base64.decode(publicKeyB64), type: KeyPairType.ed25519);
    final ok = await algo.verify(
      utf8.encode('${parts[0]}.${parts[1]}'),
      signature: Signature(sig, publicKey: pub),
    );
    if (!ok) throw const LicenseException('License key sahi nahi (shayad koi harf badal gaya)');
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const LicenseException('License key parhi nahi ja saki');
    }
    final issued = _date(m['i']);
    final device = formatDeviceId('${m['d'] ?? ''}');
    if (m['v'] != 1 || issued == null || device.isEmpty) {
      throw const LicenseException('Ye license is app version ke liye nahi');
    }
    final e = m['e'];
    final expiry = (e is String && e.isNotEmpty) ? _date(e) : null;
    if (e is String && e.isNotEmpty && expiry == null) throw const LicenseException('License ki expiry ghalat');
    return LicenseInfo(
      deviceId: device,
      shop: '${m['s'] ?? ''}',
      plan: '${m['p'] ?? 'pro'}',
      issued: issued,
      expiry: expiry,
      key: k,
    );
  }

  /// Pure faisla (test ke liye).
  static LicenseStatus decide({
    required DateTime now,
    required DateTime firstRun,
    required DateTime? lastSeen,
    required String deviceId,
    LicenseInfo? info,
  }) {
    if (lastSeen != null && now.isBefore(lastSeen.subtract(_clockSlack))) {
      return LicenseStatus(LicenseState.clockTampered, info: info);
    }
    if (info != null && info.deviceId == deviceId) {
      final end = info.endsAt;
      if (end == null) return LicenseStatus(LicenseState.active, info: info, daysLeft: -1);
      if (now.isBefore(end)) {
        final left = end.difference(now).inHours ~/ 24;
        return LicenseStatus(LicenseState.active, info: info, daysLeft: left);
      }
      return LicenseStatus(LicenseState.expired, info: info);
    }
    final trialEnd = firstRun.add(const Duration(days: trialDays));
    if (now.isBefore(trialEnd)) {
      final left = (trialEnd.difference(now).inHours / 24).ceil();
      return LicenseStatus(LicenseState.trial, daysLeft: left);
    }
    return const LicenseStatus(LicenseState.trialOver);
  }

  // ---------------------------------------------------------------- app api

  /// main() mein (DB se pehle bhi chal sakta hai). Status [notifier] mein.
  static Future<LicenseStatus> check({DateTime? now}) async {
    final t = now ?? DateTime.now();
    try {
      final p = await SharedPreferences.getInstance();
      final dev = await deviceId();

      // Pehli dafa ka waqt: dono jagah mein jo PEHLE ka ho.
      final a = int.tryParse(p.getString(_kFirstRun) ?? '');
      final b = int.tryParse(await _secRead(_kFirstRun) ?? '');
      var first = [if (a != null) a, if (b != null) b].fold<int?>(null, (m, v) => m == null || v < m ? v : m);
      first ??= t.millisecondsSinceEpoch;
      if (a != first) await p.setString(_kFirstRun, '$first');
      if (b != first) await _secWrite(_kFirstRun, '$first');

      // Aakhri dafa dekha gaya waqt (sab se aage wala).
      final la = int.tryParse(p.getString(_kLastSeen) ?? '');
      final lb = int.tryParse(await _secRead(_kLastSeen) ?? '');
      final last = [if (la != null) la, if (lb != null) lb].fold<int?>(null, (m, v) => m == null || v > m ? v : m);

      LicenseInfo? info;
      final key = await _read(p, _kKey);
      if (key != null) {
        try {
          info = await parseAndVerify(key);
        } catch (_) {
          info = null;
        }
      }
      final s = decide(
        now: t,
        firstRun: DateTime.fromMillisecondsSinceEpoch(first),
        lastSeen: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
        deviceId: dev,
        info: info,
      );
      if (s.state != LicenseState.clockTampered) {
        final seen = max(last ?? 0, t.millisecondsSinceEpoch);
        await _write(p, _kLastSeen, '$seen');
      }
      _publish(s);
      return s;
    } catch (_) {
      // Storage hi na chale to dukaan band na ho: trial jaisa (agli dafa phir check).
      const s = LicenseStatus(LicenseState.trial, daysLeft: 1);
      _publish(s);
      return s;
    }
  }

  /// Sirf badlao par notify (har check par poori app dobara na bane).
  static void _publish(LicenseStatus s) {
    final o = notifier.value;
    if (o.state == s.state && o.daysLeft == s.daysLeft && o.info?.key == s.info?.key) return;
    notifier.value = s;
  }

  /// Key lagao. Is device ki na ho / expire ho to [LicenseException].
  static Future<LicenseStatus> activate(String key) async {
    final info = await parseAndVerify(key);
    final dev = await deviceId();
    if (info.deviceId != dev) {
      throw LicenseException('Ye key doosre device (${info.deviceId}) ki hai. Is device ka ID: $dev');
    }
    final end = info.endsAt;
    if (end != null && !DateTime.now().isBefore(end)) {
      throw const LicenseException('Ye license expire ho chuka hai — naya license lein');
    }
    final p = await SharedPreferences.getInstance();
    await _write(p, _kKey, info.key);
    return check();
  }

  /// License hata do (sirf testing / device badalne ke liye).
  static Future<void> remove() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
    await _secDelete(_kKey);
    await check();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ah_developer_kiryana_store/license/license_service.dart';

/// Keys tools/license/hanna_license.js (Node) aur hanna_license.py (Python) se bani hain — Dart verify
/// unhi ko qubool kare, aur ek harf badalne par rad kare.
const _nodeKey =
    'HBK1.eyJ2IjoxLCJkIjoiVEVTVC1ERVZJLUNFMTIiLCJzIjoiVGVzdCBCYWtlcnMiLCJwIjoicHJvIiwiaSI6IjIwMjYtMTEtMjMiLCJlIjoiMjA5OS0xMi0zMSJ9.Nm9zqjJSigKuMdwoyUVtFsytSzR2RkNQ45xrZfb1iOfFS41tblBCqP6HlKAj5De6fHeUoxkaO72K01COctXDBQ';
const _pyLifetimeKey =
    'HBK1.eyJ2IjoxLCJkIjoiQUJDRC1FRkdILTIzNDUiLCJzIjoi2LnZhNuMINio24zaqdix2LIiLCJwIjoicHJvIiwiaSI6IjIwMjYtMTEtMjMiLCJlIjoiIn0.MKCOyl5XWH6kkSCOywH47G1N9k09cy2MybyKHCLqR1IlPChkb1FRsCFw9IBPzjxGlnyXoeO5uef8ARieY27rCg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('valid keys from both generators verify', () async {
    final a = await LicenseService.parseAndVerify(_nodeKey);
    expect(a.deviceId, 'TEST-DEVI-CE12');
    expect(a.shop, 'Test Bakers');
    expect(a.expiry, DateTime(2099, 12, 31));
    final b = await LicenseService.parseAndVerify('  $_pyLifetimeKey\n');
    expect(b.deviceId, 'ABCD-EFGH-2345');
    expect(b.lifetime, isTrue);
    expect(b.shop, 'علی بیکرز');
  });

  test('tampered / garbage keys are rejected', () async {
    final parts = _nodeKey.split('.');
    // payload badla (device), signature wahi
    final forged = '${parts[0]}.${parts[1].replaceFirst('VEVTV', 'VEVTW')}.${parts[2]}';
    await expectLater(LicenseService.parseAndVerify(forged), throwsA(isA<LicenseException>()));
    await expectLater(LicenseService.parseAndVerify('hello'), throwsA(isA<LicenseException>()));
    await expectLater(LicenseService.parseAndVerify('HBK1.abc.def'), throwsA(isA<LicenseException>()));
  });

  test('formatDeviceId', () {
    expect(LicenseService.formatDeviceId('abcd efgh 2345'), 'ABCD-EFGH-2345');
    expect(LicenseService.formatDeviceId('ABC'), '');
  });

  group('decide', () {
    final first = DateTime(2026, 11, 1);
    LicenseInfo info(String dev, DateTime? exp) =>
        LicenseInfo(deviceId: dev, shop: '', plan: 'pro', issued: first, expiry: exp, key: 'k');

    test('trial then trial over', () {
      final s1 = LicenseService.decide(now: DateTime(2026, 11, 3), firstRun: first, lastSeen: null, deviceId: 'D');
      expect(s1.state, LicenseState.trial);
      expect(s1.allowed, isTrue);
      expect(s1.daysLeft, 5);
      final s2 = LicenseService.decide(now: DateTime(2026, 11, 9), firstRun: first, lastSeen: null, deviceId: 'D');
      expect(s2.state, LicenseState.trialOver);
      expect(s2.allowed, isFalse);
    });

    test('active, lifetime, expired, other device', () {
      final now = DateTime(2026, 12, 1, 10);
      expect(LicenseService.decide(now: now, firstRun: first, lastSeen: null, deviceId: 'D', info: info('D', DateTime(2026, 12, 1)))
          .state, LicenseState.active); // expiry din ke aakhir tak
      expect(LicenseService.decide(now: now, firstRun: first, lastSeen: null, deviceId: 'D', info: info('D', null)).daysLeft, -1);
      expect(LicenseService.decide(now: now, firstRun: first, lastSeen: null, deviceId: 'D', info: info('D', DateTime(2026, 11, 30)))
          .state, LicenseState.expired);
      // doosre device ki key => trial ke hisaab se (yahan trial khatam)
      expect(LicenseService.decide(now: now, firstRun: first, lastSeen: null, deviceId: 'D', info: info('X', null)).state,
          LicenseState.trialOver);
    });

    test('clock moved back is caught', () {
      final s = LicenseService.decide(
          now: DateTime(2026, 11, 2), firstRun: first, lastSeen: DateTime(2026, 11, 20), deviceId: 'D', info: info('D', null));
      expect(s.state, LicenseState.clockTampered);
      expect(s.allowed, isFalse);
    });
  });

  test('activate rejects a key for another device; device id is stable', () async {
    SharedPreferences.setMockInitialValues({});
    final id1 = await LicenseService.deviceId();
    final id2 = await LicenseService.deviceId();
    expect(id1, id2);
    expect(LicenseService.formatDeviceId(id1), id1);
    await expectLater(LicenseService.activate(_nodeKey), throwsA(isA<LicenseException>()));
  });
}

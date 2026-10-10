import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase Sec4: Client & Hosting Hardening Verification Tests', () {
    test('1. web/index.html contains CSP and strict security meta tags', () {
      final file = File('web/index.html');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('Content-Security-Policy'));
      expect(content, contains("default-src 'self'"));
      expect(content, contains("object-src 'none'"));
      expect(content, contains('strict-origin-when-cross-origin'));
      expect(content, contains('nosniff'));
    });

    test('2. web/_headers enforces strict headers for web CDN deployment', () {
      final file = File('web/_headers');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('X-Content-Type-Options: nosniff'));
      expect(content, contains('X-Frame-Options: DENY'));
      expect(content, contains('Referrer-Policy: strict-origin-when-cross-origin'));
      expect(content, contains('Permissions-Policy: geolocation=(self), camera=(), microphone=()'));
      expect(content, contains("frame-ancestors 'none'"));
    });

    test('3. firebase.json contains hosting headers and security rules config', () {
      final file = File('firebase.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('firestore.rules'));
      expect(content, contains('storage.rules'));
      expect(content, contains('X-Content-Type-Options'));
      expect(content, contains('Permissions-Policy'));
    });

    test('4. AndroidManifest.xml enforces cleartext false and minimal permissions', () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('android:usesCleartextTraffic="false"'));
      expect(content, contains('android:networkSecurityConfig="@xml/network_security_config"'));

      // Ensure no dangerous unused permissions exist
      expect(content, isNot(contains('android.permission.CAMERA')));
      expect(content, isNot(contains('android.permission.RECORD_AUDIO')));
      expect(content, isNot(contains('android.permission.READ_CONTACTS')));
      expect(content, isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')));
    });

    test('5. network_security_config.xml pins to system CAs and disables cleartext', () {
      final file = File('android/app/src/main/res/xml/network_security_config.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('cleartextTrafficPermitted="false"'));
      expect(content, contains('<certificates src="system" />'));
    });

    test('6. build.gradle.kts enables R8 minification, resource shrinking, and ProGuard', () {
      final file = File('android/app/build.gradle.kts');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('isMinifyEnabled = true'));
      expect(content, contains('isShrinkResources = true'));
      expect(content, contains('proguard-rules.pro'));

      final proguardFile = File('android/app/proguard-rules.pro');
      expect(proguardFile.existsSync(), isTrue);
    });

    test('7. SECURITY.md contains threat model, DPDP 2023, and production checklist', () {
      final file = File('SECURITY.md');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('Threat Model'));
      expect(content, contains('Vulnerability Reporting Policy'));
      expect(content, contains('Secret Management & Key Architecture'));
      expect(content, contains('DPDP Act 2023'));
      expect(content, contains('Production Operator Deployment Checklist'));
      expect(content, contains('--obfuscate --split-debug-info'));
    });
  });
}

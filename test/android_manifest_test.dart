import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the release Android manifest.
///
/// Flutter declares INTERNET in its debug and profile manifests only. While
/// the app shipped as a debug APK that was invisible; the first release build
/// had no network access at all, and every Gemini call failed with
/// "Could not reach Gemini. Check your internet connection." No Dart test can
/// catch that, because the manifest is not Dart.
void main() {
  final main = File('android/app/src/main/AndroidManifest.xml');

  test('the release manifest declares every permission the app needs', () {
    expect(main.existsSync(), isTrue,
        reason: 'run this from the project root');
    final xml = main.readAsStringSync();

    // Network, for the Gemini API. The debug manifest does not apply here.
    expect(
      xml,
      contains('android.permission.INTERNET'),
      reason: 'release builds lose all network access without this',
    );
    // Camera and gallery, for photographing bills and statements.
    expect(xml, contains('android.permission.CAMERA'));
    expect(xml, contains('android.permission.READ_MEDIA_IMAGES'));
  });

  test('permissions are not left to the debug manifest to supply', () {
    final debug = File('android/app/src/debug/AndroidManifest.xml');
    if (!debug.existsSync()) return;

    final debugPermissions = RegExp(r'android:name="(android\.permission\.[^"]+)"')
        .allMatches(debug.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    final mainXml = main.readAsStringSync();

    for (final permission in debugPermissions) {
      expect(
        mainXml,
        contains(permission),
        reason: '$permission is granted in debug builds but would be missing '
            'from release builds',
      );
    }
  });
}

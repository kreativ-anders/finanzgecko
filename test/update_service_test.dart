// Gherkin: gherkin/settings.feature
import 'dart:convert';
import 'dart:io';

import 'package:finanzgecko/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('UpdateService.checkForUpdate', () {
    test('meldet updateAvailable, wenn die GitHub-Releases-API eine neuere Version nennt', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.github.com/repos/kreativ-anders/finanzgecko/releases/latest');
        return http.Response(jsonEncode({'tag_name': 'v2.0.0'}), 200);
      });
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.updateAvailable);
      expect(result.latestVersion, 'v2.0.0');
    });

    test(
      'meldet upToDate, wenn die installierte Version bereits die neueste ist (Build-Nummer wird ignoriert)',
      () async {
        final client = MockClient((request) async => http.Response(jsonEncode({'tag_name': 'v1.3.3'}), 200));
        final service = UpdateService(client: client);

        final result = await service.checkForUpdate(currentVersion: '1.3.3+9');

        expect(result.status, UpdateCheckStatus.upToDate);
      },
    );

    test('meldet upToDate, wenn die installierte Version neuer ist als der veröffentlichte Tag', () async {
      final client = MockClient((request) async => http.Response(jsonEncode({'tag_name': 'v1.0.0'}), 200));
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.upToDate);
    });

    test('meldet failed statt zu werfen, wenn die Anfrage einen Netzwerkfehler wirft (z. B. offline)', () async {
      final client = MockClient((request) async => throw const SocketException('no network'));
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.failed);
      expect(result.latestVersion, isNull);
    });

    test('meldet failed bei HTTP 404 (z. B. solange das Repository noch privat ist)', () async {
      final client = MockClient((request) async => http.Response('Not Found', 404));
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.failed);
    });

    test('meldet failed bei unerwartet geformter Antwort (fehlendes tag_name)', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'name': 'Release without a tag_name'}), 200),
      );
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.failed);
    });

    test('meldet failed bei nicht-semver-artigem Tag statt zu werfen', () async {
      final client = MockClient((request) async => http.Response(jsonEncode({'tag_name': 'nightly-build'}), 200));
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.failed);
    });

    test('liefert die Release-Assets mit, damit kein zweiter Aufruf nötig ist', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0',
            'assets': [
              {'name': 'FinanzGecko-2.0.0-mac.dmg', 'browser_download_url': 'https://example.test/dmg'},
              {'name': 'SHA256SUMS', 'browser_download_url': 'https://example.test/sums'},
              {'name': 'kaputt'},
            ],
          }),
          200,
        ),
      );

      final result = await UpdateService(client: client).checkForUpdate(currentVersion: '1.3.3');

      expect(result.assets, {
        'FinanzGecko-2.0.0-mac.dmg': 'https://example.test/dmg',
        'SHA256SUMS': 'https://example.test/sums',
      });
    });
  });

  group('UpdateService.downloadAndVerify', () {
    const assetName = 'FinanzGecko-2.0.0-mac.dmg';
    const assets = {assetName: 'https://example.test/dmg', 'SHA256SUMS': 'https://example.test/sums'};
    // downloadAndVerify only follows https URLs on a known GitHub release
    // host. These tests serve from a fake host, so they widen the allowlist
    // explicitly — production never passes this parameter.
    const fakeHosts = {'example.test'};
    // Known test vector: sha256("hello"). Deliberately hardcoded instead of
    // computed in the test itself — otherwise the test would check the
    // implementation against itself and a wrong hex padding would go unnoticed.
    const payload = 'hello';
    const payloadDigest = '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';

    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('fg_update_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    MockClient clientWith({required String sums, String body = payload}) => MockClient((request) async {
      if (request.url.toString() == 'https://example.test/sums') return http.Response(sums, 200);
      return http.Response(body, 200);
    });

    test('schreibt die Datei, wenn die Prüfsumme passt', () async {
      final target = '${tmp.path}/$assetName';
      final service = UpdateService(
        allowedAssetHosts: fakeHosts,
        client: clientWith(sums: '$payloadDigest  $assetName\n'),
      );

      final result = await service.downloadAndVerify(assets: assets, assetName: assetName, targetPath: target);

      expect(result.status, UpdateDownloadStatus.verified);
      expect(result.filePath, target);
      expect(File(target).readAsStringSync(), payload);
    });

    test('schreibt NICHTS, wenn die Prüfsumme abweicht', () async {
      final target = '${tmp.path}/$assetName';
      final service = UpdateService(
        allowedAssetHosts: fakeHosts,
        client: clientWith(sums: '${'0' * 64}  $assetName\n'),
      );

      final result = await service.downloadAndVerify(assets: assets, assetName: assetName, targetPath: target);

      expect(result.status, UpdateDownloadStatus.checksumMismatch);
      expect(result.filePath, isNull);
      expect(File(target).existsSync(), isFalse, reason: 'eine ungeprüfte Datei darf nie im Zielordner landen');
    });

    test('meldet unavailable, wenn das Release keine SHA256SUMS beilegt (ältere Releases)', () async {
      final service = UpdateService(
        allowedAssetHosts: fakeHosts,
        client: clientWith(sums: ''),
      );

      final result = await service.downloadAndVerify(
        assets: const {assetName: 'https://example.test/dmg'},
        assetName: assetName,
        targetPath: '${tmp.path}/$assetName',
      );

      expect(result.status, UpdateDownloadStatus.unavailable);
    });

    test('meldet unavailable, wenn die Prüfsummen-Datei diese Datei nicht kennt', () async {
      final service = UpdateService(
        allowedAssetHosts: fakeHosts,
        client: clientWith(sums: '$payloadDigest  irgendwas-anderes.dmg\n'),
      );

      final result = await service.downloadAndVerify(
        assets: assets,
        assetName: assetName,
        targetPath: '${tmp.path}/$assetName',
      );

      expect(result.status, UpdateDownloadStatus.unavailable);
    });

    test('lädt nichts von einem fremden Host, selbst wenn die API ihn nennt', () async {
      var contacted = false;
      // No allowedAssetHosts override: the production list applies here.
      // The URLs come from the GitHub response — trusted, but unverified.
      // This is exactly where a value from the network decides what the app
      // connects to and what it writes to disk.
      final service = UpdateService(
        client: MockClient((request) async {
          contacted = true;
          return http.Response(payload, 200);
        }),
      );

      final result = await service.downloadAndVerify(
        assets: assets,
        assetName: assetName,
        targetPath: '${tmp.path}/$assetName',
      );

      expect(result.status, UpdateDownloadStatus.unavailable);
      expect(contacted, isFalse, reason: 'ein nicht erlaubter Host darf nicht einmal kontaktiert werden');
    });

    test('meldet failed statt zu werfen, wenn das Netz wegbricht', () async {
      final service = UpdateService(
        allowedAssetHosts: fakeHosts,
        client: MockClient((request) async => throw const SocketException('no network')),
      );

      final result = await service.downloadAndVerify(
        assets: assets,
        assetName: assetName,
        targetPath: '${tmp.path}/$assetName',
      );

      expect(result.status, UpdateDownloadStatus.failed);
    });
  });
}

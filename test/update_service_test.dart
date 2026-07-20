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
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0',
            'html_url': 'https://github.com/kreativ-anders/finanzgecko/releases/tag/v2.0.0',
          }),
          200,
        );
      });
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.updateAvailable);
      expect(result.latestVersion, 'v2.0.0');
      expect(result.releaseUrl, 'https://github.com/kreativ-anders/finanzgecko/releases/tag/v2.0.0');
    });

    test(
      'meldet upToDate, wenn die installierte Version bereits die neueste ist (Build-Nummer wird ignoriert)',
      () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'tag_name': 'v1.3.3', 'html_url': 'https://x'}), 200),
        );
        final service = UpdateService(client: client);

        final result = await service.checkForUpdate(currentVersion: '1.3.3+9');

        expect(result.status, UpdateCheckStatus.upToDate);
      },
    );

    test('meldet upToDate, wenn die installierte Version neuer ist als der veröffentlichte Tag', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'tag_name': 'v1.0.0', 'html_url': 'https://x'}), 200),
      );
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
      final client = MockClient((request) async => http.Response(jsonEncode({'html_url': 'https://x'}), 200));
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.failed);
    });

    test('meldet failed bei nicht-semver-artigem Tag statt zu werfen', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'tag_name': 'nightly-build', 'html_url': 'https://x'}), 200),
      );
      final service = UpdateService(client: client);

      final result = await service.checkForUpdate(currentVersion: '1.3.3');

      expect(result.status, UpdateCheckStatus.failed);
    });
  });
}

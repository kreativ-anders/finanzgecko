import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the claims the project makes *about itself* in prose.
///
/// Sibling of `gherkin_sync_test.dart`: that one keeps spec, code and tests
/// linked; this one keeps the README, the website and the docs from asserting
/// things the code stopped doing. Both run inside `flutter test`, so the
/// release gate covers them.
///
/// **Why this exists.** The README claimed "unsigned builds trigger
/// Gatekeeper/SmartScreen warnings" and "no in-app auto-updater" for weeks
/// after both had become false. Nothing was broken, no test failed, and the
/// only reason it surfaced was somebody reading the file. Prose about
/// behaviour rots exactly like code, but without a compiler.
///
/// **What belongs here — and what does not.** Only claims that are
/// *mechanically decidable*: a value stated in two files, a hostname the app
/// can reach, a phrase that became false on a known date. Anything needing
/// judgement stays a human rule in CLAUDE.md. A doc linter that cries wolf
/// gets muted, and then it protects nothing.
///
/// **How to extend it.** Every prose "keep these in sync" warning in CLAUDE.md
/// is a candidate. When one of them bites again, convert it into a test here
/// instead of only fixing the text — that is the whole point.
void main() {
  String read(String path) => File(path).readAsStringSync();

  bool exists(String path) => File(path).existsSync();

  group('Netzwerk-Endpunkte sind vollständig offengelegt', () {
    // Extracted from the code, not from a hand-maintained list: a new endpoint
    // added in lib/ shows up here automatically instead of waiting to be
    // noticed.
    Set<String> endpointsInCode() {
      final hosts = <String>{};
      final pattern = RegExp(r'https?://([a-z0-9.-]+)');
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final m in pattern.allMatches(file.readAsStringSync())) {
          hosts.add(m.group(1)!);
        }
      }
      // The project's own site and the repo are link targets the user clicks,
      // not calls the app makes on its own — the privacy claim is about the
      // latter.
      hosts.removeWhere((h) => h == 'finanzgecko.app' || h == 'github.com');
      return hosts;
    }

    test('die Datenschutzseite nennt jeden Host, den der Code aufrufen kann', () {
      final datenschutz = read('docs/datenschutz.html');
      for (final host in endpointsInCode()) {
        expect(
          datenschutz.contains(host),
          isTrue,
          reason:
              '"$host" wird im Code aufgerufen, steht aber nicht in docs/datenschutz.html.\n'
              'Eine deutsche Seite, die einen nicht offengelegten Dienst kontaktiert, ist das '
              'einzige Versäumnis hier mit rechtlichem Gewicht — bitte ergänzen, nicht diesen '
              'Test anpassen.',
        );
      }
    });

    // Tripwire, deliberately exact. It is not "two is the right number"; it is
    // "if this number changes, four documents and a privacy claim need a human
    // decision". CLAUDE.md lists them.
    test('die Anzahl externer Endpunkte ist unverändert (sonst: vier Dokumente prüfen)', () {
      expect(
        endpointsInCode(),
        {'api.frankfurter.dev', 'api.github.com'},
        reason:
            'Die Menge der externen Hosts hat sich geändert.\n'
            'Bei jeder Änderung müssen mitgezogen werden: docs/datenschutz.html, docs/llms.txt, '
            'docs/index.html und AI_MASTER.md — dort steht jeweils die Aussage, welche '
            'Verbindungen die App überhaupt aufbauen kann.',
      );
    });
  });

  group('Release-Asset-Endungen sind dreifach gekoppelt', () {
    // lib/utils/update_assets.dart is the source of truth: it is the one the
    // running app uses to find its own update file.
    Set<String> suffixesInCode() {
      final source = read('lib/utils/update_assets.dart');
      return RegExp(r"=> '(-[^']+)'").allMatches(source).map((m) => m.group(1)!).toSet();
    }

    test('docs/download.html nennt exakt dieselben Endungen', () {
      final html = read('docs/download.html');
      final inHtml = RegExp(r'data-asset-suffix="([^"]+)"').allMatches(html).map((m) => m.group(1)!).toSet();
      expect(
        inHtml,
        suffixesInCode(),
        reason:
            'data-asset-suffix in docs/download.html weicht von updateAssetSuffixFor() ab.\n'
            'Folge im Alltag: die Download-Seite findet das Asset nicht und fällt STILL auf die '
            'Release-Seite zurück — ohne Fehlermeldung, ohne dass es jemandem auffällt.',
      );
    });

    test('die Artefaktnamen im Release-Workflow enthalten dieselben Endungen', () {
      final workflow = read('.github/workflows/release.yml');
      for (final suffix in suffixesInCode()) {
        expect(
          workflow.contains(suffix),
          isTrue,
          reason:
              '"$suffix" kommt in .github/workflows/release.yml nicht vor.\n'
              'Wird ein Artefakt dort umbenannt, müssen lib/utils/update_assets.dart und '
              'docs/download.html mitgezogen werden.',
        );
      }
    });
  });

  group('Der dokumentierte Datenpfad stimmt mit dem Code überein', () {
    test('AI_MASTER.md und dev/setup.md nennen den aktuellen macOS-Pfad', () {
      final source = read('lib/data/app_store.dart');
      final macDirName = RegExp(r"_macOsDirectoryName = '([^']+)'").firstMatch(source)?.group(1);
      expect(macDirName, isNotNull, reason: '_macOsDirectoryName nicht mehr in app_store.dart gefunden.');

      for (final doc in ['AI_MASTER.md', 'dev/setup.md']) {
        expect(
          read(doc).contains('Application Support/$macDirName'),
          isTrue,
          reason:
              '$doc nennt nicht den Pfad, den resolveDataDirectory() unter macOS tatsächlich baut '
              '("Application Support/$macDirName"). Der Ordnername ist in beiden Dateien dokumentiert.',
        );
      }
    });
  });

  group('Aussagen, die einmal falsch waren, kommen nicht zurück', () {
    // Each entry is a regression, not a style preference: the phrase was in the
    // repo, described behaviour that had already changed, and shipped that way.
    // Dates say when the claim became false.
    const stale = <({String phrase, List<String> files, String why})>[
      (
        phrase: 'unsigned builds trigger',
        files: ['README.md', 'dev/troubleshooting.md'],
        why: 'macOS wird seit 2026-08-12 signiert und von Apple geprüft — es erscheint keine Warnung mehr.',
      ),
      (
        phrase: 'No in-app auto-updater',
        files: ['README.md', 'dev/troubleshooting.md'],
        why: '"Nach Updates suchen" gibt es seit v1.7; es prüft nur auf Klick, aber es existiert.',
      ),
      (
        phrase: 'right-click → *Open*',
        files: ['README.md', 'dev/troubleshooting.md'],
        why: 'Der Gatekeeper-Umweg ist seit der Notarisierung gegenstandslos.',
      ),
    ];

    for (final claim in stale) {
      test('"${claim.phrase}" steht nirgends mehr', () {
        for (final file in claim.files) {
          if (!exists(file)) continue;
          expect(
            read(file).contains(claim.phrase),
            isFalse,
            reason: '$file behauptet wieder "${claim.phrase}".\n${claim.why}',
          );
        }
      });
    }
  });

  group('Nutzertexte bleiben ohne Fachjargon', () {
    // Manuel's rule (2026-08-13): the website says "Signiert und von Apple
    // geprüft". Nobody outside this repo knows what notarization is, and a
    // security claim nobody understands reassures nobody.
    //
    // Scope is deliberately docs/ only. Code comments in lib/ are for
    // developers and SHOULD use the precise terms.
    const bannedInUserFacingText = ['notarisiert', 'Notarisierung', 'Gatekeeper', 'Hardened Runtime', 'codesign'];

    test('docs/ verwendet keine Signatur-Fachbegriffe', () {
      final offenders = <String>[];
      for (final file in Directory('docs').listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.html') && !file.path.endsWith('.txt')) continue;
        final content = file.readAsStringSync();
        for (final term in bannedInUserFacingText) {
          if (content.toLowerCase().contains(term.toLowerCase())) {
            offenders.add('${file.path}: "$term"');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Fachjargon in Nutzertexten:\n${offenders.join('\n')}\n'
            'Stattdessen: "Signiert und von Apple geprüft."',
      );
    });
  });
}

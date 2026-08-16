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

  group('Die genannte macOS-Mindestversion stimmt mit dem Build überein', () {
    // Bis v1.8 stand auf der Seite gar keine Mindestversion — bei einem Ziel von
    // 10.15 traf sie niemanden. Mit 12 ist das anders: wer auf macOS 11 lädt,
    // bekommt ein DMG, das sich nicht öffnet, und die Seite erklärt es nicht.
    // Die Zahl steht damit an zwei Orten und driftet beim nächsten Anheben.
    test('docs/download.html nennt das Deployment-Target aus dem Xcode-Projekt', () {
      final pbxproj = read('macos/Runner.xcodeproj/project.pbxproj');
      final targets = RegExp(
        r'MACOSX_DEPLOYMENT_TARGET = ([0-9]+)(?:\.[0-9]+)*;',
      ).allMatches(pbxproj).map((m) => m.group(1)!).toSet();

      expect(targets, hasLength(1), reason: 'Uneinheitliche MACOSX_DEPLOYMENT_TARGET-Werte: $targets');
      final major = targets.single;

      expect(
        read('docs/download.html').contains('macOS $major oder neuer'),
        isTrue,
        reason:
            'Das Xcode-Projekt baut für macOS $major, docs/download.html nennt das nicht.\n'
            'Ohne diese Angabe lädt jemand mit einer älteren macOS-Version ein DMG herunter, das sich '
            'wortlos nicht öffnet — der Fall, für den eine Downloadseite da ist.',
      );
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
      (
        phrase: 'keinen Auto-Updater',
        files: ['docs/index.html', 'docs/download.html', 'docs/documentation.html'],
        why:
            'Die deutsche Entsprechung derselben Falschaussage — und die teurere, weil sie auf der '
            'Startseite stand. "Nach Updates suchen" lädt seit v1.7 die passende Datei, prüft sie '
            'gegen SHA256SUMS und legt sie ab; das FAQ schickte Leute trotzdem von Hand zu GitHub.',
      ),
      (
        phrase: 'Klartext-JSON',
        files: ['docs/index.html', 'docs/download.html', 'docs/documentation.html'],
        why:
            'Backups lassen sich seit v1.7 mit einem selbst vergebenen Passwort schützen '
            '(data/backup_crypto.dart). Ohne diesen Zusatz sagt der Satz datenschutzbewussten '
            'Leser:innen das Gegenteil dessen, was die App kann.',
      ),
      (
        phrase: 'linken Navigation',
        files: ['docs/documentation.html'],
        why: 'Die Navigation liegt am oberen Rand (ui/navigation_shell.dart), nicht links.',
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

    // Manuel's rule (2026-08-16): "keep the install wording generic". Generic
    // in TONE, specific in FACT — a shared paragraph may explain why a computer
    // asks about downloaded software at all, but the per-OS line must stay
    // true. macOS is signed and checked by Apple and shows nothing; only
    // Windows warns. This is the same claim `stale` already guards for the
    // README, one abstraction up: it stops the *next* rewrite from tidying the
    // three cards into one warning sentence.
    //
    // Block-level, not sentence-level: the download cards carry no sentence
    // punctuation, so splitting on ". " glues all three into one string and the
    // Windows card's "SmartScreen-Warnung" lands next to the macOS card. A doc
    // linter that cries wolf gets muted.
    test('keine Nutzerseite schreibt macOS eine Warnung zu', () {
      const warningWords = ['Warnung', 'warnt', 'blockiert', 'SmartScreen'];
      final blockPattern = RegExp(r'<(p|li|summary|h1|h2|h3)\b[^>]*>(.*?)</\1>', dotAll: true);
      final offenders = <String>[];

      for (final file in Directory('docs').listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.html')) continue;
        final source = stripNonProse(file.readAsStringSync());
        for (final block in blockPattern.allMatches(source)) {
          final text = plainText(block.group(2)!);
          if (!text.contains('macOS')) continue;
          for (final word in warningWords) {
            if (text.toLowerCase().contains(word.toLowerCase())) {
              offenders.add('${file.path}: "$word" im selben Absatz wie "macOS" — «${_clip(text)}»');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Eine Nutzerseite behauptet wieder, macOS warne:\n${offenders.join('\n')}\n'
            'macOS-Builds sind signiert und von Apple geprüft und starten ohne Rückfrage — nur '
            'Windows zeigt einen Hinweis. Den Text pro Betriebssystem trennen, nicht '
            'zusammenfassen.',
      );
    });

    // The entry sentence is where non-technical readers bounce: the page used
    // to open with "nativer Desktop-Vermögenstracker für Linux, macOS und
    // Windows … AES-256-verschlüsselt", and the first question a real first-time
    // reader asked was "what is Linux, Windows, macOS?". Operating systems are a
    // download decision, not an opening line.
    //
    // Deliberately scoped to the VISIBLE hero only. <title>, meta description
    // and Open Graph keep the platform keywords on purpose — different audience,
    // different job. Do not "harmonise" the two.
    test('die Startseite öffnet ohne Betriebssystem- und Krypto-Vokabular', () {
      const banned = ['AES', 'GCM', 'nativ', 'Linux', 'macOS', 'Windows', 'Keychain'];
      final source = read('docs/index.html');

      final h1 = RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true).firstMatch(source)?.group(1);
      final pitch = RegExp(r'<p class="pitch"[^>]*>(.*?)</p>', dotAll: true).firstMatch(source)?.group(1);
      expect(h1, isNotNull, reason: 'Kein <h1> in docs/index.html gefunden.');
      expect(pitch, isNotNull, reason: 'Kein <p class="pitch"> in docs/index.html gefunden.');

      final hero = plainText('$h1 $pitch').toLowerCase();
      final offenders = banned.where((t) => hero.contains(t.toLowerCase())).toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'Der erste Bildschirm nennt wieder $offenders.\n'
            'Betriebssysteme gehören zu den Download-Karten, die Verschlüsselung ins FAQ — '
            'nicht in den Satz, der erklären soll, wofür die App überhaupt gut ist. '
            '<title>/meta dürfen die Begriffe weiterhin führen, die sind für Suchmaschinen.',
      );
    });
  });

  group('Die Dokumentation beschreibt, was die App wirklich zeigt', () {
    // Both lists drifted silently: the website named three Kennzahlen where the
    // app rendered six, and five Einstellungen where it has eight — including
    // the exchange-rate consent, exactly the control a privacy-minded reader
    // goes looking for. Extracted from the code so a new tile or section fails
    // here instead of waiting to be noticed.
    test('documentation.html nennt jede Kennzahl des Dashboards', () {
      final source = read('lib/ui/views/dashboard_view.dart');
      final cardIndex = source.indexOf("title: 'Kennzahlen'");
      expect(cardIndex, greaterThan(-1), reason: "Die Kennzahlen-SectionCard heißt nicht mehr 'Kennzahlen'.");

      final tilesIndex = source.lastIndexOf('final tiles', cardIndex);
      expect(tilesIndex, greaterThan(-1), reason: 'Die Kachel-Liste vor der Kennzahlen-Karte wurde umbenannt.');

      final labels = RegExp(
        r"label: '([^']+)'",
      ).allMatches(source.substring(tilesIndex, cardIndex)).map((m) => m.group(1)!).toList();
      expect(labels, isNotEmpty, reason: 'Keine Kachel-Labels gefunden — Extraktion prüfen.');

      final docs = read('docs/documentation.html');
      for (final label in labels) {
        expect(
          docs.contains(label),
          isTrue,
          reason:
              'Das Dashboard zeigt die Kennzahl "$label", docs/documentation.html nennt sie nicht.\n'
              'Die Liste dort muss wörtlich dieselben Labels führen — sonst sucht jemand in der App '
              'nach etwas, das anders heißt.',
        );
      }
    });

    test('documentation.html nennt jeden Abschnitt der Einstellungen', () {
      final source = read('lib/ui/views/settings_view.dart');
      final titles = RegExp(
        r"SectionCard\((?:[^()]|\([^()]*\))*?title: '([^']+)'",
        dotAll: true,
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      expect(titles, isNotEmpty, reason: 'Keine SectionCard-Titel gefunden — Extraktion prüfen.');

      final docs = read('docs/documentation.html');
      for (final title in titles) {
        expect(
          docs.contains(title),
          isTrue,
          reason:
              'Die Einstellungen haben einen Abschnitt "$title", docs/documentation.html erwähnt ihn nicht.\n'
              'Undokumentierte Einstellungen sind besonders teuer, wenn sie — wie "Wechselkurse" — '
              'darüber entscheiden, ob die App ins Netz geht.',
        );
      }
    });
  });
}

/// Strips everything that is markup or machinery rather than prose, so the
/// prose checks never trip over a `<script>` payload or an HTML comment.
String stripNonProse(String html) => html
    .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
    .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
    .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// Tags out, entities in, whitespace collapsed.
String plainText(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&#8220;', '"')
    .replaceAll('&#8222;', '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _clip(String text) => text.length <= 120 ? text : '${text.substring(0, 117)}…';

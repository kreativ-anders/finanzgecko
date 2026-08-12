import 'dart:io';

/// Reine, UI- und netzfreie Logik rund um die Update-Dateien eines Releases:
/// welches Release-Asset gehört zu dieser Plattform, und passt eine
/// heruntergeladene Datei zur veröffentlichten Prüfsumme.
///
/// Bewusst ohne Netz- und Dateizugriff, damit beides ohne laufendes
/// Betriebssystem prüfbar bleibt — die Szenarien dazu stehen in
/// `gherkin/executable/update_assets.feature`.

/// Dateinamens-Endung des Release-Assets je Plattform.
///
/// **Dreifach gekoppelt** — dieselben Endungen stehen in den Artefaktnamen in
/// `.github/workflows/release.yml` und als `data-asset-suffix` in
/// `docs/download.html`. Wird dort ein Dateiname geändert, müssen alle drei
/// Stellen mitgezogen werden; sonst findet der Update-Fluss das Asset nicht
/// mehr und fällt still auf die Download-Seite zurück.
String? updateAssetSuffixFor(String operatingSystem) => switch (operatingSystem) {
  'macos' => '-mac.dmg',
  'windows' => '-Setup.exe',
  'linux' => '-x86_64.AppImage',
  _ => null,
};

/// Endung für die gerade laufende Plattform (null auf allem, wofür es kein
/// Release-Artefakt gibt).
String? get currentUpdateAssetSuffix => updateAssetSuffixFor(Platform.operatingSystem);

/// Wählt aus den Asset-Namen eines Releases den zur Plattform passenden aus.
///
/// Null, wenn keiner passt — etwa weil ein Plattform-Build fehlgeschlagen ist
/// oder die Plattform unbekannt ist. Der Aufrufer öffnet dann die
/// Download-Seite, statt eine falsche Datei zu raten.
String? selectAssetName(Iterable<String> assetNames, String operatingSystem) {
  final suffix = updateAssetSuffixFor(operatingSystem);
  if (suffix == null) return null;
  for (final name in assetNames) {
    if (name.endsWith(suffix)) return name;
  }
  return null;
}

/// Parst eine `SHA256SUMS`-Datei im Standardformat von `sha256sum`
/// (`<64 Hex-Zeichen><Leerraum>[*]<Dateiname>`, eine Zeile je Datei) zu
/// Dateiname → Hash in Kleinschreibung.
///
/// Nicht passende Zeilen werden übersprungen statt zu werfen: die Datei kommt
/// aus einem Release, nicht aus einer Nutzereingabe, und ein einzelner
/// Fremdeintrag darf die Prüfung der übrigen Dateien nicht verhindern.
Map<String, String> parseChecksums(String content) {
  final result = <String, String>{};
  // split('\n') statt LineSplitter: ein verbleibendes \r fällt beim trim() der
  // Zeile ohnehin weg, das spart den dart:convert-Import.
  for (final line in content.split('\n')) {
    final match = _checksumLine.firstMatch(line.trim());
    if (match == null) continue;
    result[match.group(2)!.trim()] = match.group(1)!.toLowerCase();
  }
  return result;
}

/// `*` vor dem Dateinamen markiert bei `sha256sum` den Binärmodus und gehört
/// nicht zum Namen.
final RegExp _checksumLine = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$');

/// Name der Prüfsummen-Datei, die der `release`-Job jedem Release beilegt.
const String checksumsAssetName = 'SHA256SUMS';

/// Wandelt einen Hash in seine Hex-Darstellung.
///
/// `padLeft(2, '0')` ist hier das Entscheidende: ohne das würde jedes Byte
/// unter 0x10 einstellig ausgegeben, der Digest wäre zu kurz und JEDER
/// Vergleich schlüge fehl — ein Fehler, der nur bei bestimmten Dateien
/// aufträte und darum leicht durchrutscht. Deshalb unten eigens spezifiziert.
String hexEncode(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Vergleicht zwei Hex-Digests unabhängig von Groß-/Kleinschreibung.
///
/// Bewusst KEIN konstantzeitiger Vergleich: hier wird eine öffentliche
/// Prüfsumme gegen eine gerade selbst berechnete gehalten: es gibt kein
/// Geheimnis, dessen Laufzeit etwas verraten könnte.
bool digestMatches(String expected, String actual) => expected.trim().toLowerCase() == actual.trim().toLowerCase();

# Troubleshooting

**`flutter doctor`: "Linux toolchain" ✗ / `clang++` fehlt:**
`sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev` (siehe [setup.md](setup.md)).

**App startet, kein Icon in der Taskleiste (Linux):** Erwartet bei direkt aus `build/` gestartetem Bundle —
`./packaging/linux/install.sh` ausführen (siehe [building.md](building.md)).

**Windows: kein Icon in Taskleiste/Titelleiste**, auch nach `dart run tool/generate_icons.dart` + Neubau: liegt
meist nicht an der `.ico`, sondern an einer verwaisten Verknüpfung. `local_notifier` registriert beim ersten Start
eine AUMID samt Startmenü-Verknüpfung (`%APPDATA%\Microsoft\Windows\Start Menu\Programs\FinanzGecko.lnk`); zeigt sie
auf einen inzwischen gelöschten/verschobenen Pfad, bleibt die Taskleiste für jeden späteren Build leer. Beheben:
`finanzgecko.exe` beenden, `.lnk`-Datei löschen, App neu starten — die Verknüpfung wird mit dem aktuellen Pfad neu
angelegt.

**`flutter build windows` bricht mit CMake-/MSBuild-Fehler ab:** Workload "Desktop development with C++" fehlt,
siehe [setup.md](setup.md).

**`flutter doctor` bricht unter Windows mit `PathNotFoundException` bei einem `AndroidStudioXXXX.X\.home`-Pfad ab:**
Bekanntes Flutter-Verhalten bei verwaister AppData-Restspur einer deinstallierten Android-Studio-Version. Für diese
App irrelevant (kein Android-Target) — ignorieren oder den Ordner unter `%LOCALAPPDATA%\Google\` löschen.

**macOS: Absturz beim ersten Start mit `PlatformException(..., -34018, "A required entitlement isn't present.")`:**
Siehe [architecture.md](architecture.md#warum-keine-datenbank-engine) — Fix ist
`MacOsOptions(usesDataProtectionKeychain: false)` in `lib/data/secure_key_store.dart`. Tritt nur auf, falls dieser
Parameter versehentlich entfernt wird.

**Wechselkurs-Abfrage schlägt fehl / "offline":** Kein Fehler — bewusster Offline-Fallback. Bei fehlendem
Netzwerkzugriff und keinem gecachten Kurs fragt die App nach einem manuell eingegebenen Kurs.

## Bekannte Einschränkungen

- **Kein In-App-Auto-Updater.** Update = neues Release-Artefakt laden (Installer erneut ausführen, AppImage
  ersetzen, `.app` ersetzen). Das Datenverzeichnis hängt nur vom Datenpfad ab, nicht vom Installationsort —
  bestehende Nutzerdaten bleiben unberührt.
- **Erster Start auf einem fremden Mac/Windows-Rechner:** Ohne Code-Signierung zeigen macOS Gatekeeper und Windows
  SmartScreen eine Warnung. Mac: Rechtsklick → *Öffnen*. Windows: "Weitere Informationen" → "Trotzdem ausführen".
  Ein kostenpflichtiges Signierzertifikat würde das beheben; `flutter build macos` signiert bereits ad-hoc, das
  reicht nur für den eigenen Rechner.

## Migration von einer früheren Version

Läuft über Export/Import: alte Version → *Einstellungen → Backup exportieren…*, neue Version → *Backup
importieren…* (Schema/Feldnamen identisch). Derselbe Weg dient auch einem Rechnerwechsel oder als zusätzliche
Sicherung. Ein Import prüft die Schemaversion und lehnt Backups aus einer neueren App-Version ab, statt sie
unvollständig einzulesen.

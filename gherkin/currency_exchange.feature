# Quelle: lib/services/currency_service.dart, lib/ui/widgets/manual_rate_dialog.dart,
#   lib/ui/widgets/rate_consent_dialog.dart, lib/data/app_store.dart
# Implementierung: lib/services/currency_service.dart
@currency
Feature: Wechselkurse — Zustimmung, Abruf, Cache und manueller Fallback
  Als Nutzer:in mit Konten/Fixposten in Fremdwährung möchte ich, dass die App aktuelle Wechselkurse verwendet —
  aber erst, nachdem ich den Abruf erlaubt habe — und auch offline oder bei einer API-Störung weiterarbeitet.

  Rule: Zustimmung zum Abruf (Opt-in)

    Scenario: Vor der ersten Entscheidung geht nichts ins Netz
      Given es wurde noch nie nach der Zustimmung gefragt (Zustand "unset")
      Then behandelt die App das wie eine Ablehnung und ruft keinen Kurs ab
      And der lokale Kurs-Cache darf trotzdem gelesen werden — er liegt auf diesem Gerät, dafür wird niemand
        kontaktiert

    Scenario: Gefragt wird im Erfassungsmoment, nicht beim Öffnen einer Ansicht
      Given der Zustand ist "unset"
      When ich einen Kontostand oder Fixposten in einer Fremdwährung speichere
      Then erscheint einmalig der Dialog "Wechselkurse online abrufen?" mit den Optionen "Kurse abrufen" und
        "Nicht abrufen"
      And derselbe Dialog erscheint niemals beim bloßen Öffnen einer Ansicht, insbesondere nicht in den
        Einstellungen
      Given Quell- und Zielwährung sind identisch
      Then wird gar nicht gefragt — ohne Umrechnung gibt es nichts zu entscheiden

    Scenario: Dialog wegklicken entscheidet nichts
      Given der Dialog "Wechselkurse online abrufen?" ist offen
      When ich ihn schließe, ohne eine der beiden Optionen zu wählen
      Then bleibt der gespeicherte Zustand "unset"
      And die aktuelle Aktion läuft auf dem Offline-Pfad weiter (Cache, sonst manueller Kurs)
      And beim nächsten Kursbedarf wird erneut gefragt

    Scenario: Entscheidung ist in den Einstellungen sichtbar und umkehrbar
      Given ich öffne Einstellungen → Wechselkurse
      Then sehe ich den aktuellen Zustand als Auswahl "Noch nicht entschieden" / "Abrufen" / "Nicht abrufen"
      And dieser Abschnitt ist auch dann schon sichtbar, wenn noch nie gefragt wurde
      And das Anzeigen löst weder einen Abruf noch einen Dialog aus
      When ich die Auswahl ändere
      Then gilt die neue Entscheidung ab dem nächsten Kursbedarf

    Scenario: Ablehnung gilt auch für die Diagnose
      Given der Abruf ist nicht erlaubt ("unset" oder "denied")
      When ich Einstellungen → Hilfe öffne oder die Debug-Informationen kopiere
      Then wird die Erreichbarkeit der Kurs-API nicht geprüft, sondern als "Nicht geprüft (Abruf nicht erlaubt)"
        ausgewiesen
      Given der Abruf ist erlaubt
      Then prüft die App die Erreichbarkeit trotzdem erst auf Klick auf "Jetzt prüfen", nicht beim Öffnen

    Scenario: Bestehende Installationen werden nicht stillschweigend übernommen
      Given eine Datendatei wurde vor diesem Feature geschrieben und kennt den Schlüssel nicht
      When die App sie lädt
      Then ergibt sich der Zustand "unset" statt einer angenommenen Zustimmung
      And beim nächsten Kursbedarf wird einmalig gefragt

  Rule: Abruf, Cache und manueller Fallback

    Scenario: Gleiche Quell- und Zielwährung braucht keinen API-Aufruf
      Given Quell- und Zielwährung sind identisch
      Then liefert die App sofort einen Kurs von 1 (Quelle "identity"), ohne Netzwerkaufruf

    Scenario: Live-Kursabruf bei unterschiedlichen Währungen
      Given Quell- und Zielwährung unterscheiden sich
      And der Abruf ist erlaubt
      And die Frankfurter.dev-API ist erreichbar
      When ein Kurs für ein Datum ("YYYY-MM-DD") angefragt wird
      Then liefert die App den Kurs von der API (Quelle "live")
      And der Kurs wird unter dem Schlüssel "<von>_<nach>_<datum>" im Kurs-Cache gespeichert

    Scenario: Cache-Fallback bei nicht erreichbarer API
      Given die API ist nicht erreichbar (Timeout nach 10 Sekunden, HTTP-Fehler oder ungültige Antwort)
      And für dieselbe Kombination aus Währungspaar und Datum existiert bereits ein gecachter Kurs
      Then liefert die App diesen gecachten Kurs (Quelle "cache")

    Scenario: Weder API noch Cache verfügbar
      Given die API ist nicht erreichbar
      And für dieses Währungspaar+Datum existiert kein gecachter Kurs
      Then liefert der Service keinen Kurs (null)
      And die aufrufende Ansicht fragt den Nutzer nach einem manuellen Kurs

    Scenario: Manuellen Kurs eingeben
      Given ein Dialog "Kein Wechselkurs verfügbar" wird angezeigt für "1 <von> = ? <nach>"
      When ich eine positive Zahl eingebe und auf "Übernehmen" klicke
      Then wird dieser Kurs für die aktuelle Aktion (Kontostand oder Fixposten speichern) verwendet
      And er wird NICHT automatisch in den persistenten Kurs-Cache übernommen (nur einmalige Verwendung)

    Scenario: Manuellen Kurs-Dialog abbrechen oder ungültig ausfüllen
      Given der Dialog "Kein Wechselkurs verfügbar" ist offen
      When ich auf "Abbrechen" klicke, das Feld leer lasse, oder eine Zahl ≤0 eingebe
      Then liefert der Dialog null
      And die aufrufende Aktion (Speichern des Kontostands/Fixpostens) wird abgebrochen bzw. schlägt fehl

    Scenario: Kurs-Cache liegt getrennt von der verschlüsselten Datenbank
      Given ein Kurs wurde frisch von der API abgerufen und gecacht
      Then wird ausschließlich die kleine Klartextdatei "finanzgecko-rates.json" geschrieben
      And die verschlüsselte Hauptdatenbank-Datei wird dafür NICHT neu geschrieben

    Scenario: Migration alter Kurs-Caches aus der Datenbank
      Given eine ältere Installation hat Kurse noch innerhalb der verschlüsselten Datenbank gespeichert
      When die App zum ersten Mal mit der neuen Version startet
      Then werden diese Kurse einmalig in die separate Klartext-Kursdatei übernommen
      And anschließend aus der verschlüsselten Datenbank entfernt

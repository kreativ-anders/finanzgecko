# Quelle: lib/services/currency_service.dart, lib/ui/widgets/manual_rate_dialog.dart, lib/data/app_store.dart
# Implementierung: lib/services/currency_service.dart
@currency
Feature: Wechselkurse — Abruf, Cache und manueller Fallback
  Als Nutzer:in mit Konten/Fixposten in Fremdwährung möchte ich, dass die App automatisch aktuelle Wechselkurse
  verwendet, aber auch offline oder bei einer API-Störung weiterarbeitet.

  Scenario: Gleiche Quell- und Zielwährung braucht keinen API-Aufruf
    Given Quell- und Zielwährung sind identisch
    Then liefert die App sofort einen Kurs von 1 (Quelle "identity"), ohne Netzwerkaufruf

  Scenario: Live-Kursabruf bei unterschiedlichen Währungen
    Given Quell- und Zielwährung unterscheiden sich
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

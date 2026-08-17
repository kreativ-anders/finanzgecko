# Source: lib/services/currency_service.dart, lib/ui/widgets/manual_rate_dialog.dart,
#   lib/ui/widgets/rate_consent_dialog.dart, lib/data/app_store.dart
# Implementation: lib/services/currency_service.dart
@currency
Feature: Exchange rates — consent, fetching, cache, and manual fallback
  As a user with Konten/Fixposten in a foreign currency, I want the app to use current exchange rates — but
  only after I've allowed fetching — and to keep working offline or during an API outage.

  Rule: Consent to fetch (opt-in)

    Scenario: Before the first decision, nothing goes over the network
      Given consent has never been asked for (state "unset")
      Then the app treats that as a refusal and fetches no rate
      And the local rate cache may still be read — it lives on this device, so nobody gets contacted for it

    Scenario: Consent is asked for at the moment of recording, not when a view opens
      Given the state is "unset"
      When I save a Kontostand or Fixposten in a foreign currency
      Then the dialog "Wechselkurse online abrufen?" appears once, with the options "Kurse abrufen" and
        "Nicht abrufen"
      And this same dialog never appears just from opening a view, in particular not in Einstellungen
      Given the source and target currency are identical
      Then no question is asked at all — with no conversion, there's nothing to decide

    Scenario: Dismissing the dialog decides nothing
      Given the "Wechselkurse online abrufen?" dialog is open
      When I close it without choosing either option
      Then the stored state stays "unset"
      And the current action continues on the offline path (cache, otherwise a manual rate)
      And the question is asked again the next time a rate is needed

    Scenario: The decision is visible and reversible in Einstellungen
      Given I open Einstellungen → Wechselkurse
      Then I see the current state as a choice of "Noch nicht entschieden" / "Abrufen" / "Nicht abrufen"
      And this section is already visible even if consent was never asked for
      And displaying it triggers neither a fetch nor a dialog
      When I change the selection
      Then the new decision applies from the next time a rate is needed

    Scenario: A refusal also applies to diagnostics
      Given fetching is not allowed ("unset" or "denied")
      When I open Einstellungen → Hilfe or copy the debug information
      Then the rate API's reachability is not checked, but reported as "Nicht geprüft (Abruf nicht erlaubt)"
      Given fetching is allowed
      Then the app still only checks reachability on a click on "Jetzt prüfen", not on open

    Scenario: Existing installations are not silently grandfathered in
      Given a data file was written before this feature existed and doesn't know the key
      When the app loads it
      Then the state resolves to "unset" instead of an assumed consent
      And the question is asked once the next time a rate is needed

  Rule: Fetching, cache, and manual fallback

    Scenario: The same source and target currency needs no API call
      Given the source and target currency are identical
      Then the app immediately returns a rate of 1 (source "identity"), with no network call

    Scenario: Live rate fetch for differing currencies
      Given the source and target currency differ
      And fetching is allowed
      And the Frankfurter.dev API is reachable
      When a rate for a date ("YYYY-MM-DD") is requested
      Then the app returns the rate from the API (source "live")
      And the rate is saved in the rate cache under the key "<von>_<nach>_<datum>"

    Scenario: Cache fallback when the API is unreachable
      Given the API is unreachable (timeout after 10 seconds, an HTTP error, or an invalid response)
      And a cached rate already exists for the same currency-pair-and-date combination
      Then the app returns that cached rate (source "cache")

    Scenario: Neither API nor cache available
      Given the API is unreachable
      And no cached rate exists for this currency pair+date
      Then the service returns no rate (null)
      And the calling view asks the user for a manual rate

    Scenario: The dialog states the actual reason
      Given no rate could be determined
      Then the dialog states the specific reason instead of a blanket "(offline?)"
      And without consent it reads "Der Online-Abruf … ist nicht erlaubt (Einstellungen → Wechselkurse)"
      And with consent given but the fetch failed, "… konnte nicht abgerufen werden (keine Verbindung oder
        Störung der API)"
      And the technical reason (HTTP status, timeout, parse error, consent state) is additionally logged
        via debugPrint

    Scenario: A failed cache write doesn't cost a rate
      Given a rate was successfully fetched from the API
      When writing the rates file fails (e.g. disk full, directory read-only)
      Then the fetched rate is still used
      And the failure is only logged, not reinterpreted as "no exchange rate available"

    Scenario: Enter a manual rate
      Given a "Kein Wechselkurs verfügbar" dialog is shown for "1 <von> = ? <nach>"
      When I enter a positive number and click "Übernehmen"
      Then this rate is used for the current action (saving a Kontostand or Fixposten)
      And it is NOT automatically stored in the persistent rate cache (one-time use only)

    Scenario: Cancel the manual rate dialog or fill it in invalidly
      Given the "Kein Wechselkurs verfügbar" dialog is open
      When I click "Abbrechen", leave the field empty, or enter a number ≤0
      Then the dialog returns null
      And the calling action (saving the Kontostand/Fixposten) is cancelled resp. fails

    Scenario: The rate cache lives separately from the encrypted database
      Given a rate was freshly fetched from the API and cached
      Then only the small plaintext file "finanzgecko-rates.json" is written
      And the encrypted main database file is NOT rewritten for this

    Scenario: Migration of old rate caches out of the database
      Given an older installation still has rates stored inside the encrypted database
      When the app starts for the first time with the new version
      Then these rates are moved once into the separate plaintext rates file
      And then removed from the encrypted database

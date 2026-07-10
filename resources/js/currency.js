// currency.js — Wechselkurse über die kostenlose Frankfurter.app API (EZB-Referenzkurse).
// Keine Library nötig, nur fetch(). Kurse werden lokal in IndexedDB gecacht,
// damit die App auch offline mit dem letzten bekannten Kurs weiterrechnen kann.

import { getCachedRate, setCachedRate } from "./store.js";

const API_BASE = "https://api.frankfurter.app";

function cacheKey(from, to, dateStr) {
  return `${from}_${to}_${dateStr}`;
}

// dateStr: "YYYY-MM-DD". Liefert { rate, source: "live"|"cache", date }.
// Wirft nur, wenn weder API noch Cache einen Kurs liefern können.
export async function getExchangeRate(from, to, dateStr) {
  if (from === to) {
    return { rate: 1, source: "identity", date: dateStr };
  }

  const key = cacheKey(from, to, dateStr);

  try {
    const url = `${API_BASE}/${dateStr}?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Frankfurter API: HTTP ${res.status}`);
    const data = await res.json();
    const rate = data.rates && data.rates[to];
    if (typeof rate !== "number") throw new Error("Kein Kurs in der Antwort enthalten");
    await setCachedRate(key, rate);
    return { rate, source: "live", date: data.date || dateStr };
  } catch (err) {
    // Offline oder API-Fehler: zuerst exakten Cache-Treffer versuchen ...
    const cached = await getCachedRate(key);
    if (cached != null) {
      return { rate: cached, source: "cache", date: dateStr };
    }
    // ... sonst None zurückgeben, damit main.js den Nutzer um eine manuelle
    // Eingabe des Kurses bitten kann.
    return null;
  }
}

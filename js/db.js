// db.js — kompletter IndexedDB-Zugriff der App.
// Schema:
//   accounts:  { id, name, bank, tag, currency, color, archived, createdAt }
//   balances:  { id, accountId, period ("YYYY-MM"), amountOriginal, currencyOriginal,
//                rate, amountBase, note, enteredAt }
//              -> unique index "byAccountPeriod" auf [accountId, period]
//   settings:  { key, value }
//   rates:     { key ("FROM_TO_YYYY-MM-DD"), rate, fetchedAt }

const DB_NAME = "vermoegenstracker";
const DB_VERSION = 1;

let dbInstance = null;

export function openDB() {
  if (dbInstance) return Promise.resolve(dbInstance);
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);

    req.onupgradeneeded = (event) => {
      const db = event.target.result;

      if (!db.objectStoreNames.contains("accounts")) {
        const accounts = db.createObjectStore("accounts", { keyPath: "id", autoIncrement: true });
        accounts.createIndex("byArchived", "archived");
      }

      if (!db.objectStoreNames.contains("balances")) {
        const balances = db.createObjectStore("balances", { keyPath: "id", autoIncrement: true });
        balances.createIndex("byAccount", "accountId");
        balances.createIndex("byAccountPeriod", ["accountId", "period"], { unique: true });
        balances.createIndex("byPeriod", "period");
      }

      if (!db.objectStoreNames.contains("settings")) {
        db.createObjectStore("settings", { keyPath: "key" });
      }

      if (!db.objectStoreNames.contains("rates")) {
        db.createObjectStore("rates", { keyPath: "key" });
      }
    };

    req.onsuccess = (event) => {
      dbInstance = event.target.result;
      resolve(dbInstance);
    };
    req.onerror = (event) => reject(event.target.error);
  });
}

function tx(storeNames, mode = "readonly") {
  return openDB().then((db) => db.transaction(storeNames, mode));
}

function reqToPromise(req) {
  return new Promise((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

// ---------- Accounts ----------

export async function addAccount(account) {
  const t = await tx("accounts", "readwrite");
  const store = t.objectStore("accounts");
  const record = {
    name: account.name,
    bank: account.bank || "",
    tag: account.tag,
    currency: account.currency || "EUR",
    color: account.color || "#00c878",
    archived: false,
    createdAt: new Date().toISOString(),
  };
  const id = await reqToPromise(store.add(record));
  return { ...record, id };
}

export async function updateAccount(id, changes) {
  const t = await tx("accounts", "readwrite");
  const store = t.objectStore("accounts");
  const existing = await reqToPromise(store.get(id));
  if (!existing) throw new Error("Konto nicht gefunden");
  const updated = { ...existing, ...changes, id };
  await reqToPromise(store.put(updated));
  return updated;
}

export async function archiveAccount(id) {
  return updateAccount(id, { archived: true });
}

export async function getAccounts({ includeArchived = false } = {}) {
  const t = await tx("accounts");
  const all = await reqToPromise(t.objectStore("accounts").getAll());
  return includeArchived ? all : all.filter((a) => !a.archived);
}

export async function getAccount(id) {
  const t = await tx("accounts");
  return reqToPromise(t.objectStore("accounts").get(id));
}

// ---------- Balances ----------

// Legt einen neuen Eintrag an oder überschreibt den bestehenden für
// (accountId, period), damit pro Konto/Monat nie Duplikate entstehen.
export async function upsertBalance(entry) {
  const t = await tx("balances", "readwrite");
  const store = t.objectStore("balances");
  const idx = store.index("byAccountPeriod");
  const existing = await reqToPromise(idx.get([entry.accountId, entry.period]));

  const record = {
    accountId: entry.accountId,
    period: entry.period, // "YYYY-MM"
    amountOriginal: entry.amountOriginal,
    currencyOriginal: entry.currencyOriginal,
    rate: entry.rate,
    amountBase: entry.amountBase,
    note: entry.note || "",
    enteredAt: new Date().toISOString(),
  };

  if (existing) {
    record.id = existing.id;
    await reqToPromise(store.put(record));
    return record;
  } else {
    const id = await reqToPromise(store.add(record));
    return { ...record, id };
  }
}

export async function deleteBalance(id) {
  const t = await tx("balances", "readwrite");
  await reqToPromise(t.objectStore("balances").delete(id));
}

export async function getBalancesForAccount(accountId) {
  const t = await tx("balances");
  const idx = t.objectStore("balances").index("byAccount");
  const all = await reqToPromise(idx.getAll(accountId));
  return all.sort((a, b) => (a.period < b.period ? -1 : 1));
}

export async function getAllBalances() {
  const t = await tx("balances");
  const all = await reqToPromise(t.objectStore("balances").getAll());
  return all.sort((a, b) => (a.period < b.period ? -1 : 1));
}

export async function getBalanceForAccountPeriod(accountId, period) {
  const t = await tx("balances");
  const idx = t.objectStore("balances").index("byAccountPeriod");
  return reqToPromise(idx.get([accountId, period]));
}

// ---------- Settings ----------

export async function getSetting(key, fallback = null) {
  const t = await tx("settings");
  const rec = await reqToPromise(t.objectStore("settings").get(key));
  return rec ? rec.value : fallback;
}

export async function setSetting(key, value) {
  const t = await tx("settings", "readwrite");
  await reqToPromise(t.objectStore("settings").put({ key, value }));
}

// ---------- Rate cache ----------

export async function getCachedRate(key) {
  const t = await tx("rates");
  const rec = await reqToPromise(t.objectStore("rates").get(key));
  return rec ? rec.rate : null;
}

export async function setCachedRate(key, rate) {
  const t = await tx("rates", "readwrite");
  await reqToPromise(t.objectStore("rates").put({ key, rate, fetchedAt: new Date().toISOString() }));
}

// ---------- Export / Import ----------

export async function exportAllData() {
  const [accounts, balances] = await Promise.all([
    getAccounts({ includeArchived: true }),
    getAllBalances(),
  ]);
  const baseCurrency = await getSetting("baseCurrency", "EUR");
  return {
    schemaVersion: 1,
    exportedAt: new Date().toISOString(),
    baseCurrency,
    accounts,
    balances,
  };
}

// Ersetzt ALLE vorhandenen Daten durch den Inhalt der Import-Datei.
// Vor dem Ersetzen wird automatisch ein Snapshot der aktuellen Daten
// zurückgegeben, damit main.js einen Undo anbieten kann.
export async function importAllData(data) {
  const snapshot = await exportAllData();

  const t = await tx(["accounts", "balances", "settings"], "readwrite");
  const accStore = t.objectStore("accounts");
  const balStore = t.objectStore("balances");
  const setStore = t.objectStore("settings");

  await reqToPromise(accStore.clear());
  await reqToPromise(balStore.clear());

  for (const acc of data.accounts || []) {
    await reqToPromise(accStore.put(acc));
  }
  for (const bal of data.balances || []) {
    await reqToPromise(balStore.put(bal));
  }
  if (data.baseCurrency) {
    await reqToPromise(setStore.put({ key: "baseCurrency", value: data.baseCurrency }));
  }

  return snapshot;
}

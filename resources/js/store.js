// store.js — ersetzt den bisherigen IndexedDB-Layer komplett.
// Die gesamte App-Datenbank ist eine einzige JSON-Datei im system-eigenen
// Datenverzeichnis der App (NL_DATAPATH, siehe "dataLocation": "system" in
// neutralino.config.json). Das ist automatisch sandbox-sicher — auch unter
// Flatpak wäre das ohne jede zusätzliche Berechtigung beschreibbar.

const STORE_FILENAME = "app-data.json";
const SCHEMA_VERSION = 1;

// Encapsulated state
let data = null;
let filePath = null;
let isInitialized = false;

function defaultData() {
  return {
    schemaVersion: SCHEMA_VERSION,
    baseCurrency: "EUR",
    accounts: [],
    balances: [],
    ratesCache: {},
    meta: { nextAccountId: 1, nextBalanceId: 1, lastExportAt: null },
  };
}

function validateData(parsed) {
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return null; // Invalid: not a plain object
  }
  
  const validated = {
    schemaVersion: parsed.schemaVersion ?? SCHEMA_VERSION,
    baseCurrency: parsed.baseCurrency ?? "EUR",
    accounts: Array.isArray(parsed.accounts) ? parsed.accounts : [],
    balances: Array.isArray(parsed.balances) ? parsed.balances : [],
    ratesCache: parsed.ratesCache && typeof parsed.ratesCache === 'object' ? parsed.ratesCache : {},
    meta: parsed.meta && typeof parsed.meta === 'object' ? parsed.meta : {},
  };
  
  // Ensure meta has required fields
  validated.meta.nextAccountId = validated.meta.nextAccountId ?? 1;
  validated.meta.nextBalanceId = validated.meta.nextBalanceId ?? 1;
  validated.meta.lastExportAt = validated.meta.lastExportAt ?? null;
  
  return validated;
}

function migrateData(data) {
  // Future migrations go here
  // if (data.schemaVersion === 1) { ... }
  return data;
}

async function ensureDirectoryExists(path) {
  try {
    await Neutralino.filesystem.getStats(path);
  } catch {
    try {
      await Neutralino.filesystem.createDirectory(path);
    } catch (err) {
      throw new Error(`Cannot create directory ${path}: ${err.message}`);
    }
  }
}

async function cleanupTempFile(tmpPath) {
  try {
    await Neutralino.filesystem.remove(tmpPath);
  } catch {
    // Ignore cleanup errors
  }
}

async function resolveFilePath() {
  if (!NL_DATAPATH) {
    throw new Error("NL_DATAPATH is not defined. Ensure Neutralino is ready and dataLocation is 'system'.");
  }
  return await Neutralino.filesystem.getJoinedPath(NL_DATAPATH, STORE_FILENAME);
}

async function initStore() {
  if (isInitialized) {
    return data;
  }
  
  filePath = await resolveFilePath();

  // Ensure directory exists (NL_DATAPATH is the directory filePath lives in)
  await ensureDirectoryExists(NL_DATAPATH);
  
  // Clean up any leftover temp files from previous crashes
  try {
    const tmpPath = filePath + ".tmp";
    await cleanupTempFile(tmpPath);
  } catch {
    // Ignore
  }
  
  try {
    const raw = await Neutralino.filesystem.readFile(filePath);
    const parsed = JSON.parse(raw);
    const validated = validateData(parsed);
    
    if (validated) {
      data = migrateData(validated);
    } else {
      data = defaultData();
      await persist();
    }
  } catch (err) {
    // Datei existiert noch nicht (erster Start) oder ist kaputt -> frisch anlegen
    data = defaultData();
    await persist();
  }
  
  isInitialized = true;
  return data;
}

// Schreibt die Datei atomar: erst in eine .tmp-Datei, dann umbenennen.
// Fällt auf direktes Überschreiben zurück, falls "move" nicht verfügbar ist.
async function persist() {
  if (!filePath) {
    throw new Error("Store not initialized. Call initStore() first.");
  }
  
  const json = JSON.stringify(data, null, 2);
  const tmpPath = filePath + ".tmp";
  
  try {
    await Neutralino.filesystem.writeFile(tmpPath, json);
    
    // Try atomic move first
    if (Neutralino.filesystem.move) {
      try {
        await Neutralino.filesystem.remove(filePath);
      } catch {
        // File might not exist, that's fine
      }
      await Neutralino.filesystem.move(tmpPath, filePath);
    } else {
      // Fallback: direct write
      await Neutralino.filesystem.writeFile(filePath, json);
    }
  } finally {
    // Always clean up temp file
    await cleanupTempFile(tmpPath);
  }
}

// ---------- Accounts ----------

export async function addAccount(account) {
  if (!isInitialized) {
    throw new Error("Store not initialized. Call initStore() first.");
  }
  
  const record = {
    id: data.meta.nextAccountId++,
    name: account.name,
    bank: account.bank || "",
    tag: account.tag,
    currency: account.currency || "EUR",
    color: account.color || "#00c878",
    archived: false,
    createdAt: new Date().toISOString(),
  };
  
  data.accounts.push(record);
  try {
    await persist();
  } catch (err) {
    // Revert on failure
    data.accounts.pop();
    throw new Error(`Failed to save account: ${err.message}`);
  }
  return record;
}

export async function updateAccount(id, changes) {
  if (!isInitialized) {
    throw new Error("Store not initialized. Call initStore() first.");
  }
  
  const acc = data.accounts.find((a) => a.id === id);
  if (!acc) throw new Error("Konto nicht gefunden");
  Object.assign(acc, changes);
  await persist();
  return acc;
}

export async function archiveAccount(id) {
  return updateAccount(id, { archived: true });
}

export async function getAccounts({ includeArchived = false } = {}) {
  if (!isInitialized) {
    await initStore();
  }
  return includeArchived ? [...data.accounts] : data.accounts.filter((a) => !a.archived);
}

export async function getAccount(id) {
  if (!isInitialized) {
    await initStore();
  }
  return data.accounts.find((a) => a.id === id) || null;
}

// ---------- Balances ----------

export async function upsertBalance(entry) {
  if (!isInitialized) {
    throw new Error("Store not initialized. Call initStore() first.");
  }
  
  const existing = data.balances.find(
    (b) => b.accountId === entry.accountId && b.period === entry.period
  );
  const record = {
    id: existing ? existing.id : data.meta.nextBalanceId++,
    accountId: entry.accountId,
    period: entry.period,
    amountOriginal: entry.amountOriginal,
    currencyOriginal: entry.currencyOriginal,
    rate: entry.rate,
    amountBase: entry.amountBase,
    note: entry.note || "",
    enteredAt: new Date().toISOString(),
  };
  
  if (existing) {
    Object.assign(existing, record);
  } else {
    data.balances.push(record);
  }
  await persist();
  return record;
}

export async function deleteBalance(id) {
  if (!isInitialized) {
    throw new Error("Store not initialized. Call initStore() first.");
  }
  
  data.balances = data.balances.filter((b) => b.id !== id);
  await persist();
}

export async function getBalancesForAccount(accountId) {
  if (!isInitialized) {
    await initStore();
  }
  return data.balances
    .filter((b) => b.accountId === accountId)
    .sort((a, b) => (a.period < b.period ? -1 : 1));
}

export async function getAllBalances() {
  if (!isInitialized) {
    await initStore();
  }
  return [...data.balances].sort((a, b) => (a.period < b.period ? -1 : 1));
}

export async function getBalanceForAccountPeriod(accountId, period) {
  if (!isInitialized) {
    await initStore();
  }
  return data.balances.find((b) => b.accountId === accountId && b.period === period) || null;
}

// ---------- Settings ----------

export async function getSetting(key, fallback = null) {
  if (!isInitialized) {
    await initStore();
  }
  if (key === "baseCurrency") return data.baseCurrency ?? fallback;
  if (key === "lastExportAt") return data.meta.lastExportAt ?? fallback;
  return fallback;
}

export async function setSetting(key, value) {
  if (!isInitialized) {
    throw new Error("Store not initialized. Call initStore() first.");
  }
  
  if (key === "baseCurrency") data.baseCurrency = value;
  if (key === "lastExportAt") data.meta.lastExportAt = value;
  await persist();
}

// ---------- Rate-Cache ----------

export async function getCachedRate(key) {
  if (!isInitialized) {
    await initStore();
  }
  return data.ratesCache[key] ?? null;
}

export async function setCachedRate(key, rate) {
  if (!isInitialized) {
    throw new Error("Store not initialized. Call initStore() first.");
  }
  
  data.ratesCache[key] = rate;
  await persist();
}

// ---------- Export / Import ----------

export async function exportAllData() {
  if (!isInitialized) {
    await initStore();
  }
  
  return {
    schemaVersion: data.schemaVersion,
    exportedAt: new Date().toISOString(),
    baseCurrency: data.baseCurrency,
    accounts: data.accounts,
    balances: data.balances,
  };
}

// Ersetzt ALLE Daten durch den Inhalt der Import-Datei. Gibt einen Snapshot
// des vorherigen Stands zurück (für ein mögliches Undo in main.js).
export async function importAllData(imported) {
  if (!isInitialized) {
    await initStore();
  }
  
  const snapshot = await exportAllData();

  const maxAccId = Math.max(0, ...(imported.accounts || []).map((a) => a.id || 0));
  const maxBalId = Math.max(0, ...(imported.balances || []).map((b) => b.id || 0));

  data.accounts = imported.accounts || [];
  data.balances = imported.balances || [];
  if (imported.baseCurrency) data.baseCurrency = imported.baseCurrency;
  data.meta.nextAccountId = Math.max(data.meta.nextAccountId, maxAccId + 1);
  data.meta.nextBalanceId = Math.max(data.meta.nextBalanceId, maxBalId + 1);

  await persist();
  return snapshot;
}

// Initialize store on first use
export async function ensureStoreInitialized() {
  if (!isInitialized) {
    await initStore();
  }
  return data;
}

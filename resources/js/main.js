import * as db from "./store.js";
import { getExchangeRate } from "./currency.js";
import { renderLineChart, renderDonut } from "./charts.js";

// ---------- Konstanten ----------

const TAGS = ["Girokonto", "Tagesgeld", "Festgeld", "Depot", "Kredit", "Bargeld", "Krypto"];
const TAG_COLORS = {
  Girokonto: "#00c878",
  Tagesgeld: "#2fd0a0",
  Festgeld: "#1fa370",
  Depot: "#7ee6c0",
  Kredit: "#ff6b6b",
  Bargeld: "#c9d6cf",
  Krypto: "#f5a623",
};
const CURRENCIES = ["EUR", "USD", "CHF", "GBP", "JPY", "SEK", "NOK", "DKK"];

let state = {
  baseCurrency: "EUR",
  accounts: [],
  balances: [],
};

// ---------- Helpers ----------

function fmtMoney(value, currency) {
  try {
    return new Intl.NumberFormat("de-DE", { style: "currency", currency }).format(value);
  } catch {
    return `${value.toFixed(2)} ${currency}`;
  }
}

function periodLabel(period) {
  const [y, m] = period.split("-");
  const months = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"];
  return `${months[parseInt(m, 10) - 1]} ${y}`;
}

function lastDayOfMonthISO(period) {
  const [y, m] = period.split("-").map(Number);
  const d = new Date(Date.UTC(y, m, 0)); // Tag 0 des Folgemonats = letzter Tag
  return d.toISOString().slice(0, 10);
}

function currentPeriod() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function allPeriodsSorted() {
  const set = new Set(state.balances.map((b) => b.period));
  return Array.from(set).sort();
}

const BACKUP_REMINDER_DAYS = 30;

async function getBackupReminder() {
  const lastExportAt = await db.getSetting("lastExportAt", null);
  if (!lastExportAt) {
    return { overdue: true, message: "Noch nie exportiert — leg jetzt ein erstes Backup an." };
  }
  const days = Math.floor((Date.now() - new Date(lastExportAt).getTime()) / (1000 * 60 * 60 * 24));
  if (days >= BACKUP_REMINDER_DAYS) {
    return { overdue: true, message: `Letztes Backup vor ${days} Tagen — Zeit für ein neues Export.` };
  }
  return { overdue: false, message: `Letztes Backup vor ${days} Tag${days === 1 ? "" : "en"}.` };
}

function el(html) {
  const t = document.createElement("template");
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
}

async function loadState() {
  try {
    const [accounts, balances, baseCurrency] = await Promise.all([
      db.getAccounts({ includeArchived: false }),
      db.getAllBalances(),
      db.getSetting("baseCurrency", "EUR"),
    ]);
    state.accounts = accounts;
    state.balances = balances;
    state.baseCurrency = baseCurrency;
    console.log("State loaded:", state.accounts.length, "accounts", state.balances.length, "balances");
  } catch (err) {
    console.error("Failed to load state:", err);
    // Set defaults to prevent errors
    state.accounts = [];
    state.balances = [];
    state.baseCurrency = "EUR";
  }
}

// ---------- Router ----------

const routes = {
  "#/": renderDashboard,
  "#/dashboard": renderDashboard,
  "#/accounts": renderAccounts,
  "#/entry": renderEntry,
  "#/settings": renderSettings,
};

async function router(hashOverride = null) {
  try {
    const hash = hashOverride || location.hash || "#/dashboard";
    const [base] = hash.split("?");
    const view = routes[base] || renderDashboard;
    console.log("Routing to:", base, "view:", typeof view);
    await loadState();
    setActiveNav(base);
    await view();
  } catch (err) {
    console.error("Router error:", err);
  }
}

function setActiveNav(base) {
  document.querySelectorAll("nav a[data-route]").forEach((a) => {
    a.setAttribute("aria-current", a.getAttribute("href") === base ? "page" : "false");
  });
}

window.addEventListener("hashchange", () => router());

let resizeTimer = null;
window.addEventListener("resize", () => {
  clearTimeout(resizeTimer);
  // Debounce: erst 200ms nach der letzten Größenänderung neu rendern,
  // sonst rendert es bei jedem Zwischenschritt des Ziehens am Fensterrand
  resizeTimer = setTimeout(() => router(), 200);
});

// ---------- Dashboard ----------

async function renderDashboard() {
  const periods = allPeriodsSorted();

  if (periods.length === 0) {
    document.getElementById("app").innerHTML = `
      <section class="empty-state">
        <h2>Noch kein Vermögen erfasst</h2>
        <p>Leg zuerst ein Konto an und trag deinen ersten Kontostand ein.</p>
        <a role="button" href="#/accounts">Konto anlegen</a>
      </section>`;
    return;
  }

  const latestPeriod = periods[periods.length - 1];
  const prevPeriod = periods.length > 1 ? periods[periods.length - 2] : null;

  const totalForPeriod = (period) =>
    state.balances
      .filter((b) => b.period === period && state.accounts.some((a) => a.id === b.accountId))
      .reduce((sum, b) => sum + b.amountBase, 0);

  const accountsWithEntryInPeriod = (period) =>
    state.balances.filter((b) => b.period === period && state.accounts.some((a) => a.id === b.accountId)).length;

  const currentTotal = totalForPeriod(latestPeriod);
  const prevTotal = prevPeriod ? totalForPeriod(prevPeriod) : null;
  const delta = prevTotal != null ? currentTotal - prevTotal : null;

  const totalChartData = periods.map((p) => ({ label: periodLabel(p), value: totalForPeriod(p) }));

  // Verteilung nach Tag im aktuellsten Monat
  const byTag = {};
  state.balances
    .filter((b) => b.period === latestPeriod)
    .forEach((b) => {
      const acc = state.accounts.find((a) => a.id === b.accountId);
      if (!acc) return;
      byTag[acc.tag] = (byTag[acc.tag] || 0) + b.amountBase;
    });
  const donutSegments = Object.entries(byTag).map(([tag, value]) => ({
    label: tag,
    value,
    color: TAG_COLORS[tag] || "#888",
  }));

  const backupReminder = await getBackupReminder();

  document.getElementById("app").innerHTML = `
    ${
      backupReminder.overdue
        ? `<div class="backup-banner">
             <span>⚠️ ${backupReminder.message}</span>
             <a href="#/settings" role="button" class="secondary">Jetzt exportieren</a>
           </div>`
        : ""
    }
    <section class="dashboard-hero">
      <p class="eyebrow">Gesamtvermögen · Stand ${periodLabel(latestPeriod)}</p>
      <h1>${fmtMoney(currentTotal, state.baseCurrency)}</h1>
      ${
        delta != null
          ? `<p class="delta ${delta >= 0 ? "positive" : "negative"}">${delta >= 0 ? "+" : ""}${fmtMoney(delta, state.baseCurrency)} ggü. ${periodLabel(prevPeriod)}</p>`
          : `<p class="delta muted">Noch kein Vergleichsmonat</p>`
      }
      <p class="hint">Basiert auf ${accountsWithEntryInPeriod(latestPeriod)} von ${state.accounts.length} aktiven Konten mit Eintrag für diesen Monat.</p>
    </section>

    <section class="card">
      <h2>Verlauf</h2>
      <div id="totalChart"></div>
    </section>

    <section class="card">
      <h2>Verteilung nach Kontotyp</h2>
      <div id="donutChart"></div>
    </section>

    <section>
      <h2>Konten</h2>
      <div id="accountCards" class="account-grid"></div>
    </section>
  `;

  renderLineChart(document.getElementById("totalChart"), totalChartData, { color: "#00c878" });
  renderDonut(document.getElementById("donutChart"), donutSegments);

  const grid = document.getElementById("accountCards");
  state.accounts.forEach((acc) => {
    const points = periods.map((p) => {
      const b = state.balances.find((x) => x.accountId === acc.id && x.period === p);
      return { label: periodLabel(p), value: b ? b.amountBase : null };
    });
    const latestForAcc = [...state.balances].reverse().find((b) => b.accountId === acc.id);
    const card = el(`
      <article class="card account-card">
        <header>
          <span class="dot" style="background:${acc.color}"></span>
          <strong>${acc.name}</strong>
          <span class="tag-badge">${acc.tag}</span>
        </header>
        <p class="account-value">${latestForAcc ? fmtMoney(latestForAcc.amountBase, state.baseCurrency) : "—"}</p>
        <div class="mini-chart"></div>
      </article>
    `);
    grid.appendChild(card);
    renderLineChart(card.querySelector(".mini-chart"), points, { color: acc.color, height: 80 });
  });
}

// ---------- Konten ----------

async function renderAccounts() {
  document.getElementById("app").innerHTML = `
    <section class="card">
      <h2>Neues Konto</h2>
      <form id="accountForm">
        <label>Name
          <input type="text" name="name" required placeholder="z.B. DKB Girokonto" />
        </label>
        <label>Bank
          <input type="text" name="bank" placeholder="z.B. DKB" />
        </label>
        <div class="grid">
          <label>Typ
            <select name="tag" required>
              ${TAGS.map((t) => `<option value="${t}">${t}</option>`).join("")}
            </select>
          </label>
          <label>Währung
            <input list="currencyList" name="currency" value="EUR" required />
            <datalist id="currencyList">
              ${CURRENCIES.map((c) => `<option value="${c}">`).join("")}
            </datalist>
          </label>
        </div>
        <label>Farbe
          <input type="color" name="color" value="#00c878" />
        </label>
        <button type="submit">Konto anlegen</button>
      </form>
    </section>

    <section>
      <h2>Bestehende Konten</h2>
      <div id="accountList"></div>
    </section>
  `;

  const accountForm = document.getElementById("accountForm");
  if (accountForm) {
    accountForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      try {
        const fd = new FormData(e.target);
        console.log("Adding account:", Object.fromEntries(fd));
        await db.addAccount({
          name: fd.get("name"),
          bank: fd.get("bank"),
          tag: fd.get("tag"),
          currency: fd.get("currency").toUpperCase(),
          color: fd.get("color"),
        });
        console.log("Account added successfully");
        await loadState();
        renderAccountList();
        e.target.reset();
      } catch (err) {
        console.error("Failed to add account:", err);
        alert("Fehler beim Anlegen des Kontos: " + (err.message || String(err)));
      }
    });
  } else {
    console.error("Account form not found!");
  }

  renderAccountList();

  function renderAccountList() {
    const listEl = document.getElementById("accountList");
    if (state.accounts.length === 0) {
      listEl.innerHTML = `<p class="empty-hint">Noch keine Konten angelegt.</p>`;
      return;
    }
    listEl.innerHTML = "";
    state.accounts.forEach((acc) => {
      const row = el(`
        <article class="card account-row">
          <span class="dot" style="background:${acc.color}"></span>
          <div class="account-row-info">
            <strong>${acc.name}</strong>
            <span class="muted">${acc.bank ? acc.bank + " · " : ""}${acc.tag} · ${acc.currency}</span>
          </div>
          <button class="secondary archive-btn" data-id="${acc.id}">Archivieren</button>
        </article>
      `);
      row.querySelector(".archive-btn").addEventListener("click", async () => {
        if (!confirm(`"${acc.name}" wirklich archivieren? Es verschwindet danach komplett aus allen Charts.`)) return;
        await db.archiveAccount(acc.id);
        await loadState();
        renderAccountList();
      });
      listEl.appendChild(row);
    });
  }
}

// ---------- Kontostand erfassen ----------

async function renderEntry() {
  if (state.accounts.length === 0) {
    document.getElementById("app").innerHTML = `
      <section class="empty-state">
        <h2>Erst ein Konto anlegen</h2>
        <p>Bevor du einen Kontostand erfassen kannst, brauchst du mindestens ein Konto.</p>
        <a role="button" href="#/accounts">Konto anlegen</a>
      </section>`;
    return;
  }

  document.getElementById("app").innerHTML = `
    <section class="card">
      <h2>Kontostand erfassen</h2>
      <p class="muted">Auch rückwirkend möglich — einfach den passenden Monat wählen. Ein bestehender Eintrag für Konto + Monat wird überschrieben.</p>
      <form id="entryForm">
        <label>Konto
          <select name="accountId" required>
            ${state.accounts.map((a) => `<option value="${a.id}">${a.name} (${a.currency})</option>`).join("")}
          </select>
        </label>
        <label>Monat
          <input type="month" name="period" value="${currentPeriod()}" required />
        </label>
        <label>Betrag (in Kontowährung)
          <input type="number" step="0.01" name="amount" required placeholder="z.B. 4230.50" />
        </label>
        <label>Notiz (optional)
          <input type="text" name="note" placeholder="optional" />
        </label>
        <div id="rateNotice" class="hint"></div>
        <button type="submit">Speichern</button>
      </form>
    </section>
  `;

  const form = document.getElementById("entryForm");
  const rateNotice = document.getElementById("rateNotice");

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const fd = new FormData(form);
    const accountId = Number(fd.get("accountId"));
    const account = state.accounts.find((a) => a.id === accountId);
    const period = fd.get("period"); // "YYYY-MM"
    const amount = parseFloat(fd.get("amount"));
    const note = fd.get("note") || "";
    const dateISO = lastDayOfMonthISO(period);

    rateNotice.textContent = "Kurs wird ermittelt …";

    let rateResult = await getExchangeRate(account.currency, state.baseCurrency, dateISO);

    if (!rateResult) {
      const manual = prompt(
        `Kein Wechselkurs ${account.currency} → ${state.baseCurrency} für ${dateISO} verfügbar (offline?).\nBitte Kurs manuell eingeben (1 ${account.currency} = ? ${state.baseCurrency}):`
      );
      const manualRate = parseFloat(manual);
      if (!manualRate || manualRate <= 0) {
        rateNotice.textContent = "Ohne gültigen Kurs kann der Eintrag nicht gespeichert werden.";
        return;
      }
      rateResult = { rate: manualRate, source: "manual", date: dateISO };
    }

    const amountBase = amount * rateResult.rate;

    await db.upsertBalance({
      accountId,
      period,
      amountOriginal: amount,
      currencyOriginal: account.currency,
      rate: rateResult.rate,
      amountBase,
    });

    rateNotice.textContent = `Gespeichert: ${fmtMoney(amountBase, state.baseCurrency)} (Kurs ${rateResult.rate.toFixed(4)}, Quelle: ${rateResult.source}).`;
    form.reset();
    document.querySelector('[name="period"]').value = currentPeriod();
  });
}

// ---------- Einstellungen ----------

async function renderSettings() {
  const lastExport = await db.getSetting("lastExportAt", null);

  document.getElementById("app").innerHTML = `
    <section class="card">
      <h2>Basiswährung</h2>
      <p class="muted">Alle Beträge werden für Dashboard-Ansichten in diese Währung umgerechnet.</p>
      <select id="baseCurrencySelect">
        ${CURRENCIES.map((c) => `<option value="${c}" ${c === state.baseCurrency ? "selected" : ""}>${c}</option>`).join("")}
      </select>
    </section>

    <section class="card">
      <h2>Export</h2>
      <p class="muted">Schreibt eine unverschlüsselte JSON-Datei mit allen Konten und Kontoständen an einen Ort deiner Wahl.</p>
      <p class="hint">${lastExport ? "Letzter Export: " + new Date(lastExport).toLocaleString("de-DE") : "Noch nie exportiert."}</p>
      <button id="exportBtn">Backup exportieren…</button>
    </section>

    <section class="card">
      <h2>Import</h2>
      <p class="muted"><strong>Achtung:</strong> Der Import ersetzt alle aktuell gespeicherten Daten vollständig.</p>
      <button id="importBtn" class="secondary">Backup importieren…</button>
    </section>
  `;

  const currencySelect = document.getElementById("baseCurrencySelect");
  if (currencySelect) {
    currencySelect.addEventListener("change", async (e) => {
      try {
        await db.setSetting("baseCurrency", e.target.value);
        await loadState();
        console.log("Base currency updated to:", e.target.value);
      } catch (err) {
        console.error("Failed to update base currency:", err);
      }
    });
  }

  document.getElementById("exportBtn").addEventListener("click", async () => {
    try {
      const exportData = await db.exportAllData();
      const suggestedName = `finanzgecko-backup-${new Date().toISOString().slice(0, 10)}.json`;
      const targetPath = await Neutralino.os.showSaveDialog("Backup speichern unter…", {
        defaultPath: suggestedName,
        filters: [
          { name: "JSON-Backup", extensions: ["json"] },
          { name: "Alle Dateien", extensions: ["*"] },
        ],
      });
      if (!targetPath) return; // Dialog abgebrochen
      await Neutralino.filesystem.writeFile(targetPath, JSON.stringify(exportData, null, 2));
      await db.setSetting("lastExportAt", new Date().toISOString());
      await renderSettings();
    } catch (err) {
      alert("Export fehlgeschlagen: " + err.message);
    }
  });

  document.getElementById("importBtn").addEventListener("click", async () => {
    try {
      const entries = await Neutralino.os.showOpenDialog("Backup-Datei auswählen", {
        filters: [
          { name: "JSON-Backup", extensions: ["json"] },
          { name: "Alle Dateien", extensions: ["*"] },
        ],
      });
      if (!entries || entries.length === 0) return; // Dialog abgebrochen
      if (!confirm("Import ersetzt ALLE aktuellen Daten. Fortfahren?")) return;

      const raw = await Neutralino.filesystem.readFile(entries[0]);
      const imported = JSON.parse(raw);
      const snapshot = await db.importAllData(imported);
      window._preImportSnapshot = snapshot; // einmaliges Undo für diese Sitzung
      await loadState();
      alert("Import abgeschlossen.");
      location.hash = "#/dashboard";
    } catch (err) {
      alert("Import fehlgeschlagen: Datei ist kein gültiges Backup.\n" + err.message);
    }
  });
}

// ---------- Init ----------

// ---------- Native Menüleiste ----------

function setupNativeMenu() {
  // Use platform-appropriate shortcuts
  const isMac = NL_OS === "Darwin";
  const modKey = isMac ? "cmd" : "ctrl";
  
  Neutralino.window.setMainMenu({
    menuItems: [
      {
        id: "file",
        text: "Datei",
        menuItems: [
          { id: "export", text: "Backup exportieren…", shortcut: `${modKey}+e` },
          { id: "import", text: "Backup importieren…", shortcut: `${modKey}+i` },
          { id: "sep1", text: "-" },
          { id: "checkUpdate", text: "Nach Updates suchen…", shortcut: `${modKey}+u` },
          { id: "sep2", text: "-" },
          { id: "quit", text: "Beenden", shortcut: `${modKey}+q` },
        ],
      },
    ],
  });

  Neutralino.events.on("mainMenuItemClicked", async (evt) => {
    switch (evt.detail.id) {
      case "export":
        location.hash = "#/settings";
        // kleine Verzögerung, damit die Settings-View erst gerendert ist
        setTimeout(() => document.getElementById("exportBtn")?.click(), 150);
        break;
      case "import":
        location.hash = "#/settings";
        setTimeout(() => document.getElementById("importBtn")?.click(), 150);
        break;
      case "checkUpdate":
        await checkForUpdates({ silent: false });
        break;
      case "quit":
        Neutralino.app.exit();
        break;
    }
  });
}

// ---------- Auto-Updater ----------

// Diese URL zeigt auf ein kleines JSON-Manifest im eigenen GitHub-Repo
// (siehe README: "update-manifest.json" bei jedem Release aktualisieren).
const UPDATE_MANIFEST_URL =
  "https://raw.githubusercontent.com/<dein-github-name>/finanzgecko/main/update-manifest.json";

async function checkForUpdates({ silent = true } = {}) {
  try {
    const manifest = await Neutralino.updater.checkForUpdates(UPDATE_MANIFEST_URL);
    if (manifest.version !== NL_APPVERSION) {
      const proceed = confirm(
        `Version ${manifest.version} ist verfügbar (aktuell: ${NL_APPVERSION}). Jetzt installieren? Die App startet danach neu.`
      );
      if (proceed) {
        await Neutralino.updater.install();
        await Neutralino.app.restartProcess();
      }
    } else if (!silent) {
      alert("Du hast bereits die neueste Version.");
    }
  } catch (err) {
    if (!silent) {
      alert("Update-Prüfung fehlgeschlagen (offline oder Manifest nicht erreichbar).\n" + err.message);
    }
    // Im Hintergrund-Check (silent) bewusst keine Fehlermeldung — offline
    // beim normalen Start soll die App nicht nerven.
  }
}

async function init() {
  try {
    // Ensure store is initialized
    await db.ensureStoreInitialized();
  } catch (err) {
    console.error("Failed to initialize store:", err);
    alert(`Fehler beim Starten: ${err.message || String(err)}`);
    throw err; // Stop initialization
  }
  
  setupNativeMenu();
  
  // Clean up temp files from previous crashes
  try {
    if (typeof NL_DATAPATH !== 'undefined') {
      const tmpPath = await Neutralino.filesystem.getJoinedPath(NL_DATAPATH, "app-data.json.tmp");
      await Neutralino.filesystem.remove(tmpPath);
    }
  } catch {
    // Ignore cleanup errors
  }
  
  // Setup navigation click handlers - directly call router
  const navLinks = document.querySelectorAll("nav a[data-route]");
  console.log("Found nav links:", navLinks.length);
  if (navLinks.length === 0) {
    console.error("Navigation links not found!");
  } else {
    navLinks.forEach((a) => {
      a.addEventListener("click", async (e) => {
        e.preventDefault();
        console.log("Nav click:", a.getAttribute("href"));
        const targetHash = a.getAttribute("href");
        try {
          await router(targetHash);
        } catch (err) {
          console.error("Navigation error:", err);
          alert(`Fehler beim Laden der Seite: ${err.message || String(err)}`);
        }
      });
    });
  }
  
  try {
    await router();
  } catch (err) {
    console.error("Failed to load initial route:", err);
    alert(`Fehler beim Laden der Startseite: ${err.message || String(err)}`);
  }
  
  checkForUpdates({ silent: true }); // unauffällig im Hintergrund, keine App-Blockade
}

// Wait for both DOM and Neutralino to be ready
function startApp() {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => startApp());
    return;
  }
  
  if (typeof Neutralino !== 'undefined') {
    Neutralino.events.on('ready', init);
    Neutralino.init();
  } else {
    // Fallback for browser testing
    init().catch(err => console.error("Init failed:", err));
  }
}

startApp();

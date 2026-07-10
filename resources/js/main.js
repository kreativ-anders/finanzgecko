import * as db from "./store.js";
import { getExchangeRate } from "./currency.js";
import { renderLineChart, renderDonut } from "./charts.js";
import { BANKS } from "./banks.js";

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
const MONTH_LABELS = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"];

// Fixposten: wiederkehrende Ein-/Ausgaben. monthFactor rechnet den jeweiligen
// Turnus auf ein Monatsäquivalent um, damit z.B. ein jährlicher und ein
// monatlicher Betrag vergleichbar sind.
const SUBSCRIPTION_INTERVALS = [
  { value: "daily", label: "Täglich", monthFactor: 30.4368 },
  { value: "weekly", label: "Wöchentlich", monthFactor: 4.34524 },
  { value: "monthly", label: "Monatlich", monthFactor: 1 },
  { value: "quarterly", label: "Vierteljährlich", monthFactor: 1 / 3 },
  { value: "yearly", label: "Jährlich", monthFactor: 1 / 12 },
];

function intervalLabel(value) {
  return SUBSCRIPTION_INTERVALS.find((i) => i.value === value)?.label || value;
}

function monthlyEquivalent(sub) {
  const factor = SUBSCRIPTION_INTERVALS.find((i) => i.value === sub.interval)?.monthFactor ?? 1;
  return sub.amountBase * factor;
}

let state = {
  baseCurrency: "EUR",
  defaultSubscriptionInterval: "monthly",
  accounts: [],
  balances: [],
  assets: [],
  subscriptions: [],
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
  return `${MONTH_LABELS[parseInt(m, 10) - 1]} ${y}`;
}

function getBankColor(bankName) {
  const match = BANKS.find((b) => b.name.toLowerCase() === (bankName || "").trim().toLowerCase());
  return match ? match.color : null;
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

// ---------- Monatsauswahl ----------
// Eigenes Widget statt <input type="month">: WebKitGTK (nativer Webview unter
// Linux) implementiert dafür keine Picker-UI, das native Feld ist dort
// unbedienbar. Das eigene Widget funktioniert plattformunabhängig identisch.

function monthPickerField(name, value) {
  const [year] = value.split("-");
  return `
    <div class="month-picker" data-value="${value}" data-view-year="${year}">
      <button type="button" class="month-picker-toggle" aria-haspopup="true" aria-expanded="false">${periodLabel(value)}</button>
      <input type="hidden" name="${name}" value="${value}" />
      <div class="month-picker-pop" hidden>
        <div class="month-picker-nav">
          <button type="button" class="month-picker-nav-btn" data-dir="-1" aria-label="Vorheriges Jahr">‹</button>
          <span class="month-picker-year"></span>
          <button type="button" class="month-picker-nav-btn" data-dir="1" aria-label="Nächstes Jahr">›</button>
        </div>
        <div class="month-picker-grid"></div>
      </div>
    </div>`;
}

function renderMonthPickerGrid(container) {
  const [selYear, selMonth] = container.dataset.value.split("-").map(Number);
  const viewYear = Number(container.dataset.viewYear);
  container.querySelector(".month-picker-year").textContent = viewYear;
  container.querySelector(".month-picker-grid").innerHTML = MONTH_LABELS.map((label, i) => {
    const m = i + 1;
    const active = viewYear === selYear && m === selMonth;
    return `<button type="button" class="month-picker-cell${active ? " active" : ""}" data-month="${m}">${label}</button>`;
  }).join("");
}

function openMonthPicker(container) {
  container.dataset.viewYear = container.dataset.value.split("-")[0];
  renderMonthPickerGrid(container);
  container.classList.add("open");
  container.querySelector(".month-picker-pop").hidden = false;
  container.querySelector(".month-picker-toggle").setAttribute("aria-expanded", "true");
}

function closeMonthPicker(container) {
  container.classList.remove("open");
  container.querySelector(".month-picker-pop").hidden = true;
  container.querySelector(".month-picker-toggle").setAttribute("aria-expanded", "false");
}

function setMonthPickerValue(container, period) {
  container.dataset.value = period;
  container.dataset.viewYear = period.split("-")[0];
  container.querySelector('input[type="hidden"]').value = period;
  container.querySelector(".month-picker-toggle").textContent = periodLabel(period);
  container.querySelector('input[type="hidden"]').dispatchEvent(new Event("change", { bubbles: true }));
}

document.addEventListener("click", (e) => {
  const clickedPicker = e.target.closest(".month-picker");
  document.querySelectorAll(".month-picker.open").forEach((el) => {
    if (el !== clickedPicker) closeMonthPicker(el);
  });

  const toggle = e.target.closest(".month-picker-toggle");
  if (toggle) {
    const container = toggle.closest(".month-picker");
    container.classList.contains("open") ? closeMonthPicker(container) : openMonthPicker(container);
    return;
  }

  const navBtn = e.target.closest(".month-picker-nav-btn");
  if (navBtn) {
    const container = navBtn.closest(".month-picker");
    container.dataset.viewYear = String(Number(container.dataset.viewYear) + Number(navBtn.dataset.dir));
    renderMonthPickerGrid(container);
    return;
  }

  const cell = e.target.closest(".month-picker-cell");
  if (cell) {
    const container = cell.closest(".month-picker");
    const period = `${container.dataset.viewYear}-${cell.dataset.month.padStart(2, "0")}`;
    setMonthPickerValue(container, period);
    closeMonthPicker(container);
  }
});

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    document.querySelectorAll(".month-picker.open").forEach(closeMonthPicker);
  }
});

function allPeriodsSorted() {
  const set = new Set(state.balances.map((b) => b.period));
  return Array.from(set).sort();
}

function balancesInPeriod(period) {
  return state.balances.filter((b) => b.period === period && state.accounts.some((a) => a.id === b.accountId));
}

// state.balances is kept sorted ascending by period (see store.js getAllBalances),
// so the last matching entry is the most recent one for that account.
function latestBalanceForAccount(accountId) {
  return [...state.balances].reverse().find((b) => b.accountId === accountId);
}

const BACKUP_REMINDER_DAYS = 30;
const BACKUP_FILE_FILTERS = [
  { name: "JSON-Backup", extensions: ["json"] },
  { name: "Alle Dateien", extensions: ["*"] },
];

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

const ASSET_REEVALUATION_DAYS = 182; // ~6 Monate

function isAssetOverdue(asset) {
  if (!asset.lastEvaluatedAt) return true;
  const days = Math.floor((Date.now() - new Date(asset.lastEvaluatedAt).getTime()) / (1000 * 60 * 60 * 24));
  return days >= ASSET_REEVALUATION_DAYS;
}

function getAssetReminder() {
  const overdue = state.assets.filter(isAssetOverdue);
  if (overdue.length === 0) return null;
  const names = overdue.map((a) => a.name).join(", ");
  return `${overdue.length} Vermögenswert${overdue.length === 1 ? "" : "e"} seit über 6 Monaten nicht neu bewertet: ${names}`;
}

function el(html) {
  const t = document.createElement("template");
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
}

function appRoot() {
  return document.getElementById("app");
}

async function loadState() {
  try {
    const [accounts, balances, assets, subscriptions, baseCurrency, defaultSubscriptionInterval] = await Promise.all([
      db.getAccounts({ includeArchived: false }),
      db.getAllBalances(),
      db.getAssets(),
      db.getSubscriptions(),
      db.getSetting("baseCurrency", "EUR"),
      db.getSetting("defaultSubscriptionInterval", "monthly"),
    ]);
    state.accounts = accounts;
    state.balances = balances;
    state.assets = assets;
    state.subscriptions = subscriptions;
    state.baseCurrency = baseCurrency;
    state.defaultSubscriptionInterval = defaultSubscriptionInterval;
  } catch (err) {
    console.error("Failed to load state:", err);
    // Set defaults to prevent errors
    state.accounts = [];
    state.balances = [];
    state.assets = [];
    state.subscriptions = [];
    state.baseCurrency = "EUR";
    state.defaultSubscriptionInterval = "monthly";
  }
}

// ---------- Router ----------

const routes = {
  "#/": renderDashboard,
  "#/dashboard": renderDashboard,
  "#/accounts": renderAccounts,
  "#/entry": renderEntry,
  "#/entries": renderEntries,
  "#/assets": renderAssets,
  "#/subscriptions": renderSubscriptions,
  "#/settings": renderSettings,
};

async function router(hashOverride = null) {
  try {
    const hash = hashOverride || location.hash || "#/dashboard";
    const [base] = hash.split("?");
    const view = routes[base] || renderDashboard;
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

function assetsSectionHTML() {
  const total = state.assets.reduce((sum, a) => sum + a.value, 0);
  return `
    <section class="card">
      <h2>Vermögenswerte</h2>
      ${
        state.assets.length === 0
          ? `<p class="empty-hint">Noch keine Vermögenswerte erfasst.</p>`
          : `<p class="account-value">${fmtMoney(total, state.baseCurrency)}</p>
             <p class="hint">${state.assets.length} Gegenstände erfasst</p>`
      }
      <a href="#/assets" role="button" class="secondary outline">Vermögenswerte verwalten</a>
    </section>`;
}

// ---------- Fixposten: gemeinsame Berechnungen (Dashboard + Verwaltungsseite) ----------

function computeSubscriptionTotals() {
  const totalIncome = state.subscriptions
    .filter((s) => s.amountBase > 0)
    .reduce((sum, s) => sum + monthlyEquivalent(s), 0);
  const totalExpense = state.subscriptions
    .filter((s) => s.amountBase < 0)
    .reduce((sum, s) => sum + Math.abs(monthlyEquivalent(s)), 0);
  return { totalIncome, totalExpense, net: totalIncome - totalExpense };
}

function subscriptionsSectionHTML() {
  const { totalIncome, totalExpense, net } = computeSubscriptionTotals();
  return `
    <section class="card">
      <h2>Fixposten</h2>
      ${
        state.subscriptions.length === 0
          ? `<p class="empty-hint">Noch keine wiederkehrenden Ein-/Ausgaben erfasst.</p>`
          : `<div class="subscription-summary">
               <div class="subscription-summary-item income">
                 <span class="muted small">Einnahmen/Monat</span>
                 <strong>${fmtMoney(totalIncome, state.baseCurrency)}</strong>
               </div>
               <div class="subscription-summary-item expense">
                 <span class="muted small">Ausgaben/Monat</span>
                 <strong>${fmtMoney(totalExpense, state.baseCurrency)}</strong>
               </div>
               <div class="subscription-summary-item net ${net >= 0 ? "positive" : "negative"}">
                 <span class="muted small">Differenz</span>
                 <strong>${net >= 0 ? "+" : ""}${fmtMoney(net, state.baseCurrency)}</strong>
               </div>
             </div>`
      }
      <a href="#/subscriptions" role="button" class="secondary outline">Fixposten verwalten</a>
    </section>`;
}

function overspendBannerHTML() {
  const { totalIncome, totalExpense, net } = computeSubscriptionTotals();
  if (state.subscriptions.length === 0 || net >= 0) return "";
  return `
    <div class="overspend-banner">
      <strong>⚠️ Deine wiederkehrenden Ausgaben (${fmtMoney(totalExpense, state.baseCurrency)}/Monat) übersteigen deine wiederkehrenden Einnahmen (${fmtMoney(totalIncome, state.baseCurrency)}/Monat)!</strong>
      <a href="#/subscriptions" role="button">Fixposten prüfen</a>
    </div>`;
}

async function renderDashboard() {
  const periods = allPeriodsSorted();
  const backupReminder = await getBackupReminder();
  const assetReminder = getAssetReminder();

  const banners = `
    ${
      backupReminder.overdue
        ? `<div class="backup-banner">
             <span>⚠️ ${backupReminder.message}</span>
             <a href="#/settings" role="button" class="secondary">Jetzt exportieren</a>
           </div>`
        : ""
    }
    ${
      assetReminder
        ? `<div class="backup-banner">
             <span>⚠️ ${assetReminder}</span>
             <a href="#/assets" role="button" class="secondary">Jetzt prüfen</a>
           </div>`
        : ""
    }
  `;

  if (periods.length === 0) {
    appRoot().innerHTML = `
      ${overspendBannerHTML()}
      ${banners}
      <section class="empty-state">
        <h2>Noch kein Vermögen erfasst</h2>
        <p>Leg zuerst ein Konto an und trag deinen ersten Kontostand ein.</p>
        <a role="button" href="#/accounts">Konto anlegen</a>
      </section>
      ${assetsSectionHTML()}
      ${subscriptionsSectionHTML()}`;
    return;
  }

  const latestPeriod = periods[periods.length - 1];
  const prevPeriod = periods.length > 1 ? periods[periods.length - 2] : null;

  const totalForPeriod = (period) => balancesInPeriod(period).reduce((sum, b) => sum + b.amountBase, 0);

  const accountsWithEntryInPeriod = (period) => balancesInPeriod(period).length;

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

  appRoot().innerHTML = `
    ${overspendBannerHTML()}
    ${banners}
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

    ${assetsSectionHTML()}
    ${subscriptionsSectionHTML()}

    <section>
      <h2>Konten</h2>
      <div id="accountCards" class="account-grid"></div>
    </section>
  `;

  renderLineChart(document.getElementById("totalChart"), totalChartData, { color: "#00c878" });
  renderDonut(document.getElementById("donutChart"), donutSegments);

  const grid = document.getElementById("accountCards");
  state.accounts.forEach((acc) => {
    const accPeriods = Array.from(new Set(state.balances.filter((b) => b.accountId === acc.id).map((b) => b.period))).sort();
    const points = accPeriods.map((p) => {
      const b = state.balances.find((x) => x.accountId === acc.id && x.period === p);
      return { label: periodLabel(p), value: b.amountBase };
    });
    const latestForAcc = latestBalanceForAccount(acc.id);
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
  appRoot().innerHTML = `
    <section class="card">
      <h2>Bestehende Konten</h2>
      <div id="accountList"></div>
    </section>

    <section class="card">
      <h2>Neues Konto</h2>
      <form id="accountForm">
        <label>Name
          <input type="text" name="name" required placeholder="z.B. DKB Girokonto" />
        </label>
        <label>Bank
          <input list="bankList" name="bank" autocomplete="off" placeholder="z.B. DKB" />
          <datalist id="bankList">
            ${BANKS.map((b) => `<option value="${b.name}">`).join("")}
          </datalist>
          <small class="muted">
            Bank fehlt? <a href="#" class="suggest-bank-link">Auf GitHub vorschlagen</a>
            oder <a href="mailto:finanzgecko@kreativ-anders.de?subject=Bank%20vorschlagen">E-Mail schreiben</a>
          </small>
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
        <button type="submit">Konto anlegen</button>
      </form>
    </section>
  `;

  const accountForm = document.getElementById("accountForm");
  if (accountForm) {
    accountForm.querySelector(".suggest-bank-link").addEventListener("click", (e) => {
      e.preventDefault();
      const typed = accountForm.querySelector('[name="bank"]').value || "";
      const title = encodeURIComponent(`Bank vorschlagen: ${typed}`);
      Neutralino.os.open(`https://github.com/kreativanders/finanzgecko/issues/new?title=${title}`);
    });
    accountForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      try {
        const fd = new FormData(e.target);
        const bank = fd.get("bank");
        await db.addAccount({
          name: fd.get("name"),
          bank,
          tag: fd.get("tag"),
          currency: fd.get("currency").toUpperCase(),
          color: getBankColor(bank) || TAG_COLORS[fd.get("tag")] || "#00c878",
        });
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
        <article class="card account-row" data-id="${acc.id}">
          <span class="dot" style="background:${acc.color}"></span>
          <div class="account-row-info">
            <strong>${acc.name}</strong>
            <span class="muted">${acc.bank ? acc.bank + " · " : ""}${acc.tag} · ${acc.currency}</span>
          </div>
          <button class="secondary outline edit-btn" data-id="${acc.id}">Bearbeiten</button>
          <button class="secondary archive-btn" data-id="${acc.id}">Archivieren</button>
        </article>
      `);
      row.querySelector(".edit-btn").addEventListener("click", () => renderAccountEditForm(row, acc));
      row.querySelector(".archive-btn").addEventListener("click", async () => {
        if (!confirm(`"${acc.name}" wirklich archivieren? Es verschwindet danach komplett aus allen Charts.`)) return;
        await db.archiveAccount(acc.id);
        await loadState();
        renderAccountList();
      });
      listEl.appendChild(row);
    });
  }

  function renderAccountEditForm(row, acc) {
    const form = el(`
      <form class="card account-edit-form" data-id="${acc.id}">
        <label>Name
          <input type="text" name="name" required value="${acc.name.replace(/"/g, "&quot;")}" />
        </label>
        <label>Bank
          <input list="bankListEdit" name="bank" autocomplete="off" value="${(acc.bank || "").replace(/"/g, "&quot;")}" />
          <datalist id="bankListEdit">
            ${BANKS.map((b) => `<option value="${b.name}">`).join("")}
          </datalist>
          <small class="muted">
            Bank fehlt? <a href="#" class="suggest-bank-link">Auf GitHub vorschlagen</a>
            oder <a href="mailto:finanzgecko@kreativ-anders.de?subject=Bank%20vorschlagen">E-Mail schreiben</a>
          </small>
        </label>
        <div class="grid">
          <label>Typ
            <select name="tag" required>
              ${TAGS.map((t) => `<option value="${t}" ${t === acc.tag ? "selected" : ""}>${t}</option>`).join("")}
            </select>
          </label>
          <label>Währung
            <input list="currencyListEdit" name="currency" value="${acc.currency}" required />
            <datalist id="currencyListEdit">
              ${CURRENCIES.map((c) => `<option value="${c}">`).join("")}
            </datalist>
          </label>
        </div>
        <div class="grid">
          <button type="submit">Speichern</button>
          <button type="button" class="secondary cancel-edit-btn">Abbrechen</button>
        </div>
      </form>
    `);
    row.replaceWith(form);

    form.querySelector(".suggest-bank-link").addEventListener("click", (e) => {
      e.preventDefault();
      const typed = form.querySelector('[name="bank"]').value || "";
      const title = encodeURIComponent(`Bank vorschlagen: ${typed}`);
      Neutralino.os.open(`https://github.com/kreativanders/finanzgecko/issues/new?title=${title}`);
    });

    form.querySelector(".cancel-edit-btn").addEventListener("click", () => {
      form.replaceWith(row);
    });

    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      try {
        const fd = new FormData(form);
        const bank = fd.get("bank");
        await db.updateAccount(acc.id, {
          name: fd.get("name"),
          bank,
          tag: fd.get("tag"),
          currency: fd.get("currency").toUpperCase(),
          color: getBankColor(bank) || acc.color,
        });
        await loadState();
        renderAccountList();
      } catch (err) {
        console.error("Failed to update account:", err);
        alert("Fehler beim Speichern: " + (err.message || String(err)));
      }
    });
  }
}

// ---------- Kontostand erfassen ----------

function entryRowHTML(account) {
  return `
    <div class="entry-row" data-account-id="${account.id}">
      <div class="entry-row-info">
        <span class="entry-row-name">${account.name} <span class="muted small">(${account.currency})</span></span>
        <span class="entry-row-hint muted small"></span>
      </div>
      <div class="entry-row-input">
        <input type="number" step="0.01" required inputmode="decimal" placeholder="Betrag" />
        <span class="entry-status" aria-hidden="true"></span>
      </div>
    </div>`;
}

async function renderEntry() {
  if (state.accounts.length === 0) {
    appRoot().innerHTML = `
      <section class="empty-state">
        <h2>Erst ein Konto anlegen</h2>
        <p>Bevor du einen Kontostand erfassen kannst, brauchst du mindestens ein Konto.</p>
        <a role="button" href="#/accounts">Konto anlegen</a>
      </section>`;
    return;
  }

  appRoot().innerHTML = `
    <section class="card">
      <h2>Kontostände erfassen</h2>
      <p class="muted">Auch rückwirkend möglich — einfach den passenden Monat wählen. Ein bestehender Eintrag für Konto + Monat wird überschrieben. Leere Felder werden übersprungen.</p>
      <form id="entryForm" novalidate>
        <div class="entry-toolbar">
          <label class="entry-month-label">Monat
            ${monthPickerField("period", currentPeriod())}
          </label>
          <label class="entry-filter">
            <input type="checkbox" id="onlyMissing" role="switch" />
            Nur fehlende anzeigen
          </label>
        </div>
        <div class="entry-grid" id="entryGrid">
          ${state.accounts.map((a) => entryRowHTML(a)).join("")}
        </div>
        <div id="entryNotice" class="hint"></div>
        <button type="submit">Alle speichern</button>
      </form>
    </section>
  `;

  const form = document.getElementById("entryForm");
  const grid = document.getElementById("entryGrid");
  const notice = document.getElementById("entryNotice");
  const onlyMissing = document.getElementById("onlyMissing");

  function rowsWithAccounts() {
    return [...grid.querySelectorAll(".entry-row")].map((row) => ({
      row,
      account: state.accounts.find((a) => a.id === Number(row.dataset.accountId)),
    }));
  }

  // Letzten bekannten Wert vor dem gewählten Monat ermitteln, als Orientierung.
  function previousBalance(accountId, period) {
    return [...state.balances]
      .filter((b) => b.accountId === accountId && b.period < period)
      .sort((a, b) => (a.period < b.period ? -1 : 1))
      .pop();
  }

  function refreshGrid(period) {
    const inPeriod = balancesInPeriod(period);
    rowsWithAccounts().forEach(({ row, account }) => {
      const input = row.querySelector("input");
      const hint = row.querySelector(".entry-row-hint");
      const current = inPeriod.find((b) => b.accountId === account.id);
      input.value = current ? current.amountOriginal : "";

      const prev = previousBalance(account.id, period);
      hint.textContent = prev ? `zuletzt ${fmtMoney(prev.amountOriginal, prev.currencyOriginal)} (${periodLabel(prev.period)})` : "";
    });
    applyMissingFilter();
  }

  function applyMissingFilter() {
    const period = form.querySelector('input[name="period"]').value;
    const inPeriod = balancesInPeriod(period);
    rowsWithAccounts().forEach(({ row, account }) => {
      const hasEntry = inPeriod.some((b) => b.accountId === account.id);
      row.hidden = onlyMissing.checked && hasEntry;
    });
  }

  refreshGrid(currentPeriod());

  form.addEventListener("change", (e) => {
    if (e.target.name === "period") refreshGrid(e.target.value);
  });
  onlyMissing.addEventListener("change", applyMissingFilter);

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const period = form.querySelector('input[name="period"]').value;
    const dateISO = lastDayOfMonthISO(period);
    const rateCache = new Map(); // currency -> rateResult|null, damit gleiche Währungen nur einmal abgefragt werden

    let saved = 0;
    let failed = 0;

    notice.textContent = "Wird gespeichert …";

    for (const { row, account } of rowsWithAccounts()) {
      const input = row.querySelector("input");
      const raw = input.value.trim();
      if (raw === "") continue;
      const amount = parseFloat(raw);
      if (!Number.isFinite(amount)) continue;

      if (!rateCache.has(account.currency)) {
        let rateResult = await getExchangeRate(account.currency, state.baseCurrency, dateISO);
        if (!rateResult) {
          const manual = prompt(
            `Kein Wechselkurs ${account.currency} → ${state.baseCurrency} für ${dateISO} verfügbar (offline?).\nBitte Kurs manuell eingeben (1 ${account.currency} = ? ${state.baseCurrency}):`
          );
          const manualRate = parseFloat(manual);
          rateResult = manualRate > 0 ? { rate: manualRate, source: "manual", date: dateISO } : null;
        }
        rateCache.set(account.currency, rateResult);
      }

      const rateResult = rateCache.get(account.currency);
      if (!rateResult) {
        failed++;
        continue;
      }

      const amountBase = amount * rateResult.rate;
      await db.upsertBalance({
        accountId: account.id,
        period,
        amountOriginal: amount,
        currencyOriginal: account.currency,
        rate: rateResult.rate,
        amountBase,
      });
      saved++;
    }

    await loadState();
    refreshGrid(period);

    const parts = [`${saved} ${saved === 1 ? "Konto" : "Konten"} gespeichert.`];
    if (failed > 0) parts.push(`${failed} ohne Kurs übersprungen.`);
    notice.textContent = parts.join(" ");
  });
}

// ---------- Einträge (bestehende Kontostände bearbeiten) ----------

async function renderEntries() {
  if (state.balances.length === 0) {
    appRoot().innerHTML = `
      <section class="empty-state">
        <h2>Noch keine Einträge</h2>
        <p>Unter "Erfassen" kannst du deinen ersten Kontostand eintragen.</p>
        <a role="button" href="#/entry">Kontostand erfassen</a>
      </section>`;
    return;
  }

  const groups = new Map();
  state.balances.forEach((bal) => {
    const key = bal.accountId;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(bal);
  });

  const sections = [
    ...state.accounts.filter((a) => groups.has(a.id)).map((a) => ({ acc: a, balances: groups.get(a.id) })),
    ...[...groups.keys()]
      .filter((accountId) => !state.accounts.some((a) => a.id === accountId))
      .map((accountId) => ({ acc: null, balances: groups.get(accountId) })),
  ];

  appRoot().innerHTML = `
    <p class="muted">Bestehende Kontostände korrigieren oder löschen.</p>
    ${sections
      .map(
        ({ acc }, i) => `
    <section class="card">
      <h2>${acc ? acc.name : "(archiviertes/gelöschtes Konto)"}</h2>
      <div class="table-scroll">
        <table id="entriesTable-${i}">
          <thead>
            <tr>
              <th>Monat</th>
              <th>Betrag</th>
              <th></th>
            </tr>
          </thead>
          <tbody></tbody>
        </table>
      </div>
    </section>`
      )
      .join("")}
  `;

  sections.forEach(({ acc, balances }, i) => {
    const tbody = document.querySelector(`#entriesTable-${i} tbody`);
    const sorted = [...balances].sort((a, b) => (a.period < b.period ? 1 : a.period > b.period ? -1 : 0));

    sorted.forEach((bal) => {
      const row = el(`
        <tr data-id="${bal.id}">
          <td>${periodLabel(bal.period)}</td>
          <td>${fmtMoney(bal.amountOriginal, bal.currencyOriginal)}</td>
          <td class="entry-actions">
            <button class="secondary outline entry-edit-btn">Bearbeiten</button>
            <button class="secondary entry-delete-btn">Löschen</button>
          </td>
        </tr>
      `);

      row.querySelector(".entry-edit-btn").addEventListener("click", () => renderEntryEditRow(row, bal, acc));
      row.querySelector(".entry-delete-btn").addEventListener("click", async () => {
        if (!confirm(`Eintrag für ${acc ? acc.name : "Konto"} · ${periodLabel(bal.period)} wirklich löschen?`)) return;
        await db.deleteBalance(bal.id);
        await loadState();
        renderEntries();
      });

      tbody.appendChild(row);
    });
  });
}

function renderEntryEditRow(row, bal, acc) {
  const editRow = el(`
    <tr data-id="${bal.id}">
      <td>${periodLabel(bal.period)}</td>
      <td>
        <input type="number" step="0.01" class="entry-amount-input" value="${bal.amountOriginal}" />
        <span class="muted small">${bal.currencyOriginal}</span>
      </td>
      <td class="entry-actions">
        <button class="entry-save-btn">Speichern</button>
        <button type="button" class="secondary entry-cancel-btn">Abbrechen</button>
      </td>
    </tr>
  `);
  row.replaceWith(editRow);

  editRow.querySelector(".entry-cancel-btn").addEventListener("click", () => {
    editRow.replaceWith(row);
  });

  editRow.querySelector(".entry-save-btn").addEventListener("click", async () => {
    const amount = parseFloat(editRow.querySelector(".entry-amount-input").value);
    if (!Number.isFinite(amount)) {
      alert("Bitte einen gültigen Betrag eingeben.");
      return;
    }
    try {
      const amountBase = amount * bal.rate;
      await db.updateBalance(bal.id, { amountOriginal: amount, amountBase });
      await loadState();
      renderEntries();
    } catch (err) {
      console.error("Failed to update entry:", err);
      alert("Fehler beim Speichern: " + (err.message || String(err)));
    }
  });
}

// ---------- Vermögenswerte ----------

async function renderAssets() {
  const assetReminder = getAssetReminder();

  appRoot().innerHTML = `
    ${
      assetReminder
        ? `<div class="backup-banner">
             <span>⚠️ ${assetReminder}</span>
           </div>`
        : ""
    }
    <section class="card">
      <h2>Vermögenswerte</h2>
      <p class="muted">Anschaffungen wie Elektronik, Möbel oder Fahrzeuge mit ihrem aktuellen Wert. Werte direkt in der Liste bearbeiten — beim Ändern gilt der Eintrag als heute neu bewertet.</p>
      <div id="assetList"></div>
    </section>

    <section class="card">
      <h2>Neuer Vermögenswert</h2>
      <form id="assetForm">
        <label>Bezeichnung
          <input type="text" name="name" required placeholder="z.B. MacBook Pro" />
        </label>
        <label>Wert (${state.baseCurrency})
          <input type="number" step="0.01" name="value" required placeholder="0,00" />
        </label>
        <button type="submit">Anlegen</button>
      </form>
    </section>
  `;

  renderAssetList();

  document.getElementById("assetForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const value = parseFloat(fd.get("value"));
    if (!Number.isFinite(value)) {
      alert("Bitte einen gültigen Wert eingeben.");
      return;
    }
    try {
      await db.addAsset({ name: fd.get("name"), value });
      await loadState();
      renderAssetList();
      e.target.reset();
    } catch (err) {
      console.error("Failed to add asset:", err);
      alert("Fehler beim Anlegen: " + (err.message || String(err)));
    }
  });

  function renderAssetList() {
    const listEl = document.getElementById("assetList");
    if (state.assets.length === 0) {
      listEl.innerHTML = `<p class="empty-hint">Noch keine Vermögenswerte angelegt.</p>`;
      return;
    }
    listEl.innerHTML = "";
    [...state.assets]
      .sort((a, b) => a.name.localeCompare(b.name, "de"))
      .forEach((asset) => {
        const overdue = isAssetOverdue(asset);
        const row = el(`
        <article class="card asset-row" data-id="${asset.id}">
          <div class="asset-row-info">
            <strong>${asset.name}</strong>
            <span class="muted small">${asset.lastEvaluatedAt ? "zuletzt bewertet " + new Date(asset.lastEvaluatedAt).toLocaleDateString("de-DE") : "noch nie bewertet"}</span>
          </div>
          ${overdue ? `<span class="tag-badge overdue-badge">Neu bewerten</span>` : ""}
          <input type="number" step="0.01" class="asset-value-input" value="${asset.value}" aria-label="Wert von ${asset.name}" />
          <button type="button" class="secondary outline asset-delete-btn">Löschen</button>
        </article>
      `);

        row.querySelector(".asset-value-input").addEventListener("change", async (e) => {
          const newValue = parseFloat(e.target.value);
          if (!Number.isFinite(newValue)) {
            e.target.value = asset.value;
            return;
          }
          try {
            await db.updateAsset(asset.id, { value: newValue });
            await loadState();
            renderAssetList();
          } catch (err) {
            console.error("Failed to update asset:", err);
            alert("Fehler beim Speichern: " + (err.message || String(err)));
            e.target.value = asset.value;
          }
        });

        row.querySelector(".asset-delete-btn").addEventListener("click", async () => {
          if (!confirm(`"${asset.name}" wirklich löschen?`)) return;
          await db.deleteAsset(asset.id);
          await loadState();
          renderAssetList();
        });

        listEl.appendChild(row);
      });
  }
}

// ---------- Fixposten (wiederkehrende Ein-/Ausgaben) ----------

// Rechnet einen positiven Betrag in der angegebenen Währung in die
// Basiswährung um (heutiger Kurs). Bei fehlgeschlagener/fehlender API fragt
// es — wie beim Kontostand-Erfassen — nach einem manuellen Kurs.
async function convertMagnitudeToBase(magnitude, currency) {
  const dateISO = new Date().toISOString().slice(0, 10);
  let rateResult = await getExchangeRate(currency, state.baseCurrency, dateISO);
  if (!rateResult) {
    const manual = prompt(
      `Kein Wechselkurs ${currency} → ${state.baseCurrency} verfügbar (offline?).\nBitte Kurs manuell eingeben (1 ${currency} = ? ${state.baseCurrency}):`
    );
    const manualRate = parseFloat(manual);
    rateResult = manualRate > 0 ? { rate: manualRate, source: "manual", date: dateISO } : null;
  }
  if (!rateResult) return null;
  return { rate: rateResult.rate, amountBase: magnitude * rateResult.rate };
}

function signToggleHTML(sign) {
  const isExpense = sign < 0;
  return `<button type="button" class="sign-toggle ${isExpense ? "expense" : "income"}" data-sign="${isExpense ? -1 : 1}" aria-label="${isExpense ? "Ausgabe" : "Einnahme"}">${isExpense ? "−" : "+"}</button>`;
}

function subscriptionRowHTML(sub) {
  const monthly = monthlyEquivalent(sub);
  return `
    <article class="card subscription-row" data-id="${sub.id}">
      <input type="text" class="subscription-name-input" value="${sub.name.replace(/"/g, "&quot;")}" aria-label="Name" />
      <select class="subscription-interval-input" aria-label="Intervall">
        ${SUBSCRIPTION_INTERVALS.map((i) => `<option value="${i.value}" ${i.value === sub.interval ? "selected" : ""}>${i.label}</option>`).join("")}
      </select>
      <input type="text" list="currencyListSub" class="subscription-currency-input" value="${sub.currencyOriginal}" aria-label="Währung" />
      <div class="subscription-amount">
        ${signToggleHTML(sub.amountOriginal < 0 ? -1 : 1)}
        <input type="number" step="0.01" min="0" class="subscription-magnitude-input" value="${Math.abs(sub.amountOriginal)}" aria-label="Betrag" />
      </div>
      <span class="muted small subscription-monthly-hint">≈ ${fmtMoney(Math.abs(monthly), state.baseCurrency)}/Monat</span>
      <button type="button" class="secondary outline subscription-delete-btn" aria-label="Löschen">Löschen</button>
    </article>`;
}

async function renderSubscriptions() {
  appRoot().innerHTML = `
    ${overspendBannerHTML()}
    <section class="card">
      <h2>Fixposten</h2>
      <p class="muted">Wiederkehrende Ein- und Ausgaben wie Gehalt, Dividenden oder Abos. Über das Vorzeichen-Symbol zwischen Einnahme (+) und Ausgabe (−) umschalten. Alle Felder sind direkt bearbeitbar.</p>
      <div class="subscription-summary" id="subscriptionSummary"></div>
    </section>

    <datalist id="currencyListSub">
      ${CURRENCIES.map((c) => `<option value="${c}">`).join("")}
    </datalist>

    <section class="card">
      <h2>Einnahmen</h2>
      <div id="subscriptionIncomeList"></div>
    </section>

    <section class="card">
      <h2>Ausgaben</h2>
      <div id="subscriptionExpenseList"></div>
    </section>

    <section class="card">
      <h2>Neuer Fixposten</h2>
      <form id="subscriptionForm">
        <label>Name
          <input type="text" name="name" required placeholder="z.B. Netflix, Gehalt, Dividenden" />
        </label>
        <div class="grid">
          <label>Intervall
            <select name="interval">
              ${SUBSCRIPTION_INTERVALS.map((i) => `<option value="${i.value}" ${i.value === state.defaultSubscriptionInterval ? "selected" : ""}>${i.label}</option>`).join("")}
            </select>
          </label>
          <label>Währung
            <input list="currencyListSub" name="currency" value="${state.baseCurrency}" required />
          </label>
        </div>
        <label>Betrag
          <div class="subscription-amount">
            ${signToggleHTML(-1)}
            <input type="number" step="0.01" min="0" name="magnitude" required placeholder="0,00" />
          </div>
          <small class="muted">Standard ist Ausgabe (−). Für eine Einnahme wie Gehalt auf + umschalten.</small>
        </label>
        <button type="submit">Anlegen</button>
      </form>
    </section>
  `;

  renderSubscriptionSummary();
  renderSubscriptionLists();

  const form = document.getElementById("subscriptionForm");
  const formSignToggle = form.querySelector(".sign-toggle");
  formSignToggle.addEventListener("click", () => {
    const isExpense = formSignToggle.classList.contains("expense");
    formSignToggle.classList.toggle("expense", !isExpense);
    formSignToggle.classList.toggle("income", isExpense);
    formSignToggle.dataset.sign = isExpense ? "1" : "-1";
    formSignToggle.textContent = isExpense ? "+" : "−";
  });

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const fd = new FormData(form);
    const name = fd.get("name").trim();
    const interval = fd.get("interval");
    const currency = fd.get("currency").toUpperCase().trim();
    const magnitude = parseFloat(fd.get("magnitude"));
    if (!name || !Number.isFinite(magnitude) || magnitude <= 0) {
      alert("Bitte Name und einen gültigen Betrag eingeben.");
      return;
    }
    const sign = Number(formSignToggle.dataset.sign);
    const conv = await convertMagnitudeToBase(magnitude, currency);
    if (!conv) {
      alert("Kein Wechselkurs verfügbar — Fixposten wurde nicht gespeichert.");
      return;
    }
    try {
      await db.addSubscription({
        name,
        interval,
        amountOriginal: sign * magnitude,
        currencyOriginal: currency,
        rate: conv.rate,
        amountBase: sign * conv.amountBase,
      });
      await loadState();
      renderSubscriptionSummary();
      renderSubscriptionLists();
      form.reset();
      formSignToggle.classList.add("expense");
      formSignToggle.classList.remove("income");
      formSignToggle.dataset.sign = "-1";
      formSignToggle.textContent = "−";
      form.querySelector('[name="currency"]').value = state.baseCurrency;
      form.querySelector('[name="interval"]').value = state.defaultSubscriptionInterval;
    } catch (err) {
      console.error("Failed to add subscription:", err);
      alert("Fehler beim Anlegen: " + (err.message || String(err)));
    }
  });

  function renderSubscriptionSummary() {
    const { totalIncome, totalExpense, net } = computeSubscriptionTotals();
    document.getElementById("subscriptionSummary").innerHTML = `
      <div class="subscription-summary-item income">
        <span class="muted small">Einnahmen/Monat</span>
        <strong>${fmtMoney(totalIncome, state.baseCurrency)}</strong>
      </div>
      <div class="subscription-summary-item expense">
        <span class="muted small">Ausgaben/Monat</span>
        <strong>${fmtMoney(totalExpense, state.baseCurrency)}</strong>
      </div>
      <div class="subscription-summary-item net ${net >= 0 ? "positive" : "negative"}">
        <span class="muted small">Differenz</span>
        <strong>${net >= 0 ? "+" : ""}${fmtMoney(net, state.baseCurrency)}</strong>
      </div>
    `;
  }

  function renderSubscriptionLists() {
    const incomeEl = document.getElementById("subscriptionIncomeList");
    const expenseEl = document.getElementById("subscriptionExpenseList");
    const income = state.subscriptions.filter((s) => s.amountOriginal > 0).sort((a, b) => a.name.localeCompare(b.name, "de"));
    const expense = state.subscriptions.filter((s) => s.amountOriginal < 0).sort((a, b) => a.name.localeCompare(b.name, "de"));

    incomeEl.innerHTML = income.length === 0 ? `<p class="empty-hint">Noch keine Einnahmen erfasst.</p>` : "";
    expenseEl.innerHTML = expense.length === 0 ? `<p class="empty-hint">Noch keine Ausgaben erfasst.</p>` : "";

    income.forEach((sub) => wireSubscriptionRow(el(subscriptionRowHTML(sub)), sub, incomeEl));
    expense.forEach((sub) => wireSubscriptionRow(el(subscriptionRowHTML(sub)), sub, expenseEl));
  }

  function wireSubscriptionRow(row, sub, container) {
    container.appendChild(row);

    const signToggle = row.querySelector(".sign-toggle");
    signToggle.addEventListener("click", async () => {
      const isExpense = signToggle.classList.contains("expense");
      signToggle.classList.toggle("expense", !isExpense);
      signToggle.classList.toggle("income", isExpense);
      signToggle.dataset.sign = isExpense ? "1" : "-1";
      signToggle.textContent = isExpense ? "+" : "−";
      await saveRow();
    });

    ["change"].forEach((evt) => {
      row.querySelector(".subscription-name-input").addEventListener(evt, saveRow);
      row.querySelector(".subscription-interval-input").addEventListener(evt, saveRow);
      row.querySelector(".subscription-currency-input").addEventListener(evt, saveRow);
      row.querySelector(".subscription-magnitude-input").addEventListener(evt, saveRow);
    });

    row.querySelector(".subscription-delete-btn").addEventListener("click", async () => {
      if (!confirm(`"${sub.name}" wirklich löschen?`)) return;
      await db.deleteSubscription(sub.id);
      await loadState();
      renderSubscriptionSummary();
      renderSubscriptionLists();
    });

    async function saveRow() {
      const name = row.querySelector(".subscription-name-input").value.trim();
      const interval = row.querySelector(".subscription-interval-input").value;
      const currency = row.querySelector(".subscription-currency-input").value.toUpperCase().trim();
      const magnitude = parseFloat(row.querySelector(".subscription-magnitude-input").value);
      const sign = Number(row.querySelector(".sign-toggle").dataset.sign);

      if (!name || !Number.isFinite(magnitude) || magnitude < 0) {
        alert("Bitte einen gültigen Namen und Betrag eingeben.");
        await loadState();
        renderSubscriptionLists();
        return;
      }

      const conv = await convertMagnitudeToBase(magnitude, currency);
      if (!conv) {
        alert("Kein Wechselkurs verfügbar — Änderung wurde nicht gespeichert.");
        await loadState();
        renderSubscriptionLists();
        return;
      }

      try {
        await db.updateSubscription(sub.id, {
          name,
          interval,
          currencyOriginal: currency,
          amountOriginal: sign * magnitude,
          rate: conv.rate,
          amountBase: sign * conv.amountBase,
        });
        await loadState();
        renderSubscriptionSummary();
        renderSubscriptionLists();
      } catch (err) {
        console.error("Failed to update subscription:", err);
        alert("Fehler beim Speichern: " + (err.message || String(err)));
        await loadState();
        renderSubscriptionLists();
      }
    }
  }
}

// ---------- Einstellungen ----------

async function renderSettings() {
  const lastExport = await db.getSetting("lastExportAt", null);

  appRoot().innerHTML = `
    <section class="card">
      <h2>Basiswährung</h2>
      <p class="muted">Alle Beträge werden für Dashboard-Ansichten in diese Währung umgerechnet.</p>
      <select id="baseCurrencySelect">
        ${CURRENCIES.map((c) => `<option value="${c}" ${c === state.baseCurrency ? "selected" : ""}>${c}</option>`).join("")}
      </select>
    </section>

    <section class="card">
      <h2>Standardintervall für Fixposten</h2>
      <p class="muted">Wird beim Anlegen eines neuen Fixpostens vorausgewählt. Monatlich passt für die meisten, da Gehalt in der Regel monatlich eingeht.</p>
      <select id="defaultSubscriptionIntervalSelect">
        ${SUBSCRIPTION_INTERVALS.map((i) => `<option value="${i.value}" ${i.value === state.defaultSubscriptionInterval ? "selected" : ""}>${i.label}</option>`).join("")}
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
      } catch (err) {
        console.error("Failed to update base currency:", err);
      }
    });
  }

  document.getElementById("defaultSubscriptionIntervalSelect").addEventListener("change", async (e) => {
    try {
      await db.setSetting("defaultSubscriptionInterval", e.target.value);
      await loadState();
    } catch (err) {
      console.error("Failed to update default subscription interval:", err);
    }
  });

  document.getElementById("exportBtn").addEventListener("click", async () => {
    try {
      const exportData = await db.exportAllData();
      const suggestedName = `finanzgecko-backup-${new Date().toISOString().slice(0, 10)}.json`;
      const targetPath = await Neutralino.os.showSaveDialog("Backup speichern unter…", {
        defaultPath: suggestedName,
        filters: BACKUP_FILE_FILTERS,
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
        filters: BACKUP_FILE_FILTERS,
      });
      if (!entries || entries.length === 0) return; // Dialog abgebrochen
      if (!confirm("Import ersetzt ALLE aktuellen Daten. Fortfahren?")) return;

      const raw = await Neutralino.filesystem.readFile(entries[0]);
      const imported = JSON.parse(raw);
      await db.importAllData(imported);
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
  "https://raw.githubusercontent.com/kreativanders/finanzgecko/main/update-manifest.json";

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
  
  // Setup navigation click handlers - update location.hash and let the
  // existing "hashchange" listener trigger the router. This keeps
  // location.hash in sync with the visible view, which the resize handler
  // below relies on when it re-renders without an explicit hash override.
  const navLinks = document.querySelectorAll("nav a[data-route]");
  if (navLinks.length === 0) {
    console.error("Navigation links not found!");
  } else {
    navLinks.forEach((a) => {
      a.addEventListener("click", async (e) => {
        e.preventDefault();
        const targetHash = a.getAttribute("href");
        if (location.hash === targetHash) {
          // hashchange won't fire for a same-hash assignment, so re-render explicitly
          await router(targetHash);
        } else {
          location.hash = targetHash;
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

// Tests für db.js - IndexedDB-Operationen
// Diese Tests benötigen eine Browser-Umgebung oder ein Mock für IndexedDB
// Für Node.js-Umgebung verwenden wir fake-indexeddb

import { assert } from 'node:assert';
import { describe, it, before, after } from 'node:test';

// Mock IndexedDB für Node.js
import 'fake-indexeddb/auto';

// Importiere die db-Funktionen
import * as db from '../js/db.js';

describe('db.js - Account Operations', async () => {
  before(async () => {
    // Öffne die Datenbank vor den Tests
    await db.openDB();
  });

  after(async () => {
    // Lösche Testdaten
    const t = await db.tx(['accounts', 'balances', 'settings', 'rates'], 'readwrite');
    await Promise.all([
      t.objectStore('accounts').clear(),
      t.objectStore('balances').clear(),
      t.objectStore('settings').clear(),
      t.objectStore('rates').clear(),
    ]);
  });

  it('should add a new account', async () => {
    const account = {
      bank: 'Test Bank',
      tag: 'Girokonto',
      currency: 'EUR',
      color: '#00c878',
    };

    const result = await db.addAccount(account);

    assert.ok(result.id, 'Account sollte eine ID haben');
    assert.strictEqual(result.bank, 'Test Bank');
    assert.strictEqual(result.tag, 'Girokonto');
    assert.strictEqual(result.currency, 'EUR');
    assert.strictEqual(result.color, '#00c878');
    assert.strictEqual(result.archived, false);
    assert.ok(result.createdAt, 'Sollte createdAt haben');
  });

  it('should add account without color (uses null)', async () => {
    const account = {
      bank: 'Test Bank No Color',
      tag: 'Tagesgeld',
      currency: 'EUR',
    };

    const result = await db.addAccount(account);

    assert.ok(result.id, 'Account sollte eine ID haben');
    assert.strictEqual(result.bank, 'Test Bank No Color');
    assert.strictEqual(result.color, null);
  });

  it('should get all accounts', async () => {
    // Erst ein Konto hinzufügen
    await db.addAccount({
      bank: 'Bank 1',
      tag: 'Girokonto',
      currency: 'EUR',
      color: '#00c878',
    });
    await db.addAccount({
      bank: 'Bank 2',
      tag: 'Tagesgeld',
      currency: 'USD',
      color: '#2fd0a0',
    });

    const accounts = await db.getAccounts();

    assert.strictEqual(accounts.length, 2, 'Sollte 2 Konten zurückgeben');
    assert(accounts.some(a => a.bank === 'Bank 1'));
    assert(accounts.some(a => a.bank === 'Bank 2'));
  });

  it('should get a specific account by ID', async () => {
    const newAccount = await db.addAccount({
      bank: 'Specific Bank',
      tag: 'Depot',
      currency: 'EUR',
      color: '#00c878',
    });

    const retrieved = await db.getAccount(newAccount.id);

    assert.strictEqual(retrieved.id, newAccount.id);
    assert.strictEqual(retrieved.bank, 'Specific Bank');
  });

  it('should update an account', async () => {
    const account = await db.addAccount({
      bank: 'Original Bank',
      tag: 'Girokonto',
      currency: 'EUR',
      color: '#00c878',
    });

    const updated = await db.updateAccount(account.id, {
      bank: 'Updated Bank',
      tag: 'Tagesgeld',
    });

    assert.strictEqual(updated.bank, 'Updated Bank');
    assert.strictEqual(updated.tag, 'Tagesgeld');
  });

  it('should archive an account', async () => {
    const account = await db.addAccount({
      bank: 'Archive Test Bank',
      tag: 'Girokonto',
      currency: 'EUR',
      color: '#00c878',
    });

    await db.archiveAccount(account.id);

    const archived = await db.getAccount(account.id);
    assert.strictEqual(archived.archived, true);

    // Archivierte Konten sollten nicht in der Standard-Liste auftauchen
    const activeAccounts = await db.getAccounts({ includeArchived: false });
    assert(activeAccounts.every(a => a.id !== account.id), 'Archiviertes Konto sollte nicht in aktiver Liste sein');

    // Aber mit includeArchived: true sollten sie auftauchen
    const allAccounts = await db.getAccounts({ includeArchived: true });
    assert(allAccounts.some(a => a.id === account.id), 'Archiviertes Konto sollte mit includeArchived:true auftauchen');
  });
});

describe('db.js - Balance Operations', async () => {
  let accountId;

  before(async () => {
    await db.openDB();
    const account = await db.addAccount({
      bank: 'Balance Test Bank',
      tag: 'Girokonto',
      currency: 'EUR',
      color: '#00c878',
    });
    accountId = account.id;
  });

  it('should upsert a balance (add new)', async () => {
    const balance = {
      accountId,
      period: '2024-01',
      amountOriginal: 1000,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 1000,
      note: 'Test balance',
    };

    const result = await db.upsertBalance(balance);

    assert.ok(result.id, 'Balance sollte eine ID haben');
    assert.strictEqual(result.accountId, accountId);
    assert.strictEqual(result.period, '2024-01');
    assert.strictEqual(result.amountBase, 1000);
  });

  it('should upsert a balance (update existing)', async () => {
    // Erste Balance hinzufügen
    await db.upsertBalance({
      accountId,
      period: '2024-02',
      amountOriginal: 1000,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 1000,
      note: 'Original',
    });

    // Gleiche Periode nochmal einfügen (sollte aktualisieren)
    const updated = await db.upsertBalance({
      accountId,
      period: '2024-02',
      amountOriginal: 1500,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 1500,
      note: 'Updated',
    });

    assert.strictEqual(updated.amountBase, 1500);
    assert.strictEqual(updated.note, 'Updated');

    // Es sollte nur ein Eintrag für diese Periode geben
    const allBalances = await db.getAllBalances();
    const februaryBalances = allBalances.filter(b => b.period === '2024-02' && b.accountId === accountId);
    assert.strictEqual(februaryBalances.length, 1, 'Sollte nur einen Eintrag pro Periode geben');
  });

  it('should get balances for a specific account', async () => {
    await db.upsertBalance({
      accountId,
      period: '2024-03',
      amountOriginal: 2000,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 2000,
    });
    await db.upsertBalance({
      accountId,
      period: '2024-04',
      amountOriginal: 2500,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 2500,
    });

    const balances = await db.getBalancesForAccount(accountId);

    assert.strictEqual(balances.length, 3); // 2024-02, 2024-03, 2024-04
    assert(balances.every(b => b.accountId === accountId));
    // Sollte chronologisch sortiert sein
    assert(balances[0].period < balances[1].period);
    assert(balances[1].period < balances[2].period);
  });

  it('should get balance for specific account and period', async () => {
    await db.upsertBalance({
      accountId,
      period: '2024-05',
      amountOriginal: 3000,
      currencyOriginal: 'EUR',
      rate: 1,
      amountBase: 3000,
    });

    const balance = await db.getBalanceForAccountPeriod(accountId, '2024-05');

    assert.ok(balance, 'Balance sollte gefunden werden');
    assert.strictEqual(balance.period, '2024-05');
    assert.strictEqual(balance.amountBase, 3000);
  });

  it('should return null for non-existent balance', async () => {
    const balance = await db.getBalanceForAccountPeriod(accountId, '2024-99');
    assert.strictEqual(balance, null);
  });
});

describe('db.js - Settings Operations', async () => {
  it('should set and get a setting', async () => {
    await db.setSetting('testKey', 'testValue');
    const value = await db.getSetting('testKey');
    assert.strictEqual(value, 'testValue');
  });

  it('should return fallback for non-existent setting', async () => {
    const value = await db.getSetting('nonExistent', 'fallback');
    assert.strictEqual(value, 'fallback');
  });
});

describe('db.js - Rate Cache Operations', async () => {
  it('should cache and retrieve exchange rates', async () => {
    await db.setCachedRate('EUR_USD_2024-01-01', 1.1);
    const rate = await db.getCachedRate('EUR_USD_2024-01-01');
    assert.strictEqual(rate, 1.1);
  });

  it('should return null for non-existent rate', async () => {
    const rate = await db.getCachedRate('EUR_JPY_1999-01-01');
    assert.strictEqual(rate, null);
  });
});

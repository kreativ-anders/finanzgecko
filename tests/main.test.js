// Tests für main.js - Helper-Funktionen
import { assert } from 'node:assert';
import { describe, it } from 'node:test';

// Importiere die reinen Helper-Funktionen (ohne DOM-Abhängigkeiten)
// Wir müssen diese Funktionen exportieren oder hier duplizieren
// Für echte Tests sollten wir sie in main.js exportieren

// Temporär hier definiert für Tests (sollten später aus main.js importiert werden)
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

describe('main.js - Helper Functions', () => {
  describe('fmtMoney', () => {
    it('should format positive currency values', () => {
      const result = fmtMoney(1234.56, 'EUR');
      assert.strictEqual(result, '1.234,56 €');
    });

    it('should format negative currency values', () => {
      const result = fmtMoney(-1234.56, 'EUR');
      assert.strictEqual(result, '-1.234,56 €');
    });

    it('should format zero', () => {
      const result = fmtMoney(0, 'EUR');
      assert.strictEqual(result, '0,00 €');
    });

    it('should format large numbers', () => {
      const result = fmtMoney(1234567.89, 'EUR');
      assert.strictEqual(result, '1.234.567,89 €');
    });

    it('should format with different currencies', () => {
      const result = fmtMoney(1000, 'USD');
      assert(result.includes('$'));
    });

    it('should handle invalid currency gracefully', () => {
      const result = fmtMoney(1000, 'XYZ');
      assert.strictEqual(result, '1000.00 XYZ');
    });

    it('should round to 2 decimal places', () => {
      const result = fmtMoney(123.456, 'EUR');
      assert.strictEqual(result, '123,46 €');
    });
  });

  describe('periodLabel', () => {
    it('should format January', () => {
      const result = periodLabel('2024-01');
      assert.strictEqual(result, 'Jan 2024');
    });

    it('should format December', () => {
      const result = periodLabel('2024-12');
      assert.strictEqual(result, 'Dez 2024');
    });

    it('should format all months correctly', () => {
      const months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
      for (let i = 1; i <= 12; i++) {
        const period = `2024-${String(i).padStart(2, '0')}`;
        const result = periodLabel(period);
        assert.strictEqual(result, `${months[i - 1]} 2024`);
      }
    });
  });

  describe('lastDayOfMonthISO', () => {
    it('should return last day of January', () => {
      const result = lastDayOfMonthISO('2024-01');
      assert.strictEqual(result, '2024-01-31');
    });

    it('should return last day of February (non-leap year)', () => {
      const result = lastDayOfMonthISO('2023-02');
      assert.strictEqual(result, '2023-02-28');
    });

    it('should return last day of February (leap year)', () => {
      const result = lastDayOfMonthISO('2024-02');
      assert.strictEqual(result, '2024-02-29');
    });

    it('should return last day of April', () => {
      const result = lastDayOfMonthISO('2024-04');
      assert.strictEqual(result, '2024-04-30');
    });

    it('should return last day of December', () => {
      const result = lastDayOfMonthISO('2024-12');
      assert.strictEqual(result, '2024-12-31');
    });
  });

  describe('currentPeriod', () => {
    it('should return current year and month in YYYY-MM format', () => {
      const result = currentPeriod();
      const now = new Date();
      const expected = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
      assert.strictEqual(result, expected);
    });
  });
});

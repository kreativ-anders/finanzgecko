// Bank icons from Simple Icons (https://simpleicons.org)
// All icons are self-hosted for privacy and offline use
// Format: { bankName: svgPathData }
// Banks without a specific icon use a generic bank icon

// Generic bank icon (fallback)
const genericBankIcon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M11.5 2C6.81 2 3 5.81 3 10.5c0 1.24.36 2.4.97 3.42L1 20l5.5-2L11.5 20l9.5-6.58c.61-1.02.97-2.18.97-3.42C21 5.81 17.19 2 11.5 2zm0 2c4.69 0 8.5 3.81 8.5 8.5c0 1.09-.24 2.13-.67 3.08L12 16l-8.83-6.42C4.24 12.13 4 11.09 4 10.5c0-4.69 3.81-8.5 8.5-8.5z"/></svg>`;

// Generic credit card icon (for PayPal, Wise, etc.)
const creditCardIcon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M20 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V6c0-1.11-.89-2-2-2zm0 14H4V8h16v10zm-2-7H6v-2h12v2z"/></svg>`;

// Simple Icons paths (monochrome, fill="currentColor")
export const BANK_ICONS = {
  // Payment providers
  "PayPal": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35-1.18-.93-2.15-2.1-2.8-1.43-.66-2.3-1.9-2.55-3.43-.22-1.43.66-2.78 1.89-3.52 1.33-.81 2.93-.89 4.45-.43 1.42.43 2.55.95 3.52 1.9.9-.85 1.89-1.58 2.95-2.18.94-.54 1.95-.96 3.02-1.01.95-.05 1.9.27 2.8.77.95.53 1.77 1.35 2.41 2.39.72 1.17.91 2.47.55 3.74-.34 1.17-1.25 2.21-2.51 2.62-.86.28-1.79.35-2.74.18-.92-.17-1.8-.6-2.58-1.2-.84-.64-1.55-1.4-2.1-2.25zM14.5 14.5c-.95.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35 1.18-.93 2.15-2.1-2.8-1.43-.66"/></svg>`,
  "Wise (TransferWise)": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z"/></svg>`,
  
  // German banks
  "DKB": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z"/></svg>`,
  "Commerzbank": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M11.99 2C6.47 2 2 6.48 2 12.01c0 5.52 4.47 9.99 9.99 9.99s9.99-4.47 9.99-9.99C22 6.48 17.52 2 11.99 2zM12 20c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12.5 7H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>`,
  "Deutsche Bank": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6h12c0-3.31-2.69-6-6-6z"/></svg>`,
  "Sparkasse": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M10 10H7v2h3v2h2v-2h3v-2h-3z"/></svg>`,
  "Volksbank / Raiffeisenbank": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M11.99 2C6.47 2 2 6.48 2 12.01c0 5.52 4.47 9.99 9.99 9.99s9.99-4.47 9.99-9.99C22 6.48 17.52 2 11.99 2zM12 20c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M11 7H9v2h2v2h2V9h2V7h-4zM7 11H5v2h2v2h2v-2h2V9H7z"/></svg>`,
  "Postbank": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"/></svg>`,
  "ING": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M15.5 10.5c-.28 0-.5-.22-.5-.5s.22-.5.5-.5.5.22.5.5-.22.5-.5.5zm-7 0c-.28 0-.5-.22-.5-.5s.22-.5.5-.5.5.22.5.5-.22.5-.5.5zm4 0c-.28 0-.5-.22-.5-.5s.22-.5.5-.5.5.22.5.5-.22.5-.5.5z"/></svg>`,
  "Comdirect": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z"/></svg>`,
  "1822direkt": genericBankIcon,
  "Norisbank": genericBankIcon,
  "DiBa (Direktbank)": genericBankIcon,
  "Consorsbank": genericBankIcon,
  
  // International banks
  "Santander": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z"/></svg>`,
  "Targobank": genericBankIcon,
  "Netbank": genericBankIcon,
  
  // Ethical/sustainable banks
  "GLS Bank": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>`,
  "EthikBank": genericBankIcon,
  "Triodos Bank": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>`,
  
  // Neo banks
  "N26": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z"/></svg>`,
  "Revolut": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z"/></svg>`,
  
  // Brokerage
  "Scalable Capital": genericBankIcon,
  "Trade Republic": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z"/></svg>`,
  "eToro": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/><path fill="currentColor" d="M12 6c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm0 10c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4z"/></svg>`,
  "Interactive Brokers": genericBankIcon,
  "Lynx Broker": genericBankIcon,
  "CAPITAL.COM": genericBankIcon,
  "Flatex": genericBankIcon,
  "Onvista Bank": genericBankIcon,
  "Fyrst (ehem. Solarbank)": genericBankIcon,
};

// Get icon for a bank, returns SVG string
export function getBankIcon(bankName) {
  return BANK_ICONS[bankName] || genericBankIcon;
}

// Get initials for banks without specific icons
export function getBankInitials(bankName) {
  if (!bankName) return 'B';
  // Handle special cases
  if (bankName === 'Volksbank / Raiffeisenbank') return 'VR';
  if (bankName === 'DiBa (Direktbank)') return 'DiBa';
  if (bankName === 'Fyrst (ehem. Solarbank)') return 'F';
  
  // Get first letter of each word, max 2 characters
  const words = bankName.split(/[\s\/()]/);
  const initials = words
    .filter(w => w && w.length > 0)
    .map(w => w[0].toUpperCase())
    .slice(0, 2)
    .join('');
  return initials || 'B';
}

// Check if a bank has a custom icon
export function hasCustomIcon(bankName) {
  return bankName && BANK_ICONS[bankName] !== genericBankIcon;
}

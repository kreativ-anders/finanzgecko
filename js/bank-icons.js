// Bank icons - using initials in a circle for better recognition
// Each bank gets its initials displayed in a colored circle
// More recognizable than generic SVG icons

// Helper to create initial circle icon
export function createInitialIcon(initials, size = 32) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" width="${size}" height="${size}">
    <circle cx="${size/2}" cy="${size/2}" r="${size/2}" fill="currentColor" opacity="0.2"/>
    <text x="50%" y="55%" dominant-baseline="middle" text-anchor="middle" 
          fill="currentColor" font-size="${Math.round(size * 0.6)}" 
          font-weight="700" font-family="sans-serif">${initials}</text>
  </svg>`;
}

// Get bank initials for icon
export function getBankInitials(bankName) {
  if (!bankName) return 'B';
  
  // Handle special cases for better recognition
  const specialCases = {
    'PayPal': 'PP',
    'Wise (TransferWise)': 'W',
    'DKB': 'DKB',
    'Commerzbank': 'CB',
    'Deutsche Bank': 'DB',
    'Sparkasse': 'S',
    'Volksbank / Raiffeisenbank': 'VR',
    'Postbank': 'PB',
    'ING': 'ING',
    'Comdirect': 'CD',
    '1822direkt': '1822',
    'Norisbank': 'NB',
    'DiBa (Direktbank)': 'DiBa',
    'Consorsbank': 'C',
    'Santander': 'S',
    'Targobank': 'T',
    'Netbank': 'NB',
    'GLS Bank': 'GLS',
    'EthikBank': 'EB',
    'Triodos Bank': 'T',
    'N26': 'N26',
    'Revolut': 'R',
    'Scalable Capital': 'SC',
    'Trade Republic': 'TR',
    'eToro': 'eT',
    'Interactive Brokers': 'IB',
    'Lynx Broker': 'L',
    'CAPITAL.COM': 'CC',
    'Flatex': 'F',
    'Onvista Bank': 'O',
    'Fyrst (ehem. Solarbank)': 'F',
  };
  
  if (specialCases[bankName]) return specialCases[bankName];
  
  // Get first letter of each word, max 2-3 characters
  const words = bankName.split(/[\s\/()]/);
  const initials = words
    .filter(w => w && w.length > 0)
    .map(w => w[0].toUpperCase())
    .slice(0, 3)
    .join('');
  return initials || 'B';
}

// Create bank icon (initial circle)
export function getBankIcon(bankName) {
  const initials = getBankInitials(bankName);
  return createInitialIcon(initials);
}

// Legacy exports for compatibility
export function hasCustomIcon(bankName) {
  return false; // All use initials now
}

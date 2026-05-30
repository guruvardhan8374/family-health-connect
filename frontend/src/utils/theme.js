export const PALETTES = {
  blue: {
    '--brand-50': '#eff6ff',
    '--brand-100': '#dbeafe',
    '--brand-200': '#bfdbfe',
    '--brand-300': '#93c5fd',
    '--brand-400': '#60a5fa',
    '--brand-500': '#3b82f6',
    '--brand-600': '#2563eb',
    '--brand-700': '#1d4ed8',
    '--brand-800': '#1e40af',
    '--brand-900': '#1e3a8a',
  },
  emerald: {
    '--brand-50': '#ecfdf5',
    '--brand-100': '#d1fae5',
    '--brand-200': '#a7f3d0',
    '--brand-300': '#6ee7b7',
    '--brand-400': '#34d399',
    '--brand-500': '#10b981',
    '--brand-600': '#059669',
    '--brand-700': '#047857',
    '--brand-800': '#065f46',
    '--brand-900': '#064e3b',
  },
  indigo: {
    '--brand-50': '#e0e7ff',
    '--brand-100': '#c7d2fe',
    '--brand-200': '#a5b4fc',
    '--brand-300': '#818cf8',
    '--brand-400': '#6366f1',
    '--brand-500': '#4f46e5',
    '--brand-600': '#4338ca',
    '--brand-700': '#3730a3',
    '--brand-800': '#312e81',
    '--brand-900': '#1e1b4b',
  },
  rose: {
    '--brand-50': '#fff1f2',
    '--brand-100': '#ffe4e6',
    '--brand-200': '#fecdd3',
    '--brand-300': '#fda4af',
    '--brand-400': '#fb7185',
    '--brand-500': '#f43f5e',
    '--brand-600': '#e11d48',
    '--brand-700': '#be123c',
    '--brand-800': '#9f1239',
    '--brand-900': '#881337',
  },
  violet: {
    '--brand-50': '#f5f3ff',
    '--brand-100': '#ede9fe',
    '--brand-200': '#ddd6fe',
    '--brand-300': '#c4b5fd',
    '--brand-400': '#a78bfa',
    '--brand-500': '#8b5cf6',
    '--brand-600': '#7c3aed',
    '--brand-700': '#6d28d9',
    '--brand-800': '#5b21b6',
    '--brand-900': '#4c1d95',
  },
  orange: {
    '--brand-50': '#fff7ed',
    '--brand-100': '#ffedd5',
    '--brand-200': '#fed7aa',
    '--brand-300': '#fdba74',
    '--brand-400': '#fb923c',
    '--brand-500': '#f97316',
    '--brand-600': '#ea580c',
    '--brand-700': '#c2410c',
    '--brand-800': '#9a3412',
    '--brand-900': '#7c2d12',
  }
};

export function applyTheme(color, darkMode) {
  const root = document.documentElement;
  const palette = PALETTES[color] || PALETTES.blue;
  
  // Set all color variables
  Object.entries(palette).forEach(([variable, val]) => {
    root.style.setProperty(variable, val);
  });

  // Handle dark mode classes and variable values
  if (darkMode) {
    root.classList.add('dark');
    root.style.setProperty('--navy-50', '#0f172a');
    root.style.setProperty('--navy-100', '#1e293b');
    root.style.setProperty('--navy-500', '#94a3b8');
    root.style.setProperty('--navy-800', '#cbd5e1');
    root.style.setProperty('--navy-900', '#f8fafc');
    // Store in localStorage for persistence before settings API loads
    localStorage.setItem('theme_dark_mode', 'true');
  } else {
    root.classList.remove('dark');
    root.style.setProperty('--navy-50', '#f4f6f8');
    root.style.setProperty('--navy-100', '#e1e6ed');
    root.style.setProperty('--navy-500', '#64748b');
    root.style.setProperty('--navy-800', '#1e293b');
    root.style.setProperty('--navy-900', '#0f172a');
    localStorage.setItem('theme_dark_mode', 'false');
  }
  localStorage.setItem('theme_color', color || 'blue');
}

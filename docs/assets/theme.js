// Theme toggle (System → Hell → Dunkel), mirroring the app's AppThemeMode. See dev/ai/website.md.
// Loaded synchronously in <head> so data-theme is set before first paint — no flash of the wrong theme.
(function () {
  'use strict';

  var KEY = 'finanzgecko-theme';
  var MODES = ['system', 'light', 'dark'];
  var root = document.documentElement;
  var english = (root.lang || '').indexOf('en') === 0;
  var LABELS = english
    ? { prefix: 'Appearance', system: 'System', light: 'Light', dark: 'Dark' }
    : { prefix: 'Darstellung', system: 'System', light: 'Hell', dark: 'Dunkel' };
  var ICONS = {
    system: '<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18z" fill="currentColor"/>',
    light: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    dark: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>'
  };
  var LIGHT_QUERY = '(prefers-color-scheme: light)';

  // WARNING: Storage can throw (Safari private mode, blocked site data) — the page must work without it.
  function load() {
    try {
      var stored = localStorage.getItem(KEY);
      return MODES.indexOf(stored) > 0 ? stored : 'system';
    } catch (e) {
      return 'system';
    }
  }

  function save(mode) {
    try {
      if (mode === 'system') localStorage.removeItem(KEY);
      else localStorage.setItem(KEY, mode);
    } catch (e) { /* choice just won't survive the reload */ }
  }

  // <source media> can't see data-theme, so the light screenshots' query is swapped for a constant.
  function applyPictures(mode) {
    var sources = document.querySelectorAll('picture source[data-theme-media], picture source[media="' + LIGHT_QUERY + '"]');
    for (var i = 0; i < sources.length; i++) {
      var s = sources[i];
      if (!s.hasAttribute('data-theme-media')) s.setAttribute('data-theme-media', s.getAttribute('media'));
      s.setAttribute('media', mode === 'light' ? 'all' : mode === 'dark' ? 'not all' : s.getAttribute('data-theme-media'));
    }
  }

  function applyThemeColor() {
    var meta = document.querySelector('meta[name="theme-color"]');
    var bg = getComputedStyle(root).getPropertyValue('--bg').trim();
    if (meta && bg) meta.setAttribute('content', bg);
  }

  function apply(mode) {
    if (mode === 'system') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', mode);
  }

  function render(button, mode) {
    var label = LABELS.prefix + ': ' + LABELS[mode];
    button.setAttribute('aria-label', label);
    button.title = label;
    button.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
      'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICONS[mode] + '</svg>';
  }

  var mode = load();
  apply(mode);

  document.addEventListener('DOMContentLoaded', function () {
    applyPictures(mode);
    applyThemeColor();

    // Injected rather than written into each page, so visitors without JavaScript never see a dead button.
    var header = document.querySelector('header.site .wrap');
    if (!header) return;
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'theme-toggle';
    render(button, mode);
    button.addEventListener('click', function () {
      mode = MODES[(MODES.indexOf(mode) + 1) % MODES.length];
      apply(mode);
      save(mode);
      applyPictures(mode);
      applyThemeColor();
      render(button, mode);
    });
    header.appendChild(button);
  });

  // Keeps theme-color in sync while "System" follows an OS switch.
  if (window.matchMedia) {
    var mq = window.matchMedia(LIGHT_QUERY);
    var onChange = function () { if (mode === 'system') applyThemeColor(); };
    if (mq.addEventListener) mq.addEventListener('change', onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }
})();

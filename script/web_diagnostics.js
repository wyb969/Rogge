/* Local-only browser crash breadcrumbs; never sends a network request. */
(function (w) {
  if (w.RoggeDiagnostics) return;
  const key = 'rogge:3184628:diagnostics:v1';
  const events = [], tasks = [];
  let previous = null, current = null, storage = true;
  try { previous = JSON.parse(w.localStorage.getItem(key) || 'null'); }
  catch (_) { storage = false; }
  const bounded = (list, value) => { list.push(value); if (list.length > 24) list.shift(); };
  const environment = () => ({
    user_agent: String(w.navigator && w.navigator.userAgent || '').slice(0, 256),
    navigation: w.performance && w.performance.getEntriesByType ? (w.performance.getEntriesByType('navigation')[0] || {}).type || 'unknown' : 'unknown',
    visibility: w.document && w.document.hidden ? 'hidden' : 'visible',
    storage_available: storage,
    js_heap_bytes: w.performance && w.performance.memory ? w.performance.memory.usedJSHeapSize : null
  });
  function save() {
    if (!current) return;
    current.browser = environment();
    current.browser_events = events.slice();
    current.long_tasks = tasks.slice();
    current.browser_saved_ms = Date.now();
    try { w.localStorage.setItem(key, JSON.stringify(current)); }
    catch (_) { storage = false; current.browser.storage_available = false; }
  }
  function note(kind, message) {
    bounded(events, {at_ms: Date.now(), kind, message: String(message || '').slice(0, 1400)});
    save();
  }
  w.RoggeDiagnostics = {
    previous,
    update(report) { current = report; save(); },
    latest() { return current || (previous && {...previous, reopened_browser: environment()}); },
    note
  };
  w.addEventListener('error', event => note('error', event.error && event.error.stack || event.message));
  w.addEventListener('unhandledrejection', event => note('unhandled_rejection', event.reason && event.reason.stack || event.reason));
  w.addEventListener('pagehide', () => note('pagehide', 'Page hidden/unloaded; this alone does not prove a crash.'));
  if (w.document) {
    w.document.addEventListener('visibilitychange', () => note('visibility', w.document.hidden ? 'hidden' : 'visible'));
    const canvas = w.document.querySelector('canvas');
    if (canvas) {
      canvas.addEventListener('webglcontextlost', () => note('webgl_context_lost', 'Graphics context lost'));
      canvas.addEventListener('webglcontextrestored', () => note('webgl_context_restored', 'Graphics context restored'));
    }
  }
  try {
    if (w.PerformanceObserver) {
      const observer = new w.PerformanceObserver(list => {
        for (const entry of list.getEntries()) bounded(tasks, {at_ms: Math.round(entry.startTime), duration_ms: Math.round(entry.duration)});
      });
      observer.observe({type: 'longtask', buffered: true});
    }
  } catch (_) { /* Safari does not expose every performance observer type. */ }
})(globalThis);

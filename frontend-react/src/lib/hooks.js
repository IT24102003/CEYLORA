import { useCallback, useEffect, useRef, useState } from "react";

export const errorMessage = (err, fallback) => err?.response?.data?.message || err?.message || fallback;

export const formatLKR = (n, digits = 0) =>
  `LKR ${Number(n ?? 0).toLocaleString(undefined, { maximumFractionDigits: digits })}`;

/**
 * Loads data with explicit loading/error state. `reload()` re-runs the fetcher
 * (keeping the previous data visible, so lists don't flash back to skeletons).
 */
export function useRemote(fetcher, deps = []) {
  const [state, setState] = useState({ data: null, loading: true, error: null });
  const fetcherRef = useRef(fetcher);
  fetcherRef.current = fetcher;

  const run = useCallback(async () => {
    setState((s) => ({ ...s, loading: true, error: null }));
    try {
      const data = await fetcherRef.current();
      setState({ data, loading: false, error: null });
    } catch (err) {
      console.error(err);
      setState((s) => ({ ...s, loading: false, error: err }));
    }
  }, []);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { run(); }, deps);

  return { ...state, reload: run };
}

/** Runs an async action with a busy flag; resolves to true on success. */
export function useAction() {
  const [busy, setBusy] = useState(null);
  const run = useCallback(async (key, fn) => {
    setBusy(key ?? true);
    try { await fn(); return true; } finally { setBusy(null); }
  }, []);
  return [busy, run];
}

export function useTheme() {
  const [theme, setTheme] = useState(() => {
    try { return localStorage.getItem("ceylora_theme"); } catch { return null; }
  });

  useEffect(() => {
    const dark = theme ? theme === "dark" : true;
    document.documentElement.dataset.theme = dark ? "dark" : "light";
  }, [theme]);

  const toggle = () => {
    const isDark = document.documentElement.dataset.theme === "dark";
    const next = isDark ? "light" : "dark";
    setTheme(next);
    try { localStorage.setItem("ceylora_theme", next); } catch { /* ignore */ }
  };
  return [document.documentElement.dataset.theme === "dark", toggle];
}

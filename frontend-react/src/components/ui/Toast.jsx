import { createContext, useCallback, useContext, useMemo, useState } from "react";
import { CheckCircle2, Info, X, XCircle } from "lucide-react";

const ToastCtx = createContext(null);
export const useToast = () => useContext(ToastCtx);

const ICONS = { success: CheckCircle2, error: XCircle, info: Info };
let nextId = 1;

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);

  const dismiss = useCallback((id) => {
    setToasts((t) => t.map((x) => (x.id === id ? { ...x, leaving: true } : x)));
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 200);
  }, []);

  const api = useMemo(() => {
    const push = (tone, message) => {
      const id = nextId++;
      setToasts((t) => [...t.slice(-3), { id, tone, message }]);
      setTimeout(() => dismiss(id), tone === "error" ? 6000 : 3800);
    };
    return { success: (m) => push("success", m), error: (m) => push("error", m), info: (m) => push("info", m) };
  }, [dismiss]);

  return (
    <ToastCtx.Provider value={api}>
      {children}
      <div className="toasts" aria-live="polite">
        {toasts.map((t) => {
          const Icon = ICONS[t.tone];
          return (
            <div key={t.id} className={`toast toast--${t.tone}${t.leaving ? " toast--leaving" : ""}`} role={t.tone === "error" ? "alert" : "status"}>
              <Icon className="toast__icon" size={18} aria-hidden="true" />
              <div className="toast__msg">{t.message}</div>
              <button type="button" className="btn btn--ghost btn--icon btn--sm" aria-label="Dismiss" onClick={() => dismiss(t.id)}>
                <X size={14} aria-hidden="true" />
              </button>
            </div>
          );
        })}
      </div>
    </ToastCtx.Provider>
  );
}

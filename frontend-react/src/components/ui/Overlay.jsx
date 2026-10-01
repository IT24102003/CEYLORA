import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { AlertTriangle, X } from "lucide-react";
import { Button, IconButton, cx } from "./Primitives";

const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/** Escape-to-close, focus trap, scroll lock and focus restore shared by every overlay. */
function useOverlay(ref, onClose) {
  const closeRef = useRef(onClose);
  useEffect(() => { closeRef.current = onClose; });

  useEffect(() => {
    const previous = document.activeElement;
    const node = ref.current;
    document.body.style.overflow = "hidden";
    const first = node?.querySelector("[data-autofocus]") || node?.querySelector(FOCUSABLE);
    first?.focus();

    const onKey = (e) => {
      if (e.key === "Escape") { e.stopPropagation(); closeRef.current(); }
      if (e.key !== "Tab" || !node) return;
      const items = [...node.querySelectorAll(FOCUSABLE)];
      if (!items.length) return;
      const a = items[0], z = items[items.length - 1];
      if (e.shiftKey && document.activeElement === a) { e.preventDefault(); z.focus(); }
      else if (!e.shiftKey && document.activeElement === z) { e.preventDefault(); a.focus(); }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
      previous?.focus?.();
    };
  }, [ref]);
}

function Frame({ onClose, drawer, large, title, description, footer, children }) {
  const ref = useRef(null);
  useOverlay(ref, onClose);
  const Wrapper = drawer ? "aside" : "div";
  return createPortal(
    <div
      className={cx("overlay", drawer && "overlay--drawer")}
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <Wrapper
        ref={ref}
        className={cx(drawer ? "drawer" : "dialog", large && "dialog--lg")}
        role="dialog"
        aria-modal="true"
        aria-label={typeof title === "string" ? title : undefined}
      >
        {!drawer && <span className="dialog__grab" aria-hidden="true" />}
        <div className="dialog__head">
          <div>
            <h2 className="dialog__title">{title}</h2>
            {description && <p className="dialog__desc">{description}</p>}
          </div>
          <IconButton icon={X} label="Close" size="sm" onClick={onClose} />
        </div>
        <div className="dialog__body">{children}</div>
        {footer && <div className="dialog__foot">{footer}</div>}
      </Wrapper>
    </div>,
    document.body,
  );
}

/** Centered dialog on desktop, bottom sheet on mobile (pure CSS). */
export const Modal = (props) => <Frame {...props} />;
/** Right-hand drawer on desktop, full-height sheet on mobile. */
export const Drawer = (props) => <Frame {...props} drawer />;

/* Promise-based confirm: `const confirm = useConfirm(); if (await confirm({ title, message }))` */
const ConfirmCtx = createContext(null);
export const useConfirm = () => useContext(ConfirmCtx);

export function ConfirmProvider({ children }) {
  const [state, setState] = useState(null);
  const confirm = useCallback((opts) => new Promise((resolve) => setState({ ...opts, resolve })), []);
  const close = (result) => { state?.resolve(result); setState(null); };

  return (
    <ConfirmCtx.Provider value={confirm}>
      {children}
      {state && (
        <Modal
          title={state.title}
          description={state.message}
          onClose={() => close(false)}
          footer={
            <>
              <Button onClick={() => close(false)}>{state.cancelLabel || "Cancel"}</Button>
              <Button variant={state.tone === "primary" ? "primary" : "danger"} data-autofocus onClick={() => close(true)}>
                {state.confirmLabel || "Delete"}
              </Button>
            </>
          }
        >
          {state.tone !== "primary" && (
            <div className="dialog__icon" style={{ background: "var(--c-danger-soft)", color: "var(--c-danger)", margin: 0 }}>
              <AlertTriangle size={20} aria-hidden="true" />
            </div>
          )}
        </Modal>
      )}
    </ConfirmCtx.Provider>
  );
}

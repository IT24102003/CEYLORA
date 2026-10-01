import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { MoreHorizontal } from "lucide-react";
import { IconButton, cx } from "./Primitives";

/**
 * Dropdown menu rendered in a portal (so scrollable table wrappers never clip it) and
 * positioned against the trigger; flips upward when there's no room below.
 * items: [{ label, icon, onClick, danger, hidden, heading }] | "separator"
 */
export function Menu({ items, label = "More actions", trigger }) {
  const [open, setOpen] = useState(false);
  const [pos, setPos] = useState(null);
  const wrapRef = useRef(null);
  const menuRef = useRef(null);

  useLayoutEffect(() => {
    if (!open) return;
    const r = wrapRef.current.getBoundingClientRect();
    const h = menuRef.current.offsetHeight;
    const up = r.bottom + h + 12 > window.innerHeight && r.top > h + 12;
    setPos({ right: Math.max(8, window.innerWidth - r.right), top: up ? r.top - h - 6 : r.bottom + 6, up });
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const close = () => setOpen(false);
    const away = (e) => {
      if (!wrapRef.current?.contains(e.target) && !menuRef.current?.contains(e.target)) close();
    };
    const esc = (e) => { if (e.key === "Escape") { close(); wrapRef.current?.querySelector("button")?.focus(); } };
    document.addEventListener("mousedown", away);
    document.addEventListener("keydown", esc);
    window.addEventListener("resize", close);
    window.addEventListener("scroll", close, true);
    menuRef.current?.querySelector('[role="menuitem"]')?.focus();
    return () => {
      document.removeEventListener("mousedown", away);
      document.removeEventListener("keydown", esc);
      window.removeEventListener("resize", close);
      window.removeEventListener("scroll", close, true);
    };
  }, [open]);

  const onMenuKey = (e) => {
    const els = [...menuRef.current.querySelectorAll('[role="menuitem"]')];
    const i = els.indexOf(document.activeElement);
    if (e.key === "ArrowDown") { e.preventDefault(); els[(i + 1) % els.length]?.focus(); }
    if (e.key === "ArrowUp") { e.preventDefault(); els[(i - 1 + els.length) % els.length]?.focus(); }
  };

  return (
    <div className="menu-wrap" ref={wrapRef}>
      {trigger ? (
        trigger({ open, toggle: () => setOpen((o) => !o) })
      ) : (
        <IconButton icon={MoreHorizontal} label={label} size="sm" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen((o) => !o)} />
      )}
      {open &&
        createPortal(
          <div
            ref={menuRef}
            className={cx("menu", pos?.up && "menu--up")}
            role="menu"
            onKeyDown={onMenuKey}
            style={{ position: "fixed", right: pos?.right ?? 0, top: pos?.top ?? 0, visibility: pos ? "visible" : "hidden" }}
          >
            {items.filter((i) => i === "separator" || !i.hidden).map((item, idx) => {
              if (item === "separator") return <div key={idx} className="menu__sep" role="separator" />;
              if (item.heading) return <div key={idx} className="menu__label">{item.heading}</div>;
              return (
                <button
                  key={idx}
                  type="button"
                  role="menuitem"
                  className={cx("menu__item", item.danger && "menu__item--danger")}
                  onClick={() => { setOpen(false); item.onClick?.(); }}
                >
                  {item.icon && <item.icon size={16} aria-hidden="true" />}
                  {item.label}
                </button>
              );
            })}
          </div>,
          document.body,
        )}
    </div>
  );
}

import { assetUrl } from "../../services/api";

export const cx = (...a) => a.filter(Boolean).join(" ");

export function Spinner({ large, className }) {
  return <span className={cx("spinner", large && "spinner--lg", className)} role="status" aria-label="Loading" />;
}

/** variant: primary | danger | success | ghost | soft-danger — size: sm | lg */
export function Button({ variant, size, block, loading, icon: Icon, children, className, type = "button", disabled, ...rest }) {
  return (
    <button
      type={type}
      className={cx(
        "btn",
        variant && `btn--${variant}`,
        size === "sm" && "btn--sm",
        size === "lg" && "btn--lg",
        block && "btn--block",
        className,
      )}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...rest}
    >
      {loading ? <Spinner /> : Icon ? <Icon size={size === "sm" ? 15 : 17} aria-hidden="true" /> : null}
      {children}
    </button>
  );
}

export function IconButton({ icon: Icon, label, size, variant = "ghost", className, ...rest }) {
  return (
    <button
      type="button"
      className={cx("btn", "btn--icon", `btn--${variant}`, size === "sm" && "btn--sm", className)}
      aria-label={label}
      data-tip={label}
      {...rest}
    >
      <Icon size={size === "sm" ? 16 : 18} aria-hidden="true" />
    </button>
  );
}

/** tone: neutral | success | warning | danger | info | accent */
export function Badge({ tone = "neutral", dot, icon: Icon, children, className, ...rest }) {
  const Tag = rest.onClick ? "button" : "span";
  return (
    <Tag className={cx("badge", tone !== "neutral" && `badge--${tone}`, className)} {...rest}>
      {dot && <span className="badge__dot" aria-hidden="true" />}
      {Icon && <Icon size={12} aria-hidden="true" />}
      {children}
    </Tag>
  );
}

export function Avatar({ name = "", size = 36, src }) {
  const initials = name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join("") || "?";
  return (
    <span className="avatar" style={{ "--size": `${size}px` }} aria-hidden="true">
      {src ? <img src={assetUrl(src)} alt="" /> : initials}
    </span>
  );
}

export function Card({ pad, interactive, className, children, ...rest }) {
  return (
    <div className={cx("card", pad && "card--pad", interactive && "card--interactive", className)} {...rest}>
      {children}
    </div>
  );
}

export function Skeleton({ w = "100%", h = 14, r, style, className }) {
  return <span className={cx("skeleton", className)} style={{ width: w, height: h, borderRadius: r, ...style }} aria-hidden="true" />;
}

export function Alert({ tone, icon: Icon, children, className, ...rest }) {
  return (
    <div className={cx("alert", tone && `alert--${tone}`, className)} role={tone === "error" ? "alert" : "status"} {...rest}>
      {Icon && <Icon size={16} aria-hidden="true" />}
      <div>{children}</div>
    </div>
  );
}

export function Tabs({ tabs, value, onChange, label }) {
  const onKey = (e) => {
    const i = tabs.findIndex((t) => t.value === value);
    if (e.key === "ArrowRight") onChange(tabs[(i + 1) % tabs.length].value);
    if (e.key === "ArrowLeft") onChange(tabs[(i - 1 + tabs.length) % tabs.length].value);
  };
  return (
    <div className="tabs" role="tablist" aria-label={label} onKeyDown={onKey}>
      {tabs.map((t) => (
        <button
          key={t.value}
          role="tab"
          type="button"
          className="tab"
          aria-selected={value === t.value}
          tabIndex={value === t.value ? 0 : -1}
          onClick={() => onChange(t.value)}
        >
          {t.label}
          {t.count != null && <span className="tab__count">{t.count}</span>}
        </button>
      ))}
    </div>
  );
}

export function Switch({ checked, onChange, label, disabled }) {
  return (
    <label className="switch">
      <input type="checkbox" checked={checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
      <span className="switch__track" />
      {label && <span>{label}</span>}
    </label>
  );
}

/** Height-animated expand/collapse (grid-rows trick — no JS measuring). */
export function Collapse({ open, children }) {
  return (
    <div className="collapse" data-open={open ? "true" : "false"} aria-hidden={!open} inert={!open || undefined}>
      <div>{children}</div>
    </div>
  );
}

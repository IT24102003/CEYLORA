import { useId } from "react";
import { AlertCircle, Search, X } from "lucide-react";
import { cx } from "./Primitives";

/** Visible label + hint + inline error, wired up with aria-describedby. `children` is a render-prop receiving the control's a11y props. */
export function Field({ label, hint, error, required, className, children }) {
  const id = useId();
  const describedBy = error ? `${id}-err` : hint ? `${id}-hint` : undefined;
  return (
    <div className={cx("field", className)}>
      {label && (
        <label className="field__label" htmlFor={id}>
          {label}
          {required && <span className="req" aria-hidden="true">*</span>}
        </label>
      )}
      {children({ id, "aria-describedby": describedBy, "aria-invalid": error ? "true" : undefined, required })}
      {error ? (
        <div className="field__error" id={`${id}-err`} role="alert">
          <AlertCircle size={14} aria-hidden="true" />
          {error}
        </div>
      ) : (
        hint && <div className="field__hint" id={`${id}-hint`}>{hint}</div>
      )}
    </div>
  );
}

export function Input({ label, hint, error, required, className, ...rest }) {
  return (
    <Field label={label} hint={hint} error={error} required={required} className={className}>
      {(p) => <input className="input" {...p} {...rest} />}
    </Field>
  );
}

export function Textarea({ label, hint, error, required, className, ...rest }) {
  return (
    <Field label={label} hint={hint} error={error} required={required} className={className}>
      {(p) => <textarea className="textarea" {...p} {...rest} />}
    </Field>
  );
}

/** options: [{ value, label }] — `placeholder` becomes the empty first option. */
export function Select({ label, hint, error, required, className, options = [], placeholder, children, ...rest }) {
  return (
    <Field label={label} hint={hint} error={error} required={required} className={className}>
      {(p) => (
        <select className="select" {...p} {...rest}>
          {placeholder != null && <option value="">{placeholder}</option>}
          {options.map((o) => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
          {children}
        </select>
      )}
    </Field>
  );
}

export function SearchInput({ value, onChange, placeholder = "Search…", label = "Search", onEnter }) {
  return (
    <div className="search" role="search">
      <Search className="search__icon" size={17} aria-hidden="true" />
      <input
        className="input"
        type="search"
        aria-label={label}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && onEnter?.()}
      />
      {value && (
        <button type="button" className="search__clear" aria-label="Clear search" onClick={() => onChange("")}>
          <X size={16} aria-hidden="true" />
        </button>
      )}
    </div>
  );
}

import { useState } from "react";
import { NavLink, Outlet, useLocation } from "react-router-dom";
import {
  BarChart3, Bot, FileText, CalendarCheck, Car, Compass, Hotel, LogOut, MapPin, Menu as MenuIcon,
  Moon, Package, ShieldCheck, Star, Sun,
} from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { useTheme } from "../lib/hooks";
import { Avatar, IconButton, Modal } from "./ui";

const NAV_GROUPS = [
  {
    label: "Overview",
    items: [
      { to: "/analytics", label: "Analytics", short: "Analytics", icon: BarChart3 },
      { to: "/agent-monitor", label: "Agent Workflow Monitor", short: "Agents", icon: Bot },
      { to: "/reports", label: "Weekly report", short: "Reports", icon: FileText },
    ],
  },
  {
    label: "Operations",
    items: [
      { to: "/bookings", label: "Bookings", short: "Bookings", icon: CalendarCheck },
      { to: "/verifications", label: "Verifications", short: "Verify", icon: ShieldCheck },
    ],
  },
  {
    label: "Catalog",
    items: [
      { to: "/destinations", label: "Destinations", short: "Places", icon: MapPin },
      { to: "/packages", label: "Packages", short: "Packages", icon: Package },
      { to: "/hotels", label: "Hotels", short: "Hotels", icon: Hotel },
    ],
  },
  {
    label: "Network",
    items: [
      { to: "/guides", label: "Guides", short: "Guides", icon: Compass },
      { to: "/vehicles", label: "Vehicles", short: "Vehicles", icon: Car },
    ],
  },
  {
    label: "Moderation",
    items: [{ to: "/reviews", label: "Reviews", short: "Reviews", icon: Star }],
  },
];

const ALL_ITEMS = NAV_GROUPS.flatMap((g) => g.items);
// The four destinations used most day-to-day get a slot in the mobile bottom bar; everything else lives under "More".
const BOTTOM_ITEMS = ["/analytics", "/bookings", "/verifications", "/guides"].map((to) => ALL_ITEMS.find((i) => i.to === to));

function Brand({ className = "brand" }) {
  return (
    <div className={className}>
      <span className="brand__mark"><img src="/logo-mark.png" alt="" style={{ width: "100%", height: "100%", objectFit: "contain" }} /></span>
      <div>
        <div className="brand__name">CEYLORA</div>
        <div className="brand__sub">Admin Panel</div>
      </div>
    </div>
  );
}

export default function AdminLayout() {
  const { user, logout } = useAuth();
  const { pathname } = useLocation();
  const [isDark, toggleTheme] = useTheme();
  const [moreOpen, setMoreOpen] = useState(false);
  const current = ALL_ITEMS.find((i) => pathname.startsWith(i.to));
  const ThemeIcon = isDark ? Sun : Moon;

  return (
    <div className="shell">
      <a className="skip-link" href="#main">Skip to content</a>

      <aside className="sidebar" aria-label="Primary">
        <Brand />
        <nav className="nav">
          {NAV_GROUPS.map((g) => (
            <div key={g.label}>
              <div className="nav__group-label">{g.label}</div>
              {g.items.map((item) => (
                <NavLink key={item.to} to={item.to} className="nav__link" title={item.label}>
                  <item.icon size={18} aria-hidden="true" />
                  <span>{item.label}</span>
                </NavLink>
              ))}
            </div>
          ))}
        </nav>
        <div className="sidebar__foot">
          <div className="userchip">
            <Avatar name={user?.name} />
            <div style={{ minWidth: 0 }}>
              <div className="userchip__name truncate">{user?.name}</div>
              <div className="userchip__role">{user?.role}</div>
            </div>
          </div>
          <button type="button" className="btn btn--ghost btn--block" style={{ justifyContent: "flex-start", marginTop: 4 }} onClick={logout} aria-label="Log out">
            <LogOut size={17} aria-hidden="true" /> <span>Log out</span>
          </button>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div className="crumbs">
            <span>Admin</span>
            <span aria-hidden="true">/</span>
            <strong>{current?.label ?? "Dashboard"}</strong>
          </div>
          <Brand className="topbar__brand" />
          <div className="row">
            <IconButton icon={ThemeIcon} label={isDark ? "Switch to light theme" : "Switch to dark theme"} onClick={toggleTheme} />
            <IconButton icon={LogOut} label="Log out" onClick={logout} className="topbar__logout" />
          </div>
        </header>

        <main id="main" tabIndex={-1} style={{ outline: "none" }}>
          <Outlet key={pathname} />
        </main>
      </div>

      <nav className="bottomnav" aria-label="Primary">
        {BOTTOM_ITEMS.map((item) => (
          <NavLink key={item.to} to={item.to} className="bottomnav__item">
            <item.icon size={22} aria-hidden="true" />
            {item.short}
          </NavLink>
        ))}
        <button type="button" className="bottomnav__item" onClick={() => setMoreOpen(true)} aria-haspopup="dialog">
          <MenuIcon size={22} aria-hidden="true" />
          More
        </button>
      </nav>

      {moreOpen && (
        <Modal title="All sections" onClose={() => setMoreOpen(false)}>
          <div className="nav-sheet__grid" onClick={() => setMoreOpen(false)}>
            {ALL_ITEMS.map((item) => (
              <NavLink key={item.to} to={item.to} className="nav-sheet__item">
                <item.icon size={22} aria-hidden="true" />
                {item.short}
              </NavLink>
            ))}
          </div>
        </Modal>
      )}
    </div>
  );
}

import { useEffect, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { Eye, EyeOff, ShieldCheck, Route as RouteIcon, BarChart3, AlertCircle } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { Button, Input, Field } from "../components/ui";
import { errorMessage } from "../lib/hooks";

// Slideshow photos live in /public/login — drop in more files and add them here.
const SLIDES = [
  { src: "/login/sigiriya.jpg", label: "Sigiriya" },
  { src: "/login/tea.jpg", label: "Hill country" },
  { src: "/login/coast.jpg", label: "Southern coast" },
  { src: "/login/colombo.jpg", label: "Colombo" },
  { src: "/login/beach.jpg", label: "Beach" },
  { src: "/login/waterfall.jpg", label: "Waterfall" },
];

export default function LoginPage() {
  const [slide, setSlide] = useState(0);
  const [prev, setPrev] = useState(null); // slide that is fading out keeps animating so it doesn't jump
  useEffect(() => {
    let current = 0;
    const t = setInterval(() => {
      setPrev(current);
      current = (current + 1) % SLIDES.length;
      setSlide(current);
    }, 6000);
    return () => clearInterval(t);
  }, []);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const { user, login } = useAuth();
  const navigate = useNavigate();

  if (user) return <Navigate to="/analytics" replace />;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(email, password);
      navigate("/analytics");
    } catch (err) {
      setError(errorMessage(err, "Login failed. Check your details and try again."));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth">
      <section className="auth__hero" aria-hidden="true">
        {SLIDES.map((sl, i) => (
          <div key={sl.src} className="auth__slide" data-state={i === slide ? "active" : i === prev ? "leaving" : "idle"} style={{ backgroundImage: `url(${sl.src})` }} />
        ))}
        <div className="auth__shade" />
        <div className="brand" style={{ padding: 0 }}>
          <span className="brand__mark"><img src="/logo-mark.png" alt="" style={{ width: "100%", height: "100%", objectFit: "contain" }} /></span>
          <div>
            <div className="brand__name">CEYLORA</div>
            <div className="brand__sub">Admin Panel</div>
          </div>
        </div>
        <div>
          <p className="auth__quote">Ceylora administration</p>
          <ul className="auth__points">
            <li><RouteIcon size={18} /> Approve trip plans</li>
            <li><ShieldCheck size={18} /> Verify guides and vehicle owners</li>
            <li><BarChart3 size={18} /> Track bookings, revenue and growth</li>
          </ul>
          <p className="auth__caption"><span key={slide}>{SLIDES[slide].label}</span></p>
        </div>
      </section>

      <main className="auth__panel">
        <div className="auth__card">
          <div style={{ background: "#fff", borderRadius: 20, padding: "var(--space-3) var(--space-5)", width: "fit-content", margin: "0 auto var(--space-5)", boxShadow: "var(--shadow-md)" }}>
            <img src="/logo.png" alt="Ceylora — Explore, Experience, Sri Lanka" style={{ width: 190, display: "block" }} />
          </div>
          <h1 className="auth__title">Welcome back</h1>
          <p className="auth__sub">Sign in with your administrator account.</p>

          <form onSubmit={handleSubmit} className="stack">
            <Input
              label="Email"
              type="email"
              required
              autoComplete="username"
              inputMode="email"
              placeholder="admin@ceylora.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <Field label="Password" required>
              {(p) => (
                <div className="pw">
                  <input
                    className="input"
                    type={showPw ? "text" : "password"}
                    autoComplete="current-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    {...p}
                  />
                  <button type="button" onClick={() => setShowPw((s) => !s)} aria-label={showPw ? "Hide password" : "Show password"}>
                    {showPw ? <EyeOff size={17} /> : <Eye size={17} />}
                  </button>
                </div>
              )}
            </Field>

            {error && (
              <div className="alert alert--error" role="alert" key={error}>
                <AlertCircle size={16} aria-hidden="true" />
                <div>{error}</div>
              </div>
            )}

            <Button type="submit" variant="primary" size="lg" block loading={loading}>
              {loading ? "Signing in…" : "Sign in"}
            </Button>
          </form>
        </div>
      </main>
    </div>
  );
}


            
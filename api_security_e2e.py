"""CEYLORA - API security + E2E + AI latency checks (stdlib only).
Run:  python api_security_e2e.py --base-url https://ceylora-production.up.railway.app
Creates ONE test tourist (random e-mail, @example.com) in the target database.
Writes api_security_e2e_results.json and prints a table for the report (SEC-01..04, SEC-08, E2E-03, PERF-06)."""
import argparse, json, time, uuid, urllib.request, urllib.error, statistics

ap = argparse.ArgumentParser(); ap.add_argument("--base-url", default="https://ceylora-production.up.railway.app")
a = ap.parse_args(); B = a.base_url.rstrip("/")

def call(method, path, body=None, token=None, headers=None, timeout=90):
    h = {"Content-Type": "application/json"}; h.update(headers or {})
    if token: h["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(B + path, data=data, method=method, headers=h)
    t = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8", "replace"), dict(r.headers), time.perf_counter() - t
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace"), dict(e.headers), time.perf_counter() - t
    except Exception as e:
        return 0, str(e), {}, time.perf_counter() - t

R = []
def rec(id_, name, expected, actual, ok): R.append({"id": id_, "test": name, "expected": expected, "actual": actual, "result": "PASSED" if ok else "FAILED"}); print(f"{id_:8} {'PASSED' if ok else 'FAILED'}  {name}: {actual}")

# --- setup: register + login a throw-away tourist
email = f"qa.{uuid.uuid4().hex[:8]}@example.com"; pwd = "Test#" + uuid.uuid4().hex[:8]
s, b, _, _ = call("POST", "/api/Auth/register", {"name": "QA Tester", "email": email, "password": pwd, "role": 0, "country": "Sri Lanka", "mobileNumber": "0770000000"})
rec("E2E-03a", "Register tourist", "200 + token", f"HTTP {s}", s == 200 and "token" in b.lower())
s, b, _, _ = call("POST", "/api/Auth/login", {"email": email, "password": pwd})
tok = ""
try: tok = json.loads(b).get("token") or json.loads(b).get("Token") or ""
except Exception: pass
rec("E2E-03b", "Login", "200 + JWT", f"HTTP {s}, token {'received' if tok else 'missing'}", s == 200 and bool(tok))

# --- security
s, *_ = call("GET", "/api/Bookings"); rec("SEC-01", "GET /api/Bookings without token", "401", f"HTTP {s}", s == 401)
s, *_ = call("PUT", "/api/agent-workflows/1/approve", {"approvalStatus": "Approved"}, token=tok); rec("SEC-02", "Tourist token calls admin approve", "403", f"HTTP {s}", s == 403)
bad = tok[:-3] + ("AAA" if not tok.endswith("AAA") else "BBB")
s, *_ = call("GET", "/api/Bookings", token=bad); rec("SEC-03", "Tampered JWT", "401", f"HTTP {s}", s == 401)
s, b, _, _ = call("POST", "/api/Auth/login", {"email": "' OR 1=1 --@example.com", "password": "' OR '1'='1"})
rec("SEC-04a", "SQL-injection style login", "400/401, no token, no 500", f"HTTP {s}", s in (400, 401) and "token" not in b.lower())
s, b, _, _ = call("GET", "/api/Destinations?search=%27%20OR%201%3D1%20--")
rec("SEC-04b", "SQL-injection style query string", "no 500, no stack trace", f"HTTP {s}", s < 500 and "Npgsql" not in b and "Exception" not in b)
s, _, h, _ = call("GET", "/api/Destinations", headers={"Origin": "https://evil.example"})
acao = h.get("Access-Control-Allow-Origin") or h.get("access-control-allow-origin") or "(none)"
rec("SEC-08", "CORS with foreign Origin", "foreign origin NOT allowed", f"Access-Control-Allow-Origin: {acao}", acao not in ("*", "https://evil.example"))
hdrs = {k.lower() for k in h}
for name in ("x-content-type-options", "strict-transport-security", "x-frame-options"):
    rec("SEC-09", f"Security header {name}", "present", "present" if name in hdrs else "missing", name in hdrs)

# --- AI latency + E2E preview
lat = []
for i in range(5):
    s, b, _, t = call("POST", "/api/agent-workflows/preview", {"objective": "3 day trip to Kandy for 4 people"}, token=tok)
    lat.append((s, round(t, 2)))
ok = all(x[0] == 200 for x in lat)
rec("PERF-06", "AI preview latency x5", "all 200; record seconds", f"{lat}; avg {statistics.mean(x[1] for x in lat):.2f}s", ok)
try:
    p = json.loads(b); rec("E2E-03c", "Preview returns plan needing approval", "requires_approval = true", f"requires_approval={p.get('requires_approval')}", p.get("requires_approval") is True)
except Exception as e: rec("E2E-03c", "Preview returns JSON plan", "JSON", f"not JSON: {b[:80]}", False)

json.dump({"base_url": B, "run_at": time.strftime("%Y-%m-%d %H:%M:%S"), "results": R}, open("api_security_e2e_results.json", "w"), indent=1)
print(f"\n{sum(r['result']=='PASSED' for r in R)}/{len(R)} passed -> api_security_e2e_results.json")
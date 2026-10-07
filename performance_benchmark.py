#!/usr/bin/env python3
"""
CEYLORA concurrent load benchmark (standard library only, no pip install needed).

Fires N concurrent virtual users at a set of REST endpoints and reports, per endpoint:
average / P95 / minimum latency, success rate, plus overall throughput.

Usage:
  python performance_benchmark.py --base-url https://<your-backend>.up.railway.app --users 50 --requests 100
Optional login benchmark (credentials are read from environment variables, never from the code):
  BENCH_EMAIL=<email> BENCH_PASSWORD=<password> python performance_benchmark.py --base-url ...

Writes benchmark_results.json next to the script and prints a Markdown table you can paste into the report.
"""
import argparse
import json
import os
import statistics
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor

PUBLIC_ENDPOINTS = [
    ("Destinations list", "GET", "/api/Destinations"),
    ("Hotels list", "GET", "/api/Hotels"),
    ("Packages list", "GET", "/api/Packages"),
    ("Vehicles list", "GET", "/api/Vehicles"),
    ("Guides list", "GET", "/api/Guides"),
]


def call(base, method, path, body=None, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            r.read()
            ok = 200 <= r.status < 300
    except urllib.error.HTTPError as e:
        ok = False
        e.read()
    except Exception:
        ok = False
    return (time.perf_counter() - start) * 1000.0, ok


def run_scenario(base, name, method, path, users, total, body=None):
    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=users) as pool:
        results = list(pool.map(lambda _: call(base, method, path, body), range(total)))
    wall = time.perf_counter() - t0
    lat = sorted(ms for ms, _ in results)
    ok = sum(1 for _, good in results if good)
    p95 = lat[min(len(lat) - 1, int(round(0.95 * len(lat))) - 1)]
    return {
        "operation": name, "method": method, "path": path, "concurrency": users, "requests": total,
        "avg_ms": round(statistics.mean(lat), 1), "p95_ms": round(p95, 1), "min_ms": round(lat[0], 1),
        "max_ms": round(lat[-1], 1), "success_rate_pct": round(100.0 * ok / total, 1),
        "throughput_rps": round(total / wall, 1),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--users", type=int, default=50)
    ap.add_argument("--requests", type=int, default=100, help="requests per endpoint")
    args = ap.parse_args()
    base = args.base_url.rstrip("/")

    scenarios = list(PUBLIC_ENDPOINTS)
    email, password = os.getenv("BENCH_EMAIL"), os.getenv("BENCH_PASSWORD")
    rows = []
    # warm-up: first request after idle can hit a cold container / DB connection
    for _, m, p in PUBLIC_ENDPOINTS[:1]:
        call(base, m, p)
    for name, method, path in scenarios:
        rows.append(run_scenario(base, name, method, path, args.users, args.requests))
    if email and password:
        rows.append(run_scenario(base, "Login (BCrypt verify + JWT)", "POST", "/api/Auth/login",
                                 min(args.users, 20), min(args.requests, 40),
                                 {"email": email, "password": password}))

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "benchmark_results.json")
    with open(out, "w") as f:
        json.dump({"base_url": base, "users": args.users, "results": rows,
                   "measured_at_utc": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())}, f, indent=2)

    print("| Operation | Concurrency | Requests | Avg (ms) | P95 (ms) | Min (ms) | Success | Req/s |")
    print("|---|---|---|---|---|---|---|---|")
    for r in rows:
        print(f"| {r['operation']} | {r['concurrency']} | {r['requests']} | {r['avg_ms']} | {r['p95_ms']} | "
              f"{r['min_ms']} | {r['success_rate_pct']}% | {r['throughput_rps']} |")
    print(f"\nSaved {out}")


if __name__ == "__main__":
    main()
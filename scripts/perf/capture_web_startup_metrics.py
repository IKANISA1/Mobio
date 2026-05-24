#!/usr/bin/env python3
"""Capture Chrome startup metrics for a built Flutter web bundle."""

from __future__ import annotations

import argparse
import contextlib
import http.server
import json
import os
import socketserver
import subprocess
import tempfile
import threading
import time
import urllib.request
from pathlib import Path
from typing import Any

import websocket


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


class CdpClient:
    def __init__(self, websocket_url: str) -> None:
        self.ws = websocket.create_connection(websocket_url, timeout=1)
        self.next_id = 1

    def close(self) -> None:
        self.ws.close()

    def command(self, method: str, params: dict[str, Any] | None = None) -> Any:
        request_id = self.next_id
        self.next_id += 1
        self.ws.send(json.dumps({
            "id": request_id,
            "method": method,
            "params": params or {},
        }))
        while True:
            message = json.loads(self.ws.recv())
            if message.get("id") == request_id:
                if "error" in message:
                    raise RuntimeError(f"{method} failed: {message['error']}")
                return message.get("result")

    def recv_until(self, predicate, timeout_seconds: float) -> list[dict[str, Any]]:
        deadline = time.monotonic() + timeout_seconds
        messages: list[dict[str, Any]] = []
        while time.monotonic() < deadline:
            remaining = max(0.1, deadline - time.monotonic())
            self.ws.settimeout(remaining)
            try:
                message = json.loads(self.ws.recv())
            except TimeoutError:
                break
            except Exception:
                break
            messages.append(message)
            if predicate(message):
                break
        return messages


def wait_for_debugger(port: int, timeout_seconds: float) -> list[dict[str, Any]]:
    deadline = time.monotonic() + timeout_seconds
    url = f"http://127.0.0.1:{port}/json/list"
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception:
            time.sleep(0.2)
    raise RuntimeError(f"Chrome did not expose DevTools targets on port {port}")


def choose_page_target(targets: list[dict[str, Any]]) -> dict[str, Any]:
    pages = [target for target in targets if target.get("type") == "page"]
    if not pages:
        raise RuntimeError("Chrome exposed no page targets")
    return pages[0]


def read_json_via_cdp(client: CdpClient, expression: str) -> Any:
    result = client.command("Runtime.evaluate", {
        "expression": expression,
        "returnByValue": True,
        "awaitPromise": True,
    })
    return json.loads(result["result"]["value"])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-dir", default="build/web")
    parser.add_argument("--output-dir", default="build/perf")
    parser.add_argument("--port", type=int, default=8099)
    parser.add_argument("--debug-port", type=int, default=9223)
    parser.add_argument("--wait-seconds", type=float, default=10)
    args = parser.parse_args()

    web_dir = Path(args.web_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    if not (web_dir / "index.html").is_file():
        raise SystemExit(f"{web_dir} does not look like a Flutter web build")

    chrome = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    if not chrome.is_file():
        raise SystemExit("Google Chrome executable not found")

    os.chdir(web_dir)
    server = ReusableTCPServer(("127.0.0.1", args.port), QuietHandler)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    user_data_dir = tempfile.TemporaryDirectory(prefix="mobi-chrome-profile.")
    trace_events: list[dict[str, Any]] = []
    chrome_proc = subprocess.Popen([
        str(chrome),
        "--headless=new",
        f"--remote-debugging-port={args.debug_port}",
        f"--remote-allow-origins=http://127.0.0.1:{args.debug_port}",
        f"--user-data-dir={user_data_dir.name}",
        "--disable-background-networking",
        "--disable-default-apps",
        "--disable-extensions",
        "--disable-popup-blocking",
        "--disable-sync",
        "--no-first-run",
        "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    client: CdpClient | None = None
    try:
        targets = wait_for_debugger(args.debug_port, 20)
        target = choose_page_target(targets)
        client = CdpClient(target["webSocketDebuggerUrl"])
        client.command("Page.enable")
        client.command("Runtime.enable")
        client.command("Performance.enable")
        client.command("Tracing.start", {
            "categories": ",".join([
                "devtools.timeline",
                "blink.user_timing",
                "loading",
                "v8",
                "disabled-by-default-devtools.timeline",
            ]),
            "transferMode": "ReportEvents",
        })

        started_at = time.monotonic()
        client.command("Page.navigate", {"url": f"http://127.0.0.1:{args.port}/"})
        client.recv_until(lambda message: message.get("method") == "Page.loadEventFired", 60)
        time.sleep(args.wait_seconds)

        timing = read_json_via_cdp(client, """
JSON.stringify({
  navigation: performance.getEntriesByType('navigation').map((entry) => entry.toJSON()),
  paint: performance.getEntriesByType('paint').map((entry) => entry.toJSON()),
  resources: performance.getEntriesByType('resource')
    .map((entry) => entry.toJSON())
    .sort((a, b) => (b.transferSize || 0) - (a.transferSize || 0))
    .slice(0, 20),
  flutterHostPresent: Boolean(
    document.querySelector('flt-glass-pane') ||
    document.querySelector('flutter-view') ||
    document.querySelector('canvas')
  ),
  bodyTextLength: document.body ? document.body.innerText.length : 0,
  url: location.href,
  readyState: document.readyState
})
""")
        performance_metrics = client.command("Performance.getMetrics")
        elapsed_ms = round((time.monotonic() - started_at) * 1000, 1)

        client.command("Tracing.end")
        messages = client.recv_until(
            lambda message: message.get("method") == "Tracing.tracingComplete",
            30,
        )
        for message in messages:
            if message.get("method") == "Tracing.dataCollected":
                trace_events.extend(message.get("params", {}).get("value", []))

        timestamp = time.strftime("%Y%m%d%H%M%S")
        metrics_path = output_dir / f"web-startup-metrics-{timestamp}.json"
        trace_path = output_dir / f"web-startup-trace-{timestamp}.json"
        metrics_path.write_text(json.dumps({
            "elapsed_ms": elapsed_ms,
            "web_dir": str(web_dir),
            "url": f"http://127.0.0.1:{args.port}/",
            "timing": timing,
            "performance_metrics": performance_metrics,
        }, indent=2), encoding="utf-8")
        trace_path.write_text(json.dumps({"traceEvents": trace_events}), encoding="utf-8")
        print(f"Wrote metrics: {metrics_path}")
        print(f"Wrote trace: {trace_path}")
    finally:
        if client is not None:
            with contextlib.suppress(Exception):
                client.close()
        chrome_proc.terminate()
        with contextlib.suppress(Exception):
            chrome_proc.wait(timeout=5)
        with contextlib.suppress(Exception):
            chrome_proc.kill()
        server.shutdown()
        server.server_close()
        user_data_dir.cleanup()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Kubernetes lifecycle adapter for a user-supplied NautilusTrader node."""

from __future__ import annotations

import argparse
import importlib
import json
import logging
import os
import signal
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable


STARTED = time.time()
STATE = {"healthy": True, "ready": False, "runs": 0, "failures": 0}
STOP = threading.Event()
NODE: Any = None


def resolve_factory(path: str) -> Callable[[dict[str, Any]], Any]:
    """Resolve a module:callable factory without evaluating arbitrary expressions."""
    module_name, separator, attribute = path.partition(":")
    if not separator or not module_name or not attribute:
        raise ValueError("factory must use module:callable syntax")
    value: Any = importlib.import_module(module_name)
    for part in attribute.split("."):
        value = getattr(value, part)
    if not callable(value):
        raise TypeError(f"factory {path!r} is not callable")
    return value


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        """Serve runner health, readiness, and Prometheus metrics."""
        if self.path == "/healthz":
            healthy = STATE["healthy"] and node_is_healthy(NODE)
            self._reply(200 if healthy else 503, b"ok\n")
            return
        if self.path == "/readyz":
            ready = STATE["ready"] and node_is_ready(NODE)
            self._reply(200 if ready else 503, b"ready\n")
            return
        if self.path == "/metrics":
            healthy = STATE["healthy"] and node_is_healthy(NODE)
            ready = STATE["ready"] and node_is_ready(NODE)
            body = (
                "# HELP nautilus_runner_up Runner process health.\n"
                "# TYPE nautilus_runner_up gauge\n"
                f"nautilus_runner_up {1 if healthy else 0}\n"
                "# HELP nautilus_runner_ready Runtime readiness.\n"
                "# TYPE nautilus_runner_ready gauge\n"
                f"nautilus_runner_ready {1 if ready else 0}\n"
                "# HELP nautilus_runner_runs_total Runtime executions.\n"
                "# TYPE nautilus_runner_runs_total counter\n"
                f"nautilus_runner_runs_total {STATE['runs']}\n"
                "# HELP nautilus_runner_failures_total Runtime failures.\n"
                "# TYPE nautilus_runner_failures_total counter\n"
                f"nautilus_runner_failures_total {STATE['failures']}\n"
                "# HELP nautilus_runner_uptime_seconds Runner uptime.\n"
                "# TYPE nautilus_runner_uptime_seconds gauge\n"
                f"nautilus_runner_uptime_seconds {time.time() - STARTED:.3f}\n"
            ).encode()
            self._reply(200, body, "text/plain; version=0.0.4")
            return
        self._reply(404, b"not found\n")

    def log_message(self, *_args: Any) -> None:
        """Suppress the base HTTP server access log."""
        return

    def _reply(self, status: int, body: bytes, content_type: str = "text/plain") -> None:
        """Write a complete HTTP response."""
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def load_config(path: str) -> dict[str, Any]:
    """Load the chart-rendered JSON configuration object."""
    with Path(path).open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise TypeError("node configuration must be a JSON object")
    return value


def stop_node(*_args: Any) -> None:
    """Stop and dispose the live node at most once."""
    global NODE
    STOP.set()
    STATE["ready"] = False
    if NODE is None:
        return
    node = NODE
    NODE = None
    try:
        if hasattr(node, "stop"):
            node.stop()
    except Exception:
        logging.exception("NautilusTrader stop failed")
    try:
        if hasattr(node, "dispose"):
            node.dispose()
    except Exception:
        logging.exception("NautilusTrader dispose failed")


def serve(port: int) -> None:
    """Serve operational endpoints until shutdown begins."""
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    server.timeout = 1
    while not STOP.is_set():
        server.handle_request()
    server.server_close()


def node_is_ready(node: Any) -> bool:
    """Return user readiness or running state, defaulting to ready when absent."""
    if node is not None:
        for attribute in ("is_ready", "is_running"):
            value = getattr(node, attribute, None)
            if callable(value):
                return bool(value())
    return True


def node_is_healthy(node: Any) -> bool:
    """Return user event-loop health when the node exposes it."""
    value = getattr(node, "is_healthy", None) if node is not None else None
    return bool(value()) if callable(value) else True


def run_live(factory_path: str, config: dict[str, Any], timeout: int) -> int:
    """Run one live node and coordinate readiness and shutdown."""
    global NODE
    if not factory_path:
        raise ValueError("NAUTILUS_RUNNER_FACTORY is required in live mode")
    NODE = resolve_factory(factory_path)(config)
    if NODE is None or not hasattr(NODE, "run"):
        raise TypeError("live factory must return an object with run()")

    node = NODE
    failure: list[BaseException] = []
    unexpected_exit: list[bool] = []

    def target() -> None:
        """Run the blocking user node while preserving its failure."""
        try:
            STATE["runs"] += 1
            node.run()
            if not STOP.is_set():
                unexpected_exit.append(True)
                STATE["failures"] += 1
                STATE["healthy"] = False
        except BaseException as exc:  # preserve runtime failures for the main thread
            failure.append(exc)
            STATE["failures"] += 1
            STATE["healthy"] = False
        finally:
            STOP.set()

    thread = threading.Thread(target=target, name="nautilus-live-node", daemon=True)
    thread.start()
    deadline = time.monotonic() + timeout
    try:
        while thread.is_alive() and not STOP.is_set():
            if node_is_ready(node):
                STATE["ready"] = True
                break
            if time.monotonic() >= deadline:
                STATE["healthy"] = False
                stop_node()
                thread.join(timeout=30)
                raise TimeoutError("live node did not become ready before timeout")
            time.sleep(0.5)
        while thread.is_alive() and not STOP.is_set():
            thread.join(timeout=1)
    finally:
        stop_node()
        thread.join(timeout=30)
    if failure:
        raise failure[0]
    if unexpected_exit:
        raise RuntimeError("live node exited without a shutdown signal")
    return 0


def run_backtest(factory_path: str, config: dict[str, Any]) -> int:
    """Run one user-supplied backtest factory or validate the package import."""
    if not factory_path:
        import nautilus_trader  # noqa: F401

        return 0
    result = resolve_factory(factory_path)(config)
    STATE["runs"] += 1
    if hasattr(result, "run"):
        result.run()
    if hasattr(result, "dispose"):
        result.dispose()
    return 0


def main() -> int:
    """Parse runner settings and dispatch the selected execution mode."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("validate", "live", "backtest"), required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--port", type=int, default=int(os.getenv("NAUTILUS_RUNNER_PORT", "8080")))
    parser.add_argument("--readiness-timeout", type=int, default=120)
    args = parser.parse_args()

    logging.basicConfig(
        level=os.getenv("NAUTILUS_RUNNER_LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )
    signal.signal(signal.SIGTERM, stop_node)
    signal.signal(signal.SIGINT, stop_node)
    config = load_config(args.config)

    if args.mode == "backtest":
        return run_backtest(os.getenv("NAUTILUS_RUNNER_FACTORY", ""), config)

    import nautilus_trader

    logging.info("NautilusTrader runtime imported: %s", getattr(nautilus_trader, "__version__", "unknown"))
    server = threading.Thread(target=serve, args=(args.port,), name="health-server", daemon=True)
    server.start()

    if args.mode == "validate":
        STATE["ready"] = True
        while not STOP.wait(1):
            pass
        return 0
    return run_live(
        os.getenv("NAUTILUS_RUNNER_FACTORY", ""),
        config,
        args.readiness_timeout,
    )


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        STATE["healthy"] = False
        STATE["failures"] += 1
        logging.exception("NautilusTrader runner failed")
        sys.exit(1)

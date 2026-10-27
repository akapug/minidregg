#!/usr/bin/python3.12
"""Appliance process lifetime only. This code makes no Mini authority decisions."""
import ctypes
import http.client
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time


def ready():
    connection = http.client.HTTPConnection("127.0.0.1", 7070, timeout=0.25)
    try:
        connection.request("GET", "/health")
        response = connection.getresponse()
        return response.status == 200
    except (OSError, http.client.HTTPException):
        return False
    finally:
        connection.close()


def supervise(adapter_command, bridge_command, readiness=ready, startup=135, grace=12):
    # Distinct sessions let us clean descendants after either leader crashes.
    # On Linux adopt orphan grandchildren too, so cleanup can reap them.
    if sys.platform == "linux":
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
            raise OSError(ctypes.get_errno(), "cannot become child subreaper")
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    old_handlers = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    children = []
    try:
        # Explicit close_fds prevents fd3 reaching Python or its engine worker.
        adapter = subprocess.Popen(adapter_command, close_fds=True, start_new_session=True)
        children.append(adapter)
        deadline = time.monotonic() + startup
        while not stopping and adapter.poll() is None and not readiness():
            if time.monotonic() >= deadline:
                raise TimeoutError("Oracle adapter startup deadline")
            time.sleep(0.05)
        if stopping:
            return 0
        if adapter.poll() is not None:
            return adapter.returncode or 1
        bridge = subprocess.Popen(bridge_command, close_fds=True, pass_fds=(3,), start_new_session=True)
        children.append(bridge)
        while not stopping:
            for child in children:
                if child.poll() is not None:
                    return child.returncode or 1
            time.sleep(0.05)
        return 0
    finally:
        # Tell leaders first: the adapter owns graceful engine/journal shutdown.
        for child in reversed(children):
            if child.poll() is None:
                child.terminate()
        deadline = time.monotonic() + grace
        while any(child.poll() is None for child in children) and time.monotonic() < deadline:
            time.sleep(0.05)
        # Even a dead leader may have left children. These are only groups we made.
        for child in reversed(children):
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        for child in children:
            child.wait()
        if sys.platform == "linux":
            while True:
                try:
                    os.waitpid(-1, 0)
                except ChildProcessError:
                    break
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)


def main():
    if len(sys.argv) != 1:
        raise SystemExit("launcher accepts no arguments")
    with socket.fromfd(3, socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        if connection.family != socket.AF_UNIX or connection.getsockopt(socket.SOL_SOCKET, socket.SO_TYPE) != socket.SOCK_STREAM:
            raise SystemExit("fd3 must be the supervisor Unix stream")
        if not isinstance(connection.getpeername(), (str, bytes)):
            raise SystemExit("fd3 must be a Unix socket")
    os.chdir("/var")
    os.umask(0o077)
    # Mini binds the signed inventory and mounts it; this is only a useful
    # application startup check. The adapter also checks every required store.
    if Path("/minidregg-data.json").exists():
        data = Path("/opt/oracle-data")
        if data.is_symlink() or not data.is_dir():
            raise SystemExit("shared Oracle data directory is unavailable")
    return supervise(
        ["/usr/bin/python3.12", "-B", "/opt/oracle/adapter/serve.py",
         "--runtime", "/opt/oracle", "--data-root", "/opt/oracle/root",
         "--workspace", "/var/oracle-workspace", "--port", "7070",
         "--max-request-bytes", "65536",
         "--tenant-pool", "--max-resident", "1", "--max-tenants", "128"],
        ["/opt/oracle-bin/minidregg-oracle-appliance", "--port", "7070"],
    )


if __name__ == "__main__":
    sys.exit(main())

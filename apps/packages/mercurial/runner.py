#!/opt/python/bin/python3
"""Grain runner for the Mercurial (hgweb) Sandstorm app.

Prepares a per-grain repository collection under $HOME/repos, generates the
hgweb config, then serves the hgwebdir WSGI application on 127.0.0.1 behind
sandstorm-http-bridge. The hg wire protocol (clone/push/archive) is served
from the same URLs as the web UI, which is what the grain's `api` interface
(bridgeConfig.apiPath = "/") exposes.
"""
import os
import re
import socketserver
import subprocess
from wsgiref.simple_server import WSGIServer, WSGIRequestHandler

HG = "/opt/python/bin/hg"

PORT = int(os.environ.get("MERCURIAL_PORT", "8000"))


def grain_repo_name():
    title = os.environ.get("SANDSTORM_GRAIN_TITLE", "")
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", title).strip("-.")
    return slug or "repo"


def setup():
    home = os.environ.get("HOME", "/var")
    repos = os.path.join(home, "repos")
    os.makedirs(repos, exist_ok=True)
    config = os.path.join(home, "hgweb.conf")
    with open(config, "w") as f:
        f.write(
            "[web]\n"
            "push_ssl = False\n"
            "allow_push = *\n"
            "\n"
            "[collections]\n"
            "%s = %s\n" % (repos, repos)
        )
    first = os.path.join(repos, grain_repo_name())
    if not os.path.isdir(first):
        # A fresh `hg init` process keeps hgweb's registrar tables pristine
        # (mixing an in-process hg.repository with hgweb double-registers
        # commands) and mirrors the grain's PATH exactly.
        subprocess.run([HG, "init", first], check=True)
    return config


def main():
    config = setup()
    from mercurial.hgweb import hgwebdir

    application = hgwebdir(os.fsencode(config))

    class ThreadingWSGIServer(socketserver.ThreadingMixIn, WSGIServer):
        daemon_threads = True

    httpd = ThreadingWSGIServer(("127.0.0.1", PORT), WSGIRequestHandler)
    httpd.set_app(application)
    httpd.serve_forever(poll_interval=0.5)


if __name__ == "__main__":
    main()
